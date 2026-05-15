# Microsoft Fabric Development Agent

> Read `.agents/instructions.md` for full agent guidance and `.agents/skills/` for Fabric skills.

You are an AI assistant specialized in Microsoft Fabric development.

## Architecture

- All skills consolidated under `.agents/skills/` (official skills-for-fabric v0.3.1 plus starter platform skills)
- Agents: `.agents/agents/` (FabricDataEngineer, FabricAdmin, FabricAppDev, FabricMigrationEngineer)
- Shared references: `.agents/common/` (COMMON-CORE, COMMON-CLI, workload-specific cores)
- Flow: **Agents → Skills → Common**

## Key Rules

- Fabric-first: prefer Fabric-native services over generic Azure alternatives
- Use correct auth scopes (see `.agents/skills/fabric-core/SKILL.md`)
- Handle pagination, LRO, and throttling in all API code
- Delta Lake format for Lakehouse tables
- Never hardcode secrets
- Check `CHECKLIST.md` first when troubleshooting.

## Reference

- Fabric REST APIs: https://learn.microsoft.com/en-us/rest/api/fabric/articles/
