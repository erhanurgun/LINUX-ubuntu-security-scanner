#!/bin/bash
#
# Security Scanner v0.3.2 - Rapor Yönetimi Modülü
# management.sh - Rapor oluşturma, listeleme, temizleme ve bildirim
#

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

cleanup_old_reports() {
    local retention_days="${REPORT_RETENTION_DAYS:-90}"

    log_info "Eski raporlar temizleniyor (>${retention_days} gün)"

    # Tarihe göre organize edilmiş raporlar
    if [[ -d "${REPORT_BASE:-$REPORT_DIR}" ]]; then
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
