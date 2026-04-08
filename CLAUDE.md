# Microsoft Fabric Development Instructions

> Read `.agents/instructions.md` for full agent guidance and `.agents/skills/` for Fabric skills.

This workspace is a scaffolding template for Microsoft Fabric development.

## Architecture

- Everything is under `.agents/`: skills, agents, common references, and prompts.
- Flow: **Agents → Skills → Common**. All self-contained.

## Authentication

```bash
az login
az account get-access-token --resource https://api.fabric.microsoft.com
```

## Key Rules

- Use Delta Lake format for all Lakehouse tables
- Parameterize workspace ID, item ID, token audience — never hardcode
- Handle pagination (`continuationToken`), LRO (`Retry-After`), throttling (`429`)
- Use `mssparkutils` for Fabric-specific notebook operations
- Never hardcode secrets — use Key Vault or environment variables
- For SDK verification, use the `microsoft-code-reference` skill

## Reference

- Fabric REST APIs: https://learn.microsoft.com/en-us/rest/api/fabric/articles/
- Fabric docs: https://learn.microsoft.com/en-us/fabric/
