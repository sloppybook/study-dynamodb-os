#!/bin/bash

echo "=== 📊 CDC システムテスト開始 ==="

# システム状況の確認
echo "🔧 システム状況の確認..."
echo "Lambda関数一覧:"
awslocal lambda list-functions --query 'Functions[].FunctionName' --output table

echo "📊 Event Source Mappingの状態:"
awslocal lambda list-event-source-mappings --function-name dynamodb-cdc-handler --query 'EventSourceMappings[0].{State:State,LastProcessingResult:LastProcessingResult}' --output table

echo "📋 現在のOpenSearchインデックス:"
curl -s "http://opensearch:9200/_cat/indices?v"

echo -e "\n=== 🧪 Lambda関数の手動テスト ==="
echo "🔬 Lambda関数を手動でテスト実行..."
awslocal lambda invoke \
  --function-name dynamodb-cdc-handler \
  --payload '{"Records":[{"eventName":"INSERT","dynamodb":{"Keys":{"id":{"S":"manual-test"}},"NewImage":{"id":{"S":"manual-test"},"name":{"S":"手動テスト"}}}}]}' \
  response.json

echo "📋 Lambda関数の応答:"
RESPONSE_CONTENT=$(cat response.json 2>/dev/null || echo "レスポンスファイルが見つかりません")
echo "$RESPONSE_CONTENT"

# エラーチェック
if echo "$RESPONSE_CONTENT" | grep -q "errorMessage"; then
  echo "❌ Lambda関数でエラーが発生しました。修正が必要です。"
  echo "🔧 エラー詳細:"
  echo "$RESPONSE_CONTENT" | grep -o '"errorMessage":"[^"]*"' || echo "エラーメッセージの詳細取得に失敗"

  echo -e "\n🛠️ トラブルシューティング:"
  echo "1. Lambda関数のログを確認してください"
  echo "2. コンテナを再起動してください: docker compose down -v && docker compose up -d"
  echo "3. ネットワーク接続を確認してください"

  # 基本的な診断を実行
  echo -e "\n🔍 基本診断:"
  echo "OpenSearch接続テスト:"
  curl -s "http://opensearch:9200/_cluster/health" | head -3 || echo "OpenSearchに接続できません"

  return 1
else
  echo "✅ Lambda関数は正常に実行されました"
fi

echo -e "\n⏳ 手動テスト結果の確認を待機中..."
sleep 5

echo "🔍 手動テスト後のOpenSearchデータ:"
curl -s "http://opensearch:9200/dynamodb-cdc/_search?pretty" 2>/dev/null || echo "インデックスがまだ作成されていません"

echo -e "\n=== 🔄 リアルタイムCDCテスト ==="

# 新規レコード挿入
echo "1️⃣ レコード挿入テスト..."
awslocal dynamodb put-item --table-name test-table --item '{"id":{"S":"cdc-test-001"},"name":{"S":"CDCユーザー1"},"email":{"S":"cdc1@example.com"}}'
awslocal dynamodb put-item --table-name test-table --item '{"id":{"S":"cdc-test-002"},"name":{"S":"CDCユーザー2"},"email":{"S":"cdc2@example.com"}}'
echo "✅ 2件のレコードを挿入しました"
sleep 15

# レコード更新
echo -e "\n2️⃣ レコード更新テスト..."
awslocal dynamodb update-item --table-name test-table --key '{"id":{"S":"cdc-test-001"}}' --update-expression "SET #name = :name" --expression-attribute-names '{"#name":"name"}' --expression-attribute-values '{":name":{"S":"CDCユーザー1（更新済み）"}}'
echo "✅ レコードを更新しました"
sleep 15

# レコード削除
echo -e "\n3️⃣ レコード削除テスト..."
awslocal dynamodb delete-item --table-name test-table --key '{"id":{"S":"cdc-test-002"}}'
echo "✅ レコードを削除しました"
sleep 15

# 最終結果確認
echo -e "\n=== 📊 最終結果 ==="

echo "📊 OpenSearchのドキュメント数:"
OPENSEARCH_COUNT=$(curl -s "http://opensearch:9200/dynamodb-cdc/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d':' -f2)

echo -e "\n🎯 CDC動作結果:"
if [ -n "$OPENSEARCH_COUNT" ] && [ "$OPENSEARCH_COUNT" -gt 0 ]; then
    echo "✅ 成功: OpenSearchに $OPENSEARCH_COUNT 件のイベントが同期されました"
    echo "🔄 CDCシステムは正常に動作しています！"

    echo -e "\n🔍 同期されたデータの確認:"
    curl -s "http://opensearch:9200/dynamodb-cdc/_search?size=10&pretty" 2>/dev/null || echo "データ表示に失敗"
else
    echo "❌ 失敗: OpenSearchにデータが同期されていません"
    echo "🛠️ docker compose down -v && docker compose up -d で再起動してください"
fi

echo -e "\n✅ CDC システムテスト完了"