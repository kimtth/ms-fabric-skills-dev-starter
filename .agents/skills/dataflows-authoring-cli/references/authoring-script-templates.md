# Authoring Script Templates

Self-contained templates for generating reusable Dataflows Gen2 authoring scripts.

**Common prerequisites** (validated in each template):
- `az` CLI installed — `https://aka.ms/install-azure-cli`
- `az login` session active
- `jq` installed — `apt-get install jq` / `brew install jq`
- Env vars: `WS_ID` (workspace ID), `API`, `RESOURCE`

## Bash Templates

### Bash — Create Dataflow with Inline Definition

```bash
#!/usr/bin/env bash
set -euo pipefail

WS_ID="${WS_ID:?Set WS_ID env var}"
API="https://api.fabric.microsoft.com/v1"
RESOURCE="https://api.fabric.microsoft.com"
DATAFLOW_NAME="${1:?Usage: $0 <dataflow_name>}"

command -v az >/dev/null 2>&1 || { echo "ERROR: az CLI not found."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found."; exit 1; }
az account show >/dev/null 2>&1 || { echo "Run 'az login' first."; exit 1; }

# Define M code (Power Query section document)
MASHUP='section Section1;

shared SalesData = let
    Source = Lakehouse.Contents([]),
    Nav1 = Source{[workspaceId = "'"$WS_ID"'"]}[Data],
    Nav2 = Nav1{[lakehouseId = "your-lakehouse-id"]}[Data],
    Nav3 = Nav2{[Id = "sales", ItemKind = "Table"]}[Data]
in
    Nav3;'

# Define query metadata
QUERY_METADATA='{
  "formatVersion": "202502",
  "computeEngineSettings": {"allowFastCopy": true, "maxConcurrency": 1},
  "name": "'"$DATAFLOW_NAME"'",
  "queryGroups": [],
  "documentLocale": "en-US",
  "queriesMetadata": {
    "SalesData": {
      "queryId": "'$(uuidgen | tr '[:upper:]' '[:lower:]')'",
      "queryName": "SalesData",
      "loadEnabled": true,
      "isHidden": false
    }
  },
  "connections": [],
  "fastCombine": false,
  "allowNativeQueries": true,
  "parametric": false
}'

# Define .platform
PLATFORM='{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {"type": "Dataflow", "displayName": "'"$DATAFLOW_NAME"'"},
  "config": {"version": "2.0", "logicalId": "'$(uuidgen | tr '[:upper:]' '[:lower:]')'"}
}'

# Base64-encode all parts
QM_B64=$(echo -n "$QUERY_METADATA" | base64 -w0)
MASHUP_B64=$(echo -n "$MASHUP" | base64 -w0)
PLATFORM_B64=$(echo -n "$PLATFORM" | base64 -w0)

# Build request body
BODY=$(jq -n \
  --arg name "$DATAFLOW_NAME" \
  --arg qm "$QM_B64" --arg mash "$MASHUP_B64" --arg plat "$PLATFORM_B64" \
  '{displayName:$name,definition:{parts:[
    {path:"queryMetadata.json",payload:$qm,payloadType:"InlineBase64"},
    {path:"mashup.pq",payload:$mash,payloadType:"InlineBase64"},
    {path:".platform",payload:$plat,payloadType:"InlineBase64"}
  ]}}')

echo "Creating dataflow '$DATAFLOW_NAME' ..."
RESULT=$(az rest --method post \
  --resource "$RESOURCE" \
  --url "$API/workspaces/$WS_ID/dataflows" \
  --body "$BODY")

echo "$RESULT" | jq '{id, displayName}'
echo "✓ Dataflow created"
```

### Bash — Read-Modify-Write Dataflow Definition

