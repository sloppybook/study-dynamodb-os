#!/usr/bin/env python3
import boto3
import json
import time
import requests
from datetime import datetime

# LocalStackのDynamoDBクライアント
dynamodb = boto3.client(
    'dynamodb',
    endpoint_url='http://localhost:4567',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='us-east-1'
)

TABLE_NAME = 'test-table'
OPENSEARCH_ENDPOINT = 'http://localhost:9201'
OPENSEARCH_INDEX = 'dynamodb-cdc'

def insert_new_item():
    """新しいアイテムを挿入"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    item_id = f"test_{timestamp}"

    item = {
        'id': {'S': item_id},
        'name': {'S': f'テストアイテム_{timestamp}'},
        'value': {'N': str(int(time.time()) % 1000)},
        'category': {'S': 'test_category'},
        'created_at': {'S': datetime.now().isoformat()}
    }

    try:
        dynamodb.put_item(TableName=TABLE_NAME, Item=item)
        print(f"✅ 新しいアイテムを挿入しました: {item_id}")
        return item_id
    except Exception as e:
        print(f"❌ 挿入エラー: {e}")
        return None

def get_item(item_id):
    """アイテムを取得"""
    try:
        response = dynamodb.get_item(
            TableName=TABLE_NAME,
            Key={'id': {'S': item_id}}
        )

        if 'Item' in response:
            item = response['Item']
            print(f"📖 DynamoDBから取得:")
            print(f"   ID: {item['id']['S']}")
            print(f"   名前: {item['name']['S']}")
            print(f"   値: {item['value']['N']}")
            print(f"   カテゴリ: {item['category']['S']}")
            if 'created_at' in item:
                print(f"   作成日時: {item['created_at']['S']}")
            return item
        else:
            print(f"❌ アイテムが見つかりません: {item_id}")
            return None
    except Exception as e:
        print(f"❌ 取得エラー: {e}")
        return None

def update_item(item_id):
    """アイテムを更新"""
    try:
        new_value = int(time.time()) % 1000
        response = dynamodb.update_item(
            TableName=TABLE_NAME,
            Key={'id': {'S': item_id}},
            UpdateExpression='SET #v = :val, #n = :name, #u = :updated',
            ExpressionAttributeNames={
                '#v': 'value',
                '#n': 'name',
                '#u': 'updated_at'
            },
            ExpressionAttributeValues={
                ':val': {'N': str(new_value)},
                ':name': {'S': f'更新済み_{item_id}'},
                ':updated': {'S': datetime.now().isoformat()}
            },
            ReturnValues='ALL_NEW'
        )

        print(f"🔄 アイテムを更新しました: {item_id}")
        print(f"   新しい値: {new_value}")
        return response
    except Exception as e:
        print(f"❌ 更新エラー: {e}")
        return None

def delete_item(item_id):
    """アイテムを削除"""
    try:
        dynamodb.delete_item(
            TableName=TABLE_NAME,
            Key={'id': {'S': item_id}}
        )
        print(f"🗑️  アイテムを削除しました: {item_id}")
        return True
    except Exception as e:
        print(f"❌ 削除エラー: {e}")
        return False

def scan_all_items():
    """全アイテムをスキャン"""
    try:
        response = dynamodb.scan(TableName=TABLE_NAME)
        items = response.get('Items', [])

        print(f"📋 DynamoDBの全アイテム ({len(items)}件):")
        for item in items:
            print(f"   - {item['id']['S']}: {item['name']['S']}")

        return items
    except Exception as e:
        print(f"❌ スキャンエラー: {e}")
        return []

def check_opensearch_sync(item_id):
    """OpenSearchでの同期状況を確認"""
    try:
        response = requests.get(f"{OPENSEARCH_ENDPOINT}/{OPENSEARCH_INDEX}/_doc/{item_id}")

        if response.status_code == 200:
            data = response.json()
            print(f"🔍 OpenSearchから取得:")
            source = data['_source']
            print(f"   ID: {source['id']}")
            print(f"   名前: {source['name']}")
            print(f"   値: {source['value']}")
            print(f"   操作: {source['operation']}")
            print(f"   タイムスタンプ: {source['timestamp']}")
            return data
        else:
            print(f"❌ OpenSearchにアイテムが見つかりません: {item_id}")
            return None
    except Exception as e:
        print(f"❌ OpenSearch確認エラー: {e}")
        return None

def main():
    """メイン処理"""
    print("🚀 DynamoDB データ操作テストを開始します")
    print("=" * 50)

    # 1. 新しいアイテムを挿入
    print("\n1️⃣ 新しいアイテムを挿入")
    item_id = insert_new_item()
    if not item_id:
        return

    # 少し待機（CDC処理のため）
    print("⏳ CDC処理を待機中...")
    time.sleep(3)

    # 2. DynamoDBから取得
    print("\n2️⃣ DynamoDBから取得")
    get_item(item_id)

    # 3. OpenSearchでの同期確認
    print("\n3️⃣ OpenSearchでの同期確認")
    check_opensearch_sync(item_id)

    # 4. アイテムを更新
    print("\n4️⃣ アイテムを更新")
    update_item(item_id)

    # 少し待機（CDC処理のため）
    print("⏳ CDC処理を待機中...")
    time.sleep(3)

    # 5. 更新後のOpenSearch確認
    print("\n5️⃣ 更新後のOpenSearch確認")
    check_opensearch_sync(item_id)

    # 6. 全アイテムをスキャン
    print("\n6️⃣ 全アイテムをスキャン")
    scan_all_items()

    # 7. アイテムを削除
    print("\n7️⃣ アイテムを削除")
    delete_item(item_id)

    # 少し待機（CDC処理のため）
    print("⏳ CDC処理を待機中...")
    time.sleep(3)

    # 8. 削除後の確認
    print("\n8️⃣ 削除後の確認")
    get_item(item_id)  # DynamoDBから確認
    check_opensearch_sync(item_id)  # OpenSearchから確認

    print("\n✅ データ操作テスト完了！")

if __name__ == "__main__":
    main()