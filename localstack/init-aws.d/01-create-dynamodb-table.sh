#!/bin/bash

echo "=== DynamoDBテーブル初期化開始 ==="

# DynamoDBテーブル作成
awslocal dynamodb create-table \
  --table-name test-table \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --stream-specification StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES \
  --billing-mode PAY_PER_REQUEST

echo "テーブル 'test-table' を作成しました"

# Point-in-Time Recovery (PITR) を有効化
echo "📊 Point-in-Time Recovery を有効化中..."
awslocal dynamodb update-continuous-backups \
  --table-name test-table \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true

echo "✅ PITR が有効化されました"

# テーブル作成確認
echo "作成されたテーブル一覧:"
awslocal dynamodb list-tables

# PITRの状態確認
echo "📋 PITR の状態確認:"
awslocal dynamodb describe-continuous-backups --table-name test-table

echo "=== DynamoDBテーブル初期化完了 ==="