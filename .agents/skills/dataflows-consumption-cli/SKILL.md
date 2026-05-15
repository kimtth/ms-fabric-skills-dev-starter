---
name: dataflows-consumption-cli
description: >
  Monitor, inspect, and discover Fabric Dataflows Gen2 via read-only CLI operations (az rest / curl).
  List dataflows across workspaces, decode base64 definitions to inspect Power Query M queries and
  queryMetadata.json, discover typed parameters with defaults, poll refresh operations for status,
  retrieve job history with timing and error details, and classify queries by staging settings.
  Use when the user wants to: (1) list dataflows, (2) inspect a dataflow definition and decode its
  mashup, (3) discover parameters, (4) check refresh status, (5) retrieve job history,
  (6) analyze staging settings, (7) examine connections and data source bindings.
  Triggers: "dataflow status", "refresh history", "dataflow monitor", "list dataflows", "dataflow
  parameters", "explore dataflow", "inspect dataflow", "dataflow run status".
---

> **Update Check — ONCE PER SESSION (mandatory)**
> The first time this skill is used in a session, run the **check-updates** skill before proceeding.
> - **GitHub Copilot CLI / VS Code**: invoke the `check-updates` skill.
> - **Claude Code / Cowork / Cursor / Windsurf / Codex**: compare local vs remote package.json version.
> - Skip if the check was already performed earlier in this session.

> **CRITICAL NOTES**
> 1. To find the workspace details (including its ID) from workspace name: list all workspaces and, then, use JMESPath filtering
> 2. To find a dataflow by name: list all dataflows in the workspace and filter by `displayName` client-side — there is no server-side name filter
> 3. `getDefinition` is a **POST**, not GET — even though it reads data

# Dataflows Gen2 — Consumption via CLI

## Table of Contents

