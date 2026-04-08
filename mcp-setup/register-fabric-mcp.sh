#!/bin/bash

set -euo pipefail

SERVER_NAME="fabric"
AUTH_TYPE="none"
TOKEN=""
TOOL="all"
SERVER_URL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --server-url)
            SERVER_URL="$2"
            shift 2
            ;;
        --server-name)
            SERVER_NAME="$2"
            shift 2
            ;;
        --auth-type)
            AUTH_TYPE="$2"
            shift 2
            ;;
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --tool)
            TOOL="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$SERVER_URL" ]]; then
    echo "Error: --server-url is required" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required. Install it first." >&2
    exit 1
fi

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

status() { echo -e "${CYAN}[*] $1${NC}"; }
success() { echo -e "${GREEN}[+] $1${NC}"; }
warning() { echo -e "${YELLOW}[!] $1${NC}"; }

build_server_config() {
    if [[ "$AUTH_TYPE" != "none" ]]; then
        if [[ -z "$TOKEN" ]]; then
            warning "AuthType is '$AUTH_TYPE' but no token was provided. Using FABRIC_MCP_TOKEN environment variable reference."
            TOKEN='${FABRIC_MCP_TOKEN}'
        fi

        jq -n \
            --arg url "$SERVER_URL" \
            --arg authType "$AUTH_TYPE" \
            --arg token "$TOKEN" \
            '{url: $url, transport: "http", auth: {type: $authType, token: $token}}'
    else
        jq -n --arg url "$SERVER_URL" '{url: $url, transport: "http"}'
    fi
}

ensure_parent_dir() {
    mkdir -p "$(dirname "$1")"
}

update_mcp_servers_file() {
    local config_path="$1"
    local tool_name="$2"
    local server_config="$3"

    status "Configuring $tool_name..."
    ensure_parent_dir "$config_path"

    local existing='{}'
    if [[ -f "$config_path" ]] && [[ -s "$config_path" ]]; then
        existing=$(cat "$config_path")
    fi

    echo "$existing" | jq --arg name "$SERVER_NAME" --argjson server "$server_config" '
        .mcpServers = (.mcpServers // {}) |
        .mcpServers[$name] = $server
    ' > "$config_path"

    success "$tool_name configured at $config_path"
}

configure_copilot() {
    local config_path="$HOME/.copilot/mcp.json"
    local server_config
    server_config=$(build_server_config)
    update_mcp_servers_file "$config_path" "GitHub Copilot CLI" "$server_config"
}

configure_claude() {
    local config_path
    if [[ "$OSTYPE" == darwin* ]]; then
        config_path="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    else
        config_path="$HOME/.config/claude/claude_desktop_config.json"
    fi

    local mcp_proxy_version="0.1.0"
    local server_config
    server_config=$(jq -n \
        --arg url "$SERVER_URL" \
        --arg version "$mcp_proxy_version" \
        '{command: "npx", args: ["-y", ("@anthropic/mcp-proxy@" + $version), $url]}')

    update_mcp_servers_file "$config_path" "Claude Desktop" "$server_config"
}

update_vscode_settings_file() {
    local config_path="$1"
    status "Configuring VS Code settings at $config_path..."
    ensure_parent_dir "$config_path"

    local existing='{}'
    if [[ -f "$config_path" ]] && [[ -s "$config_path" ]]; then
        existing=$(cat "$config_path")
    fi

    echo "$existing" | jq --arg name "$SERVER_NAME" --arg url "$SERVER_URL" '
        .["github.copilot.chat.mcpServers"] = (.["github.copilot.chat.mcpServers"] // {}) |
        .["github.copilot.chat.mcpServers"][$name] = {url: $url}
    ' > "$config_path"

    success "VS Code configured at $config_path"
}

configure_vscode() {
    local paths=()
    if [[ "$OSTYPE" == darwin* ]]; then
        paths+=("$HOME/Library/Application Support/Code/User/settings.json")
        paths+=("$HOME/Library/Application Support/Code - Insiders/User/settings.json")
    else
        paths+=("$HOME/.config/Code/User/settings.json")
        paths+=("$HOME/.config/Code - Insiders/User/settings.json")
    fi

    for path in "${paths[@]}"; do
        update_vscode_settings_file "$path"
    done
}

case "$TOOL" in
    copilot)
        configure_copilot
        ;;
    claude)
        configure_claude
        ;;
    vscode)
        configure_vscode
        ;;
    all)
        configure_copilot
        configure_claude
        configure_vscode
        ;;
    *)
        echo "Error: --tool must be one of copilot, claude, vscode, all" >&2
        exit 1
        ;;
esac

echo ""
success "Fabric MCP server '$SERVER_NAME' registered successfully."
echo ""
echo "To verify in Copilot CLI:"
echo "  /mcp list"