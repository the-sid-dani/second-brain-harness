#!/usr/bin/env bash
# scripts/lib/api-keys.sh — interactively configure CCv4 API keys
#
# Honors:
#   SKIP_API_KEYS=1  → write empty .env stubs, do not prompt
#   RECONFIGURE=1    → re-prompt even for already-populated keys

configure_api_keys() {
    step "Configuring API keys"

    if [ "${SKIP_API_KEYS:-0}" = "1" ]; then
        info "--skip-api-keys set; writing empty .env stubs"
        local env_file=".env"
        if [ ! -f "$env_file" ]; then
            cat > "$env_file" <<'STUB'
# CCv4 API keys
ANTHROPIC_API_KEY=
EXA_API_KEY=
NIA_API_KEY=
HF_TOKEN=
ATLASSIAN_BASIC_AUTH=
STUB
            info "stub $env_file written; fill in manually before running CCv4 skills"
        else
            info ".env exists; not overwriting"
        fi
        return 0
    fi

    # Interactive prompt helper — idempotent upsert into <file>.
    prompt_key() {
        local name="$1" file="$2" url="$3"
        local current_val=""
        # `|| true` guards against grep exit 1 (no match) tripping pipefail+errexit
        if [ -f "$file" ]; then
            current_val="$(grep "^${name}=" "$file" 2>/dev/null | head -1 | cut -d= -f2- || true)"
        fi
        if [ -n "$current_val" ] && [ "${RECONFIGURE:-0}" != "1" ]; then
            info "$name already set in $file (use --reconfigure to re-prompt)"
            return 0
        fi
        printf "  %s (get from %s): " "$name" "$url"
        local val
        read -r val
        # idempotent upsert
        if [ -f "$file" ] && grep -q "^${name}=" "$file"; then
            # macOS sed needs '' after -i
            sed -i.bak "s|^${name}=.*|${name}=${val}|" "$file" && rm -f "${file}.bak"
        else
            printf '%s=%s\n' "$name" "$val" >> "$file"
        fi
        info "$name written to $file"
    }

    : > /dev/null  # ensure .env exists
    [ -f .env ] || touch .env

    prompt_key ANTHROPIC_API_KEY .env "https://console.anthropic.com"
    prompt_key EXA_API_KEY .env "https://exa.ai"
    prompt_key NIA_API_KEY .env "https://trynia.ai"
    prompt_key HF_TOKEN .env "https://huggingface.co/settings/tokens (optional)"

    prompt_key ATLASSIAN_BASIC_AUTH .env "https://id.atlassian.com/manage-profile/security/api-tokens"
}
