import json

# Load the official Wazuh template (Legacy format from ES 7.x)
with open('templates/wazuh-template.json', 'r') as f:
    legacy_template = json.load(f)

# Convert to ES 8+/9.x Composable Index Template format
composable_template = {
    "index_patterns": legacy_template.get("index_patterns", ["wazuh-alerts-4.x-*"]),
    "template": {
        "settings": legacy_template.get("settings", {}),
        "mappings": legacy_template.get("mappings", {})
    },
    "priority": 500,
    "composed_of": [],
    "_meta": {"description": "Wazuh template converted for ES 9.x"}
}

# Strip legacy settings unsupported in ES 9.x
if 'index' in composable_template['template']['settings']:
    settings = composable_template['template']['settings']['index']
    settings.pop('max_script_fields', None)
    settings.pop('query', None)

with open('templates/wazuh-template-es9.json', 'w') as f:
    json.dump(composable_template, f, indent=2)

print("Template converted successfully.")
