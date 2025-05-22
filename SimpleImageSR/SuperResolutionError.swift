// Swiftの標準ライブラリ - 基本データ型、コレクション、入出力などの機能を提供
import Foundation

// MARK: - エラー定義
/*
 * enum - 列挙型の定義
 * Error, LocalizedError - プロトコルの採用（Javaのインターフェース実装に相当）
 * Error - Swiftの標準エラープロトコルで、try-catchで扱える例外となる
 * LocalizedError - ユーザー向けのエラーメッセージを提供するためのプロトコル
 */
enum SuperResolutionError: Error, LocalizedError {
    // 列挙型のケース定義 - 各種エラーの種類を表す
    case imageLoadFailed
    case pixelBufferCreationFailed
    // 関連値付きのケース - エラーに追加情報を保持できる（Javaにはない概念）
    case modelNotFound(path: String)
    case outputImageNotAvailable
    case pngConversionFailed
    
    // 計算プロパティ - LocalizedErrorプロトコルの要件
    // String? はOptional<String>型（値がnilの可能性がある）
    var errorDescription: String? {
        // switchによるパターンマッチング - 列挙型のケースごとに処理を分岐
        switch self {
        case .imageLoadFailed:
            return "画像の読み込みに失敗しました"
        case .pixelBufferCreationFailed:
            return "CVPixelBuffer変換に失敗しました"
        // 関連値の取り出し - path変数に格納される
        case .modelNotFound(let path):
            // 文字列補間 - 変数の値を文字列に埋め込む
            return "モデルが見つかりません: \(path)"
        case .outputImageNotAvailable:
            return "出力画像が取得できません（pixelBufferValue）"
        case .pngConversionFailed:
            return "PNG保存用データ生成に失敗しました"
        }
    }
}
