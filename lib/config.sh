#!/bin/bash
#
# Security Scanner - Yapılandırma Yönetimi
# config.sh - JSON ve Shell config loader
#

# JSON config'den değer oku (jq gerektirir)
get_json_value() {
    local key="$1"
    local default="${2:-}"
    local config_file="${CONFIG_DIR}/settings.json"

    if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
        local value
        value=$(jq -r "$key // empty" "$config_file" 2>/dev/null)
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

# JSON config'den array oku
get_json_array() {
    local key="$1"
    local config_file="${CONFIG_DIR}/settings.json"

    if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
        jq -r "$key[]? // empty" "$config_file" 2>/dev/null
    fi
}

# JSON config'den boolean oku
get_json_bool() {
    local key="$1"
    local default="${2:-false}"
    local config_file="${CONFIG_DIR}/settings.json"

    if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
        local value
        value=$(jq -r "$key // empty" "$config_file" 2>/dev/null)
        if [[ "$value" == "true" ]]; then
            echo "true"
        elif [[ "$value" == "false" ]]; then
            echo "false"
        else
            echo "$default"
        fi
    else
        echo "$default"
    fi
}

# Tüm JSON config'i yükle
load_json_config() {
    local config_file="${CONFIG_DIR}/settings.json"

    if [[ ! -f "$config_file" ]]; then
        log_debug "JSON config bulunamadı: $config_file"
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        log_debug "jq kurulu değil, JSON config yüklenemiyor"
        return 1
    fi

    # Scan ayarları
    SCAN_PARALLEL=$(get_json_bool '.scan.parallel' 'false')
    SCAN_THREADS=$(get_json_value '.scan.threads' '4')
    SCAN_TIMEOUT=$(get_json_value '.scan.timeout' '300')

    # Raporlama
    local json_format
    json_format=$(get_json_value '.reporting.format' '')
    [[ -n "$json_format" && "$REPORT_FORMAT" == "terminal" ]] && REPORT_FORMAT="$json_format"
    REPORT_RETENTION_DAYS=$(get_json_value '.reporting.retention_days' '90')

    # Bildirimler
    NOTIFY_DESKTOP=$(get_json_bool '.notifications.desktop' 'true')
    NOTIFY_EMAIL=$(get_json_bool '.notifications.email' 'false')

    # Filtreler
    local json_min_severity
    json_min_severity=$(get_json_value '.filters.min_severity' '')
    [[ -n "$json_min_severity" && "$MIN_SEVERITY" == "info" ]] && MIN_SEVERITY="$json_min_severity"

    # Interface
    LANGUAGE=$(get_json_value '.interface.language' 'tr')

    log_debug "JSON config yüklendi: $config_file"
    return 0
}

# Remediation JSON'dan çözüm bilgisi al
get_remediation() {
    local finding_title="$1"
    local category="$2"
    local remediation_dir="${TEMPLATES_DIR}/remediation"

    if [[ ! -d "$remediation_dir" ]]; then
        return 1
    fi

    # Kategori dosyasini kontrol et
    local category_file="${remediation_dir}/${category}.json"
    if [[ ! -f "$category_file" ]]; then
        category_file="${remediation_dir}/general.json"
    fi

    if [[ ! -f "$category_file" ]] || ! command -v jq &>/dev/null; then
        return 1
    fi

    # Başlığa göre eşleşen remediation bul
    local remediation_key
    remediation_key=$(jq -r --arg title "$finding_title" '
        to_entries[] |
        select(.value.match_pattern != null) |
        select($title | test(.value.match_pattern; "i")) |
        .key
    ' "$category_file" 2>/dev/null | head -1)

    if [[ -n "$remediation_key" ]]; then
        jq -r --arg key "$remediation_key" '.[$key]' "$category_file" 2>/dev/null
    fi
}

# Tüm remediation dosyalarını tara
find_remediation() {
    local finding_title="$1"
    local remediation_dir="${TEMPLATES_DIR}/remediation"

    if [[ ! -d "$remediation_dir" ]] || ! command -v jq &>/dev/null; then
        return 1
    fi

    for json_file in "$remediation_dir"/*.json; do
        [[ ! -f "$json_file" ]] && continue

        local result
        result=$(jq -r --arg title "$finding_title" '
            to_entries[] |
            select(.value.match_pattern != null) |
            select($title | test(.value.match_pattern; "i")) |
            .value
        ' "$json_file" 2>/dev/null | head -1)

        if [[ -n "$result" && "$result" != "null" ]]; then
            echo "$result"
            return 0
        fi
    done

    return 1
}
