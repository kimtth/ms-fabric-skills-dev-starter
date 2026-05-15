# `dbutils` → `notebookutils` Complete API Mapping

Exhaustive side-by-side reference for porting Databricks `dbutils` calls to Microsoft Fabric `notebookutils`.

---

## Quick Compatibility Summary

| `dbutils` Module | `notebookutils` Status | Action |
|---|---|---|
| `dbutils.fs` | ✅ **Full equivalent** — `notebookutils.fs` | Direct namespace swap for most methods |
| `dbutils.secrets` | ✅ **Equivalent** — `notebookutils.credentials` | Scope→URL, key→secretName signature change |
| `dbutils.notebook` | ✅ **Full equivalent** — `notebookutils.notebook` | Direct namespace swap |
| `dbutils.widgets` | ⚠️ **No direct equivalent** | Use notebook parameter cells + `notebookutils.runtime.context` |
| `dbutils.library` | ❌ **Not available** | Use Fabric Environments for library management |
| `dbutils.data` | ❌ **Not available** | Use `display(df.summary())` or pandas `.describe()` |
| `dbutils.jobs` | ❌ **Not applicable** | Job context available via `notebookutils.runtime.context` |
| `dbutils.secrets.listScopes()` | ❌ **Not available** | Key Vault scopes are referenced directly by URL |

---

## `dbutils.fs` → `notebookutils.fs`

All `fs` methods are direct replacements. Only paths change (DBFS → OneLake).

| `dbutils.fs` Method | `notebookutils.fs` Equivalent | Notes |
|---|---|---|
| `dbutils.fs.ls(path)` | `notebookutils.fs.ls(path)` | Returns `FileInfo` list |
| `dbutils.fs.cp(src, dest, recurse=False)` | `notebookutils.fs.cp(src, dest, recurse=False)` | **Identical** |
| `dbutils.fs.mv(src, dest, recurse=False)` | `notebookutils.fs.mv(src, dest, recurse=False)` | **Identical** |
| `dbutils.fs.rm(path, recurse=False)` | `notebookutils.fs.rm(path, recurse=False)` | **Identical** |
| `dbutils.fs.mkdirs(path)` | `notebookutils.fs.mkdirs(path)` | **Identical** |
| `dbutils.fs.put(path, contents, overwrite=False)` | `notebookutils.fs.put(path, contents, overwrite=False)` | **Identical** |
| `dbutils.fs.head(path, maxBytes=65536)` | `notebookutils.fs.head(path, maxBytes=65536)` | **Identical** |
| `dbutils.fs.append(path, contents, createIfNotExists)` | `notebookutils.fs.append(path, contents, createIfNotExists)` | **Identical** |
| `dbutils.fs.mount(source, mountPoint, ...)` | ❌ **Not available** — use **OneLake Shortcuts** | No FUSE mount in Fabric |
| `dbutils.fs.unmount(mountPoint)` | ❌ **Not available** | No mounts in Fabric |
| `dbutils.fs.mounts()` | ❌ **Not available** | List shortcuts via Fabric REST API |
| `dbutils.fs.refreshMounts()` | ❌ **Not available** | Not needed without mounts |
| `dbutils.fs.help()` | `notebookutils.fs.help()` | **Identical** |

### Path Migration: DBFS → OneLake

```python
# Databricks: DBFS path
dbutils.fs.ls("dbfs:/mnt/mydata/bronze/")
dbutils.fs.ls("/mnt/mydata/bronze/")         # shorthand

# Fabric: OneLake path (Files section of attached Lakehouse)
notebookutils.fs.ls("Files/mydata/bronze/")  # relative path

# Or explicit OneLake path
notebookutils.fs.ls(
    "abfss://MyWorkspace@onelake.dfs.fabric.microsoft.com/BronzeLakehouse.Lakehouse/Files/mydata/bronze/"
)
```

### Replacing `dbutils.fs.mount()`

```python
# BEFORE — Databricks: mount ADLS to DBFS
dbutils.fs.mount(
    source="abfss://container@storageaccount.dfs.core.windows.net/",
    mount_point="/mnt/mydata",
    extra_configs={
        "fs.azure.account.oauth2.client.id": "<client_id>",
        "fs.azure.account.oauth2.client.secret": dbutils.secrets.get("myScope", "clientSecret"),
        "fs.azure.account.oauth2.client.endpoint": "https://login.microsoftonline.com/<tenant>/oauth2/token"
    }
)

# AFTER — Fabric: create a OneLake Shortcut once (in Portal or REST API)
# No runtime mounting required — the shortcut makes data available at Files/mydata/
# Access it directly:
df = spark.read.parquet("Files/mydata/bronze/customers/")
```

---

## `dbutils.secrets` → `notebookutils.credentials`

The concept maps directly — Databricks secret scopes correspond to Azure Key Vault instances.

| `dbutils.secrets` Method | `notebookutils.credentials` Equivalent | Notes |
|---|---|---|
| `dbutils.secrets.get(scope, key)` | `notebookutils.credentials.getSecret(keyVaultUrl, secretName)` | `scope` → Key Vault URL; `key` → secret name |
| `dbutils.secrets.getBytes(scope, key)` | `notebookutils.credentials.getSecret(keyVaultUrl, secretName)` | Returns string; encode to bytes if needed |
| `dbutils.secrets.list(scope)` | ❌ Not available | Use Azure CLI or Key Vault SDK to list secrets |
| `dbutils.secrets.listScopes()` | ❌ Not available | Key Vault URLs are referenced directly |
| `dbutils.secrets.help()` | `notebookutils.credentials.help()` | |

