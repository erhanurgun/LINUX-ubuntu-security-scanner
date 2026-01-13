#!/bin/bash
# Description: Sistem bilgilerini toplar ve güvenlik durumunu değerlendirir

scan() {
    print_section "Sistem Bilgileri"

    # OS Bilgileri
    local os_name os_version kernel_version arch
    os_name=$(grep -oP '(?<=^NAME=").*(?="$)' /etc/os-release 2>/dev/null || echo "Unknown")
    os_version=$(grep -oP '(?<=^VERSION_ID=").*(?="$)' /etc/os-release 2>/dev/null || echo "Unknown")
    kernel_version=$(uname -r)
    arch=$(uname -m)

    echo -e "  ${DIM}İşletim Sistemi:${NC} $os_name $os_version"
    echo -e "  ${DIM}Kernel:${NC}          $kernel_version"
    echo -e "  ${DIM}Mimari:${NC}          $arch"

    # Kernel versiyon kontrolü
    local major_version
    major_version=$(echo "$kernel_version" | cut -d. -f1)
    if [[ $major_version -lt 5 ]]; then
        alert_medium "Eski kernel versiyonu" \
            "Kernel $kernel_version kullanılıyor, 5.x+ önerilir" \
            "sudo apt update && sudo apt upgrade" \
            "system"
    else
        alert_ok "Kernel versiyonu güncel ($kernel_version)"
    fi

    echo ""

    # Uptime
    local uptime_seconds uptime_days
    uptime_seconds=$(cat /proc/uptime 2>/dev/null | cut -d' ' -f1 | cut -d'.' -f1)
    uptime_days=$((uptime_seconds / 86400))

    echo -e "  ${DIM}Uptime:${NC}          $(uptime -p 2>/dev/null || echo "${uptime_days} gün")"

    if [[ $uptime_days -gt 90 ]]; then
        alert_low "Sistem uzun süredir yeniden başlatılmamış" \
            "$uptime_days gündür çalışıyor, güvenlik güncellemeleri için yeniden başlatma gerekebilir" \
            "Uygun bir zamanda sistemi yeniden başlatın" \
            "system"
    fi

    # Son boot zamanı
    echo -e "  ${DIM}Son Boot:${NC}        $(who -b 2>/dev/null | awk '{print $3, $4}')"

    echo ""

    # Kullanıcı sayısı
    local user_count root_shells
    user_count=$(getent passwd | wc -l)
    root_shells=$(getent passwd | awk -F: '$3 == 0 {print $1}' | wc -l)

    echo -e "  ${DIM}Toplam Kullanıcı:${NC} $user_count"
    echo -e "  ${DIM}UID 0 Hesaplar:${NC}  $root_shells"

    if [[ $root_shells -gt 1 ]]; then
        alert_high "Birden fazla UID 0 hesabı var" \
            "$root_shells hesap root yetkisine sahip" \
            "Gereksiz root hesaplarını devre dışı bırakın" \
            "authentication"
    fi

    # Login shell olan kullanıcılar
    local login_users
    login_users=$(getent passwd | grep -E '/bin/(ba)?sh$' | wc -l)
    echo -e "  ${DIM}Login Kullanıcı:${NC} $login_users"

    echo ""

    # Memory
    local total_mem used_mem
    total_mem=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
    used_mem=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3}')
    echo -e "  ${DIM}Bellek:${NC}          $used_mem / $total_mem"

    # Disk
    local root_usage
    root_usage=$(df -h / 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')
    echo -e "  ${DIM}Disk (/) Kullanım:${NC} ${root_usage}%"

    if [[ $root_usage -gt 90 ]]; then
        alert_medium "Disk dolmak üzere" \
            "Root disk %${root_usage} dolu" \
            "Gereksiz dosyaları temizleyin: sudo apt autoremove" \
            "system"
    fi

    echo ""

    # Yüklü paket sayısı
    local pkg_count
    if command_exists dpkg; then
        pkg_count=$(dpkg -l 2>/dev/null | grep -c "^ii")
        echo -e "  ${DIM}Yüklü Paketler:${NC}  $pkg_count"
    fi

    # systemd servisleri
    local running_services failed_services
    running_services=$(systemctl list-units --type=service --state=running 2>/dev/null | grep -c "running")
    failed_services=$(systemctl list-units --type=service --state=failed 2>/dev/null | grep -c "failed")

    echo -e "  ${DIM}Çalışan Servisler:${NC} $running_services"

    if [[ $failed_services -gt 0 ]]; then
        echo -e "  ${DIM}Başarısız Servisler:${NC} ${RED}$failed_services${NC}"
        alert_low "Başarısız servisler var" \
            "$failed_services servis başarısız durumda" \
            "systemctl --failed ile detayları görün" \
            "system"
    fi

    echo ""

    # Virtualization kontrolü
    local virt_type
    virt_type=$(systemd-detect-virt 2>/dev/null | tr -d '[:space:]')
    [[ -z "$virt_type" ]] && virt_type="none"
    if [[ "$virt_type" != "none" ]]; then
        echo -e "  ${DIM}Sanallaştırma:${NC}   $virt_type"
        alert_info "Sanal makine tespit edildi" \
            "Sanallaştırma türü: $virt_type" \
            "system"
    fi

    # Secure Boot kontrolü
    if [[ -d /sys/firmware/efi ]]; then
        local secure_boot
        secure_boot=$(mokutil --sb-state 2>/dev/null | grep -c "enabled")
        secure_boot=${secure_boot:-0}
        if [[ "$secure_boot" =~ ^[0-9]+$ ]] && [[ $secure_boot -gt 0 ]]; then
            alert_ok "Secure Boot aktif"
        else
            alert_medium "Secure Boot devre dışı" \
                "UEFI Secure Boot aktif değil" \
                "BIOS/UEFI ayarlarından Secure Boot'u etkinleştirin" \
                "system"
        fi
    fi
}
