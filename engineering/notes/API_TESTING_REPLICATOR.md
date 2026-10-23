# Kafka Replicator API Testing - cURL Commands

This document contains cURL commands for testing all CRUD operations on the Kafka Replicator API.

## Prerequisites

1. **Base URL**: Replace `{BASE_URL}` with your Fleet Manager API URL (typically through Kong Gateway)
   - Example: `https://api.example.com` or `http://localhost:8000`

2. **Organization Identifier**: Replace `{ORG_IDENTIFIER}` with your organization identifier
   - Example: `my-org`

3. **Authentication Token**: Replace `{ACCESS_TOKEN}` with your OAuth Bearer token
   - The token should be obtained from your OAuth provider (Keycloak)

## Common Headers

All requests require the Authorization header:
```bash
Authorization: Bearer {ACCESS_TOKEN}
Content-Type: application/json
```

---

## 1. Get JSON Schema (for form generation)

### GET Schema
```bash
curl -X GET "{BASE_URL}/organizations/{ORG_IDENTIFIER}/kafka-replicator/configuration-profiles/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json"
```

### List Available Schemas
```bash
curl -X GET "{BASE_URL}/organizations/{ORG_IDENTIFIER}/schema/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json"
```

---

## 2. CREATE - MirrorMaker2 Replicator (Streamtime Clusters)

### Create with two Streamtime Kafka clusters
```bash
curl -X POST "{BASE_URL}/organizations/{ORG_IDENTIFIER}/kafka-replicators/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "my-replicator-01",
    "provider": "MirrorMaker2",
    "source_kafka_id": "source-cluster-id",
    "destination_kafka_id": "dest-cluster-id",
    "source_secret": {
      "provider": "builtin",
      "path": "/replicators/my-replicator-01/source-secret",
      "authentication_type": "SASL/PLAIN",
      "content": {
        "authentication_type": "SASL/PLAIN",
        "username": "source-user",
        "password": "source-password"
      }
    },
    "destination_secret": {
      "provider": "builtin",
      "path": "/replicators/my-replicator-01/destination-secret",
      "authentication_type": "SASL/PLAIN",
      "content": {
        "authentication_type": "SASL/PLAIN",
        "username": "dest-user",
        "password": "dest-password"
      }
    },
    "replication_mode": "active-active",
    "lag_alert_threshold": 1000,
    "lag_alert_threshold_unit": "messages",
    "topic_whitelist": "topic1,topic2,prefix-*",
    "topic_blacklist": "internal-*",
    "groups_whitelist": "group1,group2",
    "groups_blacklist": "admin-*"
  }'
```

### Create with external clusters
```bash
curl -X POST "{BASE_URL}/organizations/{ORG_IDENTIFIER}/kafka-replicators/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "my-replicator-02",
    "provider": "MirrorMaker2",
    "source_connection_details": {
      "bootstrap_servers": "source-kafka.example.com:9092",
      "port": 9092,
      "security_protocol": "SASL_SSL",
      "sasl_mechanism": "SCRAM-SHA-256",
      "authentication_type": "SASL/SCRAM-SHA-256"
    },
    "destination_connection_details": {
      "bootstrap_servers": "dest-kafka.example.com:9092",
      "port": 9092,
      "security_protocol": "SASL_SSL",
      "sasl_mechanism": "SCRAM-SHA-256",
      "authentication_type": "SASL/SCRAM-SHA-256"
    },
    "source_secret": {
      "provider": "builtin",
      "path": "/replicators/my-replicator-02/source-secret",
      "authentication_type": "SASL/SCRAM-SHA-256",
      "content": {
        "authentication_type": "SASL/SCRAM-SHA-256",
        "username": "source-user",
        "password": "source-password"
      }
    },
    "destination_secret": {
      "provider": "builtin",
      "path": "/replicators/my-replicator-02/destination-secret",
      "authentication_type": "SASL/SCRAM-SHA-256",
      "content": {
        "authentication_type": "SASL/SCRAM-SHA-256",
        "username": "dest-user",
        "password": "dest-password"
      }
    },
    "replication_mode": "active-passive",
    "lag_alert_threshold": 5000,
    "lag_alert_threshold_unit": "bytes",
    "topic_whitelist": "*",
    "groups_whitelist": "*"
  }'
```

