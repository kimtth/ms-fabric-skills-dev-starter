# MCP Server Registration for Fabric

This folder contains scripts and templates to register external Fabric MCP (Model Context Protocol) servers with local AI coding tools.

These assets are for MCP servers that are already built and hosted elsewhere. They do not create or run the servers themselves.

## Prerequisites

1. GitHub Copilot CLI installed and authenticated
2. Fabric MCP server URL provided by your organization or service provider
3. Authentication credentials for the MCP server, if required

## Quick Start

### Windows (PowerShell)

```powershell
.\register-fabric-mcp.ps1 -ServerUrl "https://your-fabric-mcp-server.com" -ServerName "fabric"
```

### macOS/Linux (Bash)

```bash
./register-fabric-mcp.sh --server-url "https://your-fabric-mcp-server.com" --server-name "fabric"
```

## Configuration Options

| Option | Description | Required |
|--------|-------------|----------|
| `ServerUrl` / `--server-url` | URL of the Fabric MCP server | Yes |
| `ServerName` / `--server-name` | Local name for the server (default: `fabric`) | No |
| `AuthType` / `--auth-type` | Authentication type: `none`, `bearer`, `api-key` | No |
| `Token` / `--token` | Authentication token (if required) | Depends |
| `Tool` / `--tool` | Which tool to configure: `copilot`, `claude`, `vscode`, `all` | No |

## Manual Configuration

If you prefer to configure manually, edit your MCP configuration file.

### GitHub Copilot CLI

Location: `~/.copilot/mcp.json` or `%USERPROFILE%\.copilot\mcp.json`

```json
{
  "mcpServers": {
    "fabric": {
      "url": "https://your-fabric-mcp-server.com",
      "transport": "http",
      "auth": {
        "type": "bearer",
        "token": "${FABRIC_MCP_TOKEN}"
      }
    }
  }
}
```

### Claude Desktop

Location:

- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Linux: `~/.config/claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "fabric": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-proxy@0.1.0", "https://your-fabric-mcp-server.com"]
    }
  }
}
```

Version `0.1.0` is pinned for reproducibility. Review and bump it intentionally when upgrading.

### VS Code / VS Code Insiders

Add to `settings.json`:

```json
{
  "github.copilot.chat.mcpServers": {
    "fabric": {
      "url": "https://your-fabric-mcp-server.com"
    }
  }
}
```

Common locations:

- Windows VS Code: `%APPDATA%\Code\User\settings.json`
- Windows VS Code Insiders: `%APPDATA%\Code - Insiders\User\settings.json`
- macOS VS Code: `~/Library/Application Support/Code/User/settings.json`
- macOS VS Code Insiders: `~/Library/Application Support/Code - Insiders/User/settings.json`
- Linux VS Code: `~/.config/Code/User/settings.json`
- Linux VS Code Insiders: `~/.config/Code - Insiders/User/settings.json`

## Template File

Use `mcp-config-template.json` as a starting point for manual configuration.

## Verifying Registration

After registration, verify the MCP server is available:

```bash
# In Copilot CLI
/mcp list
```

Then try a Fabric MCP request, for example: `List all workspaces using Fabric MCP`.

## Troubleshooting

### Server Not Found

- Verify the server URL is correct and accessible
- Check firewall and proxy settings

### Authentication Failed

- Verify your token is valid and not expired
- Check that the auth type matches what the server expects

### Connection Timeout

- The MCP server may be cold-starting
- Retry after a few seconds