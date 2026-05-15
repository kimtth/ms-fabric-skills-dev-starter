# Microsoft Fabric Skills Starter for AI Coding Agents

Purpose-built Microsoft Fabric scaffolding for AI coding agents. This starter helps external developers and teams move faster with pre-configured Fabric skills, reusable prompts, and agent instructions for GitHub Copilot, Claude Code, Cursor, Windsurf, and Codex.

It is designed for practical Fabric work: Lakehouse engineering, Warehouse and SQL endpoint development, Eventhouse and KQL workflows, Power BI semantic model operations, REST API integration, and cross-workload orchestration.

## Why This Starter

- Fabric-first structure instead of a generic AI agent template
- High-value Fabric skills for Lakehouse, Warehouse, Eventhouse, Power BI, and REST APIs
- Shared instructions that keep multiple coding agents aligned on the same platform conventions
- Ready-to-use MCP setup assets for Fabric-focused agent workflows
- Built-in guidance for auth scopes, pagination, long-running operations, throttling, and OneLake patterns

## Quick Start

### Prerequisites

- Python 3.13+ (see `.python-version`)
- Azure CLI authenticated (`az login`)
- Microsoft Fabric capacity (F2+ or P1+)
- Node.js 18+ (optional, for Fabric MCP server)

### Authentication

```bash
az login
az account get-access-token --resource https://api.fabric.microsoft.com
```

### Use with Your Agent

| Agent | Entry Point |
|-------|-------------|
| GitHub Copilot | `.github/copilot-instructions.md` → auto-loaded |
| Claude Code | `CLAUDE.md` → auto-loaded |
| Cursor | `.cursorrules` → auto-loaded |
| Windsurf | `.windsurfrules` → auto-loaded |
| Codex / Jules | `AGENTS.md` → auto-loaded |
| All agents | `.agents/instructions.md` → full reference |

All entry points route to `.agents/instructions.md` for shared skills and Fabric patterns.

### MCP Setup

If you need to register a remote Fabric MCP server with GitHub Copilot CLI, Claude Desktop, or VS Code, use the tracked setup assets in `mcp-setup/`.

Examples:

```powershell
.\mcp-setup\register-fabric-mcp.ps1 -ServerUrl "https://your-fabric-mcp-server.com" -ServerName "fabric"
```

```bash
./mcp-setup/register-fabric-mcp.sh --server-url "https://your-fabric-mcp-server.com" --server-name "fabric"
```

Use `mcp-setup/mcp-config-template.json` as a starting point for manual configuration.

## Skills

All skills are under `.agents/skills/`. Each has a `SKILL.md` with YAML frontmatter and structured guidance.

### Platform Skills

| Skill | Scope |
|-------|-------|
| `fabric-core` | Topology, auth scopes, REST API, workspace/item resolution, pagination, LRO, throttling, OneLake |
| `fabric-lakehouse` | Lakehouse design, Delta tables, schemas, shortcuts, security, V-Order, PySpark, medallion |
| `fabric-api-discovery` | Fabric MCP Server tools, API specs, item definitions, developer vs consumer patterns |
| `microsoft-code-reference` | Verify Microsoft SDK methods, packages, and parameter signatures against official docs |

### Endpoint Skills (from [microsoft/skills-for-fabric](https://github.com/microsoft/skills-for-fabric) v0.3.1)

| Skill | Purpose |
|-------|---------|
| `spark-authoring-cli` | Spark and Data Engineering workflows |
| `spark-consumption-cli` | Interactive Lakehouse table analysis |
| `spark-operations-cli` | Spark job, session, and performance diagnostics |
| `sqldw-authoring-cli` | Warehouse, SQL Endpoint authoring |
| `sqldw-consumption-cli` | Read-only SQL queries |
| `sqldw-operations-cli` | Warehouse performance diagnostics and query insights |
| `eventhouse-authoring-cli` | KQL table management, ingestion, policies |
| `eventhouse-consumption-cli` | Read-only KQL queries |
| `eventstream-authoring-cli` | Eventstream topology authoring and deployment |
| `eventstream-consumption-cli` | Eventstream inspection and monitoring |
| `dataflows-authoring-cli` | Dataflows Gen2 authoring and Power Query M definitions |
| `dataflows-consumption-cli` | Dataflows Gen2 read-only exploration and monitoring |
| `dataflows-save-as-authoring-cli` | Dataflows Gen1 to Gen2 save-as upgrade workflows |
| `activator-authoring-cli` | Activator/Reflex alert and action authoring |
| `activator-consumption-cli` | Activator/Reflex definition inspection |
| `powerbi-authoring-cli` | Semantic model creation, TMDL, refresh |
| `powerbi-consumption-cli` | DAX queries and metadata |
| `search-consumption-cli` | Fabric catalog search and item discovery |
| `databricks-migration` | Databricks to Fabric migration planning |
| `synapse-migration` | Azure Synapse to Fabric migration |
| `hdinsight-migration` | Azure HDInsight to Fabric migration |
| `e2e-medallion-architecture` | Bronze/Silver/Gold lakehouse patterns |

