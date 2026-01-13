#!/bin/bash
#
# Ubuntu Security Scanner - Kaldırma Scripti
# uninstall.sh - Tam veya kısmi kaldırma seçenekleri
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
INSTALL_DIR="${HOME}/.local/share/security-scanner"
BIN_DIR="${HOME}/.local/bin"
SYSTEMD_DIR="${HOME}/.config/systemd/user"
BACKUP_DIR="${HOME}/security-scanner-backup-$(date +%Y%m%d-%H%M%S)"

# Fonksiyonlar
print_header() {
    echo ""
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}  Ubuntu Security Scanner - Kaldırma${NC}"
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

check_installation() {
    local has_install=false
    local has_timer=false
    local has_symlink=false

    if [[ -d "$INSTALL_DIR" ]]; then
        has_install=true
        local size
        size=$(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1)
        echo -e "  ${CYAN}Kurulum dizini:${NC} $INSTALL_DIR ($size)"
    fi

    if [[ -L "$BIN_DIR/security-scanner" ]]; then
        has_symlink=true
        echo -e "  ${CYAN}Symlink:${NC} $BIN_DIR/security-scanner"
    fi

    if [[ -f "$SYSTEMD_DIR/security-scanner.timer" ]]; then
        has_timer=true
        local timer_status
        timer_status=$(systemctl --user is-active security-scanner.timer 2>/dev/null || echo "inactive")
        echo -e "  ${CYAN}Systemd timer:${NC} $timer_status"
    fi

    # Alias kontrolü
    local has_aliases=false
    for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc_file" ]] && grep -q "Security Scanner Aliases" "$rc_file" 2>/dev/null; then
            has_aliases=true
            echo -e "  ${CYAN}Shell alias'ları:${NC} $rc_file"
        fi
    done

    if [[ "$has_install" == "false" && "$has_timer" == "false" && "$has_symlink" == "false" && "$has_aliases" == "false" ]]; then
        echo -e "  ${YELLOW}Kurulum bulunamadı${NC}"
        return 1
    fi

    return 0
}

# ===== ALIAS KALDIRMA =====

# Alias'ları tespit et ve kaldır
remove_aliases() {
    local rc_files=("$HOME/.bashrc" "$HOME/.zshrc")
    local found=false

    for rc_file in "${rc_files[@]}"; do
        if [[ -f "$rc_file" ]] && grep -q "Security Scanner Aliases" "$rc_file" 2>/dev/null; then
            found=true
            echo -e "  ${CYAN}Alias bulundu:${NC} $rc_file"
        fi
    done

    if [[ "$found" == "false" ]]; then
        info "Kaldırılacak alias bulunamadı"
        return 0
    fi

    echo ""
    read -p "Shell alias'larını kaldırmak ister misiniz? [E/h]: " -r remove_choice

    if [[ ! "$remove_choice" =~ ^[hHnN]$ ]]; then
        for rc_file in "${rc_files[@]}"; do
            if [[ -f "$rc_file" ]] && grep -q "Security Scanner Aliases" "$rc_file" 2>/dev/null; then
                remove_alias_block "$rc_file"
            fi
        done
    fi
}

# Alias bloğunu dosyadan sil
remove_alias_block() {
    local rc_file="$1"
    local temp_file
    temp_file=$(mktemp)

    # Başlangıç ve bitiş satırları arasını sil
    awk '
        /# ===== Security Scanner Aliases =====/{skip=1; next}
        /# ===== End Security Scanner Aliases =====/{skip=0; next}
        !skip
    ' "$rc_file" > "$temp_file"

    # Boş satırları temizle (peş peşe 2'den fazla)
    cat -s "$temp_file" > "$rc_file"
    rm -f "$temp_file"

    info "Alias'lar kaldırıldı: $rc_file"
}

# PATH satırını kaldır (opsiyonel)
remove_path_from_rc() {
    local rc_files=("$HOME/.bashrc" "$HOME/.zshrc")

    for rc_file in "${rc_files[@]}"; do
        if [[ -f "$rc_file" ]] && grep -q "# Security Scanner PATH" "$rc_file" 2>/dev/null; then
            sed -i '/# Security Scanner PATH/d' "$rc_file"
            sed -i '/\.local\/bin.*PATH/d' "$rc_file"
            info "PATH satırı kaldırıldı: $rc_file"
        fi
    done
}

# ===== TIMER YÖNETİMİ =====

stop_timer() {
    if systemctl --user is-active security-scanner.timer &>/dev/null; then
        info "Timer durduruluyor..."
        systemctl --user stop security-scanner.timer
    fi

    if systemctl --user is-enabled security-scanner.timer &>/dev/null; then
        info "Timer devre dışı bırakılıyor..."
        systemctl --user disable security-scanner.timer
    fi
}