```bash
#!/usr/bin/env bash
set -euo pipefail

WS_ID="${WS_ID:?Set WS_ID env var}"
DF_ID="${DF_ID:?Set DF_ID env var}"
API="https://api.fabric.microsoft.com/v1"
RESOURCE="https://api.fabric.microsoft.com"
WORK_DIR="${1:-./_df_work}"

command -v az >/dev/null 2>&1 || { echo "ERROR: az CLI not found."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found."; exit 1; }
az account show >/dev/null 2>&1 || { echo "Run 'az login' first."; exit 1; }

mkdir -p "$WORK_DIR"

echo "[1/4] Getting current definition ..."
RESULT=$(az rest --method post \
  --resource "$RESOURCE" \
  --url "$API/workspaces/$WS_ID/dataflows/$DF_ID/getDefinition")

echo "[2/4] Decoding definition parts ..."
echo "$RESULT" | jq -r '.definition.parts[] | select(.path=="queryMetadata.json") | .payload' | base64 -d > "$WORK_DIR/queryMetadata.json"
echo "$RESULT" | jq -r '.definition.parts[] | select(.path=="mashup.pq") | .payload' | base64 -d > "$WORK_DIR/mashup.pq"
echo "$RESULT" | jq -r '.definition.parts[] | select(.path==".platform") | .payload' | base64 -d > "$WORK_DIR/.platform"

echo "Files written to $WORK_DIR/"
echo "  - queryMetadata.json"
echo "  - mashup.pq"
echo "  - .platform"
echo ""
echo "Edit the files as needed, then re-run with --upload flag."
echo ""

if [[ "${2:-}" == "--upload" ]]; then
  echo "[3/4] Re-encoding definition parts ..."
  QM_B64=$(base64 -w0 < "$WORK_DIR/queryMetadata.json")
  MASHUP_B64=$(base64 -w0 < "$WORK_DIR/mashup.pq")
  PLATFORM_B64=$(base64 -w0 < "$WORK_DIR/.platform")

  jq -n \
    --arg qm "$QM_B64" --arg mash "$MASHUP_B64" --arg plat "$PLATFORM_B64" \
    '{definition:{parts:[
      {path:"queryMetadata.json",payload:$qm,payloadType:"InlineBase64"},
      {path:"mashup.pq",payload:$mash,payloadType:"InlineBase64"},
      {path:".platform",payload:$plat,payloadType:"InlineBase64"}
    ]}}' > "$WORK_DIR/definition.json"

  echo "[4/4] Uploading updated definition ..."
  az rest --method post \
    --resource "$RESOURCE" \
    --url "$API/workspaces/$WS_ID/dataflows/$DF_ID/updateDefinition?updateMetadata=true" \
    --body @"$WORK_DIR/definition.json"

  echo "✓ Definition updated"
fi
```

### Bash — Trigger Refresh with LRO Polling

```bash
#!/usr/bin/env bash
set -euo pipefail

WS_ID="${WS_ID:?Set WS_ID env var}"
DF_ID="${DF_ID:?Set DF_ID env var}"
API="https://api.fabric.microsoft.com/v1"
RESOURCE="https://api.fabric.microsoft.com"
POLL_INTERVAL="${POLL_INTERVAL:-15}"
MAX_POLLS="${MAX_POLLS:-60}"

command -v az >/dev/null 2>&1 || { echo "ERROR: az CLI not found."; exit 1; }
az account show >/dev/null 2>&1 || { echo "Run 'az login' first."; exit 1; }

echo "Triggering refresh for dataflow $DF_ID ..."

# Trigger the job — capture Location header for polling
RESPONSE=$(az rest --method post \
  --resource "$RESOURCE" \
  --url "$API/workspaces/$WS_ID/items/$DF_ID/jobs/Execute/instances" \
  --headers "Content-Length=0" 2>&1) || true

# Extract operation ID from response (fallback: list recent operations)
OP_URL=$(echo "$RESPONSE" | grep -oP 'https://[^\s"]+/operations/[a-f0-9-]+' | head -1)

if [[ -z "$OP_URL" ]]; then
  echo "No operation URL captured. Check Azure portal for refresh status."
  exit 1
fi

echo "Polling: $OP_URL"
ATTEMPT=0
while [[ $ATTEMPT -lt $MAX_POLLS ]]; do
  STATUS=$(az rest --method get --resource "$RESOURCE" --url "$OP_URL" --query "status" --output tsv 2>/dev/null)
  PCT=$(az rest --method get --resource "$RESOURCE" --url "$OP_URL" --query "percentComplete" --output tsv 2>/dev/null || echo "?")
  echo "  [$ATTEMPT] Status: $STATUS ($PCT%)"

  case "$STATUS" in
    Succeeded)
      echo "✓ Refresh completed successfully"
      exit 0
      ;;
    Failed)
      echo "✗ Refresh failed"
      az rest --method get --resource "$RESOURCE" --url "$OP_URL" 2>/dev/null | jq .
      exit 1
      ;;
    Cancelled)
      echo "✗ Refresh was cancelled"
      exit 1
      ;;
  esac

  sleep "$POLL_INTERVAL"
  ATTEMPT=$((ATTEMPT + 1))
done

echo "✗ Polling timed out after $((MAX_POLLS * POLL_INTERVAL))s"
exit 1
```

