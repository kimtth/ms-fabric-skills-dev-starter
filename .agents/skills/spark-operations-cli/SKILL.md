---
name: spark-operations-cli
description: >
  Diagnose failed Spark jobs, unhealthy Livy sessions,
  and performance bottlenecks in Microsoft Fabric via read-only CLI triage.
  Use when the user wants to: (1) diagnose why a Spark job, notebook run, or Lakehouse job failed,
  (2) triage stuck or dead Livy sessions, (3) identify OOM, shuffle spill, or data skew,
  (4) retrieve driver and executor logs or Spark Advisor findings,
  (5) copy event logs and start a local Spark History Server,
  (6) diagnose all Spark activities within a failed pipeline run.
  Triggers: "diagnose my failed notebook", "why did my spark job fail",
  "triage spark failure", "diagnose pipeline run failure", "why did my pipeline fail",
  "livy session stuck in starting", "spark executor OOM",
  "check spark advisor findings", "shuffle spill diagnosis",
  "why did my lakehouse job fail", "diagnose lakehouse table load",
  "data skew diagnosis", "open spark history server locally",
  "analyze spark failure logs", "spark job triage".
---

> **Update Check — ONCE PER SESSION (mandatory)**
> The first time this skill is used in a session, run the **check-updates** skill before proceeding.
> - **GitHub Copilot CLI / VS Code**: invoke the `check-updates` skill.
> - **Claude Code / Cowork / Cursor / Windsurf / Codex**: compare local vs remote package.json version.
> - Skip if the check was already performed earlier in this session.

> **CRITICAL NOTES**
> 1. To find the workspace details (including its ID) from workspace name: list all workspaces and, then, use JMESPath filtering
> 2. To find the item details (including its ID) from workspace ID, item type, and item name: list all items of that type in that workspace and, then, use JMESPath filtering
> 3. **Skill disambiguation**: `spark-operations-cli` is for **read-only triage and diagnosis** of existing jobs and sessions. For creating notebooks, running new jobs, or Spark development, use `spark-authoring-cli`. For interactive PySpark analysis and Livy session creation, use `spark-consumption-cli`.

# Spark Operations — CLI Skill

This skill provides diagnostics for Microsoft Fabric Spark job failures, Livy session health, and performance bottlenecks using Fabric REST APIs and CLI tools (`az rest`). All diagnostic operations are read-only; session cleanup (e.g., stopping zombie sessions) requires explicit user confirmation. For Spark development and notebook authoring, use `spark-authoring-cli`. For interactive PySpark analysis, use `spark-consumption-cli`.

## Table of Contents

