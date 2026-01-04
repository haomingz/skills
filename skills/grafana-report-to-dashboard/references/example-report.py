# Example report script (Elasticsearch -> email)
from elasticsearch import Elasticsearch

es = Elasticsearch('https://es.example.local:9200')

index = 'nginx-logs-*'

qps_query = {
    "size": 0,
    "query": {
        "bool": {
            "filter": [
                {"range": {"@timestamp": {"gte": "now-1h"}}},
                {"term": {"environment": "prod"}},
            ]
        }
    },
    "aggs": {
        "per_minute": {
            "date_histogram": {"field": "@timestamp", "fixed_interval": "1m"}
        }
    },
}

error_rate_query = {
    "size": 0,
    "query": {"range": {"@timestamp": {"gte": "now-1h"}}},
    "aggs": {
        "errors": {"filter": {"range": {"status": {"gte": 500}}}},
        "total": {"value_count": {"field": "status"}},
    },
}

qps_result = es.search(index=index, body=qps_query)
error_result = es.search(index=index, body=error_rate_query)

# Email rendering omitted
print(qps_result)
print(error_result)