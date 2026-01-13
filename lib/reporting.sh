#!/bin/bash
#
# Security Scanner v0.1.0 - Raporlama Modülü
# reporting.sh - Terminal, JSON ve İnteraktif HTML rapor oluşturma
#
# Yeni HTML özellikleri:
#   - Tab-based navigation (severity filtreleme)
#   - Tablo formatında bulgular (sıralanabilir)
#   - Copy-to-clipboard terminal komutları
#   - Adım adım çözüm rehberleri (remediation database)
#   - Arama ve filtreleme
#

# === YARDIMCI FONKSİYONLAR ===

# HTML special karakterleri escape et
html_escape() {
    local text="$1"
    text="${text//&/&amp;}"
    text="${text//</&lt;}"
    text="${text//>/&gt;}"
    text="${text//\"/&quot;}"
    text="${text//\'/&#39;}"
    echo "$text"
}

# Severity'yi Türkçe'ye çevir
severity_to_turkish() {
    case "$1" in
        critical) echo "KRİTİK" ;;
        high) echo "YÜKSEK" ;;
        medium) echo "ORTA" ;;
        low) echo "DÜŞÜK" ;;
        info) echo "BİLGİ" ;;
        pass) echo "GEÇTİ" ;;
        *) echo "$1" ;;
    esac
}

# Category'yi Türkçe'ye çevir
category_to_turkish() {
    case "$1" in
        system|system-info) echo "Sistem" ;;
        security-updates) echo "Güncellemeler" ;;
        kernel|kernel-security) echo "Kernel" ;;
        filesystem) echo "Dosya Sistemi" ;;
        network) echo "Ağ" ;;
        authentication) echo "Kimlik Doğrulama" ;;
        services) echo "Servisler" ;;
        permissions) echo "İzinler" ;;
        malware) echo "Zararlı Yazılım" ;;
        fim) echo "Dosya Bütünlüğü" ;;
        gnome|gnome-extensions) echo "GNOME" ;;
        containers|docker) echo "Konteynerler" ;;
        compliance) echo "Uyumluluk" ;;
        general) echo "Genel" ;;
        *) echo "$1" ;;
    esac
}

# === REMEDIATION LOOKUP ===

