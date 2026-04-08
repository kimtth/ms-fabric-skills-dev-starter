---
mode: agent
description: Scaffold a new Fabric Lakehouse with Bronze/Silver/Gold layers
tools: ["run_in_terminal"]
---

Create a new Lakehouse in my Fabric workspace using the REST API, then set up a medallion architecture with Bronze, Silver, and Gold schemas.

Prerequisites:
- Workspace must have a capacity assigned (F2+ or P1+)
- User must be authenticated via `az login`

Steps:
1. Resolve workspace ID by name using `az rest`
2. Create the Lakehouse: `POST /v1/workspaces/{wsId}/items` with `{ "type": "Lakehouse", "displayName": "..." }`
3. Wait for LRO completion if 202 is returned
4. Create a PySpark notebook that initializes the medallion schema:
   - Bronze schema for raw ingestion
   - Silver schema for cleaned/conformed data
   - Gold schema for business-ready aggregations
5. Output the Lakehouse ID, SQL endpoint, and OneLake paths
