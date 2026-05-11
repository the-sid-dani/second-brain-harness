#!/usr/bin/env bash
# scripts/lib/fastedit-mcp.sh — register FastEdit MCP in the project's .mcp.json

install_fastedit_mcp() {
    step "Registering FastEdit MCP in .mcp.json"

    local mcp_file=".mcp.json"
    if [ ! -f "$mcp_file" ]; then
        # Bootstrap a minimal .mcp.json if absent (fork user with empty MCP config)
        echo '{"mcpServers": {}}' > "$mcp_file"
        info "created empty $mcp_file"
    fi

    if ! command -v jq >/dev/null 2>&1; then
        die "jq required for $mcp_file edit — install jq first"
    fi

    if jq -e '.mcpServers.fastedit' "$mcp_file" >/dev/null 2>&1; then
        info "fastedit already registered in $mcp_file (skipping)"
        return 0
    fi

    if ! command -v fastedit >/dev/null 2>&1; then
        die "fastedit binary not found — install_ccv4_python must run first (or --no-fastedit-model was set)"
    fi
    local fastedit_path
    fastedit_path="$(command -v fastedit)"

    local tmp
    tmp="$(mktemp)"
    jq --arg cmd "$fastedit_path" \
        '.mcpServers.fastedit = {"command": $cmd, "args": ["mcp"], "type": "stdio"}' \
        "$mcp_file" > "$tmp" && mv "$tmp" "$mcp_file"
    info "fastedit registered in $mcp_file (command: $fastedit_path mcp)"
}