# Bulguya uygun remediation bilgisini bul
lookup_remediation() {
    local title="$1"
    local category="$2"
    local severity="$3"

    # Remediation JSON dosyalarını kontrol et
    local remediation_dir="${TEMPLATES_DIR:-${SCANNER_DIR}/templates}/remediation"

    if [[ ! -d "$remediation_dir" ]]; then
        return 1
    fi

    # Öncelikle kategoriye göre dosyayı seç
    local json_file=""
    case "$category" in
        authentication) json_file="$remediation_dir/authentication.json" ;;
        network) json_file="$remediation_dir/network.json" ;;
        filesystem) json_file="$remediation_dir/filesystem.json" ;;
        services) json_file="$remediation_dir/services.json" ;;
        permissions) json_file="$remediation_dir/permissions.json" ;;
        *) json_file="$remediation_dir/general.json" ;;
    esac

    # jq varsa JSON'dan ara
    if command_exists jq && [[ -f "$json_file" ]]; then
        # Her remediation entry'sinin match_pattern'i ile karşılaştır
        local keys
        keys=$(jq -r 'keys[]' "$json_file" 2>/dev/null)

        for key in $keys; do
            local pattern
            pattern=$(jq -r ".[\"$key\"].match_pattern // \"\"" "$json_file" 2>/dev/null)

            if [[ -n "$pattern" ]] && echo "$title" | grep -qiE "$pattern"; then
                # Eşleşen remediation'ı döndür
                jq -c ".[\"$key\"]" "$json_file" 2>/dev/null
                return 0
            fi
        done
    fi

    # Eşleşen bulunamadı - tüm JSON dosyalarında ara
    for json_file in "$remediation_dir"/*.json; do
        [[ -f "$json_file" ]] || continue

        if command_exists jq; then
            local keys
            keys=$(jq -r 'keys[]' "$json_file" 2>/dev/null)

            for key in $keys; do
                local pattern
                pattern=$(jq -r ".[\"$key\"].match_pattern // \"\"" "$json_file" 2>/dev/null)

                if [[ -n "$pattern" ]] && echo "$title" | grep -qiE "$pattern"; then
                    jq -c ".[\"$key\"]" "$json_file" 2>/dev/null
                    return 0
                fi
            done
        fi
    done

    return 1
}

# SVG ikonları (Heroicons - MIT License)
svg_icon_warning() {
    echo '<svg class="w-5 h-5 inline-block" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/></svg>'
}

svg_icon_clipboard() {
    echo '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"/></svg>'
}

svg_icon_info() {
    echo '<svg class="w-5 h-5 inline-block" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>'
}

svg_icon_lightbulb() {
    echo '<svg class="w-5 h-5 inline-block" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/></svg>'
}

svg_icon_check() {
    echo '<svg class="w-5 h-5 inline-block" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>'
}

svg_icon_computer() {
    echo '<svg class="w-5 h-5 inline-block" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/></svg>'
}

svg_icon_calendar() {
    echo '<svg class="w-5 h-5 inline-block" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>'
}

svg_icon_clock() {
    echo '<svg class="w-5 h-5 inline-block" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>'
}

svg_icon_key() {
    echo '<svg class="w-5 h-5 inline-block" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z"/></svg>'
}

svg_icon_search() {
    echo '<svg class="w-5 h-5 inline-block" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/></svg>'
}

# Remediation panel HTML'i oluştur
generate_remediation_panel() {
    local finding_id="$1"
    local remediation_json="$2"

    if [[ -z "$remediation_json" || "$remediation_json" == "null" ]]; then
        return
    fi

    local rem_title impact steps_count verification_cmd verification_expected

    if command_exists jq; then
        rem_title=$(echo "$remediation_json" | jq -r '.title // ""' 2>/dev/null)
        impact=$(echo "$remediation_json" | jq -r '.impact // ""' 2>/dev/null)
        steps_count=$(echo "$remediation_json" | jq -r '.steps | length' 2>/dev/null)
        verification_cmd=$(echo "$remediation_json" | jq -r '.verification.command // ""' 2>/dev/null)
        verification_expected=$(echo "$remediation_json" | jq -r '.verification.expected // ""' 2>/dev/null)
    else
        return
    fi

    cat <<EOF
                <div id="remediation-${finding_id}" class="remediation-panel hidden bg-gray-800/50 rounded-lg p-6 mt-4 border border-gray-700">
                    <div class="panel-content">
EOF

    # Impact
    if [[ -n "$impact" && "$impact" != "null" ]]; then
        cat <<EOF
                        <div class="flex items-start gap-3 p-4 bg-orange-500/10 border border-orange-500/30 rounded-lg mb-4">
                            <span class="text-orange-400 flex-shrink-0">$(svg_icon_warning)</span>
                            <span class="text-orange-300 text-sm">$(html_escape "$impact")</span>
                        </div>
EOF
    fi

    # Steps
    if [[ "$steps_count" -gt 0 ]]; then
        echo "                        <div class=\"space-y-4\">"
        echo "                            <h4 class=\"text-lg font-semibold text-gray-200\">Çözüm Adımları</h4>"

        local i
        for ((i=0; i<steps_count; i++)); do
            local instruction command note tip explanation
            instruction=$(echo "$remediation_json" | jq -r ".steps[$i].instruction // \"\"" 2>/dev/null)
            command=$(echo "$remediation_json" | jq -r ".steps[$i].command // \"\"" 2>/dev/null)
            note=$(echo "$remediation_json" | jq -r ".steps[$i].note // \"\"" 2>/dev/null)
            tip=$(echo "$remediation_json" | jq -r ".steps[$i].tip // \"\"" 2>/dev/null)
            explanation=$(echo "$remediation_json" | jq -r ".steps[$i].explanation // \"\"" 2>/dev/null)

            local step_num=$((i+1))

            cat <<EOF
                            <div class="flex gap-4">
                                <div class="flex-shrink-0 w-8 h-8 bg-blue-500 text-white rounded-full flex items-center justify-center font-bold text-sm">${step_num}</div>
                                <div class="flex-1">
                                    <p class="text-gray-200 font-medium">$(html_escape "$instruction")</p>
EOF

            # Command block
            if [[ -n "$command" && "$command" != "null" ]]; then
                local cmd_id="cmd-${finding_id}-${i}"
                cat <<EOF
                                    <div class="flex items-center bg-gray-900 border border-gray-700 rounded-md overflow-hidden my-2">
                                        <code id="${cmd_id}" class="flex-1 px-4 py-2 text-blue-400 font-mono text-sm overflow-x-auto">$(html_escape "$command")</code>
                                        <button class="copy-btn px-3 py-2 bg-gray-800 hover:bg-blue-600 text-gray-400 hover:text-white border-l border-gray-700 transition-colors" data-target="${cmd_id}" title="Kopyala">
                                            $(svg_icon_clipboard)
                                        </button>
                                    </div>
EOF
            fi

            # Note, Tip, Explanation
            if [[ -n "$note" && "$note" != "null" ]]; then
                echo "                                    <div class=\"flex items-start gap-2 text-gray-400 text-sm mt-2\"><span class=\"text-blue-400\">$(svg_icon_info)</span> $(html_escape "$note")</div>"
            fi
            if [[ -n "$tip" && "$tip" != "null" ]]; then
                echo "                                    <div class=\"flex items-start gap-2 text-yellow-400 text-sm mt-2\"><span>$(svg_icon_lightbulb)</span> $(html_escape "$tip")</div>"
            fi
            if [[ -n "$explanation" && "$explanation" != "null" ]]; then
                echo "                                    <p class=\"text-gray-500 text-sm mt-2 italic\">$(html_escape "$explanation")</p>"
            fi

            echo "                                </div>"
            echo "                            </div>"
        done

        echo "                        </div>"
    fi

    # Verification
    if [[ -n "$verification_cmd" && "$verification_cmd" != "null" ]]; then
        local verify_id="verify-${finding_id}"
        cat <<EOF
                        <div class="mt-6 pt-6 border-t border-gray-700">
                            <h4 class="flex items-center gap-2 text-green-400 font-semibold mb-3">$(svg_icon_check) Doğrulama</h4>
                            <div class="flex items-center bg-gray-900 border border-gray-700 rounded-md overflow-hidden">
                                <code id="${verify_id}" class="flex-1 px-4 py-2 text-blue-400 font-mono text-sm overflow-x-auto">$(html_escape "$verification_cmd")</code>
                                <button class="copy-btn px-3 py-2 bg-gray-800 hover:bg-blue-600 text-gray-400 hover:text-white border-l border-gray-700 transition-colors" data-target="${verify_id}" title="Kopyala">
                                    $(svg_icon_clipboard)
                                </button>
                            </div>
EOF
        if [[ -n "$verification_expected" && "$verification_expected" != "null" ]]; then
            echo "                            <p class=\"text-gray-500 text-sm mt-2\">Beklenen: $(html_escape "$verification_expected")</p>"
        fi
        echo "                        </div>"
    fi

    cat <<EOF
                    </div>
                </div>
EOF
}

# === CSS INLINE ===

inline_css() {
    local css_file="${TEMPLATES_DIR:-${SCANNER_DIR}/templates}/css/styles.css"

    if [[ -f "$css_file" ]]; then
        cat "$css_file"
    else
        # Fallback minimal CSS
        cat <<'FALLBACKCSS'
:root {
    --critical: #dc3545;
    --high: #e74c3c;
    --medium: #f39c12;
    --low: #3498db;
    --info: #6c757d;
    --pass: #28a745;
    --bg: #1a1a2e;
    --card: #16213e;
    --text: #eaeaea;
    --border: #0f3460;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: system-ui, sans-serif; background: var(--bg); color: var(--text); padding: 2rem; }
.container { max-width: 1400px; margin: 0 auto; }
.badge { padding: 0.25rem 0.5rem; border-radius: 4px; font-size: 0.75rem; font-weight: bold; }
.badge.critical { background: var(--critical); }
.badge.high { background: var(--high); }
.badge.medium { background: var(--medium); color: #000; }
.badge.low { background: var(--low); }
.badge.info { background: var(--info); }
FALLBACKCSS
    fi
}

# === JS INLINE ===

inline_js() {
    local js_file="${TEMPLATES_DIR:-${SCANNER_DIR}/templates}/js/report.js"

    if [[ -f "$js_file" ]]; then
        cat "$js_file"
    else
        # Fallback minimal JS
        cat <<'FALLBACKJS'
document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('.copy-btn').forEach(function(btn) {
        btn.addEventListener('click', function() {
            var target = document.getElementById(btn.dataset.target);
            if (target) {
                navigator.clipboard.writeText(target.textContent.trim());
            }
        });
    });
});
FALLBACKJS
    fi
}

# === JSON RAPORLAMA ===

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

# === HTML RAPORLAMA (TailwindCSS) ===

generate_html_report() {
    local output_file="${1:-${REPORT_DIR_TODAY:-$REPORT_DIR}/html/scan_${SCAN_ID}.html}"

    mkdir -p "$(dirname "$output_file")"

    # Risk seviyesine göre renk ve class
    local risk_color_class risk_level risk_border_class
    if [[ ${RISK_SCORE:-0} -ge 70 ]]; then
        risk_color_class="text-red-500"
        risk_border_class="border-red-500"
        risk_level="Kritik"
    elif [[ ${RISK_SCORE:-0} -ge 40 ]]; then
        risk_color_class="text-yellow-500"
        risk_border_class="border-yellow-500"
        risk_level="Orta"
    else
        risk_color_class="text-green-500"
        risk_border_class="border-green-500"
        risk_level="Düşük"
    fi

    # HTML başlangıcı - TailwindCSS CDN
    cat > "$output_file" <<'HTMLHEAD'
<!DOCTYPE html>
<html lang="tr" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Security Scanner Raporu</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {
                    colors: {
                        critical: '#dc3545',
                        high: '#e74c3c',
                        medium: '#f39c12',
                        low: '#3498db',
                        info: '#6c757d',
                        pass: '#28a745'
                    }
                }
            }
        }
    </script>
    <style>
        /* Fallback minimal styles for offline use */
        .hidden { display: none !important; }
        .remediation-panel.show { display: block !important; }
        /* Print styles */
        @media print {
            .no-print { display: none !important; }
            .remediation-panel { display: block !important; }
        }
    </style>
