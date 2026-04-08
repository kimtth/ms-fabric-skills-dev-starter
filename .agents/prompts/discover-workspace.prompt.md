---
mode: agent
description: Discover workspaces and items in a Fabric tenant
tools: ["run_in_terminal"]
---

List all Microsoft Fabric workspaces I have access to, then for each workspace list its items (Lakehouses, Warehouses, Notebooks, Pipelines, Semantic Models).

Use `az rest` with the Fabric REST API. Authenticate with `az login` if needed.

Steps:
1. Get a Fabric API token: `az account get-access-token --resource https://api.fabric.microsoft.com`
2. List workspaces: `GET https://api.fabric.microsoft.com/v1/workspaces`
3. For each workspace, list items: `GET https://api.fabric.microsoft.com/v1/workspaces/{id}/items`
4. Handle pagination via `continuationToken`
5. Present results as a table: Workspace | Item Name | Item Type | Item ID
