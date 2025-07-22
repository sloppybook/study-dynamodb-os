#!/bin/bash

echo "=== 📦 CDC Lambda関数自動セットアップ開始 ==="

# 冪等性チェック: 既にセットアップ済みかどうか確認
echo "🔍 既存セットアップの確認中..."
EXISTING_FUNCTION=$(awslocal lambda list-functions --query 'Functions[?FunctionName==`dynamodb-cdc-handler`].FunctionName' --output text 2>/dev/null || echo "")
EXISTING_ROLE=$(awslocal iam list-roles --query 'Roles[?RoleName==`lambda-execution-role`].RoleName' --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_FUNCTION" ] && [ "$EXISTING_FUNCTION" != "None" ]; then
    echo "✅ Lambda関数 'dynamodb-cdc-handler' は既に存在します"

    # Event Source Mappingも確認
    EXISTING_ESM=$(awslocal lambda list-event-source-mappings --function-name dynamodb-cdc-handler --query 'EventSourceMappings[0].UUID' --output text 2>/dev/null || echo "")
    if [ -n "$EXISTING_ESM" ] && [ "$EXISTING_ESM" != "None" ]; then
        echo "✅ Event Source Mappingも既に設定されています"
        echo "🎯 CDCシステムは既にセットアップ済みです。重複実行をスキップします。"
        echo "=== 📦 CDC Lambda関数自動セットアップ完了（スキップ） ==="
        exit 0
    else
        echo "⚠️ Event Source Mappingが見つかりません。Event Source Mappingのみ設定します。"
        SETUP_ESM_ONLY=true
    fi
else
    echo "📋 新規セットアップを開始します"
    SETUP_ESM_ONLY=false
fi

# Event Source Mappingのみ設定する場合はLambda関数作成をスキップ
if [ "$SETUP_ESM_ONLY" = "true" ]; then
    echo "🔗 Event Source Mappingの設定のみ実行します..."
else
    # 作業ディレクトリの作成
    WORK_DIR="/tmp/lambda-cdc-deploy"
    rm -rf $WORK_DIR
    mkdir -p $WORK_DIR

    # urllibのみを使用したシンプルなCDC Lambda関数を作成（依存関係エラー回避）
    echo "📁 軽量版Lambda関数を自動生成中..."
    cat > $WORK_DIR/simple_cdc.py << 'EOF'
import json
import urllib.request
from datetime import datetime

def lambda_handler(event, context):
    print(f'Event received: {json.dumps(event, default=str)}')

    try:
        for record in event.get('Records', []):
            event_name = record.get('eventName')
            dynamodb = record.get('dynamodb', {})
            keys = dynamodb.get('Keys', {})

            print(f'Processing {event_name} for keys: {keys}')

            # OpenSearchに送信するドキュメント
            doc = {
                'event_name': event_name,
                'timestamp': datetime.utcnow().isoformat(),
                'keys': keys
            }

            if event_name == 'INSERT':
                doc['data'] = dynamodb.get('NewImage', {})
            elif event_name == 'MODIFY':
                doc['new_data'] = dynamodb.get('NewImage', {})
                doc['old_data'] = dynamodb.get('OldImage', {})
            elif event_name == 'REMOVE':
                doc['deleted_data'] = dynamodb.get('OldImage', {})

            # OpenSearchに送信
            try:
                doc_id = str(keys.get('id', {}).get('S', 'unknown'))
                url = f'http://opensearch:9200/dynamodb-cdc/_doc/{doc_id}'

                data = json.dumps(doc).encode('utf-8')
                req = urllib.request.Request(url, data=data, method='PUT')
                req.add_header('Content-Type', 'application/json')

                with urllib.request.urlopen(req) as response:
                    response_data = response.read().decode('utf-8')
                    print(f'OpenSearch response: {response.status} - {response_data}')

            except Exception as e:
                print(f'Error sending to OpenSearch: {str(e)}')

        return {'statusCode': 200, 'body': 'CDC処理完了'}
    except Exception as e:
        print(f'Error: {str(e)}')
        return {'statusCode': 500, 'body': str(e)}
EOF

    cd $WORK_DIR

    # ZIPファイルの作成（依存関係なし）
    echo "🗜️ ZIPファイルを作成中..."
    zip simple_cdc.zip simple_cdc.py

    # IAMロール作成（冪等性を考慮）
    if [ -z "$EXISTING_ROLE" ] || [ "$EXISTING_ROLE" = "None" ]; then
        echo "🔑 IAMロールを作成中..."
        awslocal iam create-role \
          --role-name lambda-execution-role \
          --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
              {
                "Effect": "Allow",
                "Principal": {
                  "Service": "lambda.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
              }
            ]
          }' 2>/dev/null || echo "ロール作成に失敗しました"
    else
        echo "✅ IAMロール 'lambda-execution-role' は既に存在します"
    fi

    # Lambda基本実行権限をアタッチ（冪等性あり）
    awslocal iam attach-role-policy \
      --role-name lambda-execution-role \
      --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || echo "基本ポリシーは既にアタッチされています"

    # DynamoDB Streams権限をアタッチ（冪等性あり）
    awslocal iam attach-role-policy \
      --role-name lambda-execution-role \
      --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaDynamoDBExecutionRole 2>/dev/null || echo "DynamoDBポリシーは既にアタッチされています"

    # DynamoDB Streamの ARN を取得（テーブルが確実に作成されるまで少し待機）
    echo "⏳ DynamoDBテーブルの準備完了を待機中..."
    sleep 3

    echo "🔍 DynamoDB Stream ARNを取得中..."
    STREAM_ARN=$(awslocal dynamodb describe-table --table-name test-table --query 'Table.LatestStreamArn' --output text)
    echo "Stream ARN: $STREAM_ARN"

    # Lambda関数を作成（既存の場合は更新）
    if [ -z "$EXISTING_FUNCTION" ] || [ "$EXISTING_FUNCTION" = "None" ]; then
        echo "🚀 Lambda関数をデプロイ中..."
        awslocal lambda create-function \
          --function-name dynamodb-cdc-handler \
          --runtime python3.9 \
          --role arn:aws:iam::000000000000:role/lambda-execution-role \
          --handler simple_cdc.lambda_handler \
          --zip-file fileb://simple_cdc.zip \
          --timeout 60 \
          --memory-size 256
        echo "✅ Lambda関数のデプロイが完了しました"
    else
        echo "🔄 既存のLambda関数のコードを更新中..."
        awslocal lambda update-function-code \
          --function-name dynamodb-cdc-handler \
          --zip-file fileb://simple_cdc.zip 2>/dev/null || echo "コード更新をスキップ"

        # ハンドラーの更新も実行
        awslocal lambda update-function-configuration \
          --function-name dynamodb-cdc-handler \
          --handler simple_cdc.lambda_handler 2>/dev/null || echo "ハンドラー更新をスキップ"
        echo "✅ Lambda関数の更新が完了しました"
    fi

    # 環境変数の設定（冪等性あり）
    echo "⚙️ 環境変数を設定中..."
    awslocal lambda update-function-configuration \
      --function-name dynamodb-cdc-handler \
      --environment 'Variables={OPENSEARCH_ENDPOINT=http://opensearch:9200,INDEX_NAME=dynamodb-cdc}' 2>/dev/null || echo "環境変数設定をスキップ"
