#!/bin/bash
#
# Ubuntu Security Scanner - Kurulum Scripti
# install.sh - Manuel veya otomatik kurulum seçenekleri
#

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Değişkenler
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/share/security-scanner"
BIN_DIR="${HOME}/.local/bin"
SYSTEMD_DIR="${HOME}/.config/systemd/user"
SCANNER_VERSION="0.1.0"

# Fonksiyonlar
print_banner() {
    echo -e "${CYAN}"
    echo "  _____                      _ _          _____                                 "
    echo " / ____|                    (_) |        / ____|                                "
    echo "| (___   ___  ___ _   _ _ __ _| |_ _   _| (___   ___ __ _ _ __  _ __   ___ _ __ "
    echo " \___ \ / _ \/ __| | | | '__| | __| | | |\___ \ / __/ _\` | '_ \| '_ \ / _ \ '__|"
    echo " ____) |  __/ (__| |_| | |  | | |_| |_| |____) | (_| (_| | | | | | | |  __/ |   "
    echo "|_____/ \___|\___|\__,_|_|  |_|\__|\__, |_____/ \___\__,_|_| |_|_| |_|\___|_|   "
    echo "                                    __/ |                                       "
    echo "                                   |___/  v${SCANNER_VERSION}                   "
    echo -e "${NC}"
}

print_header() {
    echo ""
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}  Ubuntu Security Scanner - Kurulum${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo ""
}

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[UYARI]${NC} $1"
}

error() {
    echo -e "${RED}[HATA]${NC} $1"
}

check_requirements() {
    info "Gereksinimler kontrol ediliyor..."

    # Bash version
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        error "Bash 4.0 veya üzeri gerekli"
        exit 1
    fi

    # jq önerisi
    if ! command -v jq &>/dev/null; then
        warn "jq kurulu değil. JSON işlemleri için önerilir."
        echo -e "  Kurmak için: ${CYAN}sudo apt install jq${NC}"
    fi

    info "Gereksinimler tamam"
}

# ===== ALIAS YÖNETİMİ =====

# Kullanılan shell'i tespit et
detect_shell() {
    local shell_name
    shell_name=$(basename "$SHELL")

    case "$shell_name" in
        bash) SHELL_RC="$HOME/.bashrc" ;;
        zsh)  SHELL_RC="$HOME/.zshrc" ;;
        *)    SHELL_RC="$HOME/.bashrc" ;; # fallback
    esac

    echo "$shell_name"
}

# Alias bloğunu oluştur
generate_alias_block() {
    local current_date
    current_date=$(date +%Y-%m-%d)
    cat << ALIASES
# ===== Security Scanner Aliases =====
# Otomatik eklendi: $current_date

# Ana komut kısayolları
alias scan='security-scanner'
alias scan-quick='security-scanner --quick'
alias scan-full='security-scanner --full'
alias scan-html='security-scanner -f html'
alias scan-json='security-scanner -f json'
alias scan-all='security-scanner -f json,html,txt'

# FIM (File Integrity Monitoring)
alias scan-fim-init='security-scanner --fim-init'
alias scan-fim='security-scanner --fim-check'
alias scan-fim-update='security-scanner --fim-update'

# Modül bazlı tarama
alias scan-net='security-scanner --modules network'
alias scan-auth='security-scanner --modules authentication'
alias scan-services='security-scanner --modules services'
alias scan-perms='security-scanner --modules permissions'

# Yardımcı komutlar
alias scan-help='security-scanner --help'
alias scan-version='security-scanner --version'
alias scan-modules='security-scanner --list-modules'
alias scan-reports='security-scanner --list-reports'
alias scan-logs='tail -50 ~/.local/share/security-scanner/logs/scanner.log'

# ===== End Security Scanner Aliases =====
ALIASES
}

# PATH ekle (gerekirse)
add_path_to_rc() {
    local rc_file="$1"
    local path_line='export PATH="$HOME/.local/bin:$PATH"'

    # Zaten varsa ekleme
    if grep -q '.local/bin' "$rc_file" 2>/dev/null; then
        return 0
    fi

    echo "" >> "$rc_file"
    echo "# Security Scanner PATH" >> "$rc_file"
    echo "$path_line" >> "$rc_file"

    info "PATH eklendi: $rc_file"
}

