# 🔄 DynamoDB + OpenSearch CDC システム

LocalstackでDynamoDBとOpenSearchのChange Data Capture (CDC) システムを構築するプロジェクトです。
DynamoDBの全ての変更（INSERT/MODIFY/REMOVE）がリアルタイムでOpenSearchに同期されます。

## ✨ 特徴

- 🚀 **リアルタイム同期**: DynamoDB Streamsを使用した即座のデータ同期
- 🔄 **全操作対応**: INSERT、MODIFY、REMOVEの全ての操作をキャプチャ
- 📊 **履歴保持**: 更新前後のデータや削除されたデータも保持
- 🐳 **Docker完結**: ローカル環境で完全に動作
- 🛠️ **自動化**: ワンコマンドでセットアップとテストが可能

## 🏗️ システム構成

```
┌─────────────┐    ┌──────────────────┐    ┌─────────────┐    ┌──────────────┐
│ DynamoDB    │───▶│ DynamoDB Streams │───▶│ Lambda関数  │───▶│ OpenSearch   │
│ (Localstack)│    │                  │    │ (CDC Handler)│    │              │
└─────────────┘    └──────────────────┘    └─────────────┘    └──────────────┘
```

### 📦 コンポーネント

1. **DynamoDB**: メインデータストア（Streamsが有効）
2. **DynamoDB Streams**: データ変更を自動キャプチャ
3. **Lambda関数**: StreamイベントをOpenSearchに同期
4. **OpenSearch**: 同期されたデータの格納・検索
5. **Event Source Mapping**: StreamsとLambdaの連携

## 🚀 クイックスタート

```bash
# 🚀 ワンコマンドでCDCシステムを起動
docker compose up -d

# ⏳ 初期化完了まで待機（約30秒）
sleep 30

# ✅ 動作確認
docker exec -it localstack bash -c "cd /var/lib/localstack/scripts && ./test-cdc.sh"
```

**DynamoDBテーブル作成 → Lambda関数デプロイ → CDCセットアップがすべて自動で実行されます！**

## 📋 動作確認済み機能

### ✅ INSERT操作
```bash
# DynamoDBにレコード挿入
awslocal dynamodb put-item --table-name test-table --item '{"id":{"S":"user-001"},"name":{"S":"テストユーザー"}}'
```
→ OpenSearchに`INSERT`イベントとして記録

### ✅ MODIFY操作
```bash
# DynamoDBのレコード更新
awslocal dynamodb update-item --table-name test-table --key '{"id":{"S":"user-001"}}' --update-expression "SET #name = :name" --expression-attribute-names '{"#name":"name"}' --expression-attribute-values '{":name":{"S":"更新済みユーザー"}}'
```
→ OpenSearchに`MODIFY`イベントとして新旧データ両方を記録

### ✅ REMOVE操作
```bash
# DynamoDBのレコード削除
awslocal dynamodb delete-item --table-name test-table --key '{"id":{"S":"user-001"}}'
```
→ OpenSearchに`REMOVE`イベントとして削除データを記録

## 🔍 CDCデータ形式

OpenSearchに同期されるデータには、元のDynamoDBデータに加えて以下のメタデータが付与されます：

### INSERT イベント
```json
{
  "event_name": "INSERT",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "keys": {"id": {"S": "user-001"}},
  "data": {
    "id": {"S": "user-001"},
    "name": {"S": "テストユーザー"}
  }
}
```

### MODIFY イベント
```json
{
  "event_name": "MODIFY",
  "timestamp": "2024-01-01T12:05:00.000Z",
  "keys": {"id": {"S": "user-001"}},
  "new_data": {
    "id": {"S": "user-001"},
    "name": {"S": "更新済みユーザー"}
  },
  "old_data": {
    "id": {"S": "user-001"},
    "name": {"S": "テストユーザー"}
  }
}
```

### REMOVE イベント
```json
{
  "event_name": "REMOVE",
  "timestamp": "2024-01-01T12:10:00.000Z",
  "keys": {"id": {"S": "user-001"}},
  "deleted_data": {
    "id": {"S": "user-001"},
    "name": {"S": "更新済みユーザー"}
  }
}
```

## 🔧 基本操作

### OpenSearchでのデータ確認

```bash
# インデックス一覧
curl http://localhost:9200/_cat/indices?v

# CDCデータの検索
curl "http://localhost:9200/dynamodb-cdc/_search?pretty"

# 特定の操作タイプで検索
curl "http://localhost:9200/dynamodb-cdc/_search?q=event_name:INSERT&pretty"
curl "http://localhost:9200/dynamodb-cdc/_search?q=event_name:MODIFY&pretty"
curl "http://localhost:9200/dynamodb-cdc/_search?q=event_name:REMOVE&pretty"

# ドキュメント数の確認
curl "http://localhost:9200/dynamodb-cdc/_count?pretty"
```

