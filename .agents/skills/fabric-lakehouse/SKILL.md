---
name: fabric-lakehouse
description: >
  Fabric Lakehouse design, schemas, shortcuts, security, optimization, and PySpark patterns.
  Use when designing Lakehouse solutions, managing Delta tables, configuring OneLake shortcuts,
  or writing PySpark/Spark SQL code for Fabric notebooks.
---

# Fabric Lakehouse

## Core Concepts

Lakehouse in Microsoft Fabric combines the flexibility of a data lake with the management of a data warehouse:

- **Unified storage** in OneLake for structured and unstructured data
- **Delta Lake format** for ACID transactions, versioning, and time travel
- **SQL analytics endpoint** for T-SQL queries (auto-generated, read-only)
- **Default semantic model** for Power BI integration
- Support for CSV, Parquet (Spark-only querying for non-Delta formats)

### Key Components

| Component | Purpose |
|-----------|---------|
| Delta Tables | Managed tables with ACID compliance and schema enforcement under `Tables/` |
| Files | Unstructured/semi-structured data under `Files/` |
| SQL Endpoint | Auto-generated read-only SQL interface |
| Shortcuts | Virtual links to external/internal data without copying |
| Materialized Views | Pre-computed tables for fast query performance |

### Schemas

When creating a Lakehouse, users can enable schemas to organize tables:
- Schemas are folders under `Tables/`
- Default schema is `dbo` (cannot be deleted or renamed)
- Can reference schemas in other Lakehouses via Schema Shortcuts

## Security

### Workspace Roles (Control Plane)

| Role | Access |
|------|--------|
| Admin | Full control |
| Member | Create, edit, delete items |
| Contributor | Edit existing items |
| Viewer | Read-only |

### OneLake Security (Data Plane)

- Based on Microsoft Entra ID and RBAC
- Supports column-level and row-level security on tables
- Data access controlled through OneLake permissions

## Shortcuts

Virtual links to data without copying:

| Type | Target |
|------|--------|
| Internal | Other Fabric Lakehouses/tables (cross-workspace) |
| ADLS Gen2 | Azure Data Lake Storage Gen2 containers |
| S3 | Amazon S3 buckets |
| GCS | Google Cloud Storage |
| Dataverse | Dataverse tables |

### Create Shortcut (REST)

```
POST /v1/workspaces/<wsId>/items/<lakehouseId>/shortcuts
{
  "path": "Tables/external_data",
  "name": "my_shortcut",
  "target": {
    "oneLake": {
      "workspaceId": "<sourceWsId>",
      "itemId": "<sourceItemId>",
      "path": "Tables/source_table"
    }
  }
}
```

## Table Optimization

### V-Order

Write optimization that applies sorting, encoding, and compression for fast reads. Enabled by default for Fabric Spark.

```python
df.write.format("delta").option("vorder", "true").save(path)
```

### OPTIMIZE and VACUUM

```sql
-- Compact small files
OPTIMIZE lakehouse.schema.table_name

-- Remove old files (default 7-day retention)
VACUUM lakehouse.schema.table_name
```

### Z-Order

Co-locate related data for faster filter queries:

```sql
OPTIMIZE lakehouse.schema.table_name ZORDER BY (column1, column2)
```

## PySpark Patterns

### Read Delta Table

```python
df = spark.read.format("delta").load("Tables/my_table")
# or
df = spark.sql("SELECT * FROM lakehouse.dbo.my_table")
```

### Write Delta Table

```python
df.write.format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .save("Tables/my_table")
```

### Incremental Load (Merge)

```python
from delta.tables import DeltaTable

target = DeltaTable.forPath(spark, "Tables/my_table")
target.alias("t").merge(
    source_df.alias("s"),
    "t.id = s.id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()
```

### Notebook Utilities

Microsoft Fabric renamed MSSparkUtils to NotebookUtils. Existing `mssparkutils` code remains backward-compatible, but new code should prefer `notebookutils` for continued support and access to newer modules.

```python
# List files
notebookutils.fs.ls("Files/raw/")

# Copy files
notebookutils.fs.cp("Files/source/", "Files/dest/", recurse=True)

# Get secret from Key Vault
secret = notebookutils.credentials.getSecret("https://my-kv.vault.azure.net/", "secret-name")

# Run another notebook
notebookutils.notebook.run("other_notebook", timeout_seconds=600, arguments={"param1": "value1"})
```

## Medallion Architecture

| Layer | Purpose | Pattern |
|-------|---------|---------|
| Bronze | Raw ingestion | Append-only, preserve source schema |
| Silver | Cleaned/conformed | Deduplication, type casting, null handling |
| Gold | Business-ready | Aggregation, star schema, KPIs |

Each layer is a separate Lakehouse or schema within a Lakehouse.

## Must

- Use Delta format for all managed tables
- Enable V-Order for read-heavy workloads
- Partition large tables by date or high-cardinality columns
- Run OPTIMIZE regularly on frequently queried tables
- Use shortcuts instead of copying data across workspaces

## Avoid

- Storing non-Delta tabular data if SQL endpoint access is needed
- Deep folder nesting in `Files/` (keep hierarchy shallow)
- Small file accumulation without OPTIMIZE
- Hardcoding OneLake paths — use workspace/item variables