### Create with mixed (Streamtime source, external destination)
```bash
curl -X POST "{BASE_URL}/organizations/{ORG_IDENTIFIER}/kafka-replicators/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "my-replicator-03",
    "provider": "MirrorMaker2",
    "source_kafka_id": "source-cluster-id",
    "destination_connection_details": {
      "bootstrap_servers": "external-kafka.example.com:9092",
      "port": 9092,
      "security_protocol": "SSL",
      "authentication_type": "SSL"
    },
    "source_secret": {
      "provider": "builtin",
      "path": "/replicators/my-replicator-03/source-secret",
      "authentication_type": "SASL/OAUTHBEARER",
      "content": {
        "authentication_type": "SASL/OAUTHBEARER",
        "client_id": "source-client",
        "client_secret": "source-secret",
        "token_endpoint_uri": "https://auth.example.com/token",
        "access_token_is_jwt": true
      }
    },
    "destination_secret": {
      "provider": "builtin",
      "path": "/replicators/my-replicator-03/destination-secret",
      "authentication_type": "SSL",
      "content": {
        "authentication_type": "SSL",
        "ca_certificate": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
        "client_certificate": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
        "client_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
      }
    },
    "replication_mode": "active-active",
    "lag_alert_threshold": 30,
    "lag_alert_threshold_unit": "seconds"
  }'
```

---

## 3. CREATE - Cluster Link Replicator

### Source-initiated Cluster Link (Bidirectional)
```bash
curl -X POST "{BASE_URL}/organizations/{ORG_IDENTIFIER}/kafka-replicators/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "cluster-link-01",
    "provider": "Cluster Link",
    "source_kafka_id": "cfk-cluster-id",
    "destination_connection_details": {
      "bootstrap_servers": "external-confluent.example.com:9092",
      "port": 9092,
      "security_protocol": "SASL_SSL",
      "sasl_mechanism": "PLAIN",
      "authentication_type": "SASL/PLAIN"
    },
    "source_secret": {
      "provider": "builtin",
      "path": "/replicators/cluster-link-01/source-secret",
      "authentication_type": "SASL/PLAIN",
      "content": {
        "authentication_type": "SASL/PLAIN",
        "username": "source-user",
        "password": "source-password"
      }
    },
    "destination_secret": {
      "provider": "builtin",
      "path": "/replicators/cluster-link-01/destination-secret",
      "authentication_type": "SASL/PLAIN",
      "content": {
        "authentication_type": "SASL/PLAIN",
        "username": "dest-user",
        "password": "dest-password"
      }
    },
    "replication_mode": "active-active",
    "lag_alert_threshold": 1000,
    "lag_alert_threshold_unit": "messages",
    "source_initiated_link": true,
    "link_mode": "Bidirectional"
  }'
```

### Source-initiated Cluster Link (Destination mode)
```bash
curl -X POST "{BASE_URL}/organizations/{ORG_IDENTIFIER}/kafka-replicators/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "cluster-link-02",
    "provider": "Cluster Link",
    "source_kafka_id": "cfk-cluster-id",
    "destination_kafka_id": "another-cfk-cluster-id",
    "source_secret": {
      "provider": "vault",
      "path": "/replicators/cluster-link-02/source-secret",
      "authentication_type": "SASL/SCRAM-SHA-512",
      "content": {
        "authentication_type": "SASL/SCRAM-SHA-512",
        "username": "source-user",
        "password": "source-password"
      }
    },
    "destination_secret": {
      "provider": "vault",
      "path": "/replicators/cluster-link-02/destination-secret",
      "authentication_type": "SASL/SCRAM-SHA-512",
      "content": {
        "authentication_type": "SASL/SCRAM-SHA-512",
        "username": "dest-user",
        "password": "dest-password"
      }
    },
    "replication_mode": "active-passive",
    "lag_alert_threshold": 5000,
    "lag_alert_threshold_unit": "bytes",
    "source_initiated_link": true,
    "link_mode": "Destination"
  }'
```

