#!/bin/bash
#
# Security Scanner - Yardımcı Fonksiyonlar
# utils.sh - Tüm modüller tarafından kullanılan ortak fonksiyonlar
#

# === RENK TANIMLARI ===
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# === GLOBAL DEĞİŞKENLER ===
declare -g CRITICAL_COUNT=0
declare -g HIGH_COUNT=0
declare -g MEDIUM_COUNT=0
declare -g LOW_COUNT=0
declare -g INFO_COUNT=0
declare -g PASS_COUNT=0

# JSON findings array
declare -ga FINDINGS=()

# === LOGLAMA FONKSİYONLARI ===

log() {
    local level="${1:-INFO}"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

log_debug() {
    [[ "${DEBUG:-false}" == "true" ]] && log "DEBUG" "$1"
}

log_info() {
    log "INFO" "$1"
}

log_warn() {
    log "WARN" "$1"
}

log_error() {
    log "ERROR" "$1"
}

# === ÇIKTI FONKSİYONLARI ===

print_header() {
    local title="$1"
    local width=65

    echo ""
    echo -e "${BLUE}$(printf '═%.0s' $(seq 1 $width))${NC}"
    printf "${BLUE}%*s${NC}\n" $(((${#title}+width)/2)) "$title"
    echo -e "${BLUE}$(printf '═%.0s' $(seq 1 $width))${NC}"
    echo ""
}

print_section() {
    local title="$1"
    echo ""
    echo -e "${CYAN}${BOLD}[$title]${NC}"
    echo -e "${DIM}$(printf '─%.0s' $(seq 1 65))${NC}"
}

print_subsection() {
    local title="$1"
    echo -e "  ${BLUE}▸ $title${NC}"
}

# === ALERT FONKSİYONLARI ===

add_finding() {
    local severity="$1"
    local category="$2"
    local title="$3"
    local description="${4:-}"
    local remediation="${5:-}"
    local cvss="${6:-0.0}"

    local finding
    finding=$(cat <<EOF
{
    "severity": "$severity",
    "category": "$category",
    "title": "$title",
    "description": "$description",
    "remediation": "$remediation",
    "cvss_score": $cvss,
    "timestamp": "$(date -Iseconds)"
}
EOF
)
    FINDINGS+=("$finding")
}

alert_critical() {
    local title="$1"
    local description="${2:-}"
    local remediation="${3:-}"
    local category="${4:-general}"

    CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    add_finding "CRITICAL" "$category" "$title" "$description" "$remediation" "9.5"
    log_warn "CRITICAL: $title"

    # Filtreleme kontrolü
    should_show_severity "critical" || return 0

    echo -e "  ${RED}${BOLD}[KRİTİK]${NC} $title"
    [[ -n "$description" ]] && echo -e "          ${DIM}$description${NC}"
}

alert_high() {
    local title="$1"
    local description="${2:-}"
    local remediation="${3:-}"
    local category="${4:-general}"

    HIGH_COUNT=$((HIGH_COUNT + 1))
    add_finding "HIGH" "$category" "$title" "$description" "$remediation" "7.5"
    log_warn "HIGH: $title"

    # Filtreleme kontrolü
    should_show_severity "high" || return 0

    echo -e "  ${RED}[YÜKSEK]${NC} $title"
    [[ -n "$description" ]] && echo -e "          ${DIM}$description${NC}"
}

alert_medium() {
    local title="$1"
    local description="${2:-}"
    local remediation="${3:-}"
    local category="${4:-general}"

    MEDIUM_COUNT=$((MEDIUM_COUNT + 1))
    add_finding "MEDIUM" "$category" "$title" "$description" "$remediation" "5.0"
    log_info "MEDIUM: $title"

    # Filtreleme kontrolü
    should_show_severity "medium" || return 0

    echo -e "  ${YELLOW}[ORTA]${NC} $title"
    [[ -n "$description" ]] && echo -e "        ${DIM}$description${NC}"
}

alert_low() {
    local title="$1"
    local description="${2:-}"
    local remediation="${3:-}"
    local category="${4:-general}"

    LOW_COUNT=$((LOW_COUNT + 1))
    add_finding "LOW" "$category" "$title" "$description" "$remediation" "2.5"
    log_info "LOW: $title"

    # Filtreleme kontrolü
    should_show_severity "low" || return 0

    echo -e "  ${YELLOW}[DÜŞÜK]${NC} $title"
    [[ -n "$description" ]] && echo -e "        ${DIM}$description${NC}"
}

alert_info() {
    local title="$1"
    local description="${2:-}"
    local category="${3:-general}"

    INFO_COUNT=$((INFO_COUNT + 1))
    add_finding "INFO" "$category" "$title" "$description" "" "0.0"

    # Filtreleme kontrolü
    should_show_severity "info" || return 0

    echo -e "  ${BLUE}[BİLGİ]${NC} $title"
    [[ -n "$description" ]] && echo -e "        ${DIM}$description${NC}"
}

alert_ok() {
    local title="$1"
    PASS_COUNT=$((PASS_COUNT + 1))
    echo -e "  ${GREEN}[OK]${NC} $title"
}

alert_skip() {
    local title="$1"
    local reason="${2:-}"
    echo -e "  ${DIM}[ATLA]${NC} $title"
    [[ -n "$reason" ]] && echo -e "        ${DIM}Sebep: $reason${NC}"
}

# === SEVERİTY FİLTRELEME ===

# Severity seviyesini sayıya çevir
severity_to_number() {
    local severity="${1,,}"  # lowercase
    case "$severity" in
        info)     echo 1 ;;
        low)      echo 2 ;;
        medium)   echo 3 ;;
        high)     echo 4 ;;
        critical) echo 5 ;;
        *)        echo 0 ;;
    esac
}

