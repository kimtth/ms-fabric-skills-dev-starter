# Authoring CLI Quick Reference

Concise `az rest` invocation patterns for Dataflows Gen2 authoring, base64 helpers, definition manipulation, and agent tips. For full API patterns and M code structure, see [DATAFLOWS-AUTHORING-CORE.md](../../../common/DATAFLOWS-AUTHORING-CORE.md). For full reusable scripts, see [authoring-script-templates.md](authoring-script-templates.md).

All examples assume reusable connection variables are set:

```bash
WS_ID="<workspaceId>"
DF_ID="<dataflowId>"
API="https://api.fabric.microsoft.com/v1"
RESOURCE="https://api.fabric.microsoft.com"
```

## Core Authoring via CLI

### Create Dataflow (Empty)

```bash
az rest --method post \
  --resource "$RESOURCE" \
  --url "$API/workspaces/$WS_ID/dataflows" \
  --body '{"displayName":"MyDataflow","description":"Sales ETL dataflow"}'
```

### Create Dataflow (With Definition)

```bash
# Prepare definition parts (base64-encode each file)
QM_B64=$(cat queryMetadata.json | base64 -w0)
MASHUP_B64=$(cat mashup.pq | base64 -w0)
PLATFORM_B64=$(cat .platform | base64 -w0)

az rest --method post \
  --resource "$RESOURCE" \
  --url "$API/workspaces/$WS_ID/dataflows" \
  --body "{
    \"displayName\": \"MyDataflow\",
    \"definition\": {
      \"parts\": [
        {\"path\":\"queryMetadata.json\",\"payload\":\"$QM_B64\",\"payloadType\":\"InlineBase64\"},
        {\"path\":\"mashup.pq\",\"payload\":\"$MASHUP_B64\",\"payloadType\":\"InlineBase64\"},
        {\"path\":\".platform\",\"payload\":\"$PLATFORM_B64\",\"payloadType\":\"InlineBase64\"}
      ]
    }
  }"
```

### Get Definition

```bash
# POST (not GET!) — may return 200 or 202 (LRO)
az rest --method post \
  --resource "$RESOURCE" \
  --url "$API/workspaces/$WS_ID/dataflows/$DF_ID/getDefinition"
```

### Update Definition

```bash
# Always send all 3 parts — full replacement
az rest --method post \
  --resource "$RESOURCE" \
  --url "$API/workspaces/$WS_ID/dataflows/$DF_ID/updateDefinition?updateMetadata=true" \
  --body @definition.json
```

### Delete Dataflow

```bash
az rest --method delete \
  --resource "$RESOURCE" \
  --url "$API/workspaces/$WS_ID/dataflows/$DF_ID"
```

### Trigger Refresh (Simple)

```bash
az rest --method post \
  --resource "$RESOURCE" \
  --url "$API/workspaces/$WS_ID/items/$DF_ID/jobs/Execute/instances" \
  --headers "Content-Length=0"
```

### Trigger Refresh (With Parameters)

```bash
az rest --method post \
  --resource "$RESOURCE" \
  --url "$API/workspaces/$WS_ID/items/$DF_ID/jobs/Execute/instances" \
  --body '{
    "executionData": {"executeOption": "ApplyChangesIfNeeded"},
    "parameters": [
      {"name":"ServerName","value":"prod.database.windows.net","type":"Automatic"},
      {"name":"StartDate","value":"2025-01-01","type":"Automatic"}
    ]
  }'
```

### Rename Dataflow (Properties Only)

```bash
az rest --method patch \
  --resource "$RESOURCE" \
  --url "$API/workspaces/$WS_ID/dataflows/$DF_ID" \
  --body '{"displayName":"RenamedDataflow","description":"Updated description"}'
```

## Base64 Encoding Helpers

### Bash

```bash
# Encode file to base64 (no line wrapping)
base64 -w0 < mashup.pq

# Decode base64 payload to file
echo "<base64string>" | base64 -d > mashup.pq

# Extract and decode a specific part from getDefinition response
echo "$RESPONSE" | jq -r '.definition.parts[] | select(.path=="mashup.pq") | .payload' | base64 -d
```

### PowerShell

```powershell
# Encode file to base64
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes("mashup.pq"))

# Decode base64 to file
[System.IO.File]::WriteAllBytes("mashup.pq", [Convert]::FromBase64String($base64String))

# Encode string content (UTF-8, no BOM)
[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($content))
```

## Definition Manipulation Patterns

### Read-Modify-Write Workflow

```bash
# 1. Get current definition
RESULT=$(az rest --method post \
  --resource "$RESOURCE" \
  --url "$API/workspaces/$WS_ID/dataflows/$DF_ID/getDefinition")

# 2. Extract and decode each part
echo "$RESULT" | jq -r '.definition.parts[] | select(.path=="queryMetadata.json") | .payload' | base64 -d > queryMetadata.json
echo "$RESULT" | jq -r '.definition.parts[] | select(.path=="mashup.pq") | .payload' | base64 -d > mashup.pq
echo "$RESULT" | jq -r '.definition.parts[] | select(.path==".platform") | .payload' | base64 -d > .platform

# 3. Edit files as needed (e.g., modify mashup.pq)

# 4. Re-encode and build update payload
QM_B64=$(base64 -w0 < queryMetadata.json)
MASHUP_B64=$(base64 -w0 < mashup.pq)
PLATFORM_B64=$(base64 -w0 < .platform)

jq -n \
  --arg qm "$QM_B64" --arg mash "$MASHUP_B64" --arg plat "$PLATFORM_B64" \
  '{definition:{parts:[
    {path:"queryMetadata.json",payload:$qm,payloadType:"InlineBase64"},
    {path:"mashup.pq",payload:$mash,payloadType:"InlineBase64"},
    {path:".platform",payload:$plat,payloadType:"InlineBase64"}
  ]}}' > definition.json

# 5. Update
az rest --method post \
  --resource "$RESOURCE" \
  --url "$API/workspaces/$WS_ID/dataflows/$DF_ID/updateDefinition?updateMetadata=true" \
  --body @definition.json
```

### LRO Polling Helper

```bash
# Poll operation until terminal status
poll_operation() {
  local url="$1"
  while true; do
    STATUS=$(az rest --method get --resource "$RESOURCE" --url "$url" --query "status" --output tsv)
    echo "Status: $STATUS"
    case "$STATUS" in
      Succeeded|Failed|Cancelled) break ;;
      *) sleep 10 ;;
    esac
  done
  echo "Final status: $STATUS"
}
```

## Agent Integration Notes

- **GitHub Copilot CLI**: Generate `az rest` one-liners for dataflow CRUD or complete `.sh` scripts. Always include `--resource "https://api.fabric.microsoft.com"` in output. Remind user about base64 encoding for definition parts.
- **Claude Code / Cowork**: Run `az rest` commands via `bash` tool directly. For definition manipulation: write files first, then encode and send. Always verify `az login` before first use. After updates: get definition again to confirm.
- **Common agent pattern**:
  1. Discover workspace ID + dataflow ID
  2. Get current definition (decode all 3 parts)
  3. Formulate changes to M code or metadata
  4. Re-encode all 3 parts and update definition
  5. Optionally trigger refresh and poll for completion
