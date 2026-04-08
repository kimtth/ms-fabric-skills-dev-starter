---
mode: agent
description: Create a Fabric item via REST API with correct LRO handling
tools: ["run_in_terminal"]
---

Create a new Fabric item in a specified workspace. The item type and name will be provided.

Use the Fabric REST API with correct authentication, LRO handling, and error management.

Steps:
1. Authenticate: `az account get-access-token --resource https://api.fabric.microsoft.com`
2. Resolve workspace by name if needed: `GET /v1/workspaces` with JMESPath filter
3. Create item: `POST /v1/workspaces/{wsId}/items` with `{ "type": "<ItemType>", "displayName": "<name>" }`
4. If response is 202 Accepted:
   - Extract `x-ms-operation-id` and `Retry-After` headers
   - Poll `GET /v1/operations/{operationId}` until status is Succeeded or Failed
   - On success, get result from `GET /v1/operations/{operationId}/result`
5. If response is 201 Created: item is ready immediately
6. Output the item ID, type, and any connection properties

Supported item types: Lakehouse, Warehouse, Notebook, DataPipeline, SemanticModel, KQLDatabase, Eventhouse, SparkJobDefinition, Environment, Report
