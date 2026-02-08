# FocusSupport (Swift)

macOSメニューバー常駐の FocusSupport を Swift で実装した版です。
「今何考えてる？」と不定期に話しかけ、思考を促します。

## 特徴

- 🔔 **不定期チェックイン**: 1時間に1回、ランダムな時刻で通知
- 🧠 **簡易フィードバック**: ぼんやり/集中の簡易判定
- 📝 **思考ログ**: 今日のログをテキストで確認

## 動作要件

- macOS 12 以上
- Xcode 14+（または Swift 5.9+）

## 実行方法（ビルドスクリプト）

KeystrokeCounterと同じ方式で `.app` を生成します。

```bash
cd /Users/yurikoyamauchi/myapp/FocusSupportSwift
./build.sh
open .build/FocusSupport.app
```

## 使い方

- メニューバーの🧠アイコンをクリック
- 「今すぐ壁打ち」で入力
- 「今日のログを見る」で保存ログを開く
- 「設定」→「各種設定」で壁打ちウィンドウ/通知の画像を追加・変更（チェックインごとにランダム表示）

## ログ保存場所

`~/Library/Application Support/FocusSupport/focus_support_log.txt`

## 仕様

- **不定期通知**は「各時間帯に1回」で、時刻はランダムです。
- 通知と同時に入力ダイアログが開きます。

## 今後の拡張（例）

- Claude / OpenAI API連携
- 起動時自動開始（Login Items）
- 週次集計
