# Consumption CLI Quick Reference

Concise `az rest` one-liners for all Dataflows Gen2 consumption operations. For full API details, see [DATAFLOWS-CONSUMPTION-CORE.md](../../../common/DATAFLOWS-CONSUMPTION-CORE.md). For full reusable scripts, see [script-templates.md](script-templates.md).

All examples assume reusable connection variables are set:

```bash
WS_ID="<workspaceId>"
DF_ID="<dataflowId>"
API="https://api.fabric.microsoft.com/v1"
AZ="az rest --resource https://api.fabric.microsoft.com"
```

## Listing and Discovery

```bash
# List all dataflows in a workspace
$AZ --method get --url "$API/workspaces/$WS_ID/dataflows" \
  --query "value[].{name:displayName, id:id}" -o table

# Find dataflow by name
$AZ --method get --url "$API/workspaces/$WS_ID/dataflows" \
  --query "value[?displayName=='Sales Data Pipeline'].id" -o tsv

# Get dataflow properties
$AZ --method get --url "$API/workspaces/$WS_ID/dataflows/$DF_ID"

# List dataflows across all workspaces (iterate)
for ws in $(az rest --method get --resource "https://api.fabric.microsoft.com" \
  --url "$API/workspaces" --query "value[].id" -o tsv); do
  echo "--- Workspace: $ws ---"
  $AZ --method get --url "$API/workspaces/$ws/dataflows" \
    --query "value[].{name:displayName, id:id}" -o table 2>/dev/null
done
```

## Parameters

```bash
# Discover all parameters
$AZ --method get --url "$API/workspaces/$WS_ID/dataflows/$DF_ID/parameters" \
  --query "value[].{name:name, type:type, required:isRequired, default:defaultValue}" -o table

# Get parameters as JSON (for scripting)
$AZ --method get --url "$API/workspaces/$WS_ID/dataflows/$DF_ID/parameters" \
  --query "value" -o json
```

## Definition Exploration

```bash
# Get definition (returns base64 parts)
$AZ --method post --url "$API/workspaces/$WS_ID/dataflows/$DF_ID/getDefinition"

# Decode mashup.pq (Power Query M code)
$AZ --method post --url "$API/workspaces/$WS_ID/dataflows/$DF_ID/getDefinition" | \
  jq -r '.definition.parts[] | select(.path=="mashup.pq") | .payload' | base64 --decode

# Decode queryMetadata.json (query config and connections)
$AZ --method post --url "$API/workspaces/$WS_ID/dataflows/$DF_ID/getDefinition" | \
  jq -r '.definition.parts[] | select(.path=="queryMetadata.json") | .payload' | base64 --decode | jq .

# Decode .platform (item metadata)
$AZ --method post --url "$API/workspaces/$WS_ID/dataflows/$DF_ID/getDefinition" | \
  jq -r '.definition.parts[] | select(.path==".platform") | .payload' | base64 --decode | jq .
```

## Job and Refresh Monitoring

```bash
# Recent job instances (all)
$AZ --method get --url "$API/workspaces/$WS_ID/items/$DF_ID/jobs/instances" \
  --query "value[].{status:status, type:invokeType, start:startTimeUtc, end:endTimeUtc, error:failureReason}" -o table

# Last job status only
$AZ --method get --url "$API/workspaces/$WS_ID/items/$DF_ID/jobs/instances" \
  --query "value[0].{status:status, start:startTimeUtc, end:endTimeUtc}" -o table

# Failed jobs only
$AZ --method get --url "$API/workspaces/$WS_ID/items/$DF_ID/jobs/instances" \
  --query "value[?status=='Failed'].{id:id, start:startTimeUtc, error:failureReason}" -o table

# Poll a running operation
OP_ID="<operationId>"
$AZ --method get --url "$API/operations/$OP_ID"
```

## PowerShell Equivalents

```powershell
# List dataflows
az rest --method get --resource "https://api.fabric.microsoft.com" `
  --url "https://api.fabric.microsoft.com/v1/workspaces/$WS_ID/dataflows" `
  --query "value[].{name:displayName, id:id}" -o table

# Discover parameters
az rest --method get --resource "https://api.fabric.microsoft.com" `
  --url "https://api.fabric.microsoft.com/v1/workspaces/$WS_ID/dataflows/$DF_ID/parameters" `
  --query "value[].{name:name, type:type, required:isRequired}" -o table

# Decode mashup.pq (PowerShell)
$response = az rest --method post --resource "https://api.fabric.microsoft.com" `
  --url "https://api.fabric.microsoft.com/v1/workspaces/$WS_ID/dataflows/$DF_ID/getDefinition" | ConvertFrom-Json
$mashup = $response.definition.parts | Where-Object { $_.path -eq "mashup.pq" }
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($mashup.payload))
```

## Agent Integration Notes

- **GitHub Copilot CLI**: use `gh copilot suggest -t shell` for `az rest` one-liners; ensure `--resource` in output.
- **Claude Code / Cowork**: run `az rest` via `bash` tool; follow the Agentic Workflow in [SKILL.md](../SKILL.md); produce scripts using [script-templates.md](script-templates.md).
- Always verify `az login` session before first REST operation.
