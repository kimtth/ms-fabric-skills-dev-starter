# Synapse → Fabric Code Patterns

Before/after examples for common Synapse Analytics → Microsoft Fabric migration scenarios.

---

## Spark Notebook: Import and Session Setup

```python
# BEFORE — Synapse notebook header
from notebookutils import mssparkutils
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()
sc = spark.sparkContext

# AFTER — Fabric notebook header (nothing to import or initialize)
# spark, sc, and notebookutils are pre-instantiated in every Fabric notebook
# No imports required
```

---

## Reading Data: ADLS Path → OneLake Path

```python
# BEFORE — Synapse: read from ADLS Gen2 via linked service auth
df = spark.read.format("delta") \
    .load("abfss://silver@mystorageaccount.dfs.core.windows.net/customers/")

# AFTER — Fabric: read from OneLake (after creating a shortcut or writing data to Lakehouse)
df = spark.read.format("delta") \
    .load("abfss://MyWorkspace@onelake.dfs.fabric.microsoft.com/SilverLakehouse.Lakehouse/Tables/customers")

# OR use relative path (when notebook has Lakehouse attached as default)
df = spark.read.format("delta").load("Tables/customers")
```

---

## Writing Data to Delta Lake

```python
# BEFORE — Synapse: write to ADLS Gen2
df.write.format("delta") \
    .mode("overwrite") \
    .save("abfss://gold@mystorageaccount.dfs.core.windows.net/summary/")

# AFTER — Fabric: write to Lakehouse Tables (managed Delta)
df.write.format("delta") \
    .mode("overwrite") \
    .saveAsTable("gold_summary")  # Writes to attached Lakehouse Tables/gold_summary

# Or explicit OneLake path
df.write.format("delta") \
    .mode("overwrite") \
    .save("Tables/gold_summary")
```

---

## Credentials: Linked Service → Key Vault Secret

```python
# BEFORE — Synapse: read connection string from Key Vault Linked Service
conn_str = mssparkutils.credentials.getConnectionStringOrCreds("AzureSQL_LinkedService")

jdbc_url = f"jdbc:sqlserver://myserver.database.windows.net;databaseName=mydb;password={conn_str}"

# AFTER — Fabric: read secret from Key Vault directly
password = notebookutils.credentials.getSecret(
    "https://mykeyvault.vault.azure.net/",
    "sql-password"
)

token = notebookutils.credentials.getToken("https://database.windows.net/")
jdbc_url = "jdbc:sqlserver://myserver.database.windows.net;databaseName=mydb;encrypt=true"

df = spark.read.format("jdbc") \
    .option("url", jdbc_url) \
    .option("accessToken", token) \
    .option("dbtable", "dbo.Customers") \
    .load()
```

---

## Environment Context

```python
# BEFORE — Synapse: read job/workspace context
workspace = mssparkutils.env.getWorkspaceName()
job_id = mssparkutils.env.getJobId()

# AFTER — Fabric: read from runtime context dict
ctx = notebookutils.runtime.context
workspace = ctx["workspaceName"]
job_id = ctx["jobId"]
workspace_id = ctx["workspaceId"]
```

---

## Child Notebook Execution

```python
# BEFORE — Synapse
result = mssparkutils.notebook.run(
    "silver_transform",
    timeout=600,
    arguments={"input_table": "bronze_orders", "batch_date": "2024-01-01"}
)

# AFTER — Fabric (identical API)
result = notebookutils.notebook.run(
    "silver_transform",
    timeout=600,
    arguments={"input_table": "bronze_orders", "batch_date": "2024-01-01"}
)
```

---

## Dedicated SQL Pool DDL → Fabric Warehouse

```sql
-- BEFORE — Synapse Dedicated SQL Pool
CREATE TABLE dbo.FactSales (
    SaleID INT NOT NULL,
    CustomerID INT,
    SaleDate DATE,
    Amount DECIMAL(18,2)
)
WITH (
    DISTRIBUTION = HASH(CustomerID),
    CLUSTERED COLUMNSTORE INDEX
);

-- AFTER — Fabric Warehouse (remove distribution hints; auto-managed)
CREATE TABLE dbo.FactSales (
    SaleID INT NOT NULL,
    CustomerID INT,
    SaleDate DATE,
    Amount DECIMAL(18,2)
);
-- Note: Fabric Warehouse uses Delta-backed storage with automatic distribution
```

---

## Bulk Load: PolyBase → COPY INTO

```sql
-- BEFORE — Synapse: PolyBase external table + INSERT
CREATE EXTERNAL DATA SOURCE adls_source
    WITH (TYPE = HADOOP, LOCATION = 'abfss://raw@mystorageaccount.dfs.core.windows.net/');

CREATE EXTERNAL TABLE dbo.ext_StagingOrders (...)
    WITH (DATA_SOURCE = adls_source, LOCATION = '/orders/2024/', FILE_FORMAT = CsvFormat);

INSERT INTO dbo.FactOrders SELECT * FROM dbo.ext_StagingOrders;

-- AFTER — Fabric Warehouse: COPY INTO from OneLake
COPY INTO dbo.FactOrders
FROM 'https://onelake.dfs.fabric.microsoft.com/<workspace>/<lakehouse>.Lakehouse/Files/orders/2024/'
WITH (
    FILE_TYPE = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
);
```

---

## File System Operations

```python
# BEFORE — Synapse
files = mssparkutils.fs.ls("abfss://raw@mystorageaccount.dfs.core.windows.net/incoming/")
for f in files:
    mssparkutils.fs.cp(f.path, f"abfss://archive@mystorageaccount.dfs.core.windows.net/{f.name}")

# AFTER — Fabric
files = notebookutils.fs.ls("Files/incoming/")
for f in files:
    notebookutils.fs.cp(f.path, f"Files/archive/{f.name}")
```

---

## Spark Configuration (`%%configure`)

```python
# BEFORE — Synapse: configure Spark session via magic
%%configure
{
    "conf": {
        "spark.executor.memory": "8g",
        "spark.executor.cores": 4,
        "spark.sql.shuffle.partitions": 200
    }
}

# AFTER — Fabric: identical magic cell syntax (no change required)
%%configure
{
    "conf": {
        "spark.executor.memory": "8g",
        "spark.executor.cores": 4,
        "spark.sql.shuffle.partitions": 200
    }
}
```
