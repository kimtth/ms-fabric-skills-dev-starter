---
name: fabric-api-discovery
description: >
  Discover Fabric APIs, OpenAPI specs, item schemas, and best practices using the Fabric MCP Server.
  Use when exploring available Fabric workloads, looking up API specifications, finding item definition
  formats, or managing OneLake files programmatically. All MCP tools run locally for reference.
---

# Fabric API Discovery

## Fabric MCP Server

The Fabric Pro-Dev MCP Server provides local-first API discovery and OneLake management without connecting to live Fabric environments.

### Setup

```bash
npm install -g fabric-pro-dev-mcp-server
```

Requires Node.js 18+.

### MCP Configuration

Add to your `.mcp.json` or agent MCP config:

```json
{
  "mcpServers": {
    "fabric-pro-dev": {
      "command": "npx",
      "args": ["-y", "fabric-pro-dev-mcp-server"]
    }
  }
}
```

### Power BI MCP (Live Queries)

For live DAX queries against semantic models:

```json
{
  "mcpServers": {
    "PowerBIQuery": {
      "type": "http",
      "url": "https://api.fabric.microsoft.com/v1/mcp/powerbi",
      "oauthClientId": "<MICROSOFT_PUBLIC_CLIENT_ID_FROM_CURRENT_DOCS>",
      "oauthPublicClient": true
    }
  }
}
```

Use the Microsoft-documented public client ID from the current Fabric MCP documentation rather than hardcoding a GUID in this repository.

## API Discovery Tools

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `publicapis_list` | List all Fabric workload types with APIs | Starting Fabric development, exploring workloads |
| `publicapis_get` | Get OpenAPI spec for a specific workload | Building integrations, checking request/response schemas |
| `publicapis_platform_get` | Get platform-level API specs | Working with core/admin APIs |
| `publicapis_bestpractices_get` | Get best practices documentation | Before implementing API patterns |
| `publicapis_bestpractices_examples_get` | Get request/response examples | Need concrete API call samples |
| `publicapis_bestpractices_itemdefinition_get` | Get item schema definitions | Creating or updating item definitions |

## OneLake Tools

| Tool | Purpose |
|------|---------|
| `onelake download file` | Download files from OneLake |
| `onelake upload file` | Upload files to OneLake |
| `onelake file list` | List files in OneLake path |
| `onelake file delete` | Delete files from OneLake |
| `onelake directory create` | Create OneLake directories |
| `onelake directory delete` | Delete OneLake directories |
| `onelake item list` | List workspace items |
| `onelake item list-data` | List items via DFS endpoint |
| `onelake item create` | Create new Fabric items |

## Available Workloads

Workloads with public API specifications include:

- Lakehouses
- Warehouses
- Notebooks
- Spark Job Definitions
- Data Pipelines
- Semantic Models (Power BI)
- KQL Databases
- Eventhouse
- Real-Time Intelligence (Eventstreams)
- ML Models & Experiments
- Reports
- Environments

## Item Definitions

Fabric items can be created/updated via **definition-based** workflows using base64-encoded file parts:

```
POST /v1/workspaces/<wsId>/items/<itemId>/updateDefinition[?updateMetadata=true]
{
  "definition": {
    "format": "<format>",
    "parts": [
      { "path": "<filePath>", "payload": "<base64>", "payloadType": "InlineBase64" }
    ]
  }
}
```

Use `publicapis_bestpractices_itemdefinition_get` to discover the expected format and parts for each item type.

> **Gotcha**: Omitting `?updateMetadata=true` silently ignores the `.platform` part.

## Developer vs Consumer Patterns

### Developers (REST + Protocol)

- Use REST APIs to create/manage artifacts
- Use protocol-specific connections for data access:
  - Spark/PySpark for Lakehouse data
  - ODBC/JDBC for Warehouse queries
  - XMLA/DAX for Semantic Models
  - KQL for Real-Time Intelligence

### Consumers (MCP)

- Use MCP servers for natural-language queries
- Supported for: Semantic Models, Warehouses, Lakehouse SQL Endpoints
- No ODBC/JDBC setup needed — MCP handles connections

## CLI Tooling

| Tool | Install | Purpose |
|------|---------|---------|
| Fabric CLI | `pip install ms-fabric-cli` | Command-line Fabric operations |
| fabric-cicd | `pip install fabric-cicd` | CI/CD automation for Fabric items |
| Azure CLI | `az rest --resource https://api.fabric.microsoft.com` | REST API calls with auto-auth |
