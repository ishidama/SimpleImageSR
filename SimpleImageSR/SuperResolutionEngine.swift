// 基本データ型、入出力などの機能を提供
import Foundation
// CoreML - Appleの機械学習フレームワーク
// MLModelなどの機械学習モデル処理クラスを提供
import CoreML

// MARK: - 超解像エンジンクラス
/*
 * Core MLモデルを使用した画像超解像処理を担当するクラス
 * 画像をより高解像度にアップスケーリングする機能を提供
 */
class SuperResolutionEngine {
    // privateプロパティ - このクラス内でのみアクセス可能
    // let（定数）で宣言されたプロパティは値の変更ができない
    private let model: MLModel    // CoreMLモデルのインスタンス
    private let inputKey: String  // モデル入力のキー名
    // varで宣言されたプロパティは値を変更可能
    private var outputKey: String // モデル出力のキー名（自動検出で更新可能）
    
    /// 初期化
    /// - Parameters:
    ///   - modelURL: モデルファイルのURL
    ///   - inputKey: モデル入力キー名
    ///   - outputKey: モデル出力キー名（デフォルト値は自動検出可能）
    /*
     * イニシャライザ - クラスのインスタンスを初期化するメソッド
     * throws - 初期化時に例外がスローされる可能性あり
     * デフォルト引数値 - 引数に指定がない場合に使用される値
     * （例：input_imageやoutput_imageはデフォルト値として設定）
     */
    init(modelURL: URL, inputKey: String = "input_image", outputKey: String = "output_image") throws {
        // FileManager - ファイルシステム操作のためのクラス
        // default - シングルトンインスタンスを取得（Javaの static メンバーに相当）
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            // モデルファイルが存在しない場合はエラーをスロー
            throw SuperResolutionError.modelNotFound(path: modelURL.path)
        }
        
        // try - 例外をスローする可能性のある処理
        // MLModel(contentsOf:) - Core MLモデルをロード
        // モデルのロードに失敗する可能性があるので try キーワードが必要
        self.model = try MLModel(contentsOf: modelURL)
        self.inputKey = inputKey
        self.outputKey = outputKey
    }
    
    /// 画像処理を実行
    /// - Parameter pixelBuffer: 入力PixelBuffer
    /// - Returns: 処理後のPixelBuffer
    /// - Throws: 処理失敗時にエラー
    func process(_ pixelBuffer: CVPixelBuffer) throws -> CVPixelBuffer {
        // MLDictionaryFeatureProvider - CoreML入力を辞書形式で提供
        // [キー: 値] - Swiftの辞書リテラル構文
        let input = try MLDictionaryFeatureProvider(dictionary: [inputKey: pixelBuffer])
        
        // model.prediction - CoreMLモデルの推論実行
        // 推論処理は計算負荷が大きいため、失敗する可能性も考慮
        let output = try model.prediction(from: input)
        
        // featureNames - 出力に含まれる特徴量名（キー）の配列
        print("利用可能な出力キー: \(output.featureNames)")
        
        // if let + 条件 - オプショナルの安全な展開と追加条件判定
        // firstはOptionalを返す（空配列の場合はnil）
        if let firstKey = output.featureNames.first, outputKey == "output_image" {
            // デフォルトのキー名を使っていた場合は、モデルの実際のキー名に更新
            outputKey = firstKey
            print("出力キーを自動検出: \(outputKey)")
        }
        
        // モデルの出力から画像データを取得
        // featureValue(for:) - 指定したキーの出力値を取得
        // imageBufferValue - MLFeatureValueから画像バッファを取得（失敗するとnil）
        guard let outPixelBuffer = output.featureValue(for: outputKey)?.imageBufferValue else {
            throw SuperResolutionError.outputImageNotAvailable
        }
        
        // 処理された画像バッファを返す
        return outPixelBuffer
    }
}