```python
# BEFORE — Databricks
password = dbutils.secrets.get(scope="prod-secrets", key="db-password")
api_key  = dbutils.secrets.get(scope="prod-secrets", key="api-key")

# AFTER — Fabric
password = notebookutils.credentials.getSecret(
    "https://my-keyvault.vault.azure.net/",
    "db-password"
)
api_key = notebookutils.credentials.getSecret(
    "https://my-keyvault.vault.azure.net/",
    "api-key"
)
```

> The Fabric notebook's managed identity (or the signed-in user) must have **Key Vault Secrets User** role on the Key Vault.

---

## `dbutils.notebook` → `notebookutils.notebook`

Direct replacement — identical API surface.

| `dbutils.notebook` Method | `notebookutils.notebook` Equivalent | Notes |
|---|---|---|
| `dbutils.notebook.run(path, timeout, arguments)` | `notebookutils.notebook.run(name, timeout, arguments)` | `path` becomes notebook `name`; relative to workspace |
| `dbutils.notebook.exit(value)` | `notebookutils.notebook.exit(value)` | **Identical** |
| `dbutils.notebook.help()` | `notebookutils.notebook.help()` | **Identical** |

```python
# BEFORE — Databricks
result = dbutils.notebook.run(
    "/path/to/silver_transform",
    timeout=600,
    arguments={"input_date": "2024-01-01", "env": "prod"}
)
dbutils.notebook.exit("completed")

# AFTER — Fabric
result = notebookutils.notebook.run(
    "silver_transform",          # notebook name (not path) in same workspace
    timeout=600,
    arguments={"input_date": "2024-01-01", "env": "prod"}
)
notebookutils.notebook.exit("completed")
```

---

## `dbutils.widgets` — No Direct Equivalent

Databricks widgets are interactive UI controls. Fabric uses parameter cells and pipeline injection instead.

### Pattern 1: Pipeline-injected parameters (most common for production)

```python
# BEFORE — Databricks: define widget, read in notebook
dbutils.widgets.text("input_date", "2024-01-01", "Input Date")
input_date = dbutils.widgets.get("input_date")

# AFTER — Fabric: mark cell with "parameters" tag
# In the FIRST cell of the notebook, tag the cell as "parameters" (in notebook UI or IPYNB metadata)
# Then declare defaults:
input_date = "2024-01-01"   # default value — overridden by pipeline at runtime
env = "dev"

# In a Fabric Pipeline notebook activity, these parameters are injected by the pipeline
```

### Pattern 2: Read runtime context (for programmatic use)

```python
# AFTER — Fabric: read parameters injected at runtime
ctx = notebookutils.runtime.context
params = ctx.get("parameters", {})
input_date = params.get("input_date", "2024-01-01")
```

### Pattern 3: Parent notebook passes parameters to child

```python
# AFTER — Fabric: parent calls child with explicit args
result = notebookutils.notebook.run(
    "child_notebook",
    timeout=300,
    arguments={"input_date": "2024-01-01", "table_name": "fact_orders"}
)
# In child_notebook, read from the parameters cell (overridden at runtime)
```

---

## `dbutils.library` — Use Fabric Environments

`dbutils.library.install()` and `dbutils.library.installPyPI()` are not available in Fabric. Use Fabric Environments for reproducible library management.

```python
# BEFORE — Databricks: runtime library install
dbutils.library.installPyPI("scikit-learn", version="1.3.0")
dbutils.library.install("dbfs:/mnt/libs/mylib-1.0.whl")
dbutils.library.restartPython()

# AFTER — Fabric:
# 1. Create a Fabric Environment item in the workspace
# 2. Add scikit-learn==1.3.0 to the Environment's pip packages
# 3. Attach the Environment to the notebook (or workspace default)
# 4. The library is available without any code changes

# For custom WHL files:
# Upload to Lakehouse Files/, then add as custom library in the Environment item
```

---

## `dbutils.data` — Use display() or pandas

```python
# BEFORE — Databricks: summarize a DataFrame
dbutils.data.summarize(df)

# AFTER — Fabric: use built-in display or pandas
display(df.summary())           # Spark summary stats in Fabric display
display(df.describe())          # Alternative
df.toPandas().describe()        # Full pandas stats (for small DataFrames only)
```

---

## Runtime Context

```python
# BEFORE — Databricks: access job context
ctx = dbutils.notebook.entry_point.getDbutils().notebook().getContext()
workspace = ctx.tags().get("orgId").get()
job_id = ctx.tags().get("jobId").get()

# AFTER — Fabric
ctx = notebookutils.runtime.context
workspace_id   = ctx["workspaceId"]
workspace_name = ctx["workspaceName"]
notebook_id    = ctx["notebookId"]
job_id         = ctx.get("jobId")       # Available when run as a job/SJD
lakehouse_id   = ctx.get("defaultLakehouseId")
```
