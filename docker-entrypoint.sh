#!/bin/sh
set -e

DOMAINS_FILE="${DOMAINS_FILE:-/etc/coredns/domains.txt}"
UPSTREAMS="${UPSTREAMS:-8.8.8.8 1.1.1.1}"
GENERATED="/tmp/Corefile"

# Parse domain list:
#   - strip comment lines (starting with #) and blank lines
#   - take only the first comma-separated field (CSV support)
#   - strip inline comments and surrounding whitespace
#   - strip Windows line endings
#   - discard anything that doesn't look like a valid hostname
DOMAINS=$(grep -v '^\s*#' "$DOMAINS_FILE" 2>/dev/null \
    | grep -v '^\s*$' \
    | cut -d',' -f1 \
    | sed 's/[[:space:]].*//' \
    | tr -d '\r' \
    | grep -E '^[a-zA-Z0-9]([a-zA-Z0-9._-]*[a-zA-Z0-9])?$' \
    || true)

if [ -z "$DOMAINS" ]; then
    COUNT=0
else
    COUNT=$(printf '%s\n' "$DOMAINS" | wc -l | tr -d ' ')
fi

if [ "$COUNT" -gt 0 ]; then
    # Escape dots for use in a Go regex, then join with | for alternation
    PATTERN=$(printf '%s\n' "$DOMAINS" | sed 's/\./\\./g' | tr '\n' '|' | sed 's/|$//')
    echo "dns-filter: loaded $COUNT domain(s) for AAAA blocking"
else
    PATTERN=""
    echo "dns-filter: warning: no domains found in $DOMAINS_FILE — AAAA filter inactive"
fi

# Generate Corefile
{
    echo '.:53 {'
    if [ -n "$PATTERN" ]; then
        echo '    template IN AAAA {'
        # match apex and all subdomains for every listed domain
        echo "        match ^(.*\\.)?($PATTERN)\\.\$"
        echo '        rcode NOERROR'
        echo '        authority "filter.invalid. 60 IN SOA ns.filter.invalid. hostmaster.filter.invalid. 1 3600 900 86400 60"'
        echo '        fallthrough'
        echo '    }'
        echo ''
    fi
    echo "    forward . $UPSTREAMS"
    echo ''
    echo '    cache 30'
    echo '    log'
    echo '    errors'
    echo '}'
} > "$GENERATED"

echo "dns-filter: starting CoreDNS"
exec /coredns -conf "$GENERATED"
