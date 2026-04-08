# Microsoft Fabric Development Instructions

This workspace is a scaffolding template for Microsoft Fabric development with AI coding agents.

## Setup

Read `.agents/instructions.md` for complete guidance. Skills are in `.agents/skills/`. Prompts are in `.agents/prompts/`.

All skills, agents, and shared references are consolidated under `.agents/`.

## Routing

1. Fabric questions → read relevant skill from `.agents/skills/` first
2. Cross-workload orchestration → `.agents/agents/FabricDataEngineer.agent.md`
3. Shared API patterns → `.agents/common/COMMON-CORE.md`
4. SDK verification → use `microsoft-code-reference` skill
5. Always use correct auth scopes (see `.agents/skills/fabric-core/SKILL.md`)

## Authentication

```bash
az login
az account get-access-token --resource https://api.fabric.microsoft.com
```

## Primary Reference

- Fabric REST APIs: https://learn.microsoft.com/en-us/rest/api/fabric/articles/
- Fabric docs: https://learn.microsoft.com/en-us/fabric/

## Code Rules

- Delta Lake format for all Lakehouse tables
- Parameterize workspace ID, item ID, token audience
- Handle pagination (`continuationToken`), LRO (`Retry-After`), throttling (`429`)
- Use `mssparkutils` in Fabric notebooks
- Never hardcode secrets — use Key Vault or environment variables