</head>
<body class="bg-gray-900 text-gray-100 min-h-screen">
<div class="max-w-7xl mx-auto px-4 py-8">
HTMLHEAD

    # Header
    cat >> "$output_file" <<EOF
    <!-- Header -->
    <header class="bg-gray-800 rounded-lg p-6 mb-6 border border-gray-700">
        <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            <h1 class="text-2xl font-bold text-white">Security Scanner Raporu</h1>
            <div class="flex flex-wrap gap-4 text-sm text-gray-400">
                <span class="flex items-center gap-2">
                    $(svg_icon_computer)
                    $(hostname)
                </span>
                <span class="flex items-center gap-2">
                    $(svg_icon_calendar)
                    $(date '+%d.%m.%Y %H:%M')
                </span>
                <span class="flex items-center gap-2">
                    $(svg_icon_clock)
                    $(format_duration ${SCAN_DURATION:-0})
                </span>
                <span class="flex items-center gap-2">
                    $(svg_icon_key)
                    ID: ${SCAN_ID:-unknown}
                </span>
            </div>
        </div>
    </header>

    <!-- Summary Cards -->
    <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 mb-8">
        <!-- Risk Score Card -->
        <div class="bg-gray-800 rounded-lg p-4 border border-gray-700 col-span-2 md:col-span-1 flex flex-col items-center justify-center">
            <div class="w-20 h-20 rounded-full border-4 ${risk_border_class} flex flex-col items-center justify-center mb-2">
                <span class="text-2xl font-bold ${risk_color_class}">${RISK_SCORE:-0}</span>
                <span class="text-xs text-gray-500">Risk</span>
            </div>
            <span class="text-sm font-medium ${risk_color_class}">${risk_level} Risk</span>
        </div>

        <!-- Severity Cards -->
        <div class="bg-gray-800 rounded-lg p-4 border-l-4 border-red-500 text-center">
            <div class="text-3xl font-bold text-red-500">${CRITICAL_COUNT:-0}</div>
            <div class="text-xs text-gray-500 uppercase tracking-wide mt-1">Kritik</div>
        </div>
        <div class="bg-gray-800 rounded-lg p-4 border-l-4 border-orange-500 text-center">
            <div class="text-3xl font-bold text-orange-500">${HIGH_COUNT:-0}</div>
            <div class="text-xs text-gray-500 uppercase tracking-wide mt-1">Yüksek</div>
        </div>
        <div class="bg-gray-800 rounded-lg p-4 border-l-4 border-yellow-500 text-center">
            <div class="text-3xl font-bold text-yellow-500">${MEDIUM_COUNT:-0}</div>
            <div class="text-xs text-gray-500 uppercase tracking-wide mt-1">Orta</div>
        </div>
        <div class="bg-gray-800 rounded-lg p-4 border-l-4 border-blue-500 text-center">
            <div class="text-3xl font-bold text-blue-500">${LOW_COUNT:-0}</div>
            <div class="text-xs text-gray-500 uppercase tracking-wide mt-1">Düşük</div>
        </div>
        <div class="bg-gray-800 rounded-lg p-4 border-l-4 border-green-500 text-center">
            <div class="text-3xl font-bold text-green-500">${PASS_COUNT:-0}</div>
            <div class="text-xs text-gray-500 uppercase tracking-wide mt-1">Geçti</div>
        </div>
    </div>

    <!-- Findings Section -->
    <section class="bg-gray-800 rounded-lg border border-gray-700 mb-8">
        <div class="flex flex-col md:flex-row md:items-center md:justify-between p-4 border-b border-gray-700">
            <h2 class="text-xl font-semibold text-white mb-2 md:mb-0">Bulgular</h2>
            <div class="flex gap-2 no-print">
                <button class="px-3 py-1 text-sm bg-gray-700 hover:bg-gray-600 rounded text-gray-300 transition-colors" onclick="SecurityReport.expandAll()">Tümü Aç</button>
                <button class="px-3 py-1 text-sm bg-gray-700 hover:bg-gray-600 rounded text-gray-300 transition-colors" onclick="SecurityReport.collapseAll()">Tümü Kapat</button>
            </div>
        </div>

        <!-- Tabs -->
        <div class="flex flex-wrap gap-1 p-4 border-b border-gray-700 no-print">
            <button class="tab px-3 py-2 text-sm rounded bg-blue-600 text-white" data-severity="all">
                Tümü <span class="badge ml-1 px-2 py-0.5 bg-blue-500 rounded-full text-xs">${TOTAL_FINDINGS:-0}</span>
            </button>
            <button class="tab px-3 py-2 text-sm rounded bg-gray-700 hover:bg-gray-600 text-gray-300" data-severity="critical">
                Kritik <span class="badge ml-1 px-2 py-0.5 bg-gray-600 rounded-full text-xs">${CRITICAL_COUNT:-0}</span>
            </button>
            <button class="tab px-3 py-2 text-sm rounded bg-gray-700 hover:bg-gray-600 text-gray-300" data-severity="high">
                Yüksek <span class="badge ml-1 px-2 py-0.5 bg-gray-600 rounded-full text-xs">${HIGH_COUNT:-0}</span>
            </button>
            <button class="tab px-3 py-2 text-sm rounded bg-gray-700 hover:bg-gray-600 text-gray-300" data-severity="medium">
                Orta <span class="badge ml-1 px-2 py-0.5 bg-gray-600 rounded-full text-xs">${MEDIUM_COUNT:-0}</span>
            </button>
            <button class="tab px-3 py-2 text-sm rounded bg-gray-700 hover:bg-gray-600 text-gray-300" data-severity="low">
                Düşük <span class="badge ml-1 px-2 py-0.5 bg-gray-600 rounded-full text-xs">${LOW_COUNT:-0}</span>
            </button>
            <button class="tab px-3 py-2 text-sm rounded bg-gray-700 hover:bg-gray-600 text-gray-300" data-severity="info">
                Bilgi <span class="badge ml-1 px-2 py-0.5 bg-gray-600 rounded-full text-xs">${INFO_COUNT:-0}</span>
            </button>
        </div>

        <!-- Search and Filter -->
        <div class="flex flex-col md:flex-row gap-4 p-4 border-b border-gray-700 no-print">
            <div class="flex-1 relative">
                <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500">$(svg_icon_search)</span>
                <input type="text" id="search-findings" placeholder="Bulgu ara..." class="w-full pl-10 pr-4 py-2 bg-gray-900 border border-gray-700 rounded-lg text-gray-200 placeholder-gray-500 focus:outline-none focus:border-blue-500">
            </div>
            <select id="category-filter" class="px-4 py-2 bg-gray-900 border border-gray-700 rounded-lg text-gray-200 focus:outline-none focus:border-blue-500">
                <option value="">Tüm Kategoriler</option>
                <option value="system">Sistem</option>
                <option value="kernel">Kernel</option>
                <option value="network">Ağ</option>
                <option value="authentication">Kimlik Doğrulama</option>
                <option value="services">Servisler</option>
                <option value="permissions">İzinler</option>
                <option value="filesystem">Dosya Sistemi</option>
                <option value="malware">Zararlı Yazılım</option>
                <option value="containers">Konteynerler</option>
                <option value="compliance">Uyumluluk</option>
            </select>
        </div>

        <!-- Findings Table -->
        <div class="overflow-x-auto">
            <table class="findings-table w-full">
                <thead class="bg-gray-900">
                    <tr>
                        <th data-sort="severity" class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider cursor-pointer hover:text-white">Seviye</th>
                        <th data-sort="category" class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider cursor-pointer hover:text-white">Kategori</th>
                        <th data-sort="title" class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider cursor-pointer hover:text-white">Bulgu</th>
                        <th class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">İşlem</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-700">
