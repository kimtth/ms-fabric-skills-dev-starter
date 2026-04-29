# Lessons-Learned Checklist

Troubleshooting based on bugs and gaps discovered during development.

> Format of each entry:
> - **Symptom** — the exact signal the agent will see.
> - **Root cause** — the underlying Fabric / Spark behaviour.
> - **Fix** — the generic corrective action.
> - **Verification** — how to confirm it is fixed.
> - **Do NOT** — anti-patterns that look right but won't work.

Do **not** put workspace IDs, tenant IDs, subscription IDs, bearer tokens, or connection strings in this file. Use placeholders like `<workspace-id>`, `<lakehouse-id>`, `<token>`.

---

## 1. Ontology POST returns `HTTP 400 UnsupportedItemType`

- **Symptom** (deploy log):
  ```
  POST https://api.fabric.microsoft.com/v1/workspaces/<workspace-id>/ontologies
  BadRequest ... "errorCode":"UnsupportedItemType"
  Deployment exits with code 1.
  ```
- **Root cause**: the Fabric Ontology item type is a preview. Not every tenant / capacity has it enabled. Tenants without the preview return `UnsupportedItemType`, not 404.
- **Fix**:
  1. Treat this as a tenant or capacity capability gate, not a payload-shape problem.
  2. Wrap ontology creation in error handling and treat `UnsupportedItemType` as a skipped feature rather than a hard deployment failure when ontology support is optional.
  3. Keep a feature flag or skip switch so CI and non-preview tenants can deploy the rest of the solution without ontologies.
- **Verification**: deploy log shows a warning such as `Ontology item type not available in this tenant, skipping.` and the remaining deployment continues successfully.
- **Do NOT**: retry the POST with different `creationPayload` shapes, rename the item, or call `/items` with `type: "Ontology"` — the preview gate is tenant-level, not payload-level.

---

## 2. Notebook cell fails with `Py4JJavaError ... HEAD 400` on `Files/sample-data/...`

- **Symptom** (notebook log inside a pipeline activity):
  ```
  Py4JJavaError: An error occurred while calling o123.parquet.
  Operation failed: "Bad Request", 400, HEAD,
  http://onelake.dfs.fabric.microsoft.com/<lakehouse-id>/Files/sample-data/BT_COM0001?upn=false&action=getStatus&timeout=90
  ```
  The same notebook runs fine interactively but fails when scheduled through a Data Pipeline.
- **Root cause**: in this workspace/capacity, Spark's `getStatus` HEAD against the OneLake DFS endpoint under `Files/...` sporadically returns 400 for parquet paths written by another notebook in the same pipeline run. The write succeeds but the next activity's read fails.
- **Fix**: stop staging intermediate datasets as parquet under `Files/` when downstream activities in the same pipeline run will read them immediately. Use Delta tables inside the lakehouse instead, and read them with `spark.table(...)` rather than `spark.read.parquet(...)`.
- **Verification**: run the pipeline end to end. The upstream write activity succeeds and downstream activities can read the same dataset through table references without the OneLake HEAD 400.
- **Do NOT**: try to "fix" this by switching to `abfss://` paths, adding `notebookutils.fs.mkdirs`, or wrapping the read in retries. The OneLake HEAD 400 is not a timing issue.

---

## 3. `AnalysisException: [AMBIGUOUS_REFERENCE] Reference \`<column>\` is ambiguous`

- **Symptom** (during a Spark join):
  ```
  AnalysisException: [AMBIGUOUS_REFERENCE] Reference `<column>` is ambiguous,
  could be: [...right_side.<column>, ...left_side.<column>].
  ```
- **Root cause**: the left side of the join already carries the referenced column, and the right-hand projection also selects a column with the same name. After the join, Spark cannot resolve string-based column references unambiguously.
- **Fix**:
  ```python
  result = (left_df
            .join(right_df.select("JOIN_KEY", "ATTRIBUTE_B").dropDuplicates(["JOIN_KEY"]),
                  "JOIN_KEY", "left")
            .withColumn("DERIVED_KEY",
                        F.concat_ws("|", F.col("ATTRIBUTE_A"), F.col("ATTRIBUTE_B"))))
  ```
  Two things matter:
  1. Drop the duplicated column from the right side of the join.
  2. Use `F.col(...)` instead of bare strings in `concat_ws` so resolution errors surface as compile-time `AnalysisException` rather than runtime ambiguity.
