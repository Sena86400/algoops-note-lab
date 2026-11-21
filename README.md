# algoops-note-lab

[AlgoOps Note](https://algo-ops-note.com) の検証記事で使っている、EAのソース、テスト設定、解析結果を置くリポジトリです。記事に載せた数値は、このリポジトリの `experiments/` にある結果から埋め込んでいます。同じ設定でテストを回せば、誰でも結果を確かめられます。

本リポジトリの内容は技術検証と学習の記録です。投資助言ではなく、利益を保証するものでもありません。EAはストラテジーテスターとデモ口座での利用を前提にしています。

## 構成

| パス | 内容 |
|---|---|
| `mql5/Experts/` | 検証用EAのソース。仕様は [mql5/README.md](mql5/README.md) |
| `experiments/<id>/experiment.yaml` | 実験の定義（目的、EA、通貨ペア、期間、パラメータ） |
| `experiments/<id>/results/` | テスト設定（`tester.ini`、`inputs.set`）と解析結果（`summary.json` など） |
| `pipeline/` | レポートを解析するスクリプト（準備中） |
| `.mcp.json` | MT5公式MCPサーバーへの接続設定（APIキーは環境変数から読む） |

MT5の生のレポートは、口座やサーバーの情報を含むためコミットしていません。

## 結果を再現する

1. MT5（Build 6230以上）をデモ口座で用意する
2. `mql5/Experts/` のEAをコンパイルし、`.ex5` をデータフォルダの `MQL5\Experts\AlgoOpsNote\` に置く
3. `experiments/<id>/results/tester.ini` と `inputs.set` をデータフォルダの `MQL5\Profiles\Tester\` に置き、ストラテジーテスターで読み込んで実行する

ブローカー、ヒストリーデータ、ビルドが違えば、結果は一致しないことがあります。

## 訂正と再現の報告

記事の誤りや、再現したときに結果が合わなかった場合は、[Issue](../../issues/new/choose) で知らせてください。投資助言、売買シグナル、個別の売買判断に関する質問には回答しません。

## ライセンス

コード、テスト設定、解析結果は [MIT License](LICENSE) です。AlgoOps Noteの記事本文と図は対象外で、著作権は運営者が保持します。
