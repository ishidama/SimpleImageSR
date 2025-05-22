// Swift標準ライブラリ - 基本的なデータ型、コレクション、入出力などの機能を提供
import Foundation
// MacOS向けのUI/グラフィックス機能を提供するフレームワーク - NSImageなどを使用するために必要
import AppKit
// ArgumentParserライブラリをインポート - コマンドライン引数の解析に使用
import ArgumentParser

// MARK: - コマンドライン引数解析用構造体
/*
 * ParsableCommand - ArgumentParserが提供するプロトコル
 * コマンドラインアプリケーションの引数定義とエントリポイントを提供
 */
struct SuperResolutionCommand: ParsableCommand {
    // コマンドの基本情報を定義
    static var configuration = CommandConfiguration(
        commandName: "core-ml-super-resolution",
        abstract: "CoreMLを使用した画像超解像アプリケーション",
        discussion: "指定された画像に対して機械学習モデルを使用して超解像処理を行います。"
    )
    
    // 入力ファイルオプション
    @Option(name: [.short, .long], help: "処理する入力画像のパス")
    var input: String
    
    // 出力ファイルオプション
    @Option(name: [.short, .long], help: "処理結果を保存する出力画像のパス")
    var output: String
    
    // モデルパスオプション（デフォルト値あり）
    @Option(name: .long, help: "使用するモデルファイルのパス（指定しない場合は実行ディレクトリの'RealESRGAN_x4plus.mlmodelc'を使用）")
    var model: String?
    
    // 実行メソッド - ParsableCommandプロトコルで必須
    func run() throws {
        let app = SuperResolutionApp()
        try app.process(inputPath: input, outputPath: output, modelPath: model)
    }
}

// MARK: - メインアプリケーションクラス
/*
 * Swiftのクラス定義 - Javaと似ていますが、アクセス修飾子の位置が異なります
 * デフォルトでは internal (同一モジュール内からアクセス可能)
 */
class SuperResolutionApp {
    // private - このプロパティはクラス内部でのみアクセス可能
    // let - 不変参照（定数）、値の再代入はできない（Javaのfinal変数に相当）
    private let imageLoader = ImageLoader()
    private let imageConverter = ImageConverter()
    private let imageSaver = ImageSaver()
    
    // メインプロセスメソッド
    func process(inputPath: String, outputPath: String, modelPath: String?) throws {
        // モデルパスの決定 - 指定がなければ実行ディレクトリから探す
        let modelURL: URL
        if let customPath = modelPath {
            modelURL = URL(fileURLWithPath: customPath)
        } else {
            // 実行ファイルのディレクトリを取得
            let exeURL = URL(fileURLWithPath: CommandLine.arguments[0])
            let exeDir = exeURL.deletingLastPathComponent()
            modelURL = exeDir.appendingPathComponent("RealESRGAN_x4plus.mlmodelc")
        }
        
        // モデルのロード
        let engine = try SuperResolutionEngine(modelURL: modelURL)
        
        // 画像処理を実行
        try processImage(from: inputPath, to: outputPath, using: engine)
    }
    
    // throws - この関数が例外をスローする可能性があることを示す
    // private - このクラス内でのみ呼び出し可能なメソッド
    private func processImage(from inputPath: String, to outputPath: String, using engine: SuperResolutionEngine) throws {
        // 画像読み込み - try キーワードは例外をスローする可能性のある操作の前に必要
        let cgImage = try imageLoader.loadImage(from: inputPath)
        
        // 画像のピクセルバッファへの変換
        let inputBuffer = try imageConverter.createPixelBuffer(from: cgImage)
        
        // 超解像処理の実行 - Core MLモデルによる推論
        let outputBuffer = try engine.process(inputBuffer)
        
        // ピクセルバッファ情報のログ出力（デバッグ用）
        imageConverter.logPixelBufferInfo(outputBuffer)
        
        // 処理結果の保存
        try imageSaver.saveImage(outputBuffer, to: outputPath)
    }
    
    // -> CVPixelBuffer - この関数の戻り値の型を明示
    // フレーム単位の処理用メソッド（将来の動画処理拡張用）
    func processFrame(cgImage: CGImage, using engine: SuperResolutionEngine) throws -> CVPixelBuffer {
        // CGImageをピクセルバッファに変換
        let inputBuffer = try imageConverter.createPixelBuffer(from: cgImage)
        
        // 超解像処理を実行して結果を返す
        return try engine.process(inputBuffer)
    }
}

// MARK: - エントリーポイント
// ArgumentParserを使用したメインエントリーポイント
SuperResolutionCommand.main()
