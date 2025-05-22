// 基本的なデータ型やファイル操作のためのフレームワーク
import Foundation
// macOS向けのグラフィックスフレームワーク
import AppKit

// MARK: - 画像変換クラス
/*
 * 画像フォーマット変換に特化したクラス
 * 主にCGImage（Core Graphics Image）とCVPixelBuffer（Core Video Pixel Buffer）間の変換を担当
 * Core ML推論に必要なフォーマット変換を行う
 */
class ImageConverter {
    /// CGImageからCVPixelBufferに変換する
    /// - Parameter cgImage: 変換元のCGImage
    /// - Returns: 変換後のCVPixelBuffer
    /// - Throws: 変換失敗時にSuperResolutionError.pixelBufferCreationFailed
    func createPixelBuffer(from cgImage: CGImage) throws -> CVPixelBuffer {
        // 画像の幅と高さを取得
        // CGImageのwidth/heightプロパティはピクセル単位のサイズを返す
        let width = cgImage.width
        let height = cgImage.height
        
        // PixelBuffer作成のための属性辞書
        // CFDictionary - Core Foundation辞書型（Objective-C由来のデータ型）
        // as CFDictionary - SwiftのディクショナリをCFDictionaryにキャスト
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,  // CGImageとの互換性を確保
            kCVPixelBufferCGBitmapContextCompatibilityKey: true // CGBitmapContextとの互換性を確保
        ] as CFDictionary
        
        // CVPixelBuffer変数の宣言（初期値はnil）
        // var - 変更可能な変数（後で値が代入される）
        // ? - オプショナル型（nilが代入可能な型）
        var pxbuffer: CVPixelBuffer?
        
        // ピクセルバッファの作成
        // CVPixelBufferCreate - Core Videoフレームワークの関数
        // & - 変数のアドレスを渡す（C言語のポインタと同様）
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,  // デフォルトメモリアロケータ
            width,                // 幅
            height,               // 高さ
            // ⚠️ PixelFormat 選定について
            // 本来は kCVPixelFormatType_32RGBA (macOS 14 以降で正式追加) を使いたいが、
            // 実機の GPU / CoreVideo ドライバが対応していない場合は CVPixelBufferCreate が
            // kCVReturnInvalidPixelFormat (-6662) で失敗することがある。
            // そのため "古くから 100% 利用可能" な kCVPixelFormatType_32BGRA を採用し、
            // ・モデル変換時に color_layout = BGR へ設定    もしくは
            // ・Swift 側で R/B をスワップしてから推論
            // という形でチャンネル順を合わせている。
            // macOS 15 でも環境によって RGBA が確保できない事例が確認されているので、
            // 安定動作を優先して BGRA をデフォルトにしている。
            kCVPixelFormatType_32BGRA,  // ピクセル形式（青、緑、赤、アルファ）
            attrs,                // 属性辞書
            &pxbuffer            // 結果を格納するポインタ
        )
        
        // バッファの作成に成功したかチェック
        // status == kCVReturnSuccess - 関数が成功したかを確認
        // let buffer = pxbuffer - オプショナルバインディングでnilでないことを確認
        guard status == kCVReturnSuccess, let buffer = pxbuffer else {
            // 失敗した場合はエラーをスロー
            throw SuperResolutionError.pixelBufferCreationFailed
        }
        
        // ピクセルバッファのメモリをロック
        // バッファの内容を変更する前に必ずロックする必要がある
        // これにより、他のプロセスが同時にこのメモリにアクセスするのを防ぐ
        CVPixelBufferLockBaseAddress(buffer, [])
        
        /* -------------------------------------------------------------------------
           背景メモ：PixelFormat とチャネル順をめぐる経緯
           -------------------------------------------------------------------------
           ● 当初の設計
             - Core ML 変換時は color_layout = RGB（R,G,B の順）を想定。
             - Swift 側で RGBA (kCVPixelFormatType_32RGBA) の PixelBuffer を作り
               「R=byte0, G=byte1, B=byte2」でモデルに渡す計画だった。

           ● 問題①：32RGBA が確保できない Mac がある
             - RGBA は macOS 14 で公式追加されたが、ドライバ／GPU 世代によって
               CVPixelBufferCreate が 0xFFFFFFCE (kCVReturnInvalidPixelFormat) で失敗。
             - macOS 15 でも Intel Mac や古い Apple Silicon で同現象を確認。

           ● 問題②：BGRA のまま RGB モデルに渡すと R/B が反転
             - BGRA (=B,G,R,A) の byte0 は Blue。
             - color_layout = RGB のモデルは 「byte0=Red」と解釈 → 紫っぽい画像になる。

           ● 解決策
             1. PixelBuffer は "古くから 100% 動く" BGRA (kCVPixelFormatType_32BGRA) で生成。
             2. Core ML 変換時に color_layout = **BGR** を指定し、モデル側で
                  byte0=Blue, byte1=Green, byte2=Red とみなして学習時と一致させる。
             3. Swift の CGContext も BGRA 用に
                  premultipliedFirst + byteOrder32Little を選択。
             4. 出力も BGR → BGRA で返るので、画像保存時に追加スワップ処理は不要。

           ● これにより…
             - すべての macOS (10.15 以降) で PixelBuffer が確実に確保できる。
             - 色ズレ問題（赤↔青反転）が完全に解消。
             - Swift 側はシンプルな BGRA パイプラインのまま高速。

           ※ 将来 RGBA が安定したら pixelFormat / color_layout を戻しても良いが、
             BGRA + BGR の方が互換性・速度ともに無難なので当面この構成を採用する。
           ------------------------------------------------------------------------- */
           
        // グラフィックスコンテキスト生成
        // CGContext - Core Graphicsの描画コンテキスト（キャンバスのようなもの）
        let context = CGContext(
            // ピクセルバッファのメモリアドレス
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,        // 幅
            height: height,      // 高さ
            bitsPerComponent: 8, // 各色成分のビット数（8ビット = 0-255の値）
            // バッファの1行あたりのバイト数（ストライド）
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            // RGBカラースペース
            space: CGColorSpaceCreateDeviceRGB(),
            // ビットマップ情報（ピクセル形式を指定）
            // BGRA形式に合わせた設定
            // premultipliedFirst - アルファチャネルが最初に来る形式
            // byteOrder32Little - リトルエンディアン形式（一般的なIntelプロセッサ向け）
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        
        // コンテキスト生成成功のチェック
        guard let ctx = context else {
            // 失敗した場合はバッファをアンロックしてからエラーをスロー
            CVPixelBufferUnlockBaseAddress(buffer, [])
            throw SuperResolutionError.pixelBufferCreationFailed
        }
        
        // CGImageをコンテキストに描画
        // draw - 指定した領域に画像を描画
        // CGRect(x: 0, y: 0, width:, height:) - 描画領域を指定（原点は左上）
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // ピクセルバッファのメモリをアンロック
        // 操作が終わったらロックを解除。必ずペアで呼び出す必要がある
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        // 変換されたピクセルバッファを返す
        return buffer
    }
    
    /// PixelBufferのデバッグ情報を出力
    /// - Parameter buffer: 確認するPixelBuffer
    func logPixelBufferInfo(_ buffer: CVPixelBuffer) {
        // バッファのピクセルフォーマットを取得
        // フォーマットは整数値で返されるので、後で文字列に変換して表示
        let pixelFormat = CVPixelBufferGetPixelFormatType(buffer)
        
        // バッファの幅と高さを取得
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        
        // デバッグ情報をコンソールに出力
        print("PixelBuffer Info: format=\(pixelFormat), size=\(width)x\(height)")
    }
}
