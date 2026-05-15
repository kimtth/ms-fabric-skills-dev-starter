---
name: synapse-migration
description: >
  Port Azure Synapse Analytics notebooks, SQL pools, and pipelines to Microsoft Fabric.
  Translates mssparkutils calls to notebookutils (including the env→runtime namespace change),
  replaces Linked Services with Fabric Data Connections and OneLake Shortcuts, rewrites
  Dedicated SQL Pool DDL by removing DISTRIBUTION and CLUSTERED COLUMNSTORE hints,
  substitutes PolyBase external tables with COPY INTO, and maps Synapse Pipeline activities
  to Fabric Data Pipeline equivalents. Use when the user wants to:
  (1) port Synapse Spark notebooks to Fabric Lakehouse or Spark Job Definitions,
  (2) replace mssparkutils or Linked Services in Synapse code,
  (3) rewrite Dedicated SQL Pool T-SQL for Fabric Warehouse,
  (4) migrate Synapse Pipelines to Fabric Data Pipelines.
  Triggers: "migrate from synapse", "synapse to fabric", "mssparkutils to notebookutils",
  "synapse linked service replacement", "dedicated sql pool to warehouse",
  "polybase to copy into", "port synapse notebooks", "synapse workspace migration".
---

> **Update Check — ONCE PER SESSION (mandatory)**
> The first time this skill is used in a session, run the **check-updates** skill before proceeding.
> - **GitHub Copilot CLI / VS Code**: invoke the `check-updates` skill.
> - **Claude Code / Cowork / Cursor / Windsurf / Codex**: compare local vs remote package.json version.
> - Skip if the check was already performed earlier in this session.

> **CRITICAL NOTES**
> 1. To find workspace details (including its ID) from a workspace name: list all workspaces, then use JMESPath filtering
> 2. To find item details (including its ID) from workspace ID, item type, and item name: list all items of that type in that workspace, then use JMESPath filtering
> 3. `mssparkutils` and `notebookutils` share the same API surface in most cases — the namespace is the primary change
> 4. Linked Services have no direct REST API equivalent in Fabric — they are replaced by Data Connections (for external sources) and OneLake Shortcuts (for storage mounts)

# Synapse Analytics → Microsoft Fabric Migration

## Prerequisite Knowledge

Read these companion documents before executing migration tasks:

- [COMMON-CORE.md](../../common/COMMON-CORE.md) — Fabric REST API patterns, authentication, token audiences, item discovery
- [COMMON-CLI.md](../../common/COMMON-CLI.md) — `az rest`, `az login`, token acquisition, Fabric REST via CLI
- [SPARK-AUTHORING-CORE.md](../../common/SPARK-AUTHORING-CORE.md) — Notebook deployment, lakehouse creation, Spark job execution
- [SQLDW-AUTHORING-CORE.md](../../common/SQLDW-AUTHORING-CORE.md) — Fabric Warehouse T-SQL authoring, DDL, COPY INTO

For notebook deployment details, see [spark-authoring-cli](../spark-authoring-cli/SKILL.md).
For Fabric Warehouse DDL/DML authoring, see [sqldw-authoring-cli](../sqldw-authoring-cli/SKILL.md).

---

## Table of Contents

