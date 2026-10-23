#!/bin/bash

# Kafka Replicator API Testing - Quick Reference cURL Commands
# 
# Usage:
#   1. Set the variables below
#   2. Make this file executable: chmod +x replicator-api-curl-examples.sh
#   3. Source it or run commands directly: ./replicator-api-curl-examples.sh

# Configuration - Update these values
BASE_URL="${BASE_URL:-http://localhost:8000}"  # Default to localhost
ORG_IDENTIFIER="${ORG_IDENTIFIER:-my-org}"
ACCESS_TOKEN="${ACCESS_TOKEN:-your-token-here}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Kafka Replicator API Testing${NC}"
echo "BASE_URL: $BASE_URL"
echo "ORG_IDENTIFIER: $ORG_IDENTIFIER"
echo ""

# 1. Get JSON Schema
get_schema() {
  echo -e "${GREEN}Getting JSON Schema...${NC}"
  curl -X GET "${BASE_URL}/organizations/${ORG_IDENTIFIER}/kafka-replicator/configuration-profiles/" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" | jq '.'
}

# 2. List All Replicators
list_replicators() {
  echo -e "${GREEN}Listing all replicators...${NC}"
  curl -X GET "${BASE_URL}/organizations/${ORG_IDENTIFIER}/kafka-replicators/" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" | jq '.'
}

# 3. Get Single Replicator
get_replicator() {
  local REPLICATOR_ID="${1:-my-replicator-01}"
  echo -e "${GREEN}Getting replicator: ${REPLICATOR_ID}...${NC}"
  curl -X GET "${BASE_URL}/organizations/${ORG_IDENTIFIER}/kafka-replicators/${REPLICATOR_ID}/" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" | jq '.'
}

# 4. Create MirrorMaker2 Replicator (Streamtime Clusters)
create_mm2_streamtime() {
  local REPLICATOR_ID="${1:-test-replicator-$(date +%s)}"
  local SOURCE_CLUSTER="${2:-source-cluster-id}"
  local DEST_CLUSTER="${3:-dest-cluster-id}"
  
  echo -e "${GREEN}Creating MirrorMaker2 replicator: ${REPLICATOR_ID}...${NC}"
  curl -X POST "${BASE_URL}/organizations/${ORG_IDENTIFIER}/kafka-replicators/" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"identifier\": \"${REPLICATOR_ID}\",
      \"provider\": \"MirrorMaker2\",
      \"source_kafka_id\": \"${SOURCE_CLUSTER}\",
      \"destination_kafka_id\": \"${DEST_CLUSTER}\",
      \"source_secret\": {
        \"provider\": \"builtin\",
        \"path\": \"/replicators/${REPLICATOR_ID}/source-secret\",
        \"authentication_type\": \"SASL/PLAIN\",
        \"content\": {
          \"authentication_type\": \"SASL/PLAIN\",
          \"username\": \"source-user\",
          \"password\": \"source-password\"
        }
      },
      \"destination_secret\": {
        \"provider\": \"builtin\",
        \"path\": \"/replicators/${REPLICATOR_ID}/destination-secret\",
        \"authentication_type\": \"SASL/PLAIN\",
        \"content\": {
          \"authentication_type\": \"SASL/PLAIN\",
          \"username\": \"dest-user\",
          \"password\": \"dest-password\"
        }
      },
      \"replication_mode\": \"active-active\",
      \"lag_alert_threshold\": 1000,
      \"lag_alert_threshold_unit\": \"messages\",
      \"topic_whitelist\": \"topic1,topic2\",
      \"topic_blacklist\": \"internal-*\"
    }" | jq '.'
}

# 5. Create MirrorMaker2 Replicator (External Clusters)
create_mm2_external() {
  local REPLICATOR_ID="${1:-test-replicator-ext-$(date +%s)}"
  
  echo -e "${GREEN}Creating MirrorMaker2 replicator with external clusters: ${REPLICATOR_ID}...${NC}"
  curl -X POST "${BASE_URL}/organizations/${ORG_IDENTIFIER}/kafka-replicators/" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"identifier\": \"${REPLICATOR_ID}\",
      \"provider\": \"MirrorMaker2\",
      \"source_connection_details\": {
        \"bootstrap_servers\": \"source-kafka.example.com:9092\",
        \"port\": 9092,
        \"security_protocol\": \"SASL_SSL\",
        \"sasl_mechanism\": \"SCRAM-SHA-256\",
        \"authentication_type\": \"SASL/SCRAM-SHA-256\"
      },
      \"destination_connection_details\": {
        \"bootstrap_servers\": \"dest-kafka.example.com:9092\",
        \"port\": 9092,
        \"security_protocol\": \"SASL_SSL\",
        \"sasl_mechanism\": \"SCRAM-SHA-256\",
        \"authentication_type\": \"SASL/SCRAM-SHA-256\"
      },
      \"source_secret\": {
        \"provider\": \"builtin\",
        \"path\": \"/replicators/${REPLICATOR_ID}/source-secret\",
        \"authentication_type\": \"SASL/SCRAM-SHA-256\",
        \"content\": {
          \"authentication_type\": \"SASL/SCRAM-SHA-256\",
          \"username\": \"source-user\",
          \"password\": \"source-password\"
        }
      },
      \"destination_secret\": {
        \"provider\": \"builtin\",
        \"path\": \"/replicators/${REPLICATOR_ID}/destination-secret\",
        \"authentication_type\": \"SASL/SCRAM-SHA-256\",
        \"content\": {
          \"authentication_type\": \"SASL/SCRAM-SHA-256\",
          \"username\": \"dest-user\",
          \"password\": \"dest-password\"
        }
      },
      \"replication_mode\": \"active-passive\",
      \"lag_alert_threshold\": 5000,
      \"lag_alert_threshold_unit\": \"bytes\"
    }" | jq '.'
}

