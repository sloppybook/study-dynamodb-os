#!/bin/bash

echo "🚀 DynamoDB CDC テスト環境を起動します"

# Docker Composeでサービスを起動
echo "📦 Docker Composeサービスを起動中..."
docker-compose up -d

# サービスが起動するまで待機
echo "⏳ サービス起動を待機中..."
sleep 30

# ヘルスチェック
echo "🔍 サービス状態を確認中..."
echo "LocalStack DynamoDB:"
curl -s http://localhost:4567 > /dev/null && echo "✅ LocalStack OK" || echo "❌ LocalStack NG"

echo "OpenSearch:"
curl -s http://localhost:9201 > /dev/null && echo "✅ OpenSearch OK" || echo "❌ OpenSearch NG"

# テーブル作成
echo -e "\n📋 DynamoDBテーブルを作成中..."
./create-table.sh

# Data Prepperが起動するまで少し待機
echo "⏳ Data Prepperの起動を待機中..."
sleep 10

# データ操作テストを実行
echo -e "\n🧪 データ操作テストを実行中..."
./data-operations.sh

echo -e "\n🎉 テスト完了！"
echo "📊 OpenSearch Dashboards: http://localhost:5602"
echo "🔧 DynamoDB Admin: http://localhost:8002"