#!/bin/bash

# LocalStackのDynamoDB endpoint
ENDPOINT="http://localhost:4567"
TABLE_NAME="test-table"

echo "🚀 DynamoDBテーブルを作成しています..."

# テーブル作成リクエスト
curl -X POST \
  -H "Content-Type: application/x-amz-json-1.0" \
  -H "X-Amz-Target: DynamoDB_20120810.CreateTable" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=test/20240101/us-east-1/dynamodb/aws4_request, SignedHeaders=host;x-amz-date, Signature=test" \
  -d '{
    "TableName": "'$TABLE_NAME'",
    "KeySchema": [
      {
        "AttributeName": "id",
        "KeyType": "HASH"
      }
    ],
    "AttributeDefinitions": [
      {
        "AttributeName": "id",
        "AttributeType": "S"
      }
    ],
    "BillingMode": "PAY_PER_REQUEST",
    "StreamSpecification": {
      "StreamEnabled": true,
      "StreamViewType": "NEW_AND_OLD_IMAGES"
    }
  }' \
  $ENDPOINT

echo -e "\n✅ テーブル作成リクエストを送信しました"

# 少し待機してからテーブル情報を確認
echo "⏳ テーブル作成を待機中..."
sleep 3

# テーブル詳細を取得
echo "📋 テーブル詳細を取得しています..."
curl -X POST \
  -H "Content-Type: application/x-amz-json-1.0" \
  -H "X-Amz-Target: DynamoDB_20120810.DescribeTable" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=test/20240101/us-east-1/dynamodb/aws4_request, SignedHeaders=host;x-amz-date, Signature=test" \
  -d '{
    "TableName": "'$TABLE_NAME'"
  }' \
  $ENDPOINT | jq '.'

echo -e "\n🎉 テーブル作成完了！"