# Severity gösterilmeli mi kontrol et
should_show_severity() {
    local current_severity="${1,,}"
    local min_severity="${MIN_SEVERITY:-info}"
    local only_severity="${ONLY_SEVERITY:-}"

    # --only parametresi varsa sadece o seviyeyi göster
    if [[ -n "$only_severity" ]]; then
        [[ "${current_severity,,}" == "${only_severity,,}" ]]
        return $?
    fi

    # Minimum severity kontrolü
    local current_num min_num
    current_num=$(severity_to_number "$current_severity")
    min_num=$(severity_to_number "$min_severity")

    [[ $current_num -ge $min_num ]]
}

# === YARDIMCI FONKSİYONLAR ===

is_root() {
    [[ $EUID -eq 0 ]]
}

command_exists() {
    command -v "$1" &>/dev/null
}

file_exists() {
    [[ -f "$1" ]]
}

dir_exists() {
    [[ -d "$1" ]]
}

is_service_running() {
    local service="$1"
    systemctl is-active --quiet "$service" 2>/dev/null
}

is_service_enabled() {
    local service="$1"
    systemctl is-enabled --quiet "$service" 2>/dev/null
}

get_file_perms() {
    local file="$1"
    stat -c %a "$file" 2>/dev/null || echo "000"
}

get_file_owner() {
    local file="$1"
    stat -c %U "$file" 2>/dev/null || echo "unknown"
}

# Dosya hash'i al
get_file_hash() {
    local file="$1"
    sha256sum "$file" 2>/dev/null | awk '{print $1}'
}

# Versiyon karşılaştırma
version_compare() {
    local v1="$1"
    local op="$2"
    local v2="$3"

    case "$op" in
        "lt") [[ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n1)" == "$v1" && "$v1" != "$v2" ]] ;;
        "le") [[ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n1)" == "$v1" ]] ;;
        "gt") [[ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n1)" == "$v2" && "$v1" != "$v2" ]] ;;
        "ge") [[ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n1)" == "$v2" ]] ;;
        "eq") [[ "$v1" == "$v2" ]] ;;
        *) return 1 ;;
    esac
}

