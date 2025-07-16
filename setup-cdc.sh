#!/bin/bash

echo "🚀 DynamoDB CDCセットアップスクリプト"

# LocalStackとData Prepperが起動するまで待機
echo "⏳ サービスの起動を待機中..."
sleep 5

# DynamoDBテーブルの作成
echo "📊 DynamoDBテーブル 'test-table' を作成中..."
aws dynamodb create-table \
    --table-name test-table \
    --attribute-definitions \
        AttributeName=id,AttributeType=S \
    --key-schema \
        AttributeName=id,KeyType=HASH \
    --provisioned-throughput \
        ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --stream-specification \
        StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES \
    --endpoint-url http://localhost:4566 \
    --region us-east-1

echo "✅ テーブルが作成されました"

# S3バケットの作成（Data Prepperのエクスポート用）
echo "🪣 S3バケット 'data-prepper-export' を作成中..."
aws s3 mb s3://data-prepper-export \
    --endpoint-url http://localhost:4566 \
    --region us-east-1

echo "✅ S3バケットが作成されました"

# テストデータの挿入
echo "📝 テストデータを挿入中..."
for i in {1..5}; do
    aws dynamodb put-item \
        --table-name test-table \
        --item "{
            \"id\": {\"S\": \"item-$i\"},
            \"name\": {\"S\": \"テストアイテム$i\"},
            \"timestamp\": {\"N\": \"$(date +%s)\"},
            \"description\": {\"S\": \"これは$i番目のテストアイテムです\"}
        }" \
        --endpoint-url http://localhost:4566 \
        --region us-east-1

    echo "  - アイテム $i を挿入しました"
done

echo "🎉 セットアップ完了！"
echo ""
echo "📋 次のステップ："
echo "1. OpenSearchダッシュボードで CDC データを確認: http://localhost:9200/_cat/indices"
echo "2. Data Prepperメトリクス確認: http://localhost:4900"
echo "3. DynamoDBテーブルにデータを追加して CDC をテスト"
echo ""
echo "💡 CDCをテストするには以下のコマンドを実行："
echo "aws dynamodb put-item --table-name test-table --item '{\"id\": {\"S\": \"new-item\"}, \"name\": {\"S\": \"新しいアイテム\"}}' --endpoint-url http://localhost:4566"