- **Verification**: rerun the transformation. The join succeeds, and the derived column is populated.
- **Do NOT**: rename the column with `.withColumnRenamed(...)` *after* the join — the join itself fails column resolution first. Don't reach for `.alias(...)` + `col("a.VEHICLE_MODEL")` either; the cleanest fix is to never select the duplicate.

---

## 4. Pipeline run stuck in `NotStarted` / `InProgress` for many minutes

- **Symptom**: polling `GET /workspaces/<ws>/items/<pipeline>/jobs/instances/<run>` returns `status=NotStarted` for 1–2 minutes, then `InProgress` for 5–15 minutes, with no activity progress.
- **Root cause**: Fabric Spark needs to spin up / rehydrate a session before the first notebook activity starts. This is normal, not a hang. Subsequent runs on the same pool start faster.
- **Fix**: poll with a 30–45 s sleep, cap at ~25 minutes for cold start. Use the run's final `status` (`Completed`, `Failed`, `Cancelled`) — don't time out earlier.
- **Verification**: after the cold start, activities appear in `/jobs/instances/<run>` with their own status.
- **Do NOT**: re-submit the pipeline while a previous run is still `NotStarted` — you'll stack runs and confuse the activity logs.

---

## 5. `az account get-access-token` — which audience for which API?

- **Symptom**: `401 Unauthorized` or `403 Forbidden` when calling Fabric / SQL endpoint / Storage APIs.
- **Root cause**: Fabric-related workflows commonly use four separate token audiences, and tokens are not interchangeable.
- **Fix** — always pass the right `--resource`:
  | Purpose | Resource |
  |---|---|
  | Fabric REST APIs (`/v1/workspaces/*`) | `https://api.fabric.microsoft.com` |
  | Power BI / semantic model operations | `https://analysis.windows.net/powerbi/api` |
  | Lakehouse SQL endpoint / Warehouse (T-SQL over TDS) | `https://database.windows.net/` |
  | OneLake file I/O (`onelake.dfs.fabric.microsoft.com`) | `https://storage.azure.com/` |
- **Verification**: decode the JWT and confirm the `aud` claim matches the resource above. Re-fetch the token for each API family.
- **Do NOT**: cache a single token for all three; they expire independently and have different scopes.

---

## 6. Item update must use `updateDefinition`, not `createOrReplace`

- **Symptom**: POST `/items` with an existing item name returns `ItemDisplayNameAlreadyInUse` (409) or creates a duplicate suffixed item.
- **Root cause**: Fabric's Items API is create-only. To modify an existing item's definition (notebook, semantic model, pipeline, ontology), call `POST /v1/workspaces/{ws}/items/{itemId}/updateDefinition?updateMetadata=true` with the full definition payload and poll the returned LRO.
- **Fix**: always resolve the item ID by name first with `GET /v1/workspaces/{ws}/items?type=<Type>`, then call `updateDefinition` for existing items instead of retrying create operations.
- **Verification**: response is `202 Accepted` with an `Operation-Location` header. Poll `GET /operations/{id}` until `status == Succeeded`, then `GET /operations/{id}/result` if you need the payload.

---

## 7. DirectLake semantic model shows empty tables after deploy

- **Symptom**: model deploys, but all visuals are blank / `ErrorCode: ...TableIsEmpty`.
- **Root cause**: DirectLake binds to Delta tables in the lakehouse SQL endpoint. If the gold notebook hasn't run yet (or wrote to a different schema), the bound tables don't exist.
- **Fix**: run the upstream data pipeline before expecting data in the model. Make sure the Delta tables referenced by the semantic model exist in the expected schema and return rows from the SQL endpoint.
- **Verification**: query the referenced tables on the SQL endpoint and confirm non-zero counts, then refresh the model.
- **Do NOT**: re-deploy the semantic model to "fix" an empty visual — the deploy is already correct; the data just isn't there yet.

---

## 8. Adding a new fact table to the semantic model — required checklist

To avoid loose or missing relationships:

