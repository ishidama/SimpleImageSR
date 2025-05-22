#!/usr/bin/env python3
"""
PyTorch版RealESRGANの重みファイル（.pth）をCoreMLモデル（.mlpackage/.mlmodel）へ変換するスクリプト。

【特徴・設計方針】
- 入力: RGB画像 (uint8, 0-255, 解像度可変) → CoreML側で0-1正規化
- 出力: RGB画像 (float, 0-1, 解像度可変)
- 入出力ともRGB順、バッチ1枚、解像度はRangeDimで可変
- 出力はtorch.clampで0-1にクリップ保証
- コマンドライン引数で各種パラメータ指定可
- 変換失敗時は詳細エラー、成功時は保存先パスをprint

【利用例】
python convert_pth2coreml_new.py --pth weights/RealESRGAN_x4plus.pth --out output/RealESRGAN_x4plus.mlpackage --float16 --target mac --min-dim 64 --max-dim 2048
"""

import argparse
import sys

import coremltools as ct
import numpy as np
import torch
from basicsr.archs.rrdbnet_arch import RRDBNet
from coremltools.models.neural_network import quantization_utils

from coremltools.models.neural_network.quantization_utils import (
    /
)


class ClampedModel(torch.nn.Module):
    """
    PyTorchモデルの出力を0〜1にclampし ×255 で 0〜255 レンジへ変換するラッパー。
    CoreML変換時に値域外の出力を防ぐため必須。
    """

    def __init__(self, base_model):
        super().__init__()
        self.base_model = base_model

    def forward(self, x):
        """
        モデルのフォワードパス。

        引数:
            x (torch.Tensor): 入力テンソル。

        戻り値:
            torch.Tensor: 0から1の範囲にクランプされた後、255.0倍されたテンソル。

        注意:
            torch.clampは入力テンソルの全要素を[0.0, 1.0]の範囲内に制限します。
            0.0未満の値は0.0に、1.0より大きい値は1.0に設定されます。
            これにより、255を掛けた後も画像表現として有効な出力値であることが保証されます。
        """

        out = self.base_model(x)
        return torch.clamp(out, 0.0, 1.0) * 255.0


def load_rrdbnet(pth_path: str) -> torch.nn.Module:
    """
    RealESRGAN (RRDBNet) モデルを構築し、重みをロードする。
    - 入出力: RGB, float32, 0-1, (N,3,H,W)
    """
    model = RRDBNet(
        num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=4
    )
    ckpt = torch.load(pth_path, map_location="cpu")
    for key in ("params_ema", "params"):
        if key in ckpt:
            model.load_state_dict(ckpt[key], strict=True)
            break
    else:
        raise RuntimeError("params_ema または params キーが見つかりません")
    model.eval()
    return model


def main():
    parser = argparse.ArgumentParser(
        description="PyTorch RealESRGAN (.pth) → CoreML 変換ツール"
    )
    parser.add_argument("--pth", required=True, help="PyTorch重みファイルのパス")
    parser.add_argument("--out", required=True, help="出力CoreMLモデルのパス")
    parser.add_argument(
        "--float16", action="store_true", help="FP16精度で変換 (省略時はFP32)"
    )
    parser.add_argument(
        "--target",
        choices=["mac", "ios"],
        default="mac",
        help="デプロイターゲット(mac/ios)",
    )
    parser.add_argument(
        "--min-dim", type=int, default=64, help="最小解像度 (default: 64)"
    )
    parser.add_argument(
        "--max-dim", type=int, default=2048, help="最大解像度 (default: 2048)"
    )
    parser.add_argument(
        "--trace-size",
        type=int,
        default=64,
        help="トレース用ダミー画像サイズ (default: 64)",
    )
    args = parser.parse_args()

    try:
        # 1. モデル構築・重みロード
        model = load_rrdbnet(args.pth)
        model = ClampedModel(model)  # 出力を0-1にclampするラッパー

        # 2. 入力・出力仕様を定義
        input_desc = ct.ImageType(
            name="input_image",
            shape=ct.Shape(
                shape=(
                    1,
                    3,
                    ct.RangeDim(args.min_dim, args.max_dim),  # 高さ
                    ct.RangeDim(args.min_dim, args.max_dim),  # 幅
                )
            ),
            color_layout=ct.colorlayout.BGR,
            bias=[0.0, 0.0, 0.0],
            scale=1 / 255.0,  # uint8→float32(0-1)
        )
        # mlprogram形式では出力ImageTypeのscale指定は無効。float32(0-1)出力となる
        output_desc = ct.ImageType(
            name="output_image",
            color_layout=ct.colorlayout.BGR,
        )

        # 3. 変換オプション
        precision = ct.precision.FLOAT16 if args.float16 else ct.precision.FLOAT32
        target_map = {"mac": ct.target.macOS14, "ios": ct.target.iOS17}
        conversion_options = {
            "source": "pytorch",
            "inputs": [input_desc],
            "outputs": [output_desc],
            "convert_to": "mlprogram",
            "minimum_deployment_target": target_map[args.target],
            "compute_precision": precision,
            "compute_units": ct.ComputeUnit.ALL,
        }

        # 4. トレース用ダミー入力
        example_input = torch.rand(
            1, 3, args.trace_size, args.trace_size, dtype=torch.float32
        )
        traced = torch.jit.trace(model, example_input)

        # 5. CoreML変換
        print("[INFO] 入力: RGB, uint8, 0-255 → CoreMLで0-1正規化 (scale=1/255.0)")
        print("[INFO] 出力: RGB, float32, 0-255 (ImageType で即 PNG/JPEG 保存可能)")
        print(
            "[INFO] 入力shape: (1,3,H,W) 可変範囲: {}-{}px".format(
                args.min_dim, args.max_dim
            )
        )

        mlmodel = ct.convert(traced, **conversion_options)
        print(f"DEBUG: Type of mlmodel after conversion: {type(mlmodel)}")
        print(f"DEBUG: Value of mlmodel after conversion: {mlmodel}")

        # 5.1 量子化オプション
        if args.float16:
            print("[INFO] FP16精度で変換")
            mlmodel = quantization_utils.quantize_weights(mlmodel, nbits=16)
    
        # 6. CoreMLモデルの保存
        print(f"Saving CoreML model to {args.out}")
        mlmodel.save(args.out)

        print("Conversion complete.")
    except Exception as e:
        print(f"❌ 変換エラー: {e}", file=sys.stderr)
        import traceback

        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
