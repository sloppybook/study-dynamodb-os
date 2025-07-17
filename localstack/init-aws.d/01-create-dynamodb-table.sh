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

# テーブル作成確認
echo "作成されたテーブル一覧:"
awslocal dynamodb list-tables

echo "=== DynamoDBテーブル初期化完了 ==="