EOF

    # Findings'leri tabloya ekle
    local finding_idx=0
    for finding in "${FINDINGS[@]}"; do
        local severity title description remediation category

        if command_exists jq; then
            severity=$(echo "$finding" | jq -r '.severity' 2>/dev/null | tr '[:upper:]' '[:lower:]')
            title=$(echo "$finding" | jq -r '.title' 2>/dev/null)
            description=$(echo "$finding" | jq -r '.description // ""' 2>/dev/null)
            remediation=$(echo "$finding" | jq -r '.remediation // ""' 2>/dev/null)
            category=$(echo "$finding" | jq -r '.category // "general"' 2>/dev/null)
        else
            severity="info"
            title="Bulgu"
            description=""
            remediation=""
            category="general"
        fi

        # Severity'yi normalize et
        case "$severity" in
            kritik|critical) severity="critical" ;;
            yüksek|yuksek|high) severity="high" ;;
            orta|medium) severity="medium" ;;
            düşük|dusuk|low) severity="low" ;;
            bilgi|info) severity="info" ;;
            geçti|gecti|pass) severity="pass" ;;
        esac

        # Pass bulgularını atla (opsiyonel)
        [[ "$severity" == "pass" ]] && continue

        local finding_id="finding-${finding_idx}"
        local severity_tr
        severity_tr=$(severity_to_turkish "$severity")
        local category_tr
        category_tr=$(category_to_turkish "$category")

        # Severity badge class
        local badge_class
        case "$severity" in
            critical) badge_class="bg-red-500/20 text-red-400 border border-red-500/30" ;;
            high) badge_class="bg-orange-500/20 text-orange-400 border border-orange-500/30" ;;
            medium) badge_class="bg-yellow-500/20 text-yellow-400 border border-yellow-500/30" ;;
            low) badge_class="bg-blue-500/20 text-blue-400 border border-blue-500/30" ;;
            info) badge_class="bg-gray-500/20 text-gray-400 border border-gray-500/30" ;;
            *) badge_class="bg-gray-500/20 text-gray-400 border border-gray-500/30" ;;
        esac

        # Remediation bilgisini ara
        local remediation_data
        remediation_data=$(lookup_remediation "$title" "$category" "$severity")

        local has_remediation="false"
        [[ -n "$remediation_data" ]] && has_remediation="true"

        cat >> "$output_file" <<EOF
                    <tr class="finding-row hover:bg-gray-700/50" data-severity="${severity}" data-category="${category}">
                        <td class="px-4 py-3">
                            <span class="inline-block px-2 py-1 text-xs font-semibold uppercase rounded ${badge_class}">${severity_tr}</span>
                        </td>
                        <td class="px-4 py-3 text-gray-400 text-sm">${category_tr}</td>
                        <td class="px-4 py-3">
                            <div class="font-medium text-gray-200">$(html_escape "$title")</div>
