#!/usr/bin/env python3
import boto3
import json
import time

# LocalStackのDynamoDBクライアント
dynamodb = boto3.client(
    'dynamodb',
    endpoint_url='http://localhost:4567',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='us-east-1'
)

def create_table_with_stream():
    """DynamoDB Streamsを有効にしたテーブルを作成"""
    table_name = 'test-table'

    try:
        # テーブルが既に存在するかチェック
        dynamodb.describe_table(TableName=table_name)
        print(f"テーブル '{table_name}' は既に存在します。")
        return
    except dynamodb.exceptions.ResourceNotFoundException:
        pass

    # テーブル作成
    response = dynamodb.create_table(
        TableName=table_name,
        KeySchema=[
            {
                'AttributeName': 'id',
                'KeyType': 'HASH'
            }
        ],
        AttributeDefinitions=[
            {
                'AttributeName': 'id',
                'AttributeType': 'S'
            }
        ],
        BillingMode='PAY_PER_REQUEST',
        StreamSpecification={
            'StreamEnabled': True,
            'StreamViewType': 'NEW_AND_OLD_IMAGES'
        }
    )

    print(f"テーブル '{table_name}' を作成しました。")
    print(f"テーブルARN: {response['TableDescription']['TableArn']}")

    # StreamARNを取得
    if 'StreamSpecification' in response['TableDescription']:
        stream_arn = response['TableDescription']['LatestStreamArn']
        print(f"StreamARN: {stream_arn}")

        # パイプライン設定ファイルを更新
        update_pipeline_config(response['TableDescription']['TableArn'], stream_arn)

    return response

def update_pipeline_config(table_arn, stream_arn):
    """パイプライン設定ファイルを実際のARNで更新"""
    config_file = 'data-prepper/pipelines/dynamodb-pipeline.yaml'

    try:
        with open(config_file, 'r') as f:
            content = f.read()

        # ARNを置換
        content = content.replace(
            'table_arn: "arn:aws:dynamodb:us-east-1:000000000000:table/test-table"',
            f'table_arn: "{table_arn}"'
        )
        content = content.replace(
            'stream_arn: "arn:aws:dynamodb:us-east-1:000000000000:table/test-table/stream/2024-01-01T00:00:00.000"',
            f'stream_arn: "{stream_arn}"'
        )

        with open(config_file, 'w') as f:
            f.write(content)

        print(f"パイプライン設定を更新しました: {config_file}")

    except Exception as e:
        print(f"設定ファイルの更新に失敗しました: {e}")

def insert_test_data():
    """テストデータを挿入"""
    table_name = 'test-table'

    test_items = [
        {
            'id': {'S': 'item1'},
            'name': {'S': 'テストアイテム1'},
            'value': {'N': '100'},
            'category': {'S': 'electronics'}
        },
        {
            'id': {'S': 'item2'},
            'name': {'S': 'テストアイテム2'},
            'value': {'N': '200'},
            'category': {'S': 'books'}
        },
        {
            'id': {'S': 'item3'},
            'name': {'S': 'テストアイテム3'},
            'value': {'N': '150'},
            'category': {'S': 'clothing'}
        }
    ]

    for item in test_items:
        try:
            dynamodb.put_item(
                TableName=table_name,
                Item=item
            )
            print(f"アイテムを挿入しました: {item['id']['S']}")
            time.sleep(1)  # Stream処理のため少し待機
        except Exception as e:
            print(f"アイテム挿入エラー: {e}")

def update_test_data():
    """テストデータを更新（Stream イベント生成のため）"""
    table_name = 'test-table'

    try:
        # item1を更新
        dynamodb.update_item(
            TableName=table_name,
            Key={'id': {'S': 'item1'}},
            UpdateExpression='SET #v = :val, #n = :name',
            ExpressionAttributeNames={
                '#v': 'value',
                '#n': 'name'
            },
            ExpressionAttributeValues={
                ':val': {'N': '120'},
                ':name': {'S': 'テストアイテム1（更新済み）'}
            }
        )
        print("item1を更新しました")

        # item2を削除
        dynamodb.delete_item(
            TableName=table_name,
            Key={'id': {'S': 'item2'}}
        )
        print("item2を削除しました")

    except Exception as e:
        print(f"データ更新エラー: {e}")

if __name__ == "__main__":
    print("DynamoDB設定を開始します...")

    # テーブル作成
    create_table_with_stream()

    # 少し待機
    time.sleep(5)

    # テストデータ挿入
    print("\nテストデータを挿入します...")
    insert_test_data()

    # 少し待機
    time.sleep(5)

    # データ更新（Stream イベント生成）
    print("\nデータを更新します...")
    update_test_data()

    print("\nDynamoDB設定完了！")
    print("次のコマンドでData Prepperを起動してください:")
    print("docker-compose up -d data-prepper")