// AppKit - macOSのUIとグラフィックス機能を提供するフレームワーク
// NSImageなどの画像クラスを使用するために必要
import AppKit

// MARK: - 画像読み込みクラス
/*
 * クラス定義 - ImageLoaderという名前のクラスを定義
 * 画像ファイルの読み込みに特化した単一責任の設計
 */
class ImageLoader {
    /// 画像ファイルからCGImageを読み込む
    /// - Parameter path: 画像ファイルのパス
    /// - Returns: 読み込まれたCGImage
    /// - Throws: 画像読み込み失敗時にSuperResolutionError.imageLoadFailed
    /*
     * 上記は「ドキュメンテーションコメント」- Xcodeでは自動補完で表示される
     * throws キーワード - この関数が例外をスローする可能性があることを示す
     * -> CGImage - 戻り値の型がCGImageであることを示す型アノテーション
     */
    func loadImage(from path: String) throws -> CGImage {
        // guard-let パターン - 複数のオプショナル型の安全な展開
        // オプショナルチェーン - 一連のオプショナル処理を連結
        // let A = B, let C = D, ... - 複数条件の同時チェック
        guard let nsImage = NSImage(contentsOfFile: path),
              // tiffRepresentation - NSImageからTIFFデータ形式への変換
              let tiffData = nsImage.tiffRepresentation,
              // NSBitmapImageRep - ビットマップイメージの表現を扱うクラス
              let bitmap = NSBitmapImageRep(data: tiffData),
              // cgImage - CoreGraphicsイメージへの変換
              let cgImage = bitmap.cgImage else {
            // throw - 例外をスロー（Javaの throw new に相当）
            throw SuperResolutionError.imageLoadFailed
        }
        // 成功時は読み込まれたCGImageを返す
        return cgImage
    }
}