EOF

        if [[ -n "$description" && "$description" != "null" ]]; then
            echo "                            <div class=\"text-sm text-gray-500 mt-1\">$(html_escape "$description")</div>" >> "$output_file"
        fi

        cat >> "$output_file" <<EOF
                        </td>
                        <td class="px-4 py-3">
EOF

        if [[ "$has_remediation" == "true" ]]; then
            cat >> "$output_file" <<EOF
                            <button class="btn-expand inline-flex items-center gap-1 px-3 py-1 text-sm bg-gray-700 hover:bg-blue-600 rounded text-gray-300 hover:text-white transition-colors" data-target="remediation-${finding_id}">
                                <span class="btn-text">Çözüm</span>
                                <span class="arrow text-xs">▼</span>
                            </button>
EOF
        else
            echo "                            <span class=\"text-gray-600\">-</span>" >> "$output_file"
        fi

        cat >> "$output_file" <<EOF
                        </td>
                    </tr>
EOF

        # Remediation panel (ayrı satırda)
        if [[ "$has_remediation" == "true" ]]; then
            cat >> "$output_file" <<EOF
                    <tr class="remediation-row" data-severity="${severity}" data-category="${category}">
                        <td colspan="4" class="px-4 py-0">
EOF
            generate_remediation_panel "$finding_id" "$remediation_data" >> "$output_file"
            cat >> "$output_file" <<EOF
                        </td>
                    </tr>
