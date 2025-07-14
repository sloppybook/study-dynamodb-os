#!/bin/bash

# LocalStackのDynamoDB endpoint
ENDPOINT="http://localhost:4567"
TABLE_NAME="test-table"

# 共通ヘッダー
HEADERS=(
  -H "Content-Type: application/x-amz-json-1.0"
  -H "Authorization: AWS4-HMAC-SHA256 Credential=test/20240101/us-east-1/dynamodb/aws4_request, SignedHeaders=host;x-amz-date, Signature=test"
)

# 現在のタイムスタンプを生成
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ITEM_ID="test_${TIMESTAMP}"

echo "🚀 DynamoDB データ操作テストを開始します"
echo "=" * 50

# 1. アイテムを挿入
echo -e "\n1️⃣ 新しいアイテムを挿入"
curl -X POST \
  "${HEADERS[@]}" \
  -H "X-Amz-Target: DynamoDB_20120810.PutItem" \
  -d '{
    "TableName": "'$TABLE_NAME'",
    "Item": {
      "id": {"S": "'$ITEM_ID'"},
      "name": {"S": "テストアイテム_'$TIMESTAMP'"},
      "value": {"N": "100"},
      "category": {"S": "test_category"},
      "created_at": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}
    }
  }' \
  $ENDPOINT

echo -e "\n✅ アイテムを挿入しました: $ITEM_ID"

# 少し待機（CDC処理のため）
echo "⏳ CDC処理を待機中..."
sleep 3

# 2. アイテムを取得
echo -e "\n2️⃣ アイテムを取得"
curl -X POST \
  "${HEADERS[@]}" \
  -H "X-Amz-Target: DynamoDB_20120810.GetItem" \
  -d '{
    "TableName": "'$TABLE_NAME'",
    "Key": {
      "id": {"S": "'$ITEM_ID'"}
    }
  }' \
  $ENDPOINT | jq '.'

# 3. アイテムを更新
echo -e "\n3️⃣ アイテムを更新"
NEW_VALUE=$((RANDOM % 1000))
curl -X POST \
  "${HEADERS[@]}" \
  -H "X-Amz-Target: DynamoDB_20120810.UpdateItem" \
  -d '{
    "TableName": "'$TABLE_NAME'",
    "Key": {
      "id": {"S": "'$ITEM_ID'"}
    },
    "UpdateExpression": "SET #v = :val, #n = :name, #u = :updated",
    "ExpressionAttributeNames": {
      "#v": "value",
      "#n": "name",
      "#u": "updated_at"
    },
    "ExpressionAttributeValues": {
      ":val": {"N": "'$NEW_VALUE'"},
      ":name": {"S": "更新済み_'$ITEM_ID'"},
      ":updated": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}
    },
    "ReturnValues": "ALL_NEW"
  }' \
  $ENDPOINT | jq '.'

echo -e "\n✅ アイテムを更新しました: $ITEM_ID (新しい値: $NEW_VALUE)"

# 少し待機（CDC処理のため）
echo "⏳ CDC処理を待機中..."
sleep 3

# 4. 全アイテムをスキャン
echo -e "\n4️⃣ 全アイテムをスキャン"
curl -X POST \
  "${HEADERS[@]}" \
  -H "X-Amz-Target: DynamoDB_20120810.Scan" \
  -d '{
    "TableName": "'$TABLE_NAME'"
  }' \
  $ENDPOINT | jq '.Items[] | {id: .id.S, name: .name.S, value: .value.N}'

# 5. OpenSearchでの同期確認
echo -e "\n5️⃣ OpenSearchでの同期確認"
curl -X GET "http://localhost:9201/dynamodb-cdc/_doc/$ITEM_ID" | jq '.'

# 6. アイテムを削除
echo -e "\n6️⃣ アイテムを削除"
curl -X POST \
  "${HEADERS[@]}" \
  -H "X-Amz-Target: DynamoDB_20120810.DeleteItem" \
  -d '{
    "TableName": "'$TABLE_NAME'",
    "Key": {
      "id": {"S": "'$ITEM_ID'"}
    }
  }' \
  $ENDPOINT

echo -e "\n✅ アイテムを削除しました: $ITEM_ID"

# 少し待機（CDC処理のため）
echo "⏳ CDC処理を待機中..."
sleep 3

# 7. 削除後の確認
echo -e "\n7️⃣ 削除後の確認"
echo "DynamoDBから確認:"
curl -X POST \
  "${HEADERS[@]}" \
  -H "X-Amz-Target: DynamoDB_20120810.GetItem" \
  -d '{
    "TableName": "'$TABLE_NAME'",
    "Key": {
      "id": {"S": "'$ITEM_ID'"}
    }
  }' \
  $ENDPOINT | jq '.'

echo -e "\nOpenSearchから確認:"
curl -X GET "http://localhost:9201/dynamodb-cdc/_doc/$ITEM_ID" | jq '.'

echo -e "\n✅ データ操作テスト完了！"