| Topic | Reference |
|---|---|
| Migration Workload Map | [§ Migration Workload Map](#migration-workload-map) |
| `mssparkutils` → `notebookutils` API Mapping | [utility-api-mapping.md](resources/utility-api-mapping.md) |
| Linked Services → Data Connections / Shortcuts | [connectivity-migration.md](resources/connectivity-migration.md) |
| Before/After Code Patterns | [code-patterns.md](resources/code-patterns.md) |
| T-SQL Surface Area Gaps | [§ T-SQL Surface Area Gaps](#t-sql-surface-area-gaps) |
| Spark Configuration Differences | [§ Spark Configuration Differences](#spark-configuration-differences) |
| Must / Prefer / Avoid | [§ Must / Prefer / Avoid](#must--prefer--avoid) |
| Authentication & Token Acquisition | [COMMON-CORE.md § Authentication](../../common/COMMON-CORE.md#authentication--token-acquisition) |
| Lakehouse Management | [SPARK-AUTHORING-CORE.md § Lakehouse Management](../../common/SPARK-AUTHORING-CORE.md#lakehouse-management) |
| Notebook Management | [SPARK-AUTHORING-CORE.md § Notebook Management](../../common/SPARK-AUTHORING-CORE.md#notebook-management) |
| Fabric Warehouse Authoring | [SQLDW-AUTHORING-CORE.md](../../common/SQLDW-AUTHORING-CORE.md) |

---

## Migration Workload Map

Use this table to determine the correct Fabric target for each Synapse component:

| Synapse Component | Fabric Target | Notes |
|---|---|---|
| **Spark Pool** (notebooks, jobs) | Fabric Spark (Lakehouse / Notebooks / SJD) | Starter Pool replaces on-demand pools for most workloads |
| **Dedicated SQL Pool** | **Fabric Warehouse** | T-SQL surface area differences apply — see [§ T-SQL Surface Area Gaps](#t-sql-surface-area-gaps) |
| **Serverless SQL Pool** | **Lakehouse SQL Endpoint** | Read-only Delta/Parquet queries; no DDL required |
| **Synapse Pipelines** | **Fabric Data Pipelines** | Activity types, triggers, and expressions are broadly compatible |
| **Synapse Link for Cosmos DB / SQL** | **Fabric Mirroring** | Native mirroring replaces the Synapse Link connector pattern |
| **Linked Services** | **Data Connections** (external) / **OneLake Shortcuts** (storage) | See [connectivity-migration.md](resources/connectivity-migration.md) |
| **Integration Datasets** | **Fabric Pipeline source/sink config** | Dataset definitions are inlined into pipeline activities in Fabric |
| **Managed Virtual Networks** | **Fabric Managed Private Endpoints** | Configure in Fabric capacity settings |
| **Synapse Studio** | **Fabric workspace** | All artifact types live in a single workspace with Git integration |

### Decision Tree: Which Fabric Spark Workload?

```text
Synapse Spark workload
├── Interactive notebook with data exploration → Fabric Notebook (attached to Lakehouse)
├── Scheduled/production job → Spark Job Definition (SJD)
├── T-SQL over files/Delta → Lakehouse SQL Endpoint (no migration needed — just point to OneLake)
└── Real-time ingest → Fabric Eventstream + Lakehouse
```

---

## T-SQL Surface Area Gaps

Fabric Warehouse supports a broad T-SQL surface, but some Dedicated SQL Pool features differ:

| Synapse Dedicated SQL Pool Feature | Fabric Warehouse Equivalent | Action Required |
|---|---|---|
| `CREATE EXTERNAL TABLE` (PolyBase) | `COPY INTO` or Lakehouse SQL Endpoint | Rewrite ingestion; use `COPY INTO` for bulk load from ADLS/OneLake |
| `DISTRIBUTION = HASH(col)` | Not applicable — Fabric auto-distributes | Remove distribution hints from DDL |
| `CLUSTERED COLUMNSTORE INDEX` (default) | Delta Lake (Lakehouse) or Fabric Warehouse DCI | Warehouse tables use Delta-backed storage automatically |
| Result set caching | Not available | Remove cache hints; rely on query plan caching |
| Workload management (classifiers) | Not available | Use workspace capacity management |
| `sp_rename` | Supported | No change needed |
| `MERGE` statement | Supported | No change needed |
| Temp tables (`#temp`) | Supported | No change needed |
| Window functions | Supported | No change needed |

> **Delegate to `sqldw-authoring-cli`** for all T-SQL DDL/DML authoring tasks after mapping the workload.

---

## Spark Configuration Differences

| Synapse Spark Concept | Fabric Spark Equivalent | Notes |
|---|---|---|
| **Spark Pool definition** (node type, autoscale min/max) | **Custom Pool** or **Starter Pool** | Starter Pool (auto-provisioned, no config needed) covers most dev workloads; Custom Pools for production SLAs |
| `%%configure` magic cell (session-level config) | `%%configure` magic — **identical syntax** | Supported in Fabric notebooks |
| `spark.conf.set(...)` | `spark.conf.set(...)` — **identical** | No change needed |
| Environment-scoped libraries (pool packages) | **Fabric Environment** attached to workspace/notebook | Replace pool-level library installs with a Fabric Environment item |
| Synapse-specific Spark versions | Fabric Runtime versions (1.1 = Spark 3.3, 1.2 = Spark 3.4, 1.3 = Spark 3.5) | Align runtime version; test deprecated API calls |
| `spark.read.synapsesql(...)` connector | **Not available** — use `notebookutils` + Lakehouse shortcuts or Warehouse JDBC | Replace with OneLake reads or SQL endpoint queries |

---

## Must / Prefer / Avoid

### MUST DO
- **Replace all `mssparkutils` imports with `notebookutils`** — see [utility-api-mapping.md](resources/utility-api-mapping.md) for the complete namespace table
- **Replace all Linked Services** with Fabric Data Connections (for external databases/services) or OneLake Shortcuts (for ADLS Gen2 / Blob storage mounts) — see [connectivity-migration.md](resources/connectivity-migration.md)
- **Replace `spark.read.synapsesql()`** with Lakehouse shortcut reads or JDBC connections to the Fabric Warehouse SQL endpoint
- **Re-test all notebooks** after migration against the target Fabric Runtime version — Spark minor version differences can surface deprecated API warnings
- **Externalize all workspace/item IDs** — never hardcode; use pipeline parameters or Variable Libraries
- **Replace pool-level library installs** with Fabric Environments attached at the workspace or notebook level

### PREFER
- **OneLake Shortcuts over full data copies** — mount existing ADLS Gen2 containers as shortcuts rather than re-ingesting data during migration
- **Fabric Starter Pool** for dev/test migrations — eliminates pool warm-up wait time inherent in Synapse on-demand pools
- **Lakehouse SQL Endpoint** as a drop-in for Serverless SQL Pool reads — point existing consumers at the endpoint with minimal query changes
- **Medallion architecture** for migrated data — align with Bronze/Silver/Gold patterns (see `e2e-medallion-architecture` skill)
- **Incremental migration** — migrate and validate workload by workload rather than performing a big-bang cutover
- **Parameterized notebooks** to allow environment promotion (dev → test → prod) without code changes

### AVOID
- **Do not copy-paste PolyBase `CREATE EXTERNAL TABLE` DDL** into Fabric Warehouse — rewrite as `COPY INTO` or use Lakehouse for external data access
- **Do not assume Synapse Linked Service connection strings are reusable** — credentials and endpoints must be reconfigured as Fabric Data Connections
- **Do not install libraries in notebook cells** (`%pip install` at runtime) for production workloads — use Fabric Environments for reproducible, versioned library management
- **Do not migrate Dedicated SQL Pool distribution hints** (`HASH`, `ROUND_ROBIN`, `REPLICATE`) verbatim — remove them; Fabric Warehouse handles distribution automatically
- **Do not use `wasb://` or `abfss://container@storageaccount.dfs.core.windows.net/` paths** as primary data paths — migrate data access to OneLake `abfss://workspace@onelake.dfs.fabric.microsoft.com/` paths

---

## Examples

See [code-patterns.md](resources/code-patterns.md) for full before/after examples. Key quick references:

**`mssparkutils.env` → `notebookutils.runtime`**

```python
# Synapse
workspace = mssparkutils.env.getWorkspaceName()

# Fabric
workspace = notebookutils.runtime.context["workspaceName"]
```

**Linked Service credential → Key Vault secret**

```python
# Synapse
conn = mssparkutils.credentials.getConnectionStringOrCreds("MyLinkedService")

# Fabric
conn = notebookutils.credentials.getSecret("https://myvault.vault.azure.net/", "my-secret")
```

**Dedicated SQL Pool DDL → Fabric Warehouse DDL**

```sql
-- Synapse (remove distribution hints)
CREATE TABLE dbo.Fact (...) WITH (DISTRIBUTION = HASH(id), CLUSTERED COLUMNSTORE INDEX);

-- Fabric Warehouse
CREATE TABLE dbo.Fact (...);
```