### Agents (`.agents/agents/`)

| Agent | Scope |
|-------|-------|
| `FabricDataEngineer` | Cross-workload orchestration: medallion, ETL/ELT, migration, data quality |
| `FabricAdmin` | Capacity, governance, security, cost |
| `FabricAppDev` | Application development with Fabric |
| `FabricMigrationEngineer` | Migration planning for Synapse, Databricks, and HDInsight to Fabric |

### Shared References (`.agents/common/`)

| File | Purpose |
|------|---------|
| `COMMON-CORE.md` | Fabric topology, auth, scopes, REST API patterns, pagination, LRO, throttling |
| `COMMON-CLI.md` | CLI recipes (`az rest`, pagination handling, job execution) |
| `ITEM-DEFINITIONS-CORE.md` | Item definition envelope, create/update/export/import |
| `SPARK-AUTHORING-CORE.md` | Spark/Livy/Delta table patterns |
| `SPARK-CONSUMPTION-CORE.md` | Spark read/query and Livy consumption patterns |
| `SPARK-MONITORING-CORE.md` | Spark monitoring API and diagnostics patterns |
| `SPARK-NOTEBOOK-AUTHORING-CORE.md` | Notebook authoring and lakehouse context guidance |
| `SQLDW-AUTHORING-CORE.md` | T-SQL surface area and limitations |
| `SQLDW-CONSUMPTION-CORE.md` | SQL read/query, security, metadata refresh, and performance patterns |
| `DATAFLOWS-AUTHORING-CORE.md` | Dataflows Gen2 definition and authoring patterns |
| `DATAFLOWS-CONSUMPTION-CORE.md` | Dataflows Gen2 inspection and monitoring patterns |
| `EVENTHOUSE-AUTHORING-CORE.md` | KQL ingestion and policy patterns |
| `EVENTHOUSE-CONSUMPTION-CORE.md` | KQL query, Eventhouse discovery, and analytics patterns |
| `EVENTSTREAM-AUTHORING-CORE.md` | Eventstream topology authoring patterns |
| `EVENTSTREAM-CONSUMPTION-CORE.md` | Eventstream inspection and monitoring patterns |

## Fabric REST API Quick Reference

Base URL: `https://api.fabric.microsoft.com/v1/`

### Auth Scopes

| Target | Scope |
|--------|-------|
| Fabric REST API | `https://api.fabric.microsoft.com/.default` |
| OneLake (DFS/Blob) | `https://storage.azure.com/.default` |
| Warehouse / SQL Endpoint | `https://database.windows.net/.default` |
| KQL / Kusto | `https://kusto.kusto.windows.net/.default` |
| Power BI / XMLA | `https://analysis.windows.net/powerbi/api/.default` |

### Patterns

- **Pagination**: List APIs return `continuationToken`. Repeat with `?continuationToken=<value>` until null
- **LRO**: Mutating ops may return `202` with `Location`, `x-ms-operation-id`, `Retry-After`. Poll until `Succeeded` or `Failed`
- **Throttling**: `429` includes `Retry-After`. Must wait before retrying

### Tooling

| Tool | Install | Purpose |
|------|---------|---------|
| Fabric CLI | `pip install ms-fabric-cli` | Command-line Fabric operations |
| fabric-cicd | `pip install fabric-cicd` | CI/CD automation |
| Fabric Pro-Dev MCP | `npm install -g fabric-pro-dev-mcp-server` | Local MCP server for API discovery |

## References

| Topic | URL |
|-------|-----|
| Fabric REST API | https://learn.microsoft.com/en-us/rest/api/fabric/articles/ |
| Fabric docs | https://learn.microsoft.com/en-us/fabric/ |
| Lakehouse | https://learn.microsoft.com/en-us/fabric/data-engineering/lakehouse-overview |
| Warehouse | https://learn.microsoft.com/en-us/fabric/data-warehouse/data-warehousing |
| Notebooks | https://learn.microsoft.com/en-us/fabric/data-engineering/how-to-use-notebook |
| Pipelines | https://learn.microsoft.com/en-us/fabric/data-factory/data-factory-overview |
| Eventhouse / KQL | https://learn.microsoft.com/en-us/fabric/real-time-intelligence/create-database |
| Semantic Models | https://learn.microsoft.com/en-us/power-bi/connect-data/service-datasets-understand |
| Data Agents | https://learn.microsoft.com/en-us/fabric/data-science/concept-data-agent |
| skills-for-fabric | https://github.com/microsoft/skills-for-fabric |

