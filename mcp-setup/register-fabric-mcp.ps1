<#
.SYNOPSIS
    Registers a Fabric MCP server with GitHub Copilot CLI, Claude Desktop, and VS Code.

.DESCRIPTION
    Adds MCP server configuration to local AI tool config files for a remote Fabric MCP server.

.PARAMETER ServerUrl
    The URL of the Fabric MCP server.

.PARAMETER ServerName
    Local name for the server. Defaults to fabric.

.PARAMETER AuthType
    Authentication type: none, bearer, api-key. Defaults to none.

.PARAMETER Token
    Authentication token. Required only when the server expects it.

.PARAMETER Tool
    Which tool to configure: copilot, claude, vscode, all. Defaults to all.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ServerUrl,

    [string]$ServerName = "fabric",

    [ValidateSet("none", "bearer", "api-key")]
    [string]$AuthType = "none",

    [string]$Token = "",

    [ValidateSet("copilot", "claude", "vscode", "all")]
    [string]$Tool = "all"
)

$ErrorActionPreference = "Stop"

function Write-Status($Message) {
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Write-Success($Message) {
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Warn($Message) {
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Read-JsonHashtable($Path) {
    if (-not (Test-Path $Path)) {
        return @{}
    }

    $raw = Get-Content $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @{}
    }

    return $raw | ConvertFrom-Json -AsHashtable
}

function Write-JsonFile($Path, $Object) {
    $directory = Split-Path $Path -Parent
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $Object | ConvertTo-Json -Depth 20 | Set-Content $Path -Encoding UTF8
}

function Add-McpServer($ConfigPath, $ToolName, $ServerConfig) {
    Write-Status "Configuring $ToolName..."

    $config = Read-JsonHashtable $ConfigPath
    if (-not $config.ContainsKey("mcpServers")) {
        $config["mcpServers"] = @{}
    }

    $config["mcpServers"][$ServerName] = $ServerConfig
    Write-JsonFile $ConfigPath $config
    Write-Success "$ToolName configured at $ConfigPath"
}

function Get-VsCodeSettingsPaths {
    $paths = @()
    if ($env:APPDATA) {
        $paths += (Join-Path $env:APPDATA "Code\User\settings.json")
        $paths += (Join-Path $env:APPDATA "Code - Insiders\User\settings.json")
    }
    return $paths | Select-Object -Unique
}

$serverConfig = @{
    url = $ServerUrl
    transport = "http"
}

if ($AuthType -ne "none") {
    if ([string]::IsNullOrWhiteSpace($Token)) {
        Write-Warn "AuthType is '$AuthType' but no token was provided. Using FABRIC_MCP_TOKEN environment variable reference."
        $Token = '`${FABRIC_MCP_TOKEN}'
    }

    $serverConfig["auth"] = @{
        type = $AuthType
        token = $Token
    }
}

if ($Tool -eq "copilot" -or $Tool -eq "all") {
    $copilotConfig = Join-Path $env:USERPROFILE ".copilot\mcp.json"
    Add-McpServer $copilotConfig "GitHub Copilot CLI" $serverConfig
}

if ($Tool -eq "claude" -or $Tool -eq "all") {
    $claudeConfig = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
    $mcpProxyVersion = "0.1.0"
    $claudeServerConfig = @{
        command = "npx"
        args = @("-y", "@anthropic/mcp-proxy@$mcpProxyVersion", $ServerUrl)
    }
    Add-McpServer $claudeConfig "Claude Desktop" $claudeServerConfig
}

if ($Tool -eq "vscode" -or $Tool -eq "all") {
    $settingsPaths = Get-VsCodeSettingsPaths
    $updated = $false

    foreach ($settingsPath in $settingsPaths) {
        Write-Status "Configuring VS Code settings at $settingsPath..."
        $settings = Read-JsonHashtable $settingsPath
        if (-not $settings.ContainsKey("github.copilot.chat.mcpServers")) {
            $settings["github.copilot.chat.mcpServers"] = @{}
        }

        $settings["github.copilot.chat.mcpServers"][$ServerName] = @{ url = $ServerUrl }
        Write-JsonFile $settingsPath $settings
        Write-Success "VS Code settings updated at $settingsPath"
        $updated = $true
    }

    if (-not $updated) {
        Write-Warn "No VS Code settings paths were found for this user profile."
    }
}

Write-Host ""
Write-Success "Fabric MCP server '$ServerName' registered successfully."
Write-Host ""
Write-Host "To verify in Copilot CLI:" -ForegroundColor White
Write-Host "  /mcp list" -ForegroundColor Gray