1. Give every new fact a stable relationship key that matches the target dimension key. When a natural key spans multiple columns, materialize it consistently before the model layer.
2. Add the semantic model definition for the new fact table, including the relationship key column.
3. Add a relationship entry in `relationships.tmdl` of the form:
   ```
   relationship <fact>_to_<dimension>
     fromColumn: <fact>.<dimension>_key
     toColumn: <dimension>.<dimension>_key
   ```
4. If the fact relates to multiple dimensions, declare each required relationship explicitly rather than relying on inference.
5. Re-publish the semantic model after the table and relationships are defined.

---

## 9. Split rule: sample generation vs transformation

To keep a solution reproducible and make it obvious which code is synthetic data generation versus production transformation logic:

- The synthetic-data generation stage is the only stage allowed to invent or seed records.
- The bronze or raw-ingest stage should be pure copy from the source landing area into managed tables. No business transformations, no filters.
- The silver or conformed stage should own cleaning, standardisation, and joins.
- The gold or serving stage should own surrogate keys, aggregates, and the marts used by semantic models or downstream agents.

If a future change would put synthetic data generation into downstream transformation stages, move that logic back into the dedicated generation stage and keep downstream stages reading managed tables.

---

## 10. Re-running after a failed activity

- **Symptom**: one activity failed half-way; gold tables are partially stale.
- **Root cause**: when each stage writes idempotently to Delta tables, a failed run can usually be corrected by rerunning the full pipeline instead of trying to repair partial state by hand.
- **Fix**: resubmit the whole pipeline when the affected stages write with idempotent overwrite or merge semantics. Avoid manual cleanup unless the pipeline design explicitly requires it.
- **Verification**: fresh row counts and downstream outputs match the expected post-run state.
- **Do NOT**: hand-delete intermediate tables or files first unless you have evidence that the pipeline is not idempotent.

---

## 11. Notebook UI shows `Explorer -> Data Items -> No data sources added`

- **Symptom**: a notebook opens in Fabric, but the left pane shows `Explorer -> Data Items -> No data sources added`. In the notebook runtime, lakehouse-relative operations such as `spark.table("<schema>.<table>")`, `/lakehouse/default/...`, or bare schema references fail or behave as if no default lakehouse is attached.
- **Root cause**: the notebook was created or updated **without** the default lakehouse dependency metadata. Fabric can store notebook code successfully while still leaving the notebook unattached in the UI if the lakehouse dependency block is omitted or incomplete in the notebook definition payload.
- **Fix**:
  1. Inspect the notebook create or update path and verify it supplies all default lakehouse identifiers required by Fabric:
     - lakehouse ID
     - lakehouse display name
     - workspace ID that owns the lakehouse
  2. Ensure the notebook definition metadata includes the dependency block that marks the default lakehouse attachment. A representative payload shape is:
     ```powershell
     $metaObj.dependencies = @{
         lakehouse = @{
             default_lakehouse              = $DefaultLakehouseId
             default_lakehouse_name         = $DefaultLakehouseName
             default_lakehouse_workspace_id = $DefaultLakehouseWorkspaceId
             known_lakehouses               = @(@{ id = $DefaultLakehouseId })
         }
     }
     ```
  3. Re-deploy or re-publish the notebook after fixing the metadata. Re-open the notebook and confirm the default lakehouse now appears under `Explorer -> Data Items`.
- **Verification**:
  1. Open the notebook in Fabric and confirm `Explorer -> Data Items` lists the attached lakehouse instead of `No data sources added`.
  2. Run a simple lakehouse-relative check such as `spark.sql("SHOW TABLES IN <schema>")` or `spark.table("<schema>.<table>").count()`.
  3. Confirm notebook code that depends on the default lakehouse works without manually attaching a lakehouse in the UI.
- **Do NOT**:
  1. Diagnose this first as a notebook code issue; this symptom is primarily about **notebook metadata / lakehouse attachment**.
  2. Assume the notebook is attached just because its code references `/lakehouse/default/...` or `spark.table(...)`.
  3. Fix it only in the UI and leave the deployment or publication path unchanged. The next notebook redeploy or update will remove the manual fix if the metadata block is still missing.