### Bash — CI/CD Export and Import

```bash
#!/usr/bin/env bash
set -euo pipefail

API="https://api.fabric.microsoft.com/v1"
RESOURCE="https://api.fabric.microsoft.com"
ACTION="${1:?Usage: $0 <export|import> [options]}"

command -v az >/dev/null 2>&1 || { echo "ERROR: az CLI not found."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found."; exit 1; }
az account show >/dev/null 2>&1 || { echo "Run 'az login' first."; exit 1; }

case "$ACTION" in
  export)
    SRC_WS="${2:?Usage: $0 export <src_workspace_id> <dataflow_id> <output_dir>}"
    SRC_DF="${3:?Usage: $0 export <src_workspace_id> <dataflow_id> <output_dir>}"
    OUT_DIR="${4:?Usage: $0 export <src_workspace_id> <dataflow_id> <output_dir>}"
    mkdir -p "$OUT_DIR"

    echo "Exporting dataflow $SRC_DF from workspace $SRC_WS ..."
    RESULT=$(az rest --method post \
      --resource "$RESOURCE" \
      --url "$API/workspaces/$SRC_WS/dataflows/$SRC_DF/getDefinition")

    echo "$RESULT" | jq -r '.definition.parts[] | select(.path=="queryMetadata.json") | .payload' | base64 -d > "$OUT_DIR/queryMetadata.json"
    echo "$RESULT" | jq -r '.definition.parts[] | select(.path=="mashup.pq") | .payload' | base64 -d > "$OUT_DIR/mashup.pq"
    echo "$RESULT" | jq -r '.definition.parts[] | select(.path==".platform") | .payload' | base64 -d > "$OUT_DIR/.platform"
    echo "✓ Exported to $OUT_DIR/"
    ;;

  import)
    TGT_WS="${2:?Usage: $0 import <tgt_workspace_id> <dataflow_id> <input_dir>}"
    TGT_DF="${3:?Usage: $0 import <tgt_workspace_id> <dataflow_id> <input_dir>}"
    IN_DIR="${4:?Usage: $0 import <tgt_workspace_id> <dataflow_id> <input_dir>}"

    echo "Importing definition from $IN_DIR to dataflow $TGT_DF ..."
    QM_B64=$(base64 -w0 < "$IN_DIR/queryMetadata.json")
    MASHUP_B64=$(base64 -w0 < "$IN_DIR/mashup.pq")
    PLATFORM_B64=$(base64 -w0 < "$IN_DIR/.platform")

    jq -n \
      --arg qm "$QM_B64" --arg mash "$MASHUP_B64" --arg plat "$PLATFORM_B64" \
      '{definition:{parts:[
        {path:"queryMetadata.json",payload:$qm,payloadType:"InlineBase64"},
        {path:"mashup.pq",payload:$mash,payloadType:"InlineBase64"},
        {path:".platform",payload:$plat,payloadType:"InlineBase64"}
      ]}}' > /tmp/df_import_payload.json

    az rest --method post \
      --resource "$RESOURCE" \
      --url "$API/workspaces/$TGT_WS/dataflows/$TGT_DF/updateDefinition?updateMetadata=true" \
      --body @/tmp/df_import_payload.json

    rm -f /tmp/df_import_payload.json
    echo "✓ Definition imported"
    ;;

  *)
    echo "Usage: $0 <export|import> [options]"
    exit 1
    ;;
esac
```

## PowerShell Templates

### PowerShell — Create Dataflow with Definition