EOF
        fi

        ((finding_idx++))
    done

    # Tablo ve section kapanışı + System Info + Footer
    cat >> "$output_file" <<EOF
                </tbody>
            </table>
        </div>
    </section>

    <!-- System Info -->
    <section class="bg-gray-800 rounded-lg border border-gray-700 p-6 mb-8">
        <h2 class="text-lg font-semibold text-white mb-4">Sistem Bilgileri</h2>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div>
                <span class="block text-xs text-gray-500 uppercase tracking-wide mb-1">İşletim Sistemi</span>
                <span class="text-gray-200">$(grep -oP '(?<=^PRETTY_NAME=").*(?="$)' /etc/os-release 2>/dev/null || echo 'Ubuntu')</span>
            </div>
            <div>
                <span class="block text-xs text-gray-500 uppercase tracking-wide mb-1">Kernel</span>
                <span class="text-gray-200">$(uname -r)</span>
            </div>
            <div>
                <span class="block text-xs text-gray-500 uppercase tracking-wide mb-1">Mimari</span>
                <span class="text-gray-200">$(uname -m)</span>
            </div>
            <div>
                <span class="block text-xs text-gray-500 uppercase tracking-wide mb-1">Hostname</span>
                <span class="text-gray-200">$(hostname)</span>
            </div>
        </div>
    </section>

    <!-- Footer -->
    <footer class="border-t border-gray-700 pt-6">
        <div class="flex flex-col md:flex-row md:justify-between md:items-center gap-4">
            <div class="text-center md:text-left">
                <p class="text-gray-400 text-sm font-medium">Security Scanner v${SCANNER_VERSION:-0.1.0}</p>
                <p class="text-gray-600 text-xs mt-1">Tarama ID: ${SCAN_ID:-unknown} | $(date '+%d.%m.%Y %H:%M')</p>
            </div>
            <div class="text-center md:text-right">
                <p class="text-gray-500 text-xs">Bu rapor otomatik olarak oluşturulmuştur.</p>
                <p class="text-gray-600 text-xs mt-1">Çözüm adımları uygulanmadan önce yedek alınması önerilir.</p>
            </div>
        </div>
    </footer>