# Alias'ları ekle
add_aliases() {
    local rc_file="$1"

    # Zaten varsa ekleme
    if grep -q "Security Scanner Aliases" "$rc_file" 2>/dev/null; then
        warn "Alias'lar zaten mevcut: $rc_file"
        return 0
    fi

    echo "" >> "$rc_file"
    generate_alias_block >> "$rc_file"

    info "Alias'lar eklendi: $rc_file"
}

# Ana kuruluma alias seçeneği ekle
install_aliases() {
    local shell_name
    shell_name=$(detect_shell)

    echo ""
    echo -e "${CYAN}Shell alias'ları eklensin mi?${NC}"
    echo -e "  Kullandığınız shell: ${GREEN}$shell_name${NC} ($SHELL_RC)"
    echo ""
    echo "  Eklenecek alias'lar:"
    echo "    scan           -> security-scanner"
    echo "    scan-quick     -> security-scanner --quick"
    echo "    scan-html      -> security-scanner -f html"
    echo "    scan-fim       -> security-scanner --fim-check"
    echo "    ... ve daha fazlası"
    echo ""

    read -p "Alias'ları eklemek ister misiniz? [E/h]: " -r add_aliases_choice

    if [[ ! "$add_aliases_choice" =~ ^[hHnN]$ ]]; then
        add_path_to_rc "$SHELL_RC"
        add_aliases "$SHELL_RC"

        echo ""
        info "Alias'ları aktifleştirmek için:"
        echo -e "  ${CYAN}source $SHELL_RC${NC}"
        echo ""
    fi
}

# ===== KURULUM FONKSİYONLARI =====

install_manual() {
    info "Manuel kurulum başlatılıyor..."

    # Ana dizin
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR"

    # Dosyaları kopyala
    info "Dosyalar kopyalanıyor..."
    cp -r "$SCRIPT_DIR/bin" "$INSTALL_DIR/"
    cp -r "$SCRIPT_DIR/lib" "$INSTALL_DIR/"
    cp -r "$SCRIPT_DIR/modules" "$INSTALL_DIR/"
    cp -r "$SCRIPT_DIR/config" "$INSTALL_DIR/"
    cp -r "$SCRIPT_DIR/templates" "$INSTALL_DIR/"

    # Data ve reports dizinleri
    mkdir -p "$INSTALL_DIR/data"
    mkdir -p "$INSTALL_DIR/reports"
    mkdir -p "$INSTALL_DIR/logs"

    # Çalıştırılabilir yap
    chmod +x "$INSTALL_DIR/bin/security-scanner"

    # Symlink
    ln -sf "$INSTALL_DIR/bin/security-scanner" "$BIN_DIR/security-scanner"

    # PATH kontrolü
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        warn "$BIN_DIR PATH'te değil"
        echo ""
        echo -e "  Aşağıdaki satırı ${CYAN}~/.bashrc${NC} veya ${CYAN}~/.zshrc${NC} dosyasına ekleyin:"
        echo -e "  ${YELLOW}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        echo ""
    fi

    info "Manuel kurulum tamamlandı"
    echo -e "  Kullanım: ${CYAN}security-scanner --help${NC}"
}

