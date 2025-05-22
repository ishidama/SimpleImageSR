# CoreML-RealESRGAN CLI

macOS 向け Core ML 版 **RealESRGAN_x4plus** を使って  
画像を超解像（SR, Super-Resolution）するシンプルなコマンドラインツールです。  
変換スクリプトで生成した **FP16-MLProgram** モデルを呼び出し推論します。

## 更新履歴
- 2023/5/22
    - とりあえず動くようになったので保存と、githubの使いかたの練習を兼ねて公開

## 今後の予定
- フォルダ指定時の一括処理および、--sufix オプションの追加

---
## 特長

| 項目 | 説明 |
| ---- | ---- |
| **入力** | PNG/JPEG などの RGB 画像（解像度可変） |
| **出力** | 4× に拡大された PNG（BGRA, sRGB） |
| **モデル** | `RealESRGAN_x4plus.mlmodelc`（FP16・MLProgram） |
| **速度** | Apple Silicon M-series で ≒ 0.6 s / 256×256px（参考値） |
| **依存** | macOS 14 以降 / Xcode 15 以降 |

---

## ファイル構成
```
SimpleImageSR/          Xcode プロジェクト
├── main.swift       … CLI エントリポイント
├── ImageConverter.swift     … 画像変換ユーティリティ
├── ImageLoader.swift        … 画像読み込み処理
├── ImageSaver.swift         … 画像保存処理
├── SuperResolutionEngine.swift  … 超解像エンジンコア
├── SuperResolutionError.swift   … エラー定義
├── RealESRGAN_x4plus.mlpackage/   … Core ML (FP16) モデル
├── readme.md        … このファイル (日本語)
└── README_en.md     … 英語版README
scripts/
├── quick_sr.py      … RealESRGAN x4+のCoreML版モデルをcoremltoolsで利用するテスト用スクリプト
└── convert_pth2coreml_new.py     … PyTorch → CoreML 変換スクリプト
```

## ビルド & 実行

```bash
# 1) モデル変換（初回のみ）
python scripts/convert_pth2coreml_new.py \
  --pth weights/RealESRGAN_x4plus.pth \
  --out SimpleImageSR/RealESRGAN_x4plus.mlpackage \
  --float16 --target mac

# 2) Xcode で build（Release でも Debug でも可）

# 3) 画像を推論
./SimplePhotoSR input.png output.png
```
 
### モデルの前提
- PyTorch で学習した Real-ESRGAN x4+ モデルを CoreML 形式に変換して利用しています。変換については [convert_pth2coreml_new.py](scripts/convert_pth2coreml_new.py) を参照してください。

---

## Acknowledgements

This project is a lightweight Core ML wrapper around the excellent **[Real‑ESRGAN](https://github.com/xinntao/Real-ESRGAN)** by Xintao et al.  
All credit for the underlying super‑resolution model architecture and pretrained weights belongs to the Real‑ESRGAN authors and community contributors.

---

## ライセンス

このプロジェクトは MIT ライセンスのもとで公開されています。
詳細は `LICENSE` ファイルをご覧ください。

同梱の Real-ESRGAN モデルおよび重みは、元の [Real-ESRGAN ライセンス](https://github.com/xinntao/Real-ESRGAN/blob/master/LICENSE) に従います。