</div>

<script>
EOF

    # JavaScript inline
    inline_js >> "$output_file"

    cat >> "$output_file" <<'HTMLFOOT'
</script>
</body>
</html>
HTMLFOOT

    log_info "HTML raporu oluşturuldu: $output_file"
    echo -e "  ${GREEN}HTML raporu:${NC} $output_file"
}

# === ANA RAPORLAMA FONKSİYONU ===

generate_reports() {
    local formats="${REPORT_FORMAT:-terminal}"

    print_section "RAPORLAR"
    echo ""

    # Her format için rapor oluştur
    local IFS=','
    for format in $formats; do
        format=$(echo "$format" | xargs)  # Trim

        case "$format" in
            json)
                generate_json_report
                ;;
            html)
                generate_html_report
                ;;
            terminal)
                # Terminal zaten gösteriliyor
                ;;
            *)
                log_warn "Bilinmeyen rapor formatı: $format"
                ;;
        esac
    done

    echo ""
}

# === ESKİ RAPORLARI TEMİZLE ===

cleanup_old_reports() {
    local retention_days="${REPORT_RETENTION_DAYS:-90}"

    log_info "Eski raporlar temizleniyor (>${retention_days} gün)"

    # Tarihe göre organize edilmiş raporlar
    if [[ -d "${REPORT_BASE:-$REPORT_DIR}" ]]; then
        # X günden eski tarihleri sil
        local cutoff_date
        cutoff_date=$(date -d "-${retention_days} days" +%Y-%m-%d 2>/dev/null)

        if [[ -n "$cutoff_date" ]]; then
            find "${REPORT_BASE:-$REPORT_DIR}" -maxdepth 1 -type d -name "20*" | while read -r dir; do
                local dir_date
                dir_date=$(basename "$dir")
                if [[ "$dir_date" < "$cutoff_date" ]]; then
                    rm -rf "$dir"
                    log_info "Silindi: $dir"
                fi
            done
        fi
    fi

    # Eski formattaki raporları da temizle
    for dir in json html; do
        find "${REPORT_DIR}/${dir}" -type f -mtime +"$retention_days" -delete 2>/dev/null
    done

    # Eski logları temizle
    local log_retention="${LOG_RETENTION_DAYS:-30}"
    find "${LOG_DIR}" -type f -name "*.log" -mtime +"$log_retention" -delete 2>/dev/null
}

