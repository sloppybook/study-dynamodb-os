```bash
docker compose up -d
docker exec localstack bash
awslocal opensearch create-domain --domain-name my-domain
awslocal opensearch describe-domain --domain-name my-domain
exit
curl -X PUT http://my-domain.us-east-1.opensearch.localhost.localstack.cloud:4566/my-index
curl http://my-domain.us-east-1.opensearch.localhost.localstack.cloud:4566/_cluster/health
```

## curlでDynamoDBテーブル操作をするコマンド

### テーブル削除
```bash
curl -X POST http://localhost:4566/ \
  -H "Content-Type: application/x-amz-json-1.0" \
  -H "X-Amz-Target: DynamoDB_20120810.DeleteTable" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=test/20230101/us-east-1/dynamodb/aws4_request, SignedHeaders=host;x-amz-date;x-amz-target, Signature=test" \
  -d '{"TableName": "my-table"}'
```

### テーブル作成
```bash
curl -X POST http://localhost:4566/ \
  -H "Content-Type: application/x-amz-json-1.0" \
  -H "X-Amz-Target: DynamoDB_20120810.CreateTable" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=test/20230101/us-east-1/dynamodb/aws4_request, SignedHeaders=host;x-amz-date;x-amz-target, Signature=test" \
  -d '{
    "TableName": "my-table",
    "AttributeDefinitions": [
      {"AttributeName": "id", "AttributeType": "S"}
    ],
    "KeySchema": [
      {"AttributeName": "id", "KeyType": "HASH"}
    ],
    "BillingMode": "PAY_PER_REQUEST"
  }'
```

### テーブル一覧取得
```bash
curl -X POST http://localhost:4566/ \
  -H "Content-Type: application/x-amz-json-1.0" \
  -H "X-Amz-Target: DynamoDB_20120810.ListTables" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=test/20230101/us-east-1/dynamodb/aws4_request, SignedHeaders=host;x-amz-date;x-amz-target, Signature=test" \
  -d '{}'
```