---

## 4. READ - List All Replicators

### GET List
```bash
curl -X GET "{BASE_URL}/organizations/{ORG_IDENTIFIER}/kafka-replicators/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json"
```

### GET List with query parameters (if supported)
```bash
curl -X GET "{BASE_URL}/organizations/{ORG_IDENTIFIER}/kafka-replicators/?status=Healthy&provider=MirrorMaker2" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json"
```

---

## 5. READ - Get Single Replicator

### GET by Identifier
```bash
curl -X GET "{BASE_URL}/organizations/{ORG_IDENTIFIER}/kafka-replicators/{REPLICATOR_IDENTIFIER}/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json"
```

Example:
```bash
curl -X GET "{BASE_URL}/organizations/my-org/kafka-replicators/my-replicator-01/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json"
```

---

## 6. UPDATE - Partial Update (PATCH)

### Update replication mode and lag threshold
```bash
curl -X PATCH "{BASE_URL}/organizations/{ORG_IDENTIFIER}/kafka-replicators/{REPLICATOR_IDENTIFIER}/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "replication_mode": "active-passive",
    "lag_alert_threshold": 2000,
    "lag_alert_threshold_unit": "messages"
  }'
```

### Update topic filters
```bash
curl -X PATCH "{BASE_URL}/organizations/{ORG_IDENTIFIER}/kafka-replicators/{REPLICATOR_IDENTIFIER}/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "topic_whitelist": "new-topic-1,new-topic-2",
    "topic_blacklist": "temp-*",
    "groups_whitelist": "new-group-*"
  }'
```

### Update Cluster Link mode
```bash
curl -X PATCH "{BASE_URL}/organizations/{ORG_IDENTIFIER}/kafka-replicators/cluster-link-01/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "link_mode": "Source"
  }'
```

---

## 7. UPDATE - Full Update (PUT)

### Full update (all fields)
```bash
curl -X PUT "{BASE_URL}/organizations/{ORG_IDENTIFIER}/kafka-replicators/{REPLICATOR_IDENTIFIER}/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "my-replicator-01",
    "provider": "MirrorMaker2",
    "source_kafka_id": "source-cluster-id",
    "destination_kafka_id": "dest-cluster-id",
    "source_secret_path": "/replicators/my-replicator-01/source-secret",
    "destination_secret_path": "/replicators/my-replicator-01/destination-secret",
    "replication_mode": "active-active",
    "lag_alert_threshold": 1500,
    "lag_alert_threshold_unit": "messages",
    "topic_whitelist": "topic1,topic2",
    "topic_blacklist": "internal-*",
    "groups_whitelist": "group1",
    "groups_blacklist": null
  }'
```

**Note**: PUT typically requires all fields. Use PATCH for partial updates.

---

## 8. DELETE - Remove Replicator

### DELETE
```bash
curl -X DELETE "{BASE_URL}/organizations/{ORG_IDENTIFIER}/kafka-replicators/{REPLICATOR_IDENTIFIER}/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json"
```

Example:
```bash
curl -X DELETE "{BASE_URL}/organizations/my-org/kafka-replicators/my-replicator-01/" \
  -H "Authorization: Bearer {ACCESS_TOKEN}" \
  -H "Content-Type: application/json"
```

---

## Authentication Examples

### Using OAuth Token
```bash
export ACCESS_TOKEN="your-oauth-token-here"
export BASE_URL="https://api.example.com"
export ORG_IDENTIFIER="my-org"

curl -X GET "${BASE_URL}/organizations/${ORG_IDENTIFIER}/kafka-replicators/" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json"
```

### Get Token from Keycloak (example)
```bash
# Get OAuth token from Keycloak
TOKEN=$(curl -X POST "https://keycloak.example.com/realms/fleet-manager/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=your-client-id" \
  -d "client_secret=your-client-secret" \
  -d "grant_type=client_credentials" | jq -r '.access_token')

# Use token in API request
curl -X GET "${BASE_URL}/organizations/${ORG_IDENTIFIER}/kafka-replicators/" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json"
```

