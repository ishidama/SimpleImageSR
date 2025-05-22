#!/usr/bin/env python3
import argparse
import os
import time  # 時間計測用にtimeモジュールを追加

import coremltools as ct
import matplotlib.pyplot as plt
import numpy as np
from PIL import Image


def load_image(path):
    """画像ファイルをRGB PIL.Imageとして読み込む"""
    img = Image.open(path).convert("RGB")
    return img


def save_image(arr, path):
    """
    モデル出力を画像として保存する。
    - Image.Image型のみをサポート
    - 値域がfloatなら255倍してuint8へ変換し保存
    """
    if isinstance(arr, Image.Image):
        img = np.array(arr)
        if img.max() <= 1.0:
            img = (img * 255.0).clip(0, 255).astype(np.uint8)
        else:
            img = np.clip(img, 0, 255).astype(np.uint8)
        Image.fromarray(img).save(path)
    else:
        raise TypeError(
            f"サポート対象外の型です: {type(arr)}。Image.Imageインスタンスが必要です。"
        )


def main():
    p = argparse.ArgumentParser()
    p.add_argument("model", help=".mlpackage or .mlmodel")
    p.add_argument("input", help="入力画像ファイル (jpg/png)")
    p.add_argument("output", help="出力画像ファイル (png)")
    p.add_argument(
        "--hist-dir", default="output", help="ヒストグラム画像の保存ディレクトリ"
    )
    args = p.parse_args()

    # モデル読み込み
    try:
        mlmodel = ct.models.MLModel(args.model)
    except Exception as e:
        print(f"❌ モデルの読み込みに失敗しました: {e}")
        return

    # 画像読み込み
    inp = load_image(args.input)

    # 推論
    try:
        # 推論の直前で時間計測開始
        start_time = time.time()

        result = mlmodel.predict({"input_image": inp})

        # 推論の直後で時間計測終了
        end_time = time.time()
        inference_time = (end_time - start_time) * 1000  # ミリ秒単位に変換
        print(f"推論時間: {inference_time:.2f} ms")

    except Exception as e:
        print(f"❌ モデル推論中にエラー: {e}")
        return

    # 出力キー名の自動検出（出力がoutput_image以外の場合にも対応）
    if "output_image" in result:
        out = result["output_image"]
        out_key = "output_image"
    else:
        # 最初のキーを自動取得
        out_key = next(iter(result.keys()))
        print(f"DEBUG: Output key found: {out_key}")
        out = result[out_key]

    # 出力が Image.Image インスタンスであることを確認
    if not isinstance(out, Image.Image):
        raise TypeError(
            f"モデル出力の型が Image ではありません: {type(out)} が返されました。CoreMLモデルが ImageType で出力するように設定されているか確認してください。"
        )

    print(
        f"DEBUG: Type of 'out' (model prediction result for key '{out_key}'): {type(out)}"
    )
    if isinstance(out, Image.Image):
        print(f"DEBUG: Pillow Image mode: {out.mode}")
        _debug_img_np = np.array(out)
        print(
            f"DEBUG: np.array(out) -> dtype: {_debug_img_np.dtype}, shape: {_debug_img_np.shape}, min: {_debug_img_np.min():.4f}, max: {_debug_img_np.max():.4f}, mean: {_debug_img_np.mean():.4f}"
        )

    # 出力値の情報を表示
    out_np = np.array(out)
    print(
        "出力値 min:",
        out_np.min(),
        "max:",
        out_np.max(),
        "dtype:",
        out_np.dtype,
        "shape:",
        out_np.shape,
    )

    # --- 追加: float値のままの分布を保存 ---
    if np.issubdtype(out_np.dtype, np.floating):
        np.save(os.path.join(args.hist_dir, "output_float.npy"), out_np)
        print(f"float値のまま保存: {os.path.join(args.hist_dir, 'output_float.npy')}")
        print(
            "float値 min:", out_np.min(), "max:", out_np.max(), "mean:", out_np.mean()
        )
        plt.figure()
        plt.hist(out_np.flatten(), bins=100, range=(0, 1))
        plt.title("Output Float Value Histogram (0-1)")
        plt.xlabel("Value")
        plt.ylabel("Count")
        plt.savefig(os.path.join(args.hist_dir, "hist_output_float.png"))
        print(
            f"✅ float値ヒストグラムを保存しました: {os.path.join(args.hist_dir, 'hist_output_float.png')}"
        )

    # 保存
    # --- 修正: Imageインスタンスのみ処理 ---
    # outはすでにImage.Imageインスタンスであることが確認済み
    img = np.array(out)
    if img.max() <= 1.0:
        img = (img * 255.0).clip(0, 255).astype(np.uint8)
    else:
        img = np.clip(img, 0, 255).astype(np.uint8)
    Image.fromarray(img).save(args.output)
    print(f"✅ 出力を保存しました: {args.output}")

    # ヒストグラム保存用ディレクトリの自動生成
    os.makedirs(args.hist_dir, exist_ok=True)
    hist_path = os.path.join(args.hist_dir, "hist_output.png")

    # ヒストグラムを保存
    plt.figure()
    # 値域0-255, floatの場合でも255倍されている想定
    flat = out_np.flatten()
    if np.issubdtype(flat.dtype, np.floating):
        # float型なら0-1, 0-255, それ以外も考慮
        if flat.max() <= 1.0:
            plt.hist(flat * 255.0, bins=256, range=(0, 255))
        else:
            plt.hist(flat, bins=256, range=(0, 255))
    else:
        plt.hist(flat, bins=256, range=(0, 255))
    plt.title("Output Image Histogram")
    plt.xlabel("Pixel Value")
    plt.ylabel("Count")
    plt.savefig(hist_path)
    print(f"✅ ヒストグラムを保存しました: {hist_path}")


if __name__ == "__main__":
    main()