| Task | Reference | Notes |
|---|---|---|
| Fabric Topology & Key Concepts | [COMMON-CORE.md § Fabric Topology & Key Concepts](../../common/COMMON-CORE.md#fabric-topology--key-concepts) ||
| Environment URLs | [COMMON-CORE.md § Environment URLs](../../common/COMMON-CORE.md#environment-urls) ||
| Authentication & Token Acquisition | [COMMON-CORE.md § Authentication & Token Acquisition](../../common/COMMON-CORE.md#authentication--token-acquisition) | Wrong audience = 401; read before any auth issue |
| Core Control-Plane REST APIs | [COMMON-CORE.md § Core Control-Plane REST APIs](../../common/COMMON-CORE.md#core-control-plane-rest-apis) ||
| Pagination | [COMMON-CORE.md § Pagination](../../common/COMMON-CORE.md#pagination) ||
| Long-Running Operations (LRO) | [COMMON-CORE.md § Long-Running Operations (LRO)](../../common/COMMON-CORE.md#long-running-operations-lro) ||
| Rate Limiting & Throttling | [COMMON-CORE.md § Rate Limiting & Throttling](../../common/COMMON-CORE.md#rate-limiting--throttling) ||
| Job Execution | [COMMON-CORE.md § Job Execution](../../common/COMMON-CORE.md#job-execution) ||
| Capacity Management | [COMMON-CORE.md § Capacity Management](../../common/COMMON-CORE.md#capacity-management) ||
| Gotchas & Troubleshooting | [COMMON-CORE.md § Gotchas & Troubleshooting](../../common/COMMON-CORE.md#gotchas--troubleshooting) ||
| Best Practices | [COMMON-CORE.md § Best Practices](../../common/COMMON-CORE.md#best-practices) ||
| Tool Selection Rationale | [COMMON-CLI.md § Tool Selection Rationale](../../common/COMMON-CLI.md#tool-selection-rationale) ||
| Finding Workspaces and Items in Fabric | [COMMON-CLI.md § Finding Workspaces and Items in Fabric](../../common/COMMON-CLI.md#finding-workspaces-and-items-in-fabric) | **Mandatory** — *READ link first* [needed for finding workspace id by its name or item id by its name, item type, and workspace id] |
| Authentication Recipes | [COMMON-CLI.md § Authentication Recipes](../../common/COMMON-CLI.md#authentication-recipes) | `az login` flows and token acquisition |
| Fabric Control-Plane API via `az rest` | [COMMON-CLI.md § Fabric Control-Plane API via az rest](../../common/COMMON-CLI.md#fabric-control-plane-api-via-az-rest) | **Always pass `--resource https://api.fabric.microsoft.com`** or `az rest` fails |
| Pagination Pattern | [COMMON-CLI.md § Pagination Pattern](../../common/COMMON-CLI.md#pagination-pattern) ||
| Long-Running Operations (LRO) Pattern | [COMMON-CLI.md § Long-Running Operations (LRO) Pattern](../../common/COMMON-CLI.md#long-running-operations-lro-pattern) ||
| Gotchas & Troubleshooting (CLI-Specific) | [COMMON-CLI.md § Gotchas & Troubleshooting (CLI-Specific)](../../common/COMMON-CLI.md#gotchas--troubleshooting-cli-specific) | `az rest` audience, shell escaping, token expiry |
| Quick Reference: `az rest` Template | [COMMON-CLI.md § Quick Reference: az rest Template](../../common/COMMON-CLI.md#quick-reference-az-rest-template) ||
| Quick Reference: Token Audience / CLI Tool Matrix | [COMMON-CLI.md § Quick Reference: Token Audience ↔ CLI Tool Matrix](../../common/COMMON-CLI.md#quick-reference-token-audience--cli-tool-matrix) | Which `--resource` + tool for each service |
| Livy Session Management | [SPARK-CONSUMPTION-CORE.md § Livy Session Management](../../common/SPARK-CONSUMPTION-CORE.md#livy-session-management) | Session creation, states, lifecycle, termination |
| Interactive Data Exploration | [SPARK-CONSUMPTION-CORE.md § Interactive Data Exploration](../../common/SPARK-CONSUMPTION-CORE.md#interactive-data-exploration) | Statement execution, output retrieval, data discovery |
| Notebook Execution & Job Management | [SPARK-AUTHORING-CORE.md § Notebook Execution & Job Management](../../common/SPARK-AUTHORING-CORE.md#notebook-execution--job-management) ||
| Job Failure Classification | [job-diagnostics.md § Failure Classification](references/job-diagnostics.md#failure-classification) | OOM, shuffle, timeout, dependency, configuration errors |
| Reading Spark Logs via REST | [job-diagnostics.md § Reading Spark Logs via REST](references/job-diagnostics.md#reading-spark-logs-via-rest) | Driver/executor log retrieval from Livy |
| Job Instance History | [job-diagnostics.md § Job Instance History](references/job-diagnostics.md#job-instance-history) | Query recent runs, compare durations, detect regressions |
| Failure Triage Workflow | [job-diagnostics.md § Failure Triage Workflow](references/job-diagnostics.md#failure-triage-workflow) | Step-by-step decision tree for diagnosing failures |
| Session Health Assessment | [session-health.md § Livy Session Lifecycle](references/session-health.md#livy-session-lifecycle) | Session states, transitions, expected durations |
| Idle and Zombie Session Detection | [session-health.md § Idle and Zombie Session Detection](references/session-health.md#idle-and-zombie-session-detection) | Find and clean up leaked sessions |
| Session Resource Monitoring | [session-health.md § Session Resource Monitoring](references/session-health.md#session-resource-monitoring) | Memory and executor usage via Livy |
| Session Recovery Patterns | [session-health.md § Session Recovery Patterns](references/session-health.md#session-recovery-patterns) | Restart strategies and session replacement |
| Performance Anti-Patterns | [performance-patterns.md § Anti-Patterns](references/performance-patterns.md#anti-patterns) | Spill, shuffle, skew, small files, collect misuse |
| Stage and Task Analysis | [performance-patterns.md § Stage and Task Analysis](references/performance-patterns.md#stage-and-task-analysis) | Reading Spark UI metrics via REST |
| Optimization Recipes | [performance-patterns.md § Optimization Recipes](references/performance-patterns.md#optimization-recipes) | Partition tuning, broadcast joins, caching |
| Capacity and Resource Diagnostics | [performance-patterns.md § Capacity and Resource Diagnostics](references/performance-patterns.md#capacity-and-resource-diagnostics) | CU consumption, throttling detection |
| JobInsight Event Log Copy | [jobinsight-api.md § LogUtils.copyEventLog](references/jobinsight-api.md#logutilscopyeventlog) | Copy event logs from Fabric to OneLake for offline analysis |
| Local Spark History Server | [spark-history-server.md § Overview](references/spark-history-server.md#overview) | Start local SHS for full Spark UI (DAG, tasks, SQL plans) |
| Pipeline Run Diagnosis | [pipeline-diagnosis.md](references/pipeline-diagnosis.md) | Diagnose all Spark activities within a pipeline run (Steps P1–P6) |
| Spark Monitoring API Overview | [SPARK-MONITORING-CORE.md § Overview](../../common/SPARK-MONITORING-CORE.md#overview) | GA monitoring APIs — no active session required |
| Workspace & Item Session Listing | [SPARK-MONITORING-CORE.md § Workspace and Item-Level Session Listing](../../common/SPARK-MONITORING-CORE.md#workspace-and-item-level-session-listing) | List Spark apps across workspace with filtering |
| Open-Source Spark History Server APIs | [SPARK-MONITORING-CORE.md § Open-Source Spark History Server APIs](../../common/SPARK-MONITORING-CORE.md#open-source-spark-history-server-apis) | Jobs, stages, executors, SQL queries via REST |
| Driver and Executor Log APIs | [SPARK-MONITORING-CORE.md § Driver and Executor Log APIs](../../common/SPARK-MONITORING-CORE.md#driver-and-executor-log-apis) | Direct log retrieval without active session |
| Livy Log API | [SPARK-MONITORING-CORE.md § Livy Log API](../../common/SPARK-MONITORING-CORE.md#livy-log-api) | Session-level log with byte-offset pagination |
| Spark Advisor API | [SPARK-MONITORING-CORE.md § Spark Advisor API](../../common/SPARK-MONITORING-CORE.md#spark-advisor-api) | **Key** — automated skew detection, task errors, recommendations |
| Resource Usage API | [SPARK-MONITORING-CORE.md § Resource Usage API](../../common/SPARK-MONITORING-CORE.md#resource-usage-api) | vCore timeline, idle/running cores, efficiency metrics |
| Monitoring Diagnostic Workflow | [SPARK-MONITORING-CORE.md § Diagnostic Workflow Using Monitoring APIs](../../common/SPARK-MONITORING-CORE.md#diagnostic-workflow-using-monitoring-apis) | Step-by-step triage using monitoring APIs |
| Manual CLI Recipes | [diagnostic-workflow.md § Manual CLI Recipes](references/diagnostic-workflow.md#manual-cli-recipes) | Ad-hoc diagnostic commands for manual use |
| Key Diagnostic Patterns | [diagnostic-workflow.md § Key Diagnostic Patterns](references/diagnostic-workflow.md#key-diagnostic-patterns) | Symptom → first check → likely cause lookup |
| Diagnostic Tiers | [diagnostic-workflow.md § Diagnostic Tiers](references/diagnostic-workflow.md#diagnostic-tiers) | Tier 1 (online REST) vs Tier 2 (local SHS) |
| Severity Thresholds | [diagnostic-workflow.md § Severity Thresholds](references/diagnostic-workflow.md#severity-thresholds) | Metric thresholds for classifying findings |

---

## Must/Prefer/Avoid

### MUST DO

- Always retrieve job/session status before attempting remediation
- Use workspace and item discovery from [COMMON-CLI.md](../../common/COMMON-CLI.md#finding-workspaces-and-items-in-fabric) — never hardcode IDs
- Check Livy session state before submitting diagnostic statements
- Follow the [Failure Triage Workflow](references/job-diagnostics.md#failure-triage-workflow) for systematic diagnosis
- Always check the Spark Advisor API before reading raw logs — it often identifies the root cause immediately
- Use monitoring APIs (no active session required) before attempting Livy-based diagnostics
- Poll job/session status with 10–30 second intervals; timeout diagnostics after 30 minutes
- Always include the Notebook Snapshot URL in diagnostic output — it has the longest retention and enables cell-level inspection in the Fabric UI

### PREFER

- Querying job instance history to establish baseline before declaring a regression
- Reusing existing idle sessions for diagnostic queries instead of creating new ones
- Checking capacity utilization when jobs are slow before blaming the Spark code
- Using `az rest` with JMESPath filtering to extract specific fields from large API responses
- The Spark Advisor API over manual log parsing for skew, task errors, and timeout detection
- Resource Usage API `coreEfficiency` metric to quantify cluster utilization before recommending scaling
- Job instance history comparison (last 5 runs) to detect regressions before deep-diving

### AVOID

- Killing sessions without checking if they have active statements
- Creating new sessions for every diagnostic query (reuse idle sessions)
- Assuming OOM without checking actual memory metrics from Livy
- Hardcoded workspace or item IDs in diagnostic scripts
- Diagnosing performance without first checking capacity throttling via the Admin API
- Submitting diagnostic statements to sessions in `busy` state

---

## Examples

### Example 1: Diagnose a Failed Notebook

User prompt: *"Why did my notebook ETL_Daily fail in workspace Production?"*

Agent workflow:
1. Resolves workspace → `workspaceId`, item → `itemId` (Notebook)
2. Lists recent Livy sessions, auto-picks the Failed session
3. Queries Spark Advisor → finds `TaskError: OutOfMemoryError` on executor
4. Queries `/stages` → confirms data skew (12× max/median ratio in stage 5)
5. Presents report with HIGH findings + fix recommendations

### Example 2: Triage Stuck Livy Session

User prompt: *"My Livy session abc-1234 is stuck in starting state"*

Agent workflow:
1. Uses session ID directly, queries session state
2. Lists all workspace sessions → detects 8 concurrent sessions (capacity pressure)
3. Checks Livy log → no errors, just queued
4. Reports: capacity contention, recommends waiting or cancelling idle sessions

### Example 3: Pipeline Failure Root Cause

User prompt: *"Diagnose pipeline run 5678 in workspace Analytics"*

Agent workflow:
1. Resolves pipeline, calls `queryActivityRuns` for run 5678
2. Finds 2 Notebook activities: one Succeeded, one Failed
3. Extracts `output.result.error.{ename, evalue, traceback}` from failed activity
4. Constructs Notebook Snapshot URL for cell-level inspection
5. Presents error details + snapshot link + suggested fix

---

## Quick Start

### Environment Setup

Apply environment detection from [COMMON-CLI.md](../../common/COMMON-CLI.md#authentication-recipes) to set:
- `$FABRIC_API_BASE` and `$FABRIC_RESOURCE_SCOPE`
- `$FABRIC_API_URL` and `$LIVY_API_PATH` for Livy operations

**Authentication**: Use token acquisition from [COMMON-CLI.md § Authentication Recipes](../../common/COMMON-CLI.md#authentication-recipes).

---

## Automated Diagnostic Workflow

When the user provides a simple prompt (e.g., *"Diagnose my notebook ETL_Pipeline"*, *"What's wrong with Spark application abc-123"*, *"Check workspace Production for issues"*), follow this automated workflow. The agent collects all data and reports findings — the user does **not** need to know specific error patterns or API details.

### Entry Points (what the user provides)

| User provides | Agent resolves |
|---|---|
| Workspace name | → `workspaceId` (via workspace list + name filter) |
| Notebook / SJD / Lakehouse name | → `itemId` (via item list + name/type filter) |
| Pipeline name + run ID | → Find child Notebook/SJD activities → extract Spark sessions (see [Pipeline Run Diagnosis](#pipeline-run-diagnosis)) |
| Livy session ID | → Use directly |
| Spark application ID | → Use directly |
| Nothing specific | → Ask for at minimum workspace name + item name |

### Step 1 — Resolve & Discover

```bash
# Resolve workspace
workspaceId=$(az rest --method get --resource "$FABRIC_RESOURCE_SCOPE" \
  --url "$FABRIC_API_URL/workspaces" \
  --query "value[?displayName=='<UserWorkspaceName>'].id" --output tsv)

# Resolve item (notebook, SJD, or lakehouse)
itemId=$(az rest --method get --resource "$FABRIC_RESOURCE_SCOPE" \
  --url "$FABRIC_API_URL/workspaces/$workspaceId/items?type=Notebook" \
  --query "value[?displayName=='<UserItemName>'].id" --output tsv)
# If not found as Notebook, try SparkJobDefinition, then Lakehouse:
#   ?type=SparkJobDefinition  or  ?type=Lakehouse

# List recent Livy sessions (sorted newest first)
# Use the correct item-type path:
#   /notebooks/{itemId}/livySessions
#   /sparkJobDefinitions/{itemId}/livySessions
#   /lakehouses/{itemId}/livySessions
az rest --method get --resource "$FABRIC_RESOURCE_SCOPE" \
  --url "$FABRIC_API_URL/workspaces/$workspaceId/<itemTypePath>/$itemId/livySessions" \
  --output json
```

**Item-type API paths:**

| Item Type | Livy Sessions Path | Job Instances Path | Job Types |
|---|---|---|---|
| Notebook | `/notebooks/{id}/livySessions` | `/items/{id}/jobs/instances` | `PipelineRunNotebook`, `SparkSession` |
| Spark Job Definition | `/sparkJobDefinitions/{id}/livySessions` | `/items/{id}/jobs/instances` | `SparkJob` |
| Lakehouse | `/lakehouses/{id}/livySessions` | `/lakehouses/{id}/jobs/instances` | `TableLoad`, `TableMaintenance` |

> **Lakehouse note**: Lakehouse Spark sessions are typically short-lived (table loads, maintenance). If `livySessions` returns empty, check `jobs/instances` for `TableLoad`/`TableMaintenance` job history. Lakehouse jobs do not have a Notebook Snapshot — use Spark Advisor and driver logs for diagnostics.

**Present a session summary table** to the user (most recent 10):

```markdown
## Recent Sessions for <notebook name>

| # | Session ID | State | Submitted | Duration | App ID |
|---|------------|-------|-----------|----------|--------|
| 1 | abc-1234…  | Failed    | 2h ago  | 5m 23s  | app_…001 |
| 2 | def-5678…  | Succeeded | 4h ago  | 12m 10s | app_…002 |
| 3 | ghi-9012…  | Failed    | 1d ago  | 0s      | —        |
```

**Session selection logic:**
- **Auto-pick** if unambiguous — e.g., user said "why did it fail" and exactly 1 recent session has `state == Failed` → select it automatically and proceed
- **Ask the user** if ambiguous — multiple sessions match the user's intent (e.g., 2+ recent Failed sessions, or user said "diagnose" without specifying failed/slow) → present the table and ask which session to diagnose
- **User provided session/app ID** → skip the table entirely, use the ID directly

Extract `livyId`, `sparkApplicationId`, and `state` from the selected session.

### Step 1b — Fallback: Session Not Found / Data Expired

If the user provided a Livy session ID but it is **not found** in any session listing (workspace-level or item-level) and Spark Monitoring APIs return 404:

> **Why this happens**: Spark Monitoring API data (jobs, stages, executor logs, driver stderr) has **limited retention** after session completion — typically minutes to hours. Diagnose failures as soon as possible after they occur for the richest data.

**1. Determine the notebook ID** — ask the user if unknown:
```text
I found no active data for session `<livyId>` via Spark Monitoring APIs (data retention expired).

To diagnose this session, I need the **notebook name or ID** it belongs to.
- If this was from a **pipeline run**, provide the pipeline name + run ID — `queryActivityRuns` may still have error details.
- If you know the **notebook name**, provide it and I'll construct a direct link to the Fabric UI snapshot.
```

**2. Search pipeline runs** (if user confirms pipeline origin or workspace has pipelines):
Iterate pipelines → `GET /items/$pipelineId/jobs/instances?limit=5` → for Failed runs, `queryActivityRuns` to find sessionId match. Returns `output.result.error.{ename, evalue, traceback[]}` — richest error data available.

**3. Check Job Instance API** — `GET /items/$notebookId/jobs/instances?limit=5` for high-level `failureReason` (longer retention than Spark Monitoring APIs).

**4. Construct Notebook Snapshot URL** for manual cell-level inspection:
```text
https://app.powerbi.com/workloads/de-ds/sparkmonitor/{notebookId}/{livyId}?trident=1&experience=power-bi&ctid={tenantId}&tab=related
```
The Fabric UI retains notebook snapshots **much longer** than Spark Monitoring APIs (shows failed cell, traceback, cell execution times, and source code).

**5. Present report** with all available data:
```markdown
## Diagnostic Summary

**Session**: <livyId> | **Notebook**: <notebook name> | **State**: API data expired

### Error Details

[If queryActivityRuns returned data]:
**Exception**: <ename>: <evalue>
**Cell**: Cell In[<N>], line <M>
**Traceback**: <traceback lines>

[If only Job Instance data]:
**Failure Reason**: <failureReason from Job Instance API>

### Notebook Snapshot (cell-level details)
**Open Notebook Snapshot in Fabric UI**: `<constructed URL>`
↑ Click to view the exact failed cell, error output, and source code in the Fabric UI.

### Suggested Next Steps
1. Open the Notebook Snapshot link above to identify the exact failed cell and error
2. Fix the identified issue and re-run the notebook
3. For future failures, diagnose within 1 hour for full Spark Monitoring API data
4. For recurring failures, set up [proactive event log copy](references/jobinsight-api.md) to OneLake
```

> **Key principle**: Exhaust all public APIs (queryActivityRuns → Job Instance → Spark Monitoring) before falling back to the manual Notebook Snapshot URL. Always present the snapshot link — it has the longest retention.

> **Data retention summary** (public APIs):
> | API | Approximate retention | Error detail level |
> |-----|----------------------|-------------------|
> | Spark Monitoring (Advisor, logs, jobs, stages) | Minutes–hours | Full (stack traces, metrics) |
> | `queryActivityRuns` (pipeline path) | ~1 hour | Full (ename, evalue, traceback, cell/line) |
> | Job Instance `failureReason` | Days | High-level summary only |
> | Notebook Snapshot URL (Fabric UI) | Days–weeks | Full cell-level (manual) |

### Step 2 — Auto-Route by Session State

| State | Automatic actions |
|---|---|
| `Failed` | Run **Step 3** (failure) + **Step 4** (performance) + **Step 5** (resource) |
| `Succeeded` | Run **Step 4** (performance) + **Step 5** (resource) |
| `InProgress` | Run **Step 4** (performance — partial snapshot) + **Step 5** (resource) |
| `Cancelled` | Check Livy log for cancellation reason, then **Step 3** |
| `idle` / `busy` / `starting` | Run **Step 6** (session health) |
| `dead` / `killed` / `error` | Run **Step 3** (failure) + **Step 6** (session health) |

### Step 3 — Failure Analysis (automatic)

**Error API priority** — query in this order, stop when root cause is clear:
1. **Spark Advisor** (`/advice`) — automated root-cause with fix recommendations
2. **Driver stderr** (`/logs?type=driver&fileName=stderr&isDownload=true`) — raw exception stack traces
3. **Job Instance** (`/jobs/instances/{id}`) — high-level `failureReason`
4. **Executor logs** (`/logs?type=executor&meta=true`) — per-executor OOM / `ExecutorLostFailure`
5. **Livy log** (`/logs?type=livy`) — startup errors, library packaging failures
6. **Resource Usage** (`/resourceUsage`) — `capacityExceeded`, task limit exhaustion
7. **Notebook Snapshot URL** (manual) — all APIs expired, see [Step 1b](#step-1b--fallback-session-not-found--data-expired)

> For **pipeline runs**, `queryActivityRuns` (Step P2 in [pipeline-diagnosis.md](references/pipeline-diagnosis.md)) is the richest single source — returns `output.result.error.{ename, evalue, traceback[]}` with cell/line numbers.

All API paths follow the pattern: `$FABRIC_API_URL/workspaces/$workspaceId/<itemTypePath>/$itemId/livySessions/$livyId/applications/$appId/<endpoint>` — see [SPARK-MONITORING-CORE.md](../../common/SPARK-MONITORING-CORE.md) for full specs.

**Auto-classify** errors by matching log content against the [Quick Reference Table](references/job-diagnostics.md#quick-reference-table).

### Step 4 — Performance Analysis (automatic)

Query `/stages` and `/allexecutors` endpoints (see [SPARK-MONITORING-CORE.md § Open-Source Spark History Server APIs](../../common/SPARK-MONITORING-CORE.md#open-source-spark-history-server-apis)).

**Auto-flag** using [Detection Thresholds](references/performance-patterns.md#detection-thresholds): data skew (max/median task duration > 3×), disk spill (`diskBytesSpilled > 0`), GC pressure (`jvmGcTime/executorRunTime > 20%`), heavy shuffle (`shuffleWriteBytes > 1 GB`), small partitions (high task count, < 100ms each).

### Step 5 — Resource Utilization (automatic)

Query `/resourceUsage` endpoint (see [SPARK-MONITORING-CORE.md § Resource Usage API](../../common/SPARK-MONITORING-CORE.md#resource-usage-api)). Extract `coreEfficiency`, `idleTime`, `duration`.

**Auto-flag:** `coreEfficiency < 0.3` → HIGH (underutilized); `idleTime / duration > 0.4` → MEDIUM (high idle).

### Step 6 — Session Health (automatic)

List all sessions via `GET /workspaces/$workspaceId/spark/livySessions`. **Auto-flag:** `idle` with no recent statements → zombie; `starting` beyond expected duration → capacity issue; many concurrent sessions → capacity pressure.

### Step 7 — Compile & Present Report

After running the applicable steps, present a structured report:

```markdown
## Diagnostic Summary

**Application**: <notebook name> | **Session**: <livyId> | **State**: <state>

### Findings (ordered by severity)

| # | Severity | Category | Finding | Recommended Fix |
|---|----------|----------|---------|-----------------|
| 1 | HIGH     | Failure  | Driver OOM from collect() on line 45 | Replace with df.write.parquet() |
| 2 | HIGH     | Perf     | Data skew in stage 12 (8.2× ratio) | Enable AQE skew join |
| 3 | MEDIUM   | Perf     | Disk spill in stage 8 (2.1 GB) | Increase shuffle partitions |
| 4 | MEDIUM   | Resource | Core efficiency 22% | Reduce executor count |

### Links
- **Notebook Snapshot**: `https://app.powerbi.com/workloads/de-ds/sparkmonitor/{notebookId}/{livyId}?trident=1&experience=power-bi&ctid={tenantId}&tab=related`
- **Spark Monitor**: `https://app.powerbi.com/workloads/de-ds/sparkmonitor/{notebookId}/{livyId}?trident=1&experience=power-bi&ctid={tenantId}`

### Suggested Next Steps
1. [Most impactful fix first]
2. [Second fix]
3. [Optional: escalate to Tier 2 if needed]
```

**Notebook Snapshot URL**: Use the URL pattern from [Step 1b](#step-1b--fallback-session-not-found--data-expired). Use `app.powerbi.com` for production, `msit.powerbi.com` for MSIT.

> **Tier 2 escalation**: If any step returns truncated data, HTTP 408/504, or the user asks for DAG/SQL plan visualization, suggest the [offline workflow](references/spark-history-server.md).