# CVSS skoru hesapla
calculate_risk_score() {
    local critical="${1:-0}"
    local high="${2:-0}"
    local medium="${3:-0}"
    local low="${4:-0}"
    local total=$((critical + high + medium + low))

    if [[ $total -eq 0 ]]; then
        echo "0"
        return
    fi

    local weighted=$((critical * 10 + high * 7 + medium * 4 + low * 1))
    local max_possible=$((total * 10))
    local score=$((weighted * 100 / max_possible))

    echo "$score"
}

# Severity'ye göre renk döndür
get_severity_color() {
    local severity="$1"
    case "$severity" in
        CRITICAL) echo -e "${RED}${BOLD}" ;;
        HIGH) echo -e "${RED}" ;;
        MEDIUM) echo -e "${YELLOW}" ;;
        LOW) echo -e "${YELLOW}" ;;
        INFO) echo -e "${BLUE}" ;;
        *) echo -e "${NC}" ;;
    esac
}

# Zaman formatla
format_duration() {
    local seconds="$1"
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))

    if [[ $minutes -gt 0 ]]; then
        echo "${minutes}d ${remaining_seconds}s"
    else
        echo "${remaining_seconds}s"
    fi
}

# Boyut formatla
format_size() {
    local bytes="$1"

    if [[ $bytes -ge 1073741824 ]]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc)G"
    elif [[ $bytes -ge 1048576 ]]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc)M"
    elif [[ $bytes -ge 1024 ]]; then
        echo "$(echo "scale=2; $bytes/1024" | bc)K"
    else
        echo "${bytes}B"
    fi
}

# IP adresi validasyonu
is_valid_ip() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if [[ $ip =~ $regex ]]; then
        local IFS='.'
        read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            [[ $octet -gt 255 ]] && return 1
        done
        return 0
    fi
    return 1
}

# Port validasyonu
is_valid_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ && $port -ge 1 && $port -le 65535 ]]
}

# Spinner göster (uzun işlemler için)
show_spinner() {
    local pid="$1"
    local message="${2:-İşlem devam ediyor...}"
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " ${CYAN}[%c]${NC} %s\r" "$spinstr" "$message"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
    done
    printf "    \r"
}

# Progress bar
show_progress() {
    local current="$1"
    local total="$2"
    local width="${3:-40}"
    local title="${4:-}"

    # Division by zero koruması
    [[ $total -eq 0 ]] && return

    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    # Bar'ı oluştur
    local filled_bar="" empty_bar=""
    for ((i=0; i<filled; i++)); do filled_bar+="█"; done
    for ((i=0; i<empty; i++)); do empty_bar+="░"; done

    # Carriage return ile satır başına dön ve yaz
    # printf %b escape kodlarını yorumlar
    printf "\r  %-12s [%b%s%b%s%b] %3d%%   " "$title" "${GREEN}" "$filled_bar" "${DIM}" "$empty_bar" "${NC}" "$percent"

    # Tamamlandığında yeni satır
    [[ $current -eq $total ]] && echo ""
}

# Bildirim gönder
send_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"

    if command_exists notify-send; then
        notify-send -u "$urgency" "$title" "$message"
    fi
}

# Cleanup trap için
cleanup() {
    # Geçici dosyaları temizle
    [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}

# Array'de eleman var mı kontrol et
in_array() {
    local needle="$1"
    shift
    local hay
    for hay in "$@"; do
        [[ "$hay" == "$needle" ]] && return 0
    done
    return 1
}

# Config dosyasından değer oku
get_config_value() {
    local key="$1"
    local default="${2:-}"
    local config_file="${CONFIG_FILE:-}"

    if [[ -f "$config_file" ]]; then
        local value
        value=$(grep "^${key}=" "$config_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

# Whitelist kontrolü
is_whitelisted() {
    local item="$1"
    local whitelist_file="${DATA_DIR:-}/whitelist.conf"

    if [[ -f "$whitelist_file" ]]; then
        grep -qF "$item" "$whitelist_file" 2>/dev/null
    else
        return 1
    fi
}
