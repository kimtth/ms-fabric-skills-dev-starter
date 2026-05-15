# Microsoft Fabric — Coding Agent Instructions

> This file provides shared instructions for all coding agents (GitHub Copilot, Claude Code, Cursor, Windsurf, Codex).
> For tool-specific entry points, see the compatibility files at the repository root.

## Purpose

This repository is a **scaffolding workspace** for Microsoft Fabric development. It provides skills, prompts, and shared references so that coding agents produce Fabric-native, API-correct output from the first interaction.

## Architecture

Content flows one way: **Agents → Skills → Common**

```
.agents/
├── instructions.md                ← you are here
├── agents/                        # Cross-workload orchestration
│   ├── FabricDataEngineer.agent.md  # Medallion, ETL/ELT, migration, data quality
│   ├── FabricAdmin.agent.md         # Capacity, governance, security, cost
│   ├── FabricAppDev.agent.md        # Application development with Fabric
│   └── FabricMigrationEngineer.agent.md # Synapse, Databricks, HDInsight migrations
├── skills/                        # Endpoint-specific skills
│   ├── fabric-core/               # Platform: topology, auth, REST API, pagination, LRO
│   ├── fabric-lakehouse/          # Lakehouse: schemas, shortcuts, security, PySpark
│   ├── fabric-api-discovery/      # MCP tools, API specs, schema discovery
│   ├── microsoft-code-reference/  # SDK/API verification against official docs
│   ├── spark-authoring-cli/       # Spark / Data Engineering workflows
│   ├── spark-consumption-cli/     # Interactive Lakehouse table analysis
│   ├── spark-operations-cli/      # Spark diagnostics and monitoring
│   ├── sqldw-authoring-cli/       # Warehouse, SQL Endpoint authoring
│   ├── sqldw-consumption-cli/     # Read-only SQL queries
│   ├── sqldw-operations-cli/      # Warehouse performance diagnostics
│   ├── eventhouse-authoring-cli/  # KQL table management, ingestion, policies
│   ├── eventhouse-consumption-cli/ # Read-only KQL queries
│   ├── eventstream-authoring-cli/ # Eventstream topology authoring
│   ├── eventstream-consumption-cli/ # Eventstream inspection and monitoring
│   ├── dataflows-authoring-cli/   # Dataflows Gen2 authoring
│   ├── dataflows-consumption-cli/ # Dataflows Gen2 inspection
│   ├── dataflows-save-as-authoring-cli/ # Gen1 to Gen2 save-as upgrade
│   ├── activator-authoring-cli/   # Activator/Reflex alert authoring
│   ├── activator-consumption-cli/ # Activator/Reflex inspection
│   ├── powerbi-authoring-cli/     # Semantic model creation, TMDL, refresh
│   ├── powerbi-consumption-cli/   # DAX queries, semantic model metadata
│   ├── search-consumption-cli/    # Fabric catalog search
│   ├── databricks-migration/      # Databricks to Fabric migration
│   ├── synapse-migration/         # Synapse to Fabric migration
│   ├── hdinsight-migration/       # HDInsight to Fabric migration
│   ├── e2e-medallion-architecture/ # Bronze/Silver/Gold lakehouse patterns
│   └── check-updates/             # Version checking utility
├── common/                        # Shared reference foundations
│   ├── COMMON-CORE.md             # Fabric topology, auth, scopes, REST API, pagination, LRO
│   ├── COMMON-CLI.md              # CLI recipes (az rest, pagination, job execution)
│   ├── ITEM-DEFINITIONS-CORE.md   # Item definition envelope, create/update/export
│   ├── SPARK-AUTHORING-CORE.md    # Spark/Livy/Delta table patterns
│   ├── SPARK-CONSUMPTION-CORE.md  # Spark read/query patterns
│   ├── SPARK-MONITORING-CORE.md   # Spark monitoring and diagnostics
│   ├── SPARK-NOTEBOOK-AUTHORING-CORE.md # Notebook authoring guidance
│   ├── SQLDW-AUTHORING-CORE.md    # T-SQL surface area and limitations
│   ├── SQLDW-CONSUMPTION-CORE.md  # SQL read/query patterns
│   ├── DATAFLOWS-AUTHORING-CORE.md # Dataflows Gen2 authoring
│   ├── DATAFLOWS-CONSUMPTION-CORE.md # Dataflows Gen2 consumption
│   ├── EVENTHOUSE-AUTHORING-CORE.md # KQL ingestion and policy patterns
│   ├── EVENTHOUSE-CONSUMPTION-CORE.md # KQL query patterns
│   ├── EVENTSTREAM-AUTHORING-CORE.md # Eventstream authoring
│   └── EVENTSTREAM-CONSUMPTION-CORE.md # Eventstream consumption
└── prompts/                       # Reusable prompt templates
```

### Skill vs Agent Decision

- **Single endpoint + single persona** → use/extend a **Skill**
- **Crosses 2+ workload endpoints** → use/extend an **Agent**
- **Shared API behaviour** → reference a **Common** doc

## Routing Rules