### Lambda関数の確認

```bash
docker exec -it localstack bash

# Lambda関数一覧
awslocal lambda list-functions

# CDCトリガーの確認
awslocal lambda list-event-source-mappings --function-name dynamodb-cdc-handler

# Lambda関数のログ確認
awslocal logs describe-log-groups --log-group-name-prefix "/aws/lambda/dynamodb-cdc-handler"
```

### DynamoDBの確認

```bash
# テーブル一覧
awslocal dynamodb list-tables

# テーブルの詳細（Streams情報含む）
awslocal dynamodb describe-table --table-name test-table

# テーブルの全データ
awslocal dynamodb scan --table-name test-table
```

## 📁 プロジェクト構成

```
.
├── docker-compose.yml          # Docker Compose設定
├── localstack/
│   └── init-aws.d/
│       ├── 01-create-dynamodb-table.sh  # DynamoDBテーブル初期化
│       └── 02-setup-cdc.sh              # CDCセットアップ
├── scripts/
│   └── test-cdc.sh            # 包括的CDCテスト
└── README.md
```

## 🛠️ トラブルシューティング

### Lambda関数が実行されない場合

1. **DynamoDB Streamsの確認**
   ```bash
   awslocal dynamodb describe-table --table-name test-table --query 'Table.{StreamArn:LatestStreamArn,StreamEnabled:StreamSpecification.StreamEnabled}'
   ```

2. **Event Source Mappingの状態確認**
   ```bash
   awslocal lambda list-event-source-mappings --function-name dynamodb-cdc-handler
   ```

3. **Lambda関数の手動テスト**
   ```bash
   awslocal lambda invoke --function-name dynamodb-cdc-handler --payload '{"Records":[{"eventName":"INSERT","dynamodb":{"Keys":{"id":{"S":"test"}},"NewImage":{"id":{"S":"test"},"name":{"S":"テスト"}}}}]}' response.json
   ```

### OpenSearchにデータが同期されない場合

1. **OpenSearchの接続確認**
   ```bash
   curl http://localhost:9200/_cluster/health
   ```

2. **Lambda関数のログ確認**
   ```bash
   docker exec -it localstack bash
   LOG_STREAM=$(awslocal logs describe-log-streams --log-group-name "/aws/lambda/dynamodb-cdc-handler" --query 'logStreams[0].logStreamName' --output text)
   awslocal logs get-log-events --log-group-name "/aws/lambda/dynamodb-cdc-handler" --log-stream-name "$LOG_STREAM"
   ```

3. **ネットワーク接続の確認**
   ```bash
   docker exec -it localstack bash -c "curl -I http://opensearch:9200"
   ```

### システムが正常に動作しない場合

以下を確認してください：

1. **コンテナの再起動**: `docker compose down -v && docker compose up -d`
2. **初期化の待機**: システム起動後30秒程度待機
3. **ログの確認**: Lambda関数やDynamoDBのログを確認

## 📊 パフォーマンス情報

- **同期遅延**: 通常1-5秒以内
- **対応データ型**: DynamoDBの全データ型（String, Number, Binary, Set, Map, List, etc.）
- **バッチサイズ**: 10レコード/バッチ
- **再試行**: 自動（AWS Lambda標準）

## 🔄 システムの停止・再起動

### 停止
```bash
docker compose down -v
```

### 完全な再起動
```bash
# 既存システムの停止
docker compose down -v
rm -rf volume/

# 新規起動（自動でCDCセットアップが実行される）
docker compose up -d
sleep 30

# 動作確認
docker exec -it localstack bash -c "cd /var/lib/localstack/scripts && ./test-cdc.sh"
```

## 📚 参考資料

- [DynamoDB Streams](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html)
- [AWS Lambda Event Source Mappings](https://docs.aws.amazon.com/lambda/latest/dg/invocation-eventsourcemapping.html)
- [OpenSearch API](https://opensearch.org/docs/latest/api-reference/)
- [Localstack Documentation](https://docs.localstack.cloud/)

## 🎯 今後の拡張案

- 🔒 **エラーハンドリング**: DLQ（Dead Letter Queue）の実装
- 🔄 **フィルタリング**: 特定の操作やフィールドのみ同期
- 📊 **変換機能**: データ形式の変換・正規化

---

**✅ DynamoDB（Localstack）とOpenSearchのリアルタイムCDCシステムが完成しました！**