---

## Error Responses

### 400 Bad Request - Validation Error
```json
{
  "detail": "identifier is required"
}
```

### 400 Bad Request - Missing Secret
```json
{
  "detail": "Both source_secret and destination_secret are required"
}
```

### 400 Bad Request - Invalid Cluster Link Configuration
```json
{
  "detail": "link_mode is required when source_initiated_link=True for Cluster Link"
}
```

### 404 Not Found
```json
{
  "detail": "Kafka replicator 'my-replicator-01' not found for organization 'my-org'"
}
```

### 401 Unauthorized
```json
{
  "detail": "Authentication credentials were not provided."
}
```

---

## Response Examples

### Successful Create (201)
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "identifier": "my-replicator-01",
  "provider": "MirrorMaker2",
  "source_kafka_id": "source-cluster-id",
  "destination_kafka_id": "dest-cluster-id",
  "source_secret_path": "builtin:///replicators/my-replicator-01/source-secret",
  "destination_secret_path": "builtin:///replicators/my-replicator-01/destination-secret",
  "replication_mode": "active-active",
  "lag_alert_threshold": 1000.0,
  "lag_alert_threshold_unit": "messages",
  "topic_whitelist": "topic1,topic2,prefix-*",
  "topic_blacklist": "internal-*",
  "groups_whitelist": "group1,group2",
  "groups_blacklist": "admin-*",
  "fleet_id": "auto-selected-fleet-id",
  "status": "Provisioning",
  "warnings": {
    "fleet_placement_warning": "Replicator is deployed on the same fleet as source cluster. This shares the same fault boundary."
  },
  "source_initiated_link": false,
  "link_mode": null,
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:30:00Z"
}
```

### Successful List (200)
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "identifier": "my-replicator-01",
    "provider": "MirrorMaker2",
    "status": "Healthy",
    ...
  },
  {
    "id": "660e8400-e29b-41d4-a716-446655440001",
    "identifier": "my-replicator-02",
    "provider": "MirrorMaker2",
    "status": "Provisioning",
    ...
  }
]
```

---

## Testing Checklist

- [ ] Get JSON schema endpoint
- [ ] Create MirrorMaker2 with Streamtime clusters
- [ ] Create MirrorMaker2 with external clusters
- [ ] Create MirrorMaker2 with mixed clusters
- [ ] Create Cluster Link (source-initiated, bidirectional)
- [ ] Create Cluster Link (source-initiated, destination mode)
- [ ] Create Cluster Link (source-initiated, source mode)
- [ ] List all replicators
- [ ] Get single replicator
- [ ] Update replicator (PATCH)
- [ ] Update replicator (PUT)
- [ ] Delete replicator
- [ ] Test validation errors (missing fields)
- [ ] Test authentication errors (invalid token)
- [ ] Test not found errors (invalid identifier)

---

## Notes

1. **Secret Paths**: The API will auto-generate secret paths based on the replicator identifier if not provided:
   - Source: `/replicators/{identifier}/source-secret`
   - Destination: `/replicators/{identifier}/destination-secret`

2. **Fleet Selection**: The fleet is automatically selected by the system. Users cannot specify the fleet.

3. **Secret Content**: The secret content must match the authentication_type schema:
   - `SASL/PLAIN`: requires `username`, `password`
   - `SASL/SCRAM-SHA-256` or `SASL/SCRAM-SHA-512`: requires `username`, `password`
   - `SASL/OAUTHBEARER`: requires `client_id`, `client_secret`, `token_endpoint_uri`; optional: `access_token_is_jwt` (default: true), `scope`, `audience`, `max_seconds_without_reauthentication`
   - `SSL`: requires `ca_certificate`, `client_certificate`, `client_key`

4. **Workflow Dispatch**: Creating/updating/deleting a replicator automatically dispatches a Temporal workflow to handle deployment.

5. **Status Values**: Possible status values include:
   - `Provisioning`: Workflow started, deployment in progress
   - `Healthy`: Deployment successful, replicator running
   - `Error`: Deployment failed or error occurred
   - `Deleting`: Deletion in progress