| Task | Reference | Notes |
|---|---|---|
| Finding Workspaces and Items in Fabric | [COMMON-CLI.md § Finding Workspaces and Items in Fabric](../../common/COMMON-CLI.md#finding-workspaces-and-items-in-fabric) | **Mandatory** — *READ link first* |
| Fabric Topology & Key Concepts | [COMMON-CORE.md § Fabric Topology & Key Concepts](../../common/COMMON-CORE.md#fabric-topology--key-concepts) ||
| Environment URLs | [COMMON-CORE.md § Environment URLs](../../common/COMMON-CORE.md#environment-urls) ||
| Authentication & Token Acquisition | [COMMON-CORE.md § Authentication & Token Acquisition](../../common/COMMON-CORE.md#authentication--token-acquisition) | Wrong audience = 401; read before any auth issue |
| Core Control-Plane REST APIs | [COMMON-CORE.md § Core Control-Plane REST APIs](../../common/COMMON-CORE.md#core-control-plane-rest-apis) | Includes pagination, LRO polling, and rate-limiting patterns |
| Job Execution | [COMMON-CORE.md § Job Execution](../../common/COMMON-CORE.md#job-execution) ||
| Gotchas, Best Practices & Troubleshooting | [COMMON-CORE.md § Gotchas, Best Practices & Troubleshooting](../../common/COMMON-CORE.md#gotchas-best-practices--troubleshooting) ||
| Tool Selection Rationale | [COMMON-CLI.md § Tool Selection Rationale](../../common/COMMON-CLI.md#tool-selection-rationale) ||
| Authentication Recipes | [COMMON-CLI.md § Authentication Recipes](../../common/COMMON-CLI.md#authentication-recipes) | `az login` flows and token acquisition |
| Fabric Control-Plane API via `az rest` | [COMMON-CLI.md § Fabric Control-Plane API via az rest](../../common/COMMON-CLI.md#fabric-control-plane-api-via-az-rest) | **Always pass `--resource`**; includes pagination and LRO helpers |
| Job Execution (CLI) | [COMMON-CLI.md § Job Execution](../../common/COMMON-CLI.md#job-execution) ||
| Gotchas & Troubleshooting (CLI-Specific) | [COMMON-CLI.md § Gotchas & Troubleshooting (CLI-Specific)](../../common/COMMON-CLI.md#gotchas--troubleshooting-cli-specific) | `az rest` audience, shell escaping, token expiry |
| Quick Reference | [COMMON-CLI.md § Quick Reference](../../common/COMMON-CLI.md#quick-reference) | `az rest` template + token audience/tool matrix |
| Consumption Capability Matrix | [DATAFLOWS-CONSUMPTION-CORE.md § Consumption Capability Matrix](../../common/DATAFLOWS-CONSUMPTION-CORE.md#consumption-capability-matrix) | **Read first** — shows what ops are available |
| REST API Surface (Consumption) | [DATAFLOWS-CONSUMPTION-CORE.md § REST API Surface](../../common/DATAFLOWS-CONSUMPTION-CORE.md#rest-api-surface-consumption) | List, Get, Parameters, getDefinition, Jobs |
| Dataflow Definition Exploration | [DATAFLOWS-CONSUMPTION-CORE.md § Dataflow Definition Exploration](../../common/DATAFLOWS-CONSUMPTION-CORE.md#dataflow-definition-exploration) | Decode mashup.pq, queryMetadata.json, .platform |
| Parameter Discovery and Analysis | [DATAFLOWS-CONSUMPTION-CORE.md § Parameter Discovery and Analysis](../../common/DATAFLOWS-CONSUMPTION-CORE.md#parameter-discovery-and-analysis) | Types, formats, M code patterns |
| Refresh and Job Monitoring | [DATAFLOWS-CONSUMPTION-CORE.md § Refresh and Job Monitoring](../../common/DATAFLOWS-CONSUMPTION-CORE.md#refresh-and-job-monitoring) | LRO pattern, job instances, polling best practices |
| Agentic Exploration Pattern | [DATAFLOWS-CONSUMPTION-CORE.md § Agentic Exploration Pattern](../../common/DATAFLOWS-CONSUMPTION-CORE.md#agentic-exploration-pattern-chat-with-my-dataflows) | 6-step discovery sequence |
| Security and Permissions Model | [DATAFLOWS-CONSUMPTION-CORE.md § Security and Permissions Model](../../common/DATAFLOWS-CONSUMPTION-CORE.md#security-and-permissions-model) | Permission matrix by operation |
| Common Errors | [DATAFLOWS-CONSUMPTION-CORE.md § Common Errors](../../common/DATAFLOWS-CONSUMPTION-CORE.md#common-errors) | Error codes and resolutions |
| Gotchas and Troubleshooting Reference | [DATAFLOWS-CONSUMPTION-CORE.md § Gotchas and Troubleshooting](../../common/DATAFLOWS-CONSUMPTION-CORE.md#gotchas-and-troubleshooting-reference) | 12 numbered issues with cause + resolution |
| Quick Reference One-Liners | [consumption-cli-quickref.md](references/consumption-cli-quickref.md) | `az rest` one-liners for all consumption ops |
| Discovery Patterns | [discovery-queries.md](references/discovery-queries.md) | Definition decoding, parameter extraction, connection analysis |
| Script Templates | [script-templates.md](references/script-templates.md) | Copy-paste bash and PowerShell templates |
| Tool Stack | [SKILL.md § Tool Stack](#tool-stack) ||
| Connection | [SKILL.md § Connection](#connection) ||
| Agentic Exploration ("Chat With My Dataflows") | [SKILL.md § Agentic Exploration](#agentic-exploration-chat-with-my-dataflows) | **Start here** for dataflow exploration |

---

## Tool Stack

| Tool | Role | Install |
|---|---|---|
| `az` CLI | **Primary**: Auth (`az login`), Fabric REST API via `az rest` | Pre-installed in most dev environments |
| `curl` | Alternative HTTP client for REST calls | Pre-installed |
| `jq` | Parse JSON responses, extract fields, format output | Pre-installed or trivial |
| `base64` | Decode definition parts from base64 | Built into bash; PowerShell uses `[Convert]::FromBase64String` |
| `bash`/`pwsh` | Script execution | Pre-installed |

> **Agent check** — verify before first operation:
> ```bash
> az account show >/dev/null 2>&1 || echo "RUN: az login"
> command -v jq >/dev/null 2>&1 || echo "INSTALL: apt-get install jq OR brew install jq"
> ```

---

## Connection

### Resolve Workspace ID and Dataflow ID

Per [COMMON-CLI.md](../../common/COMMON-CLI.md) Finding Workspaces and Items in Fabric:

```bash
# Find workspace ID by name
WS_ID=$(az rest --method get \
  --resource "https://api.fabric.microsoft.com" \
  --url "https://api.fabric.microsoft.com/v1/workspaces" \
  --query "value[?displayName=='My Workspace'].id" --output tsv)

# Find dataflow ID by name within workspace
DF_ID=$(az rest --method get \
  --resource "https://api.fabric.microsoft.com" \
  --url "https://api.fabric.microsoft.com/v1/workspaces/$WS_ID/dataflows" \
  --query "value[?displayName=='Sales Data Pipeline'].id" --output tsv)
```

### Reusable Connection Variables

```bash
# Set once at script top
WS_ID="<workspaceId>"
DF_ID="<dataflowId>"
API="https://api.fabric.microsoft.com/v1"
AZ="az rest --resource https://api.fabric.microsoft.com"
```

---

## Agentic Exploration ("Chat With My Dataflows")

### Discovery Sequence

Run these in order to fully explore a workspace's dataflows. See [references/discovery-queries.md](references/discovery-queries.md) for extended patterns.

```bash
# 1. List workspaces → find target
az rest --method get --resource "https://api.fabric.microsoft.com" \
  --url "$API/workspaces" --query "value[].{name:displayName, id:id}" -o table

# 2. List dataflows → enumerate all
az rest --method get --resource "https://api.fabric.microsoft.com" \
  --url "$API/workspaces/$WS_ID/dataflows" \
  --query "value[].{name:displayName, id:id, desc:description}" -o table

# 3. Get dataflow properties
az rest --method get --resource "https://api.fabric.microsoft.com" \
  --url "$API/workspaces/$WS_ID/dataflows/$DF_ID"

# 4. Discover parameters
az rest --method get --resource "https://api.fabric.microsoft.com" \
  --url "$API/workspaces/$WS_ID/dataflows/$DF_ID/parameters" \
  --query "value[].{name:name, type:type, required:isRequired, default:defaultValue}" -o table

# 5. Get definition → decode mashup.pq
RESPONSE=$(az rest --method post --resource "https://api.fabric.microsoft.com" \
  --url "$API/workspaces/$WS_ID/dataflows/$DF_ID/getDefinition")
echo "$RESPONSE" | jq -r '.definition.parts[] | select(.path=="mashup.pq") | .payload' | base64 --decode

# 6. Check job history
az rest --method get --resource "https://api.fabric.microsoft.com" \
  --url "$API/workspaces/$WS_ID/items/$DF_ID/jobs/instances" \
  --query "value[].{status:status, type:invokeType, start:startTimeUtc, end:endTimeUtc, error:failureReason}" -o table
```

### Agentic Workflow

1. **Discover** → Run Steps 1–3 to list and identify dataflows.
2. **Parameters** → Step 4 to understand inputs and defaults.
3. **Definition** → Step 5 to inspect M queries, connections, staging config.
4. **Monitor** → Step 6 for refresh history and error patterns.
5. **Iterate** → Drill into specific queries or connection details.
6. **Present** → Summarize findings or generate a reusable script (see [script-templates.md](references/script-templates.md)).

---

## Gotchas, Rules, Troubleshooting

For full platform gotchas: [DATAFLOWS-CONSUMPTION-CORE.md](../../common/DATAFLOWS-CONSUMPTION-CORE.md) Gotchas and Troubleshooting Reference and [COMMON-CLI.md](../../common/COMMON-CLI.md) Gotchas & Troubleshooting (CLI-Specific).

### MUST DO

- **Always `az login` first** — `az rest` uses the active session. No session → cryptic failure.
- **Always `--resource "https://api.fabric.microsoft.com"`** — wrong audience = 401.
- **Handle pagination** — repeat requests with `continuationToken` until absent/null.
- **Handle LRO for `getDefinition`** — may return `202 Accepted` with `Location` header; poll until complete.
- **Decode base64 before inspecting** — definition parts are base64-encoded.
- **Use POST for `getDefinition`** — it is NOT a GET endpoint.

### AVOID

- **Hardcoded GUIDs** — always discover via list-then-filter pattern.
- **Assuming `getDefinition` is GET** — it is POST (common mistake).
- **Ignoring pagination** — list endpoints may return partial results.
- **Polling too aggressively** — respect `Retry-After` headers on 429s.
- **Expecting `getDefinition` with Viewer role** — requires Read+Write (Contributor+).

### PREFER

- **`az rest` over raw `curl`** — handles auth automatically.
- **List-then-filter pattern** — no server-side name filter for dataflows.
- **Exponential backoff** for job polling — 5s → 10s → 20s → 30s cap.
- **`jq` for response parsing** — cleaner than shell string manipulation.
- **JMESPath `--query`** for simple field extraction directly in `az rest`.
- **Env vars** (`WS_ID`, `DF_ID`, `API`) for script reuse.

### TROUBLESHOOTING

| Symptom | Cause | Fix |
|---|---|---|
| `401 Unauthorized` | Token expired or wrong audience | `az login`; ensure `--resource "https://api.fabric.microsoft.com"` |
| `403 Forbidden` on `getDefinition` | Viewer role (Read-only) | Requires Contributor role or higher (Read+Write) |
| `404 Not Found` | Wrong workspace or dataflow ID | Re-discover via List Dataflows API |
| `getDefinition` returns `202` | Large definition or server load | Poll the `Location` header URL until operation completes |
| Empty parameters array | Dataflow has no parameters | Expected behavior — check mashup.pq for `IsParameterQuery` |
| Base64 decode shows garbled text | BOM in encoded content | Strip UTF-8 BOM (`\xEF\xBB\xBF`) when decoding |
| `429 TooManyRequests` | Rate limited | Respect `Retry-After` header; implement exponential backoff |
| Duplicate results in list | Re-using stale continuationToken | Always use the token from the most recent response |
| `OperationNotSupportedForItem` | Wrong item type | Verify item is type `Dataflow` via Get Item |

---

## Examples

### Example 1: List All Dataflows in a Workspace

```bash
az rest --method get \
  --url "https://api.fabric.microsoft.com/v1/workspaces/${WS_ID}/items?type=Dataflow" \
  --resource "https://api.fabric.microsoft.com" \
  --query "value[].{Name:displayName, Id:id, Type:type}" -o table
```

### Example 2: Decode a Dataflow Definition

```bash
# Step 1: Request definition (POST — returns 202 with Location header)
LOCATION=$(az rest --method post \
  --url "https://api.fabric.microsoft.com/v1/workspaces/${WS_ID}/items/${DF_ID}/getDefinition" \
  --resource "https://api.fabric.microsoft.com" \
  --headers "Content-Length=0" \
  --output none --include-response-headers 2>&1 | grep -i "^location:" | awk '{print $2}' | tr -d '\r')

# Step 2: Poll until definition is ready
DEF=$(az rest --method get --url "${LOCATION}" \
  --resource "https://api.fabric.microsoft.com")

# Step 3: Decode mashup.pq to see the Power Query M code
echo "$DEF" | python3 -c "
import json, base64, sys
parts = json.load(sys.stdin)['definition']['parts']
for p in parts:
    if p['path'] == 'mashup.pq':
        print(base64.b64decode(p['payload']).decode('utf-8'))
"
```

### Example 3: Check Refresh Job History

```bash
# Get recent job instances for a dataflow
az rest --method get \
  --url "https://api.fabric.microsoft.com/v1/workspaces/${WS_ID}/items/${DF_ID}/jobs/instances?limit=5" \
  --resource "https://api.fabric.microsoft.com" \
  --query "value[].{Status:status, Start:startTimeUtc, End:endTimeUtc, Id:id}" -o table
```

### Example 4: Discover Parameters from Definition

```bash
# After decoding the definition (see Example 2), extract parameters:
echo "$DEF" | python3 -c "
import json, base64, sys
parts = json.load(sys.stdin)['definition']['parts']
for p in parts:
    if p['path'] == 'queryMetadata.json':
        meta = json.loads(base64.b64decode(p['payload']).decode('utf-8'))
        for qname, qmeta in meta.get('queriesMetadata', {}).items():
            if qmeta.get('queryGroupId') == 'parameters' or 'IsParameterQuery' in str(qmeta):
                print(f'Parameter: {qname}')
"
```
