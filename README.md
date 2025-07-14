```shell
~/repository/test-dynamo (main*) » 
curl -X GET "http://localhost:9201/_cat/indices?v"
curl -X GET "http://localhost:9201/dynamodb-cdc/_search" | jq '.'
health status index                     uuid                   pri rep docs.count docs.deleted store.size pri.store.size
yellow open   dynamodb-cdc              ctnlUoP8QsOzHAhOd0hqhg   1   1          7            0      7.3kb          7.3kb
green  open   .opensearch-observability 24BKSUoRQUKgYHONvKYC7A   1   0          0            0       208b           208b
green  open   .plugins-ml-config        ON-aBNM2Q46D-PXEXyA1YA   1   0          1            0      3.9kb          3.9kb
green  open   .kibana_1                 KyfNiwS9Rd2jKZHOkXBZOw   1   0          0            0       208b           208b
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  2129  100  2129    0     0  40223      0 --:--:-- --:--:-- --:--:-- 40942
{
  "took": 41,
  "timed_out": false,
  "_shards": {
    "total": 1,
    "successful": 1,
    "skipped": 0,
    "failed": 0
  },
  "hits": {
    "total": {
      "value": 7,
      "relation": "eq"
    },
    "max_score": 1.0,
    "hits": [
      {
        "_index": "dynamodb-cdc",
        "_id": "item3",
        "_score": 1.0,
        "_source": {
          "operation": "INSERT",
          "timestamp": "2025-07-12T15:16:39.278496",
          "event_name": "INSERT",
          "id": "item3",
          "name": "テストアイテム3",
          "value": 150,
          "category": "clothing"
        }
      },
      {
        "_index": "dynamodb-cdc",
        "_id": "item2",
        "_score": 1.0,
        "_source": {
          "operation": "REMOVE",
          "timestamp": "2025-07-12T15:16:39.300604",
          "event_name": "REMOVE",
          "id": "item2",
          "name": "テストアイテム2",
          "value": 200,
          "category": "books"
        }
      },
      {
        "_index": "dynamodb-cdc",
        "_id": "item4",
        "_score": 1.0,
        "_source": {
          "operation": "INSERT",
          "timestamp": "2025-07-12T15:16:39.310262",
          "event_name": "INSERT",
          "id": "item4",
          "name": "CDCテストアイテム",
          "value": 300,
          "category": "test"
        }
      },
      {
        "_index": "dynamodb-cdc",
        "_id": "item1",
        "_score": 1.0,
        "_source": {
          "operation": "MODIFY",
          "timestamp": "2025-07-12T15:16:39.321032",
          "event_name": "MODIFY",
          "id": "item1",
          "name": "テストアイテム1（更新済み）",
          "value": 999,
          "category": "electronics"
        }
      },
      {
        "_index": "dynamodb-cdc",
        "_id": "test_20250712_151435",
        "_score": 1.0,
        "_source": {
          "operation": "REMOVE",
          "timestamp": "2025-07-12T15:16:39.352153",
          "event_name": "REMOVE",
          "id": "test_20250712_151435",
          "name": "更新済み_test_20250712_151435",
          "value": 878,
          "category": "test_category"
        }
      },
      {
        "_index": "dynamodb-cdc",
        "_id": "curl_test_001",
        "_score": 1.0,
        "_source": {
          "operation": "INSERT",
          "timestamp": "2025-07-12T15:16:39.361746",
          "event_name": "INSERT",
          "id": "curl_test_001",
          "name": "curlで登録したアイテム",
          "value": 777,
          "category": "curl_test"
        }
      },
      {
        "_index": "dynamodb-cdc",
        "_id": "curl_test_002",
        "_score": 1.0,
        "_source": {
          "operation": "MODIFY",
          "timestamp": "2025-07-12T15:17:36.981579",
          "event_name": "MODIFY",
          "id": "curl_test_002",
          "name": "curlで更新したアイテム2",
          "value": 999,
          "category": "curl_test"
        }
      }
    ]
  }
}
-------------------------------------------------------------------------------------------------------------------------------------------
~/repository/test-dynamo (main*) » 
curl -X GET "http://localhost:9201/dynamodb-cdc/_doc/test_001" | jq '.'
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    56  100    56    0     0   3435      0 --:--:-- --:--:-- --:--:--  3500
{
  "_index": "dynamodb-cdc",
  "_id": "test_001",
  "found": false
}
-------------------------------------------------------------------------------------------------------------------------------------------
~/repository/test-dynamo (main*) » 
curl -X GET "http://localhost:9201/dynamodb-cdc/_search?pretty" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "match_all": {}
    }
  }'
{
  "took" : 15,
  "timed_out" : false,
  "_shards" : {
    "total" : 1,
    "successful" : 1,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 7,
      "relation" : "eq"
    },
    "max_score" : 1.0,
    "hits" : [
      {
        "_index" : "dynamodb-cdc",
        "_id" : "item3",
        "_score" : 1.0,
        "_source" : {
          "operation" : "INSERT",
          "timestamp" : "2025-07-12T15:16:39.278496",
          "event_name" : "INSERT",
          "id" : "item3",
          "name" : "テストアイテム3",
          "value" : 150,
          "category" : "clothing"
        }
      },
      {
        "_index" : "dynamodb-cdc",
        "_id" : "item2",
        "_score" : 1.0,
        "_source" : {
          "operation" : "REMOVE",
          "timestamp" : "2025-07-12T15:16:39.300604",
          "event_name" : "REMOVE",
          "id" : "item2",
          "name" : "テストアイテム2",
          "value" : 200,
          "category" : "books"
        }
      },
      {
        "_index" : "dynamodb-cdc",
        "_id" : "item4",
        "_score" : 1.0,
        "_source" : {
          "operation" : "INSERT",
          "timestamp" : "2025-07-12T15:16:39.310262",
          "event_name" : "INSERT",
          "id" : "item4",
          "name" : "CDCテストアイテム",
          "value" : 300,
          "category" : "test"
        }
      },
      {
        "_index" : "dynamodb-cdc",
        "_id" : "item1",
        "_score" : 1.0,
        "_source" : {
          "operation" : "MODIFY",
          "timestamp" : "2025-07-12T15:16:39.321032",
          "event_name" : "MODIFY",
          "id" : "item1",
          "name" : "テストアイテム1（更新済み）",
          "value" : 999,
          "category" : "electronics"
        }
      },
      {
        "_index" : "dynamodb-cdc",
        "_id" : "test_20250712_151435",
        "_score" : 1.0,
        "_source" : {
          "operation" : "REMOVE",
          "timestamp" : "2025-07-12T15:16:39.352153",
          "event_name" : "REMOVE",
          "id" : "test_20250712_151435",
          "name" : "更新済み_test_20250712_151435",
          "value" : 878,
          "category" : "test_category"
        }
      },
      {
        "_index" : "dynamodb-cdc",
        "_id" : "curl_test_001",
        "_score" : 1.0,
        "_source" : {
          "operation" : "INSERT",
          "timestamp" : "2025-07-12T15:16:39.361746",
          "event_name" : "INSERT",
          "id" : "curl_test_001",
          "name" : "curlで登録したアイテム",
          "value" : 777,
          "category" : "curl_test"
        }
      },
      {
        "_index" : "dynamodb-cdc",
        "_id" : "curl_test_002",
        "_score" : 1.0,
        "_source" : {
          "operation" : "MODIFY",
          "timestamp" : "2025-07-12T15:17:36.981579",
          "event_name" : "MODIFY",
          "id" : "curl_test_002",
          "name" : "curlで更新したアイテム2",
          "value" : 999,
          "category" : "curl_test"
        }
      }
    ]
  }
}
```
