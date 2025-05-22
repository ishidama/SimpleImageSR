// Foundationフレームワーク - ファイル操作などの基本機能を提供
import Foundation
// AppKitフレームワーク - macOS向けのグラフィック処理機能を提供
import AppKit

// MARK: - 画像保存クラス
/*
 * 画像保存に特化したクラス - 単一責任原則に基づく設計
 * CVPixelBufferからPNGファイルへの変換と保存を担当
 */
class ImageSaver {
    /// CVPixelBufferをPNGとして保存
    /// - Parameters:
    ///   - pixelBuffer: 保存するピクセルバッファ
    ///   - path: 保存先のパス
    /// - Throws: 保存失敗時にエラー
    /*
     * 第一引数の外部名が省略（_）されているため、呼び出し時はパラメータ名なしで渡せる
     * これはObjective-C由来の命名慣習で、第一引数の名前は関数名に暗黙的に含まれる
     * 例: saveImage(someBuffer, to: "path") のように呼び出される
     */
    func saveImage(_ pixelBuffer: CVPixelBuffer, to path: String) throws {
        // CVPixelBufferからCIImageへの変換
        // CIImage - Core Image フレームワークのイメージ表現
        // バッファから直接イメージを生成できる便利なイニシャライザ
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // NSBitmapImageRepへの変換 - macOSのビットマップ表現クラス
        // ファイル形式変換ができる便利なクラス
        let rep = NSBitmapImageRep(ciImage: ciImage)
        
        // PNG形式への変換
        // using: .png - 列挙型による形式指定（型安全）
        // properties: [:] - 空のディクショナリ（追加オプションなし）
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            // 変換失敗時にエラーをスロー
            throw SuperResolutionError.pngConversionFailed
        }
        
        // ファイル保存処理
        // URL(fileURLWithPath:) - 文字列パスからURLオブジェクトを作成
        // write(to:) - DataオブジェクトをURLで指定された場所に書き込む
        try pngData.write(to: URL(fileURLWithPath: path))
        // 成功メッセージの表示（文字列補間を使用）
        print("✅ 変換完了: \(path)")
    }
}
