#!/bin/bash
#
# Security Scanner - Çekirdek Modül
# core.sh - Modül yükleme, tarama orkestrasyon ve sonuç toplama
#

# === MODÜL YÖNETİMİ ===

# Tüm mevcut modülleri listele
list_modules() {
    local modules_dir="${SCANNER_DIR}/modules"

    if [[ ! -d "$modules_dir" ]]; then
        echo "Modül dizini bulunamadı: $modules_dir" >&2
        return 1
    fi

    echo -e "${BOLD}Mevcut Modüller:${NC}"
    echo ""

    local count=0
    for module in "$modules_dir"/*.sh; do
        [[ ! -f "$module" ]] && continue

        local name
        name=$(basename "$module" .sh)
        local description=""

        # Modül açıklamasını al (ilk yorum satırından)
        description=$(grep -m1 "^# Description:" "$module" 2>/dev/null | cut -d: -f2- | xargs)

        if [[ -z "$description" ]]; then
            description="(açıklama yok)"
        fi

        printf "  ${CYAN}%-25s${NC} %s\n" "$name" "$description"
        count=$((count + 1))
    done

    echo ""
    echo "Toplam: $count modül"
}

# Modül var mı kontrol et
module_exists() {
    local module_name="$1"
    local module_file="${SCANNER_DIR}/modules/${module_name}.sh"

    [[ -f "$module_file" ]]
}

# Tek modül yükle ve çalıştır
run_module() {
    local module_name="$1"
    local module_file="${SCANNER_DIR}/modules/${module_name}.sh"

    if [[ ! -f "$module_file" ]]; then
        log_error "Modül bulunamadı: $module_name"
        return 1
    fi

    if [[ ! -r "$module_file" ]]; then
        log_error "Modül okunamıyor: $module_name"
        return 1
    fi

    log_info "Modül çalıştırılıyor: $module_name"

    # Modülü source et (subshell kullanmadan - counter'ların çalışması için)
    source "$module_file"

    # scan fonksiyonunu çağır
    if declare -f "scan" &>/dev/null; then
        scan
        local exit_code=$?
        # scan fonksiyonunu temizle (bir sonraki modül için)
        unset -f scan
        log_info "Modül tamamlandı: $module_name (exit: $exit_code)"
        return $exit_code
    else
        log_error "Modülde scan fonksiyonu bulunamadı: $module_name"
        return 1
    fi
}

# Tüm modülleri çalıştır
run_all_modules() {
    local modules_dir="${SCANNER_DIR}/modules"
    local enabled_modules="${ENABLED_MODULES:-all}"
    local disabled_modules="${DISABLED_MODULES:-}"

    local total_modules=0
    local completed_modules=0
    local failed_modules=0

    # Modül listesini al (sıralı)
    local modules=()
    for module in "$modules_dir"/*.sh; do
        [[ -f "$module" ]] && modules+=("$module")
    done

    total_modules=${#modules[@]}

    if [[ $total_modules -eq 0 ]]; then
        log_warn "Çalıştırılacak modül bulunamadı"
        return 0
    fi

    log_info "Toplam $total_modules modül çalıştırılacak"

    for module in "${modules[@]}"; do
        local module_name
        module_name=$(basename "$module" .sh)

        # Disabled kontrolü
        if [[ -n "$disabled_modules" ]]; then
            if in_array "$module_name" ${disabled_modules//,/ }; then
                log_info "Modül devre dışı: $module_name"
                alert_skip "$module_name" "Yapılandırmada devre dışı"
                continue
            fi
        fi

        # Enabled kontrolü (all değilse)
        if [[ "$enabled_modules" != "all" ]]; then
            if ! in_array "$module_name" ${enabled_modules//,/ }; then
                log_debug "Modül etkin değil: $module_name"
                continue
            fi
        fi

        # Modülü çalıştır
        if run_module "$module_name"; then
            completed_modules=$((completed_modules + 1))
        else
            failed_modules=$((failed_modules + 1))
            log_error "Modül başarısız: $module_name"
        fi
    done

    log_info "Tarama tamamlandı: $completed_modules başarılı, $failed_modules başarısız"

    return $failed_modules
}

# Hızlı tarama (sadece kritik modüller)
run_quick_scan() {
    local quick_modules=(
        "01-system-info"
        "02-security-updates"
        "03-kernel-security"
        "05-network"
        "06-authentication"
    )

    log_info "Hızlı tarama başlatılıyor..."

    for module in "${quick_modules[@]}"; do
        if module_exists "$module"; then
            run_module "$module"
        else
            log_debug "Hızlı tarama modülü bulunamadı: $module"
        fi
    done
}

# Belirli modülleri çalıştır
run_specific_modules() {
    local modules_list="$1"
    local IFS=','

    for module in $modules_list; do
        module=$(echo "$module" | xargs)  # Boşlukları temizle

        if module_exists "$module"; then
            run_module "$module"
        else
            log_warn "Modül bulunamadı: $module"
            echo -e "${YELLOW}Uyarı: Modül bulunamadı: $module${NC}"
        fi
    done
}

# === TARAMA ORKESTRASYONu ===

# Tarama başlat
start_scan() {
    local scan_mode="${1:-full}"
    local start_time
    start_time=$(date +%s)

    # Tarama ID oluştur
    SCAN_ID=$(date +"%Y%m%d_%H%M%S")_$$
    export SCAN_ID

    log_info "Tarama başladı: $SCAN_ID (mod: $scan_mode)"

    # Header yazdır
    if [[ "${SILENT_MODE:-false}" != "true" ]]; then
        print_header "SECURITY SCANNER v2.0"
        echo -e "  ${DIM}Tarama ID:${NC}  $SCAN_ID"
        echo -e "  ${DIM}Mod:${NC}        $scan_mode"
        echo -e "  ${DIM}Tarih:${NC}      $(date '+%Y-%m-%d %H:%M:%S')"
        echo -e "  ${DIM}Kullanıcı:${NC}  $USER"
        echo -e "  ${DIM}Hostname:${NC}   $(hostname)"
        echo ""
    fi

    # Tarama moduna göre çalıştır
    case "$scan_mode" in
        quick)
            run_quick_scan
            ;;
        full)
            run_all_modules
            ;;
        specific)
            run_specific_modules "${SPECIFIC_MODULES:-}"
            ;;
        *)
            log_error "Bilinmeyen tarama modu: $scan_mode"
            return 1
            ;;
    esac

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    SCAN_DURATION=$duration
    export SCAN_DURATION

    log_info "Tarama süresi: $(format_duration $duration)"
}

# Sonuçları topla
collect_results() {
    # Risk skoru hesapla
    RISK_SCORE=$(calculate_risk_score "$CRITICAL_COUNT" "$HIGH_COUNT" "$MEDIUM_COUNT" "$LOW_COUNT")
    export RISK_SCORE

    # Toplam bulgu sayısı
    TOTAL_FINDINGS=$((CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT))
    export TOTAL_FINDINGS

    log_info "Sonuçlar: Critical=$CRITICAL_COUNT, High=$HIGH_COUNT, Medium=$MEDIUM_COUNT, Low=$LOW_COUNT"
    log_info "Risk skoru: $RISK_SCORE/100"
}

# Özet yazdır
print_summary() {
    print_section "ÖZET"

    local risk_color
    if [[ $RISK_SCORE -ge 70 ]]; then
        risk_color="${RED}${BOLD}"
    elif [[ $RISK_SCORE -ge 40 ]]; then
        risk_color="${YELLOW}"
    else
        risk_color="${GREEN}"
    fi

    echo ""
    echo -e "  ${BOLD}Risk Skoru:${NC} ${risk_color}$RISK_SCORE/100${NC}"
    echo ""
    echo -e "  ${RED}${BOLD}Kritik:${NC}  $CRITICAL_COUNT"
    echo -e "  ${RED}Yüksek:${NC}  $HIGH_COUNT"
    echo -e "  ${YELLOW}Orta:${NC}    $MEDIUM_COUNT"
    echo -e "  ${YELLOW}Düşük:${NC}   $LOW_COUNT"
    echo -e "  ${BLUE}Bilgi:${NC}   $INFO_COUNT"
    echo -e "  ${GREEN}Geçti:${NC}   $PASS_COUNT"
    echo ""
    echo -e "  ${DIM}Toplam bulgu:${NC} $TOTAL_FINDINGS"
    echo -e "  ${DIM}Tarama süresi:${NC} $(format_duration ${SCAN_DURATION:-0})"
    echo ""

    # Kritik uyarı
    if [[ $CRITICAL_COUNT -gt 0 ]]; then
        echo -e "${RED}${BOLD}[!] DİKKAT: $CRITICAL_COUNT kritik güvenlik açığı tespit edildi!${NC}"
        echo ""
    fi
}

# === BAĞIMLILIK KONTROLÜ ===

check_dependencies() {
    local missing=()
    local optional_missing=()

    # Zorunlu bağımlılıklar
    local required_deps=("jq" "ss" "stat" "find" "grep" "awk" "sed")

    for dep in "${required_deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done

    # Opsiyonel bağımlılıklar
    local optional_deps=("clamscan" "rkhunter" "chkrootkit" "lynis" "parallel")

    for dep in "${optional_deps[@]}"; do
        if ! command_exists "$dep"; then
            optional_missing+=("$dep")
        fi
    done

    # Sonuçları göster
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Eksik zorunlu bağımlılıklar:${NC}"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Kurulum: sudo apt install ${missing[*]}"
        return 1
    fi

    echo -e "${GREEN}Tüm zorunlu bağımlılıklar mevcut.${NC}"

    if [[ ${#optional_missing[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Opsiyonel araçlar (gelişmiş tarama için):${NC}"
        for dep in "${optional_missing[@]}"; do
            case "$dep" in
                clamscan) echo "  - clamav (malware tarama)" ;;
                rkhunter) echo "  - rkhunter (rootkit tarama)" ;;
                chkrootkit) echo "  - chkrootkit (rootkit tarama)" ;;
                lynis) echo "  - lynis (sistem denetimi)" ;;
                parallel) echo "  - parallel (paralel tarama)" ;;
            esac
        done
        echo ""
        echo "Kurulum: sudo apt install ${optional_missing[*]}"
    fi

    return 0
}

# Opsiyonel araçları kur
install_optional_tools() {
    echo "Opsiyonel güvenlik araçları kuruluyor..."

    local tools=("clamav" "rkhunter" "chkrootkit" "lynis" "parallel")

    if is_root; then
        apt update
        apt install -y "${tools[@]}"
    else
        echo "Root yetkisi gerekli. Şu komutu çalıştırın:"
        echo "sudo apt install ${tools[*]}"
    fi
}

# === YAPILANIŞ YÜKLEME ===

load_config() {
    local config_file="${CONFIG_FILE:-${SCANNER_DIR}/config/scanner.conf}"

    if [[ -f "$config_file" ]]; then
        log_debug "Yapılandırma yükleniyor: $config_file"
        source "$config_file"
    else
        log_warn "Yapılandırma dosyası bulunamadı: $config_file"
    fi
}

# Varsayılan değerleri ayarla
set_defaults() {
    : "${SCAN_PARALLEL:=false}"
    : "${SCAN_THREADS:=4}"
    : "${SCAN_TIMEOUT:=300}"
    : "${ENABLED_MODULES:=all}"
    : "${DISABLED_MODULES:=}"
    : "${REPORT_FORMAT:=terminal}"
    : "${REPORT_RETENTION_DAYS:=90}"
    : "${NOTIFY_DESKTOP:=true}"
    : "${NOTIFY_EMAIL:=false}"
    : "${FIM_ENABLED:=true}"
    : "${MIN_SEVERITY:=low}"
}
