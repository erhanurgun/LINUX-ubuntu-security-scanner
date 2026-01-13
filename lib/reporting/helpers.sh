#!/bin/bash
#
# Security Scanner v0.3.5 - Raporlama Yardımcı Fonksiyonları
# helpers.sh - HTML escape, çeviri ve SVG ikonlar
#

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

# Bulguya uygun remediation bilgisini bul
lookup_remediation() {
    local title="$1"
    local category="$2"
    local severity="$3"

    local remediation_dir="${TEMPLATES_DIR:-${SCANNER_DIR}/templates}/remediation"
    [[ ! -d "$remediation_dir" ]] && return 1

    # Kategoriye göre dosyayı seç
    local json_file=""
    case "$category" in
        authentication) json_file="$remediation_dir/authentication.json" ;;
        network) json_file="$remediation_dir/network.json" ;;
        filesystem) json_file="$remediation_dir/filesystem.json" ;;
        services) json_file="$remediation_dir/services.json" ;;
        permissions) json_file="$remediation_dir/permissions.json" ;;
        malware) json_file="$remediation_dir/malware.json" ;;
        gnome|gnome-extensions) json_file="$remediation_dir/gnome.json" ;;
        containers|docker) json_file="$remediation_dir/containers.json" ;;
        compliance) json_file="$remediation_dir/compliance.json" ;;
        fim) json_file="$remediation_dir/fim.json" ;;
        system|system-info) json_file="$remediation_dir/system.json" ;;
        kernel|kernel-security) json_file="$remediation_dir/kernel-security.json" ;;
        security-updates) json_file="$remediation_dir/security-updates.json" ;;
        *) json_file="$remediation_dir/general.json" ;;
    esac

    # jq varsa JSON'dan ara
    if command_exists jq && [[ -f "$json_file" ]]; then
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
