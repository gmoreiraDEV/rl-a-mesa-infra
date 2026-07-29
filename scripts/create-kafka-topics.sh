#!/usr/bin/env bash
set -euo pipefail

bootstrap_servers="${KAFKA_BOOTSTRAP_SERVERS:-localhost:9092}"
partitions="${KAFKA_PARTITIONS:-3}"
replication_factor="${KAFKA_REPLICATION_FACTOR:-1}"
kafka_topics_command="${KAFKA_TOPICS_COMMAND:-/opt/kafka/bin/kafka-topics.sh}"

contexts=(
  access
  audit
  billing
  catalog
  content
  contracts
  customers
  identity
  media
  notifications
  orders
  personal-chef
)

for context in "${contexts[@]}"; do
  event_topic="amesa.${context}.events.v1"
  "$kafka_topics_command" \
    --bootstrap-server "$bootstrap_servers" \
    --create \
    --if-not-exists \
    --topic "$event_topic" \
    --partitions "$partitions" \
    --replication-factor "$replication_factor"
  "$kafka_topics_command" \
    --bootstrap-server "$bootstrap_servers" \
    --create \
    --if-not-exists \
    --topic "${event_topic}.dlq" \
    --partitions "$partitions" \
    --replication-factor "$replication_factor"
done
