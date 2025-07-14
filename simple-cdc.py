#!/usr/bin/env python3
import boto3
import json
import time
import requests
from datetime import datetime
import threading

# 設定
LOCALSTACK_ENDPOINT = 'http://localhost:4567'
OPENSEARCH_ENDPOINT = 'http://localhost:9201'
TABLE_NAME = 'test-table'
OPENSEARCH_INDEX = 'dynamodb-cdc'

# クライアント初期化
dynamodb = boto3.client(
    'dynamodb',
    endpoint_url=LOCALSTACK_ENDPOINT,
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='us-east-1'
)

dynamodb_streams = boto3.client(
    'dynamodbstreams',
    endpoint_url=LOCALSTACK_ENDPOINT,
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='us-east-1'
)

def get_stream_arn():
    """DynamoDBテーブルのStream ARNを取得"""
    try:
        response = dynamodb.describe_table(TableName=TABLE_NAME)
        return response['Table']['LatestStreamArn']
    except Exception as e:
        print(f"Stream ARN取得エラー: {e}")
        return None

def create_opensearch_index():
    """OpenSearchインデックスを作成"""
    mapping = {
        "mappings": {
            "properties": {
                "id": {"type": "keyword"},
                "name": {"type": "text"},
                "value": {"type": "integer"},
                "category": {"type": "keyword"},
                "operation": {"type": "keyword"},
                "timestamp": {"type": "date"},
                "event_name": {"type": "keyword"}
            }
        }
    }

    try:
        response = requests.put(
            f"{OPENSEARCH_ENDPOINT}/{OPENSEARCH_INDEX}",
            json=mapping,
            headers={'Content-Type': 'application/json'}
        )
        if response.status_code in [200, 400]:  # 400は既存インデックスの場合
            print(f"OpenSearchインデックス '{OPENSEARCH_INDEX}' を作成/確認しました")
        else:
            print(f"インデックス作成エラー: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"OpenSearch接続エラー: {e}")

def process_stream_record(record):
    """Stream レコードを処理してOpenSearchに送信"""
    try:
        event_name = record['eventName']

        # DynamoDBの値を変換
        doc = {
            'operation': event_name,
            'timestamp': datetime.now().isoformat(),
            'event_name': event_name
        }

        # レコードのタイプに応じて処理
        if event_name in ['INSERT', 'MODIFY']:
            if 'NewImage' in record['dynamodb']:
                new_image = record['dynamodb']['NewImage']
                doc.update({
                    'id': new_image.get('id', {}).get('S', ''),
                    'name': new_image.get('name', {}).get('S', ''),
                    'value': int(new_image.get('value', {}).get('N', 0)),
                    'category': new_image.get('category', {}).get('S', '')
                })
        elif event_name == 'REMOVE':
            if 'OldImage' in record['dynamodb']:
                old_image = record['dynamodb']['OldImage']
                doc.update({
                    'id': old_image.get('id', {}).get('S', ''),
                    'name': old_image.get('name', {}).get('S', ''),
                    'value': int(old_image.get('value', {}).get('N', 0)),
                    'category': old_image.get('category', {}).get('S', '')
                })

        # OpenSearchに送信
        doc_id = doc.get('id', str(int(time.time())))
        response = requests.post(
            f"{OPENSEARCH_ENDPOINT}/{OPENSEARCH_INDEX}/_doc/{doc_id}",
            json=doc,
            headers={'Content-Type': 'application/json'}
        )

        if response.status_code in [200, 201]:
            print(f"✅ {event_name}: {doc_id} をOpenSearchに送信しました")
        else:
            print(f"❌ OpenSearch送信エラー: {response.status_code} - {response.text}")

    except Exception as e:
        print(f"レコード処理エラー: {e}")

def process_shard(shard_id, stream_arn):
    """シャードを処理"""
    try:
        # シャードイテレーターを取得
        iterator_response = dynamodb_streams.get_shard_iterator(
            StreamArn=stream_arn,
            ShardId=shard_id,
            ShardIteratorType='TRIM_HORIZON'
        )

        shard_iterator = iterator_response['ShardIterator']

        while shard_iterator:
            try:
                # レコードを取得
                response = dynamodb_streams.get_records(
                    ShardIterator=shard_iterator,
                    Limit=100
                )

                records = response.get('Records', [])

                for record in records:
                    process_stream_record(record)

                # 次のイテレーターを取得
                shard_iterator = response.get('NextShardIterator')

                if not records:
                    time.sleep(1)  # レコードがない場合は少し待機

            except Exception as e:
                print(f"レコード取得エラー: {e}")
                time.sleep(5)
                break

    except Exception as e:
        print(f"シャード処理エラー: {e}")

def start_stream_processing():
    """Stream処理を開始"""
    stream_arn = get_stream_arn()
    if not stream_arn:
        print("Stream ARNが取得できませんでした")
        return

    print(f"Stream ARN: {stream_arn}")

    # OpenSearchインデックスを作成
    create_opensearch_index()

    try:
        # Streamの詳細を取得
        stream_response = dynamodb_streams.describe_stream(StreamArn=stream_arn)
        shards = stream_response['StreamDescription']['Shards']

        print(f"シャード数: {len(shards)}")

        # 各シャードを処理するスレッドを開始
        threads = []
        for shard in shards:
            shard_id = shard['ShardId']
            print(f"シャード {shard_id} の処理を開始します")

            thread = threading.Thread(
                target=process_shard,
                args=(shard_id, stream_arn)
            )
            thread.daemon = True
            thread.start()
            threads.append(thread)

        # メインループ
        print("🚀 DynamoDB Streams CDC処理を開始しました")
        print("Ctrl+Cで停止します...")

        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n⏹️  CDC処理を停止しています...")

    except Exception as e:
        print(f"Stream処理開始エラー: {e}")

if __name__ == "__main__":
    start_stream_processing()