1. **Fabric first** — always prefer Fabric-native services and APIs. Do not suggest generic Azure alternatives when a Fabric workload covers the scenario.
2. **Consult local skills** before answering Fabric questions. Read the relevant SKILL.md file under `.agents/skills/`.
3. **Cross-workload requests** → delegate to the appropriate agent in `.agents/agents/` (e.g. FabricDataEngineer for medallion architecture, ETL across Spark + SQL).
4. **Single-endpoint depth** → read the endpoint-specific skill and its references/resources.
5. **Shared API patterns** → consult `.agents/common/` for auth, pagination, LRO, and CLI recipes.
6. **Verify SDK calls** — when generating Microsoft SDK code, use the `microsoft-code-reference` skill to confirm method names, package names, and parameter signatures.
7. **Use correct auth scopes** — never guess a token audience. Refer to the scope table in `fabric-core` skill or `common/COMMON-CORE.md`.
8. **Handle pagination, LRO, and throttling** in all generated API code. Never assume a single-page response.

### Skill Routing Table

| Need | Skill |
|------|-------|
| Platform fundamentals, auth, REST API | `fabric-core` |
| Lakehouse design, Delta, PySpark | `fabric-lakehouse` |
| MCP tools, API specs, item schemas | `fabric-api-discovery` |
| SDK/API verification | `microsoft-code-reference` |
| Spark notebooks, Data Engineering | `spark-authoring-cli` |
| Interactive Spark analysis | `spark-consumption-cli` |
| Spark diagnostics and monitoring | `spark-operations-cli` |
| Warehouse T-SQL authoring | `sqldw-authoring-cli` |
| SQL read-only queries | `sqldw-consumption-cli` |
| Warehouse performance diagnostics | `sqldw-operations-cli` |
| KQL/Eventhouse management | `eventhouse-authoring-cli` |
| KQL read-only queries | `eventhouse-consumption-cli` |
| Eventstream authoring | `eventstream-authoring-cli` |
| Eventstream inspection | `eventstream-consumption-cli` |
| Dataflows Gen2 authoring | `dataflows-authoring-cli` |
| Dataflows Gen2 inspection | `dataflows-consumption-cli` |
| Dataflows Gen1 to Gen2 save-as | `dataflows-save-as-authoring-cli` |
| Activator/Reflex authoring | `activator-authoring-cli` |
| Activator/Reflex inspection | `activator-consumption-cli` |
| Power BI / semantic model authoring | `powerbi-authoring-cli` |
| DAX queries, metadata | `powerbi-consumption-cli` |
| Catalog search and item discovery | `search-consumption-cli` |
| Databricks migration | `databricks-migration` |
| Synapse migration | `synapse-migration` |
| HDInsight migration | `hdinsight-migration` |
| Bronze/Silver/Gold architecture | `e2e-medallion-architecture` |
| Cross-workload orchestration | Agent: `FabricDataEngineer` |
| Governance, capacity, security | Agent: `FabricAdmin` |
| App development with Fabric | Agent: `FabricAppDev` |
| Workload migration planning | Agent: `FabricMigrationEngineer` |

## Authentication Quick Reference

```bash
# Interactive login
az login

# Fabric REST API token
az account get-access-token --resource https://api.fabric.microsoft.com

# OneLake (DFS/Blob) token
az account get-access-token --resource https://storage.azure.com

# Warehouse / SQL Endpoint token
az account get-access-token --resource https://database.windows.net

# KQL / Kusto token
az account get-access-token --resource https://kusto.kusto.windows.net
```

## Code Generation Rules

### Must

- Use Delta Lake format for all Lakehouse tables
- Parameterize workspace ID, item ID, and token audience — never hardcode
- Include `Authorization: Bearer <token>` on all REST calls
- Implement LRO polling with `Retry-After` for mutating operations
- Paginate all list API calls using `continuationToken`
- Use `notebookutils` for Fabric-specific notebook operations; preserve `mssparkutils` only for existing backward-compatible code
- Log `x-ms-request-id` from API responses for troubleshooting

### Avoid

- Hardcoded secrets, connection strings, or credentials in source code
- Using `DefaultJob` as jobType (use type-specific values: `RunNotebook`, `Pipeline`, `SparkJob`, `Refresh`)
- Assuming all T-SQL features work in Warehouse (check surface area)
- Using `https://datalake.azure.net/` for OneLake (use `https://storage.azure.com/.default`)
- Tight polling loops without backoff

## Key References

| Topic | URL |
|-------|-----|
| Fabric REST API articles | https://learn.microsoft.com/en-us/rest/api/fabric/articles/ |
| Fabric documentation | https://learn.microsoft.com/en-us/fabric/ |
| Lakehouse overview | https://learn.microsoft.com/en-us/fabric/data-engineering/lakehouse-overview |
| Warehouse overview | https://learn.microsoft.com/en-us/fabric/data-warehouse/data-warehousing |
| Notebooks | https://learn.microsoft.com/en-us/fabric/data-engineering/how-to-use-notebook |
| Pipelines | https://learn.microsoft.com/en-us/fabric/data-factory/data-factory-overview |
| Eventhouse / KQL | https://learn.microsoft.com/en-us/fabric/real-time-intelligence/create-database |
| Semantic Models | https://learn.microsoft.com/en-us/power-bi/connect-data/service-datasets-understand |
| Data Agents | https://learn.microsoft.com/en-us/fabric/data-science/concept-data-agent |