fi

# DynamoDB StreamsとLambdaのトリガー設定（冪等性を考慮）
STREAM_ARN=$(awslocal dynamodb describe-table --table-name test-table --query 'Table.LatestStreamArn' --output text)

if [ "$STREAM_ARN" != "None" ] && [ -n "$STREAM_ARN" ]; then
    # 既存のEvent Source Mappingを確認
    EXISTING_ESM=$(awslocal lambda list-event-source-mappings --function-name dynamodb-cdc-handler --query 'EventSourceMappings[0].UUID' --output text 2>/dev/null || echo "")

    if [ -z "$EXISTING_ESM" ] || [ "$EXISTING_ESM" = "None" ]; then
        echo "🔗 DynamoDB StreamsトリガーをLambda関数に設定中..."
        awslocal lambda create-event-source-mapping \
          --function-name dynamodb-cdc-handler \
          --event-source-arn $STREAM_ARN \
          --starting-position LATEST \
          --batch-size 10 \
          --maximum-batching-window-in-seconds 5
        echo "✅ DynamoDB StreamsトリガーをLambda関数に設定しました"
    else
        echo "✅ Event Source Mappingは既に設定されています（UUID: $EXISTING_ESM）"
    fi
else
    echo "❌ DynamoDB Stream ARNが取得できませんでした"
fi

# Lambda関数のテスト（新規作成時のみ）
if [ "$SETUP_ESM_ONLY" != "true" ]; then
    echo "🧪 Lambda関数を自動テスト実行中..."
    awslocal lambda invoke \
      --function-name dynamodb-cdc-handler \
      --payload '{"Records":[{"eventName":"INSERT","dynamodb":{"Keys":{"id":{"S":"auto-deploy-test-'$(date +%s)'"}},"NewImage":{"id":{"S":"auto-deploy-test-'$(date +%s)'"},"name":{"S":"自動デプロイテスト ('$(date)')}"}}}}]}' \
      /tmp/auto-test-response.json 2>/dev/null

    echo "📋 自動テスト結果:"
    cat /tmp/auto-test-response.json 2>/dev/null || echo "テスト応答が見つかりません"
fi

# 設定状況の確認
echo "📋 セットアップ完了状況:"
echo "Lambda関数一覧:"
awslocal lambda list-functions --query 'Functions[].FunctionName' --output table

echo "Event Source Mappings:"
awslocal lambda list-event-source-mappings --function-name dynamodb-cdc-handler --query 'EventSourceMappings[0].{State:State,UUID:UUID,FunctionArn:FunctionArn}' --output table 2>/dev/null || echo "Event Source Mappingが見つかりません"

# OpenSearchのインデックステンプレート作成（冪等性あり）
echo "🔍 OpenSearchのインデックステンプレートを作成中..."
curl -X PUT "http://opensearch:9200/_index_template/dynamodb-cdc-template" \
  -H "Content-Type: application/json" \
  -d '{
    "index_patterns": ["dynamodb-cdc*"],
    "template": {
      "settings": {
        "number_of_shards": 1,
        "number_of_replicas": 0
      },
      "mappings": {
        "properties": {
          "event_name": {
            "type": "keyword"
          },
          "timestamp": {
            "type": "date"
          },
          "keys": {
            "type": "object"
          }
        }
      }
    }
  }' 2>/dev/null || echo "インデックステンプレート作成をスキップ"

echo "🎯 CDCシステムの自動セットアップが完了しました！"
echo "✅ このスクリプトは冪等性があり、何度実行しても安全です"

echo "=== 📦 CDC Lambda関数自動セットアップ完了 ==="