# 6. Create Cluster Link Replicator
create_cluster_link() {
  local REPLICATOR_ID="${1:-cluster-link-$(date +%s)}"
  local SOURCE_CLUSTER="${2:-cfk-cluster-id}"
  
  echo -e "${GREEN}Creating Cluster Link replicator: ${REPLICATOR_ID}...${NC}"
  curl -X POST "${BASE_URL}/organizations/${ORG_IDENTIFIER}/kafka-replicators/" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"identifier\": \"${REPLICATOR_ID}\",
      \"provider\": \"Cluster Link\",
      \"source_kafka_id\": \"${SOURCE_CLUSTER}\",
      \"destination_connection_details\": {
        \"bootstrap_servers\": \"external-confluent.example.com:9092\",
        \"port\": 9092,
        \"security_protocol\": \"SASL_SSL\",
        \"sasl_mechanism\": \"PLAIN\",
        \"authentication_type\": \"SASL/PLAIN\"
      },
      \"source_secret\": {
        \"provider\": \"builtin\",
        \"path\": \"/replicators/${REPLICATOR_ID}/source-secret\",
        \"authentication_type\": \"SASL/PLAIN\",
        \"content\": {
          \"authentication_type\": \"SASL/PLAIN\",
          \"username\": \"source-user\",
          \"password\": \"source-password\"
        }
      },
      \"destination_secret\": {
        \"provider\": \"builtin\",
        \"path\": \"/replicators/${REPLICATOR_ID}/destination-secret\",
        \"authentication_type\": \"SASL/PLAIN\",
        \"content\": {
          \"authentication_type\": \"SASL/PLAIN\",
          \"username\": \"dest-user\",
          \"password\": \"dest-password\"
        }
      },
      \"replication_mode\": \"active-active\",
      \"lag_alert_threshold\": 1000,
      \"lag_alert_threshold_unit\": \"messages\",
      \"source_initiated_link\": true,
      \"link_mode\": \"Bidirectional\"
    }" | jq '.'
}

# 7. Update Replicator (PATCH)
update_replicator() {
  local REPLICATOR_ID="${1:-my-replicator-01}"
  
  echo -e "${GREEN}Updating replicator: ${REPLICATOR_ID}...${NC}"
  curl -X PATCH "${BASE_URL}/organizations/${ORG_IDENTIFIER}/kafka-replicators/${REPLICATOR_ID}/" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "replication_mode": "active-passive",
      "lag_alert_threshold": 2000,
      "lag_alert_threshold_unit": "messages",
      "topic_whitelist": "updated-topic1,updated-topic2"
    }' | jq '.'
}

# 8. Delete Replicator
delete_replicator() {
  local REPLICATOR_ID="${1:-my-replicator-01}"
  
  echo -e "${YELLOW}Deleting replicator: ${REPLICATOR_ID}...${NC}"
  curl -X DELETE "${BASE_URL}/organizations/${ORG_IDENTIFIER}/kafka-replicators/${REPLICATOR_ID}/" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" | jq '.'
}

# Main menu (if script is executed directly)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Available functions:"
  echo "  get_schema"
  echo "  list_replicators"
  echo "  get_replicator <replicator_id>"
  echo "  create_mm2_streamtime <replicator_id> <source_cluster> <dest_cluster>"
  echo "  create_mm2_external <replicator_id>"
  echo "  create_cluster_link <replicator_id> <source_cluster>"
  echo "  update_replicator <replicator_id>"
  echo "  delete_replicator <replicator_id>"
  echo ""
  echo "Example:"
  echo "  source replicator-api-curl-examples.sh"
  echo "  create_mm2_streamtime test-01 cluster1 cluster2"
  echo ""
fi