# === RAPOR LİSTELE ===

list_reports() {
    echo -e "${BOLD}Mevcut Raporlar:${NC}"
    echo ""

    local report_base="${REPORT_BASE:-$REPORT_DIR}"

    # Tarihe göre organize edilmiş raporlar
    if [[ -d "$report_base" ]]; then
        local dates
        dates=$(find "$report_base" -maxdepth 1 -type d -name "20*" | sort -r | head -10)

        if [[ -n "$dates" ]]; then
            echo -e "${CYAN}Son 10 tarama tarihi:${NC}"
            for date_dir in $dates; do
                local date_name
                date_name=$(basename "$date_dir")
                local html_count json_count
                html_count=$(find "$date_dir/html" -type f 2>/dev/null | wc -l)
                json_count=$(find "$date_dir/json" -type f 2>/dev/null | wc -l)
                echo "  $date_name: HTML($html_count) JSON($json_count)"
            done
            echo ""
        fi
    fi

    # Toplam istatistik
    for type in json html; do
        local dir="${report_base}"
        local count
        count=$(find "$dir" -type f -name "*.${type}" 2>/dev/null | wc -l)
        echo -e "  ${CYAN}${type^^}:${NC} $count rapor"
    done
}

# === BİLDİRİM GÖNDER ===

send_scan_notification() {
    local title="Security Scanner Tamamlandı"
    local message

    if [[ ${CRITICAL_COUNT:-0} -gt 0 ]]; then
        message="${CRITICAL_COUNT} kritik, ${HIGH_COUNT} yüksek seviye bulgu!"
        send_notification "$title" "$message" "critical"
    elif [[ ${HIGH_COUNT:-0} -gt 0 ]]; then
        message="${HIGH_COUNT} yüksek seviye bulgu tespit edildi"
        send_notification "$title" "$message" "normal"
    else
        message="Tarama tamamlandı. Risk skoru: ${RISK_SCORE:-0}/100"
        send_notification "$title" "$message" "low"
    fi
}
