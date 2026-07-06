# Wazuh + Elasticsearch Integration via Filebeat 9.x

A lightweight Docker Compose setup that ships Wazuh Manager alerts to Elasticsearch using **only Filebeat 9.x** — no Logstash, no heavy middleware.

## Architecture

Three containers, minimal moving parts:

| Container | Role | Lifecycle |
|-----------|------|-----------|
| `init-es` | Downloads Wazuh Filebeat module + provisions ES roles/users | One-shot, exits on success |
| `wazuh-manager` | Receives agent logs, writes to `/var/ossec/logs` | Persistent |
| `filebeat` | Reads logs, enriches via Ingest Pipeline, indexes into ES | Persistent (waits for init-es) |

## Prerequisites

- Docker + Docker Compose v2
- Elasticsearch 9.x cluster (external)
- Python 3 (for template conversion)

## Quick Start

### 1. Clone & Prepare

```bash
git clone https://github.com/instresting-git/wazuh-elastic-integration-with-filebeat9.git
cd wazuh-elastic-integration-with-filebeat9

# Create required directories
mkdir -p filebeat templates filebeat_resources
```

### 2. Download & Convert the Wazuh Index Template

```bash
# Download official Wazuh template (Legacy format for ES 7.x)
curl -o templates/wazuh-template.json \
  https://raw.githubusercontent.com/wazuh/wazuh/v4.14.6/extensions/elasticsearch/7.x/wazuh-template.json

# Convert to ES 9.x Composable Index Template format
python3 convert_template.py
```

### 3. Configure Credentials

Edit these files with your Elasticsearch details:

**`init_es.sh`:**
```bash
ES_URL="https://<YOUR_ES_HOST>:9200"
ES_USER="elastic"
ES_PASS="<YOUR_ELASTIC_PASSWORD>"
WAZUH_PASS="<YOUR_WAZUH_FILEBEAT_PASSWORD>"
```

**`filebeat/filebeat.yml`:**
```yaml
output.elasticsearch:
  hosts: ['https://<YOUR_ES_HOST>:9200']
  password: "<YOUR_WAZUH_FILEBEAT_PASSWORD>"
```

> **Note for ES 9.x:** Passwords must meet complexity requirements (uppercase + lowercase + digits + special characters). Simple passwords like `changeme` will be rejected.

### 4. Start the Stack

```bash
docker compose up -d
```

On first run, `init-es` will:
1. Download the Wazuh Filebeat module from packages.wazuh.com
2. Normalize the directory structure
3. Wait for Elasticsearch to be reachable
4. Create the `wazuh_role` and `wazuh_user`

Filebeat waits for `init-es` to exit successfully before starting.

### 5. Verify

```bash
docker compose ps              # All three containers
docker compose logs init-es    # Should show "Initialization complete."
docker compose logs filebeat   # Should show successful ES connection
```

## ES 9.x Compatibility

Wazuh's official Filebeat module and Index Template were designed for ES 7.x. This setup handles two key compatibility issues:

1. **Index Template** — `convert_template.py` transforms the Legacy template (`_template` API) into Composable format (`_index_template` API) required by ES 8+
2. **Ingest Pipeline** — The Wazuh module's pipeline (JSON parsing + GeoIP enrichment) works natively with ES 9.x Filebeat

## File Structure

```
wazuh-elastic-integration-filebeat9/
├── docker-compose.yml
├── init_es.sh                  # One-shot init script
├── convert_template.py         # Legacy → Composable template converter
├── filebeat/
│   └── filebeat.yml            # Filebeat configuration
├── filebeat_resources/         # Shared volume: module downloaded at runtime
│   └── module/wazuh/           # (populated by init-es)
└── templates/
    ├── wazuh-template.json     # Downloaded from Wazuh GitHub (Legacy)
    └── wazuh-template-es9.json # Converted for ES 9.x (Composable)
```

## Key Design Decisions

- **init-es pattern:** Self-contained initialization eliminates manual pre-deployment steps
- **`service_completed_successfully`:** Guarantees Filebeat won't start until ES is fully provisioned
- **Docker volumes for shared logs:** Filebeat mounts `wazuh-logs` as read-only — security boundary
- **No Logstash:** The Wazuh Filebeat module's built-in Ingest Pipeline handles JSON parsing and GeoIP enrichment at index time

## Version Matrix

| Component | Version |
|-----------|---------|
| Wazuh Manager | 4.14.6 |
| Filebeat | 9.4.3 |
| Elasticsearch | 9.x |
| Wazuh Filebeat Module | 0.4 |

## License

MIT