```powershell
#Requires -Version 5.1
param(
    [Parameter(Mandatory)][string]$WorkspaceId,
    [Parameter(Mandatory)][string]$DataflowName,
    [string]$Description = "Created via CLI"
)

$null = az account show 2>$null
if ($LASTEXITCODE -ne 0) { Write-Error "Not logged in. Run: az login"; exit 1 }

$api = "https://api.fabric.microsoft.com/v1"
$resource = "https://api.fabric.microsoft.com"

# Define M code
$mashup = @"
section Section1;

shared SalesData = let
    Source = Lakehouse.Contents([]),
    Nav1 = Source{[workspaceId = "$WorkspaceId"]}[Data]
in
    Nav1;
"@

# Define query metadata
$queryMetadata = @{
    formatVersion = "202502"
    computeEngineSettings = @{ allowFastCopy = $true; maxConcurrency = 1 }
    name = $DataflowName
    queryGroups = @()
    documentLocale = "en-US"
    queriesMetadata = @{
        SalesData = @{
            queryId = [guid]::NewGuid().ToString()
            queryName = "SalesData"
            loadEnabled = $true
            isHidden = $false
        }
    }
    connections = @()
    fastCombine = $false
    allowNativeQueries = $true
    parametric = $false
} | ConvertTo-Json -Depth 5

# Define .platform
$platform = @{
    "`$schema" = "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json"
    metadata = @{ type = "Dataflow"; displayName = $DataflowName }
    config = @{ version = "2.0"; logicalId = [guid]::NewGuid().ToString() }
} | ConvertTo-Json -Depth 3

# Base64-encode
$qmB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($queryMetadata))
$mashupB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($mashup))
$platformB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($platform))

$body = @{
    displayName = $DataflowName
    description = $Description
    definition = @{
        parts = @(
            @{ path = "queryMetadata.json"; payload = $qmB64; payloadType = "InlineBase64" }
            @{ path = "mashup.pq"; payload = $mashupB64; payloadType = "InlineBase64" }
            @{ path = ".platform"; payload = $platformB64; payloadType = "InlineBase64" }
        )
    }
} | ConvertTo-Json -Depth 5

Write-Host "Creating dataflow '$DataflowName' ..."
$result = az rest --method post --resource $resource `
    --url "$api/workspaces/$WorkspaceId/dataflows" `
    --body $body | ConvertFrom-Json

Write-Host "Created: $($result.id) - $($result.displayName)"
```

### PowerShell — Trigger Refresh with Polling

```powershell
#Requires -Version 5.1
param(
    [Parameter(Mandatory)][string]$WorkspaceId,
    [Parameter(Mandatory)][string]$DataflowId,
    [int]$PollIntervalSec = 15,
    [int]$TimeoutMin = 30
)

$null = az account show 2>$null
if ($LASTEXITCODE -ne 0) { Write-Error "Not logged in. Run: az login"; exit 1 }

$api = "https://api.fabric.microsoft.com/v1"
$resource = "https://api.fabric.microsoft.com"

Write-Host "Triggering refresh ..."
$response = az rest --method post --resource $resource `
    --url "$api/workspaces/$WorkspaceId/items/$DataflowId/jobs/Execute/instances" `
    --headers "Content-Length=0" 2>&1

# Extract operation URL
$opUrl = ($response | Select-String -Pattern 'https://[^\s"]+/operations/[a-f0-9-]+' -AllMatches).Matches[0].Value

if (-not $opUrl) {
    Write-Warning "No operation URL captured. Check portal."
    exit 1
}

$deadline = (Get-Date).AddMinutes($TimeoutMin)
while ((Get-Date) -lt $deadline) {
    $op = az rest --method get --resource $resource --url $opUrl | ConvertFrom-Json
    Write-Host "  Status: $($op.status) ($($op.percentComplete)%)"

    switch ($op.status) {
        "Succeeded" { Write-Host "Refresh completed"; exit 0 }
        "Failed"    { Write-Error "Refresh failed"; $op | ConvertTo-Json; exit 1 }
        "Cancelled" { Write-Warning "Refresh cancelled"; exit 1 }
    }

    Start-Sleep -Seconds $PollIntervalSec
}

Write-Error "Polling timed out after $TimeoutMin minutes"
exit 1
```