install_systemd() {
    info "Systemd timer kuruluyor..."

    mkdir -p "$SYSTEMD_DIR"

    # Service dosyası
    cat > "$SYSTEMD_DIR/security-scanner.service" <<EOF
[Unit]
Description=Ubuntu Security Scanner - Güvenlik Taraması
Documentation=https://github.com/erhanurgun/LINUX-ubuntu-security-scanner
After=network.target

[Service]
Type=oneshot
ExecStart=${INSTALL_DIR}/bin/security-scanner --quick -f json,html
Environment=HOME=${HOME}
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

    # Timer dosyası
    cat > "$SYSTEMD_DIR/security-scanner.timer" <<EOF
[Unit]
Description=Ubuntu Security Scanner - Günlük Tarama Zamanlayıcısı
Documentation=https://github.com/erhanurgun/LINUX-ubuntu-security-scanner

[Timer]
# Her gün saat 09:00'da çalıştır
OnCalendar=*-*-* 09:00:00
# Boot sonrası 5 dakika bekle
OnBootSec=5min
# Kaçırılan taramaları yakala
Persistent=true
# Rastgele gecikme (yük dağıtımı)
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF

    # Systemd'yi yeniden yükle
    systemctl --user daemon-reload

    # Timer'ı etkinleştir
    systemctl --user enable security-scanner.timer
    systemctl --user start security-scanner.timer

    info "Systemd timer kuruldu ve etkinleştirildi"
    echo ""
    echo -e "  Timer durumu: ${CYAN}systemctl --user status security-scanner.timer${NC}"
    echo -e "  Manuel çalıştır: ${CYAN}systemctl --user start security-scanner.service${NC}"
    echo -e "  Loglar: ${CYAN}journalctl --user -u security-scanner.service${NC}"
}

show_menu() {
    print_header

    echo "Kurulum seçenekleri:"
    echo ""
    echo -e "  ${CYAN}1)${NC} Sadece manuel kullanım için kur"
    echo -e "     ${DIM}- ~/.local/share/security-scanner/ dizinine kopyalar${NC}"
    echo -e "     ${DIM}- ~/.local/bin/security-scanner symlink oluşturur${NC}"
    echo -e "     ${DIM}- security-scanner komutu ile manuel çalıştırabilirsiniz${NC}"
    echo ""
    echo -e "  ${CYAN}2)${NC} Manuel + Otomatik zamanlayıcı ile kur ${GREEN}(Önerilen)${NC}"
    echo -e "     ${DIM}- Yukarıdakilere ek olarak:${NC}"
    echo -e "     ${DIM}- Systemd timer kurar (günlük 09:00'da otomatik tarama)${NC}"
    echo -e "     ${DIM}- Boot sonrası 5 dakika içinde tarama${NC}"
    echo -e "     ${DIM}- JSON + HTML raporlar otomatik oluşturulur${NC}"
    echo ""
    echo -e "  ${CYAN}3)${NC} İptal"
    echo ""
}

main() {
    print_banner

    # Portable mod kontrolü
    if [[ "$1" == "--portable" ]]; then
        info "Portable mod: Kurulum yapılmadı"
        info "Doğrudan çalıştırmak için: ./bin/security-scanner"
        exit 0
    fi

    # Zaten kurulu mu?
    if [[ -d "$INSTALL_DIR" ]]; then
        warn "Security Scanner zaten kurulu: $INSTALL_DIR"
        echo ""
        read -p "Üzerine yazmak istiyor musunuz? [e/H]: " -r overwrite
        if [[ ! "$overwrite" =~ ^[eEyY]$ ]]; then
            info "Kurulum iptal edildi"
            exit 0
        fi
        echo ""
    fi

    check_requirements

    show_menu

    read -p "Seçiminiz [1/2/3]: " -r choice

    case "$choice" in
        1)
            echo ""
            install_manual
            install_aliases
            ;;
        2)
            echo ""
            install_manual
            install_aliases
            install_systemd
            ;;
        3)
            info "Kurulum iptal edildi"
            exit 0
            ;;
        *)
            error "Geçersiz seçim"
            exit 1
            ;;
    esac

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Kurulum başarıyla tamamlandı!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Hızlı başlangıç:"
    echo -e "  ${CYAN}security-scanner --quick${NC}        # Hızlı tarama"
    echo -e "  ${CYAN}security-scanner --help${NC}         # Yardım"
    echo -e "  ${CYAN}security-scanner -f html${NC}        # HTML rapor"
    echo ""

    # Timer kurulduysa bilgi ver
    if [[ "$choice" == "2" ]]; then
        echo "Otomatik tarama:"
        echo -e "  ${CYAN}systemctl --user status security-scanner.timer${NC}"
        echo ""
    fi
}

main "$@"
