#!/bin/sh
set -e

echo "Installing curl in Alpine..."
apk add --no-cache curl > /dev/null 2>&1

# ⚠️ REPLACE THESE with your own values before deploying
ES_URL="https://<YOUR_ES_HOST>:9200"
ES_USER="elastic"
ES_PASS="<YOUR_ELASTIC_PASSWORD>"
WAZUH_PASS="<YOUR_WAZUH_FILEBEAT_PASSWORD>"  # ES 9.x requires uppercase+lowercase+digit+special

# Resource directory inside container (maps to docker-compose volume)
RESOURCE_DIR="/resources"
TARBALL="$RESOURCE_DIR/wazuh-filebeat-0.4.tar.gz"
MODULE_DIR="$RESOURCE_DIR/module"

# ==========================================
# 1. Download & extract Wazuh Filebeat module
# ==========================================
if [ ! -d "$MODULE_DIR/wazuh" ]; then
  echo "Downloading Wazuh Filebeat module..."
  wget -q -O "$TARBALL" https://packages.wazuh.com/4.x/filebeat/wazuh-filebeat-0.4.tar.gz
  echo "Extracting..."
  tar -xzf "$TARBALL" -C "$RESOURCE_DIR"

  # Normalize directory structure to module/wazuh/
  mkdir -p "$RESOURCE_DIR/module"

  # Case A: extracted directly as /resources/wazuh/
  if [ -d "$RESOURCE_DIR/wazuh" ] && [ ! -d "$RESOURCE_DIR/module/wazuh" ]; then
    mv "$RESOURCE_DIR/wazuh" "$RESOURCE_DIR/module/wazuh"
  # Case B: extracted as /resources/wazuh-filebeat-0.4/module/wazuh/
  elif [ -d "$RESOURCE_DIR/wazuh-filebeat-0.4/module/wazuh" ]; then
    mv "$RESOURCE_DIR/wazuh-filebeat-0.4/module/wazuh" "$RESOURCE_DIR/module/wazuh"
  # Case C: already /resources/module/wazuh/ (no-op)
  elif [ -d "$RESOURCE_DIR/module/wazuh" ]; then
    echo "Directory structure is already correct."
  else
    echo "ERROR: Cannot find wazuh module after extraction. Dumping tree:"
    find "$RESOURCE_DIR" -maxdepth 3
    exit 1
  fi

  echo "Wazuh module extracted and structured successfully."
else
  echo "Wazuh module already exists, skipping download."
fi

# ==========================================
# 2. Initialize Elasticsearch (create role & user)
# ==========================================
echo "Waiting for Elasticsearch..."
until curl -k -s -u $ES_USER:$ES_PASS "$ES_URL" > /dev/null; do
  sleep 2
done
echo "ES is up. Initializing..."

# Create wazuh_role
curl -s -k -u $ES_USER:$ES_PASS -X PUT "$ES_URL/_security/role/wazuh_role" -H 'Content-Type: application/json' -d'
{
  "cluster": [ "monitor", "manage_ingest_pipelines", "manage_ilm","manage_index_templates","manage", "all" ],
  "indices": [ { "names": [ "wazuh-*" ], "privileges": [ "write", "create_index", "manage", "manage_ilm", "read" ] } ]
}'

# Create wazuh_user
curl -s -k -u $ES_USER:$ES_PASS -X PUT "$ES_URL/_security/user/wazuh_user" -H 'Content-Type: application/json' -d"
{
  \"password\" : \"$WAZUH_PASS\",
  \"roles\" : [ \"wazuh_role\" ],
  \"full_name\" : \"Wazuh Filebeat User\"
}"

echo "Initialization complete."
