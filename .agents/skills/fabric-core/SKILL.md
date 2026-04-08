---
name: fabric-core
description: >
  Core Microsoft Fabric platform reference: topology, authentication, token scopes,
  REST API base URL, pagination, long-running operations, throttling, workspace and
  item resolution, OneLake access, and common gotchas. Use this skill whenever working
  with Fabric REST APIs, managing workspaces/items, or troubleshooting auth errors.
---

# Fabric Core Platform

## Topology

| Concept | Description |
|---------|-------------|
| **Tenant** | Single Fabric instance per organisation, aligned with one Microsoft Entra ID tenant |
| **Capacity** | Compute pool (F-SKU or P-SKU) powering Fabric workloads. Every workspace must be assigned to one |
| **Workspace** | Container for Fabric items. Defines collaboration and security boundary |
| **Item** | Artefact inside a workspace — Lakehouse, Warehouse, Notebook, SemanticModel, etc. Each has a unique GUID |
| **OneLake** | Unified tenant-wide data lake. All items store data as Delta/Parquet files in OneLake |

## Environment URLs

| Service | URL |
|---------|-----|
| Fabric REST API | `https://api.fabric.microsoft.com/v1/` |
| OneLake DFS (global) | `https://onelake.dfs.fabric.microsoft.com` |
| OneLake Blob (global) | `https://onelake.blob.fabric.microsoft.com` |
| Warehouse / SQL Endpoint TDS | `<unique-id>.datawarehouse.fabric.microsoft.com:1433` |
| XMLA Endpoint | `powerbi://api.powerbi.com/v1.0/myorg/<workspace>` |
| Entra ID Token Endpoint | `https://login.microsoftonline.com/<tenantId>/oauth2/v2.0/token` |
| Power BI REST API | `https://api.powerbi.com/v1.0/myorg/` |
| KQL Cluster URI | `https://trd-<hash>.z<n>.kusto.fabric.microsoft.com` (per-item) |

## Authentication

All Fabric REST API calls require a **Microsoft Entra ID OAuth 2.0 bearer token**. No API keys, SAS tokens, or SQL auth for REST APIs.

### Token Audiences / Scopes

Using the wrong audience is the #1 cause of `401 Unauthorized`.

| Access Target | Scope |
|---------------|-------|
| Fabric REST API | `https://api.fabric.microsoft.com/.default` |
| Power BI REST API (legacy) | `https://analysis.windows.net/powerbi/api/.default` |
| OneLake (DFS / Blob) | `https://storage.azure.com/.default` |
| Warehouse / SQL Endpoint (TDS) | `https://database.windows.net/.default` |
| KQL / Kusto | `https://kusto.kusto.windows.net/.default` |
| XMLA Endpoint | `https://analysis.windows.net/powerbi/api/.default` |
| Azure Resource Management | `https://management.azure.com/.default` |

> **OneLake gotcha**: Only accepts `https://storage.azure.com/.default`. Using `https://datalake.azure.net/` will fail.

### Identity Types

| Identity | Use case |
|----------|----------|
| User principal | Interactive human user (broadest API support) |
| Service principal (SPN) | App registration. Requires admin consent + tenant setting |
| Managed identity | Azure-managed. Works from Azure compute |
| Workspace identity | Fabric-managed SPN tied to a workspace. No secret to manage |

### Entra App Registration

1. Create app registration at `https://entra.microsoft.com`
2. Add redirect URI `http://localhost` for interactive flows
3. Add API permissions under **Power BI Service**: `Workspace.ReadWrite.All`, `Item.ReadWrite.All`, `OneLake.ReadWrite.All`
4. Enable "Service principals can use Fabric APIs" in Fabric Admin Portal

### CLI Authentication

```bash
# Interactive login
az login

# Fabric REST API token
az account get-access-token --resource https://api.fabric.microsoft.com

# Using az rest (must specify --resource for Fabric)
az rest --method get \
  --resource "https://api.fabric.microsoft.com" \
  --url "https://api.fabric.microsoft.com/v1/workspaces"
```

## Core REST APIs

Base URL: `https://api.fabric.microsoft.com/v1`

All requests require `Authorization: Bearer <token>` and `Content-Type: application/json` for POST/PUT/PATCH.

### Workspace Operations

```
GET  /v1/workspaces                              # List workspaces
GET  /v1/workspaces/<workspaceId>                 # Get workspace
POST /v1/workspaces                               # Create workspace
     { "displayName": "...", "capacityId": "..." }
POST /v1/workspaces/<id>/assignToCapacity          # Assign capacity
     { "capacityId": "..." }
GET  /v1/capacities                                # List available capacities
```

