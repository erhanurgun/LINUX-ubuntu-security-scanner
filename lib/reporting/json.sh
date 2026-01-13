#!/bin/bash
#
# Security Scanner v0.2.2 - JSON Rapor Modülü
# json.sh - JSON formatında rapor oluşturma
#

generate_json_report() {
    local output_file="${1:-${REPORT_DIR_TODAY:-$REPORT_DIR}/json/scan_${SCAN_ID}.json}"

    mkdir -p "$(dirname "$output_file")"

    # Risk seviyesini belirle
    local risk_level="low"
    if [[ ${RISK_SCORE:-0} -ge 70 ]]; then
        risk_level="critical"
    elif [[ ${RISK_SCORE:-0} -ge 50 ]]; then
        risk_level="high"
    elif [[ ${RISK_SCORE:-0} -ge 30 ]]; then
        risk_level="medium"
    fi

    # Findings array'ini JSON formatına çevir
    local findings_json="["
    local first=true

    for finding in "${FINDINGS[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            findings_json+=","
        fi
        findings_json+="$finding"
    done
    findings_json+="]"

    # Findings by category gruplandırması
    local findings_by_category=""
    if command_exists jq; then
        findings_by_category=$(echo "$findings_json" | jq -c '
            group_by(.category // "general") |
            map({(.[0].category // "general"): .}) |
            add // {}
        ' 2>/dev/null || echo '{}')
    else
        findings_by_category='{}'
    fi

    # Tarih bilgileri
    local generated_at
    generated_at=$(date -Iseconds)
    local scan_started
    if [[ -n "${SCAN_START_TIME:-}" ]]; then
        scan_started=$(date -d "@${SCAN_START_TIME}" -Iseconds 2>/dev/null || echo "$generated_at")
    else
        scan_started="$generated_at"
    fi

    # Ana JSON raporu oluştur
    cat > "$output_file" <<EOF
{
    "meta": {
        "version": "${SCANNER_VERSION:-0.1.0}",
        "generated_at": "${generated_at}",
        "scan_id": "${SCAN_ID:-unknown}",
        "report_format": "2.0"
    },
    "scan": {
        "mode": "${SCAN_MODE:-full}",
        "duration_seconds": ${SCAN_DURATION:-0},
        "started_at": "${scan_started}",
        "completed_at": "${generated_at}",
        "user": "$USER"
    },
    "host": {
        "hostname": "$(hostname)",
        "os": "$(grep -oP '(?<=^PRETTY_NAME=").*(?="$)' /etc/os-release 2>/dev/null || echo 'Unknown')",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)",
        "uptime_seconds": $(cat /proc/uptime 2>/dev/null | cut -d' ' -f1 | cut -d'.' -f1 || echo 0)
    },
    "summary": {
        "risk_score": ${RISK_SCORE:-0},
        "risk_level": "${risk_level}",
        "total_findings": ${TOTAL_FINDINGS:-0},
        "passed_checks": ${PASS_COUNT:-0},
        "by_severity": {
            "critical": ${CRITICAL_COUNT:-0},
            "high": ${HIGH_COUNT:-0},
            "medium": ${MEDIUM_COUNT:-0},
            "low": ${LOW_COUNT:-0},
            "info": ${INFO_COUNT:-0}
        }
    },
    "findings_by_category": ${findings_by_category},
    "findings": ${findings_json}
}
EOF

    # JSON doğrulama ve formatlama
    if command_exists jq; then
        local temp_file
        temp_file=$(mktemp)
        if jq '.' "$output_file" > "$temp_file" 2>/dev/null; then
            mv "$temp_file" "$output_file"
        else
            rm -f "$temp_file"
            log_error "JSON raporu geçersiz: $output_file"
            return 1
        fi
    fi

    log_info "JSON raporu oluşturuldu: $output_file"
    echo -e "  ${GREEN}JSON raporu:${NC} $output_file"
}