remove_timer() {
    stop_timer

    info "Systemd dosyaları siliniyor..."

    [[ -f "$SYSTEMD_DIR/security-scanner.service" ]] && rm -f "$SYSTEMD_DIR/security-scanner.service"
    [[ -f "$SYSTEMD_DIR/security-scanner.timer" ]] && rm -f "$SYSTEMD_DIR/security-scanner.timer"

    systemctl --user daemon-reload

    info "Systemd timer kaldırıldı"
}

backup_data() {
    if [[ -d "$INSTALL_DIR/reports" ]] || [[ -d "$INSTALL_DIR/data" ]]; then
        info "Veriler yedekleniyor: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"

        [[ -d "$INSTALL_DIR/reports" ]] && cp -r "$INSTALL_DIR/reports" "$BACKUP_DIR/"
        [[ -d "$INSTALL_DIR/data" ]] && cp -r "$INSTALL_DIR/data" "$BACKUP_DIR/"
        [[ -d "$INSTALL_DIR/logs" ]] && cp -r "$INSTALL_DIR/logs" "$BACKUP_DIR/"

        info "Yedekleme tamamlandı"
    fi
}

remove_installation() {
    info "Kurulum dizini siliniyor..."

    # Symlink
    [[ -L "$BIN_DIR/security-scanner" ]] && rm -f "$BIN_DIR/security-scanner"

    # Ana dizin
    [[ -d "$INSTALL_DIR" ]] && rm -rf "$INSTALL_DIR"

    info "Kurulum kaldırıldı"
}

show_menu() {
    print_header

    echo "Mevcut kurulum bilgisi:"
    if ! check_installation; then
        echo ""
        info "Kaldırılacak bir kurulum bulunamadı"
        exit 0
    fi

    echo ""
    echo "Ne yapmak istersiniz?"
    echo ""
    echo -e "  ${CYAN}1)${NC} Sadece systemd timer'ı kaldır"
    echo -e "     ${DIM}- Otomatik taramayı durdurur${NC}"
    echo -e "     ${DIM}- Manuel kullanım devam eder${NC}"
    echo ""
    echo -e "  ${CYAN}2)${NC} Tam kaldırma (veriler yedeklenir)"
    echo -e "     ${DIM}- Tüm dosyalar silinir${NC}"
    echo -e "     ${DIM}- Raporlar ve veriler yedeklenir${NC}"
    echo -e "     ${DIM}- Shell alias'ları kaldırılır${NC}"
    echo ""
    echo -e "  ${CYAN}3)${NC} Tam kaldırma (yedekleme OLMADAN)"
    echo -e "     ${RED}${DIM}- DİKKAT: Tüm veriler kalıcı olarak silinir!${NC}"
    echo ""
    echo -e "  ${CYAN}4)${NC} Sadece shell alias'larını kaldır"
    echo -e "     ${DIM}- Diğer kurulum aynen kalır${NC}"
    echo ""
    echo -e "  ${CYAN}5)${NC} İptal"
    echo ""
}

main() {
    show_menu

    read -p "Seçiminiz [1/2/3/4/5]: " -r choice

    case "$choice" in
        1)
            echo ""
            if [[ -f "$SYSTEMD_DIR/security-scanner.timer" ]]; then
                remove_timer
            else
                warn "Systemd timer bulunamadı"
            fi
            ;;
        2)
            echo ""
            read -p "Emin misiniz? Veriler yedeklenecek. [e/H]: " -r confirm
            if [[ "$confirm" =~ ^[eEyY]$ ]]; then
                backup_data
                remove_timer 2>/dev/null || true
                remove_aliases
                remove_installation
            else
                info "Kaldırma iptal edildi"
                exit 0
            fi
            ;;
        3)
            echo ""
            echo -e "${RED}UYARI: Tüm veriler kalıcı olarak silinecek!${NC}"
            read -p "Devam etmek istiyor musunuz? [e/H]: " -r confirm
            if [[ "$confirm" =~ ^[eEyY]$ ]]; then
                read -p "Son kez onaylayın - SİLİYOR MUSUNUZ? [evet/hayır]: " -r final_confirm
                if [[ "$final_confirm" == "evet" ]]; then
                    remove_timer 2>/dev/null || true
                    remove_aliases
                    remove_installation
                else
                    info "Kaldırma iptal edildi"
                    exit 0
                fi
            else
                info "Kaldırma iptal edildi"
                exit 0
            fi
            ;;
        4)
            echo ""
            remove_aliases
            ;;
        5)
            info "İşlem iptal edildi"
            exit 0
            ;;
        *)
            error "Geçersiz seçim"
            exit 1
            ;;
    esac

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  İşlem başarıyla tamamlandı!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    if [[ "$choice" == "2" ]]; then
        echo -e "Yedek konumu: ${CYAN}$BACKUP_DIR${NC}"
        echo ""
    fi
}

main "$@"