### Item Operations

```
GET  /v1/workspaces/<wsId>/items                   # List all items
GET  /v1/workspaces/<wsId>/items?type=Lakehouse     # Filter by type
GET  /v1/workspaces/<wsId>/items/<itemId>           # Get item
POST /v1/workspaces/<wsId>/items                    # Create item
     { "displayName": "...", "type": "<ItemType>" }
```

Type-specific endpoints return additional `properties`:
```
GET /v1/workspaces/<wsId>/{lakehouses|warehouses|notebooks|semanticModels|kqlDatabases|...}
```

### Resolve Workspace by Name

```bash
az rest --method get \
  --resource "https://api.fabric.microsoft.com" \
  --url "https://api.fabric.microsoft.com/v1/workspaces" \
  --query "value[?displayName=='MyWorkspace'] | [0].id" \
  --output tsv
```

### Resolve Item by Name

```bash
az rest --method get \
  --resource "https://api.fabric.microsoft.com" \
  --url "https://api.fabric.microsoft.com/v1/workspaces/$WS_ID/items?type=Lakehouse" \
  --query "value[?displayName=='MyLakehouse'] | [0].id" \
  --output tsv
```

### Job Execution

```
POST /v1/workspaces/<wsId>/items/<itemId>/jobs/instances?jobType=<jobType>
```

| Item Type | jobType |
|-----------|---------|
| Notebook | `RunNotebook` |
| DataPipeline | `Pipeline` |
| SparkJobDefinition | `SparkJob` |
| SemanticModel | `Refresh` |

> **Gotcha**: `DefaultJob` does NOT work for most item types. Use the type-specific value.

## Pagination

All list APIs use continuation-token-based pagination.

1. Make the initial `GET` request
2. If response contains `continuationToken` (non-null), repeat with `?continuationToken=<value>`
3. Continue until `continuationToken` is null or absent

Use `continuationUri` directly if provided. Never modify the token — it is opaque.

## Long-Running Operations (LRO)

Many mutating operations return `202 Accepted` with:
- `Location` — poll URL
- `x-ms-operation-id` — operation GUID
- `Retry-After` — seconds to wait

**Poll**: `GET /v1/operations/<operationId>` → `{ "status": "Running|Succeeded|Failed" }`

**Get result**: `GET /v1/operations/<operationId>/result` (after `Succeeded`)

**Best practices**: Honour `Retry-After`. Use exponential backoff if absent. Set a max timeout. Handle `Failed` gracefully.

## Throttling

HTTP `429 Too Many Requests` includes `Retry-After` header. Callers **must** wait.

| API Category | Limit |
|--------------|-------|
| Admin APIs | 200 req/hour per principal per tenant |
| General Fabric APIs | Varies by endpoint |
| OneLake ADLS APIs | Standard Azure Storage throttling (per-workspace) |

Implement retry with **exponential backoff + jitter**. Respect `Retry-After`. Avoid tight polling loops.

## OneLake Data Access

### URL Structure

```
https://onelake.dfs.fabric.microsoft.com/<workspace>/<item>.<itemtype>/<path>
```

ABFS URI (for Spark):
```
abfss://<workspace>@onelake.dfs.fabric.microsoft.com/<item>.<itemtype>/<path>
```

- `<workspace>` — GUID or display name (use GUID for ABFS)
- `<item>.<itemtype>` — e.g. `MySalesLakehouse.Lakehouse`
- `<path>` — `Tables/<tableName>` or `Files/<folder>/<file>`

> OneLake **only** accepts `scope = https://storage.azure.com/.default`.

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `401 Unauthorized` | Wrong token audience or expired token | Verify `aud` claim. Check scope table above |
| `403 Forbidden` | Missing workspace role or item permission | Check role assignments. For SPNs: verify admin portal settings |
| `404 Not Found` | Wrong workspace/item ID | Re-resolve the workspace/item |
| `429 Too Many Requests` | Rate limit exceeded | Wait for `Retry-After`, then retry |
| `FeatureNotAvailable` | Workspace has no capacity assigned | Assign capacity first, verify `capacityAssignmentProgress` is "Completed" |

## Best Practices

- Parameterize all URLs — base URL, workspace ID, item ID, token audience
- Use type-specific list endpoints when item properties are needed
- Check before creating — implement idempotent operations
- Wrap all mutating calls in an LRO-aware handler
- Log `x-ms-request-id` from responses for support requests
- Cache workspace/item metadata — avoid repeated list calls
- Prefer GUIDs over display names for programmatic access
- Store secrets in Key Vault — never in source code
- Distinguish transient (429/503/504) vs permanent (400/403/404) errors
