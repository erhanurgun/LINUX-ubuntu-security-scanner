#!/bin/bash
# Description: Güvenlik güncellemelerini kontrol eder

scan() {
    print_section "Güvenlik Güncellemeleri"

    # apt-get update durumu kontrolü
    local apt_updated=false
    local apt_cache_time
    apt_cache_time=$(stat -c %Y /var/lib/apt/lists/partial 2>/dev/null || echo "0")
    local current_time
    current_time=$(date +%s)
    local age=$((current_time - apt_cache_time))

    if [[ $age -gt 86400 ]]; then  # 24 saat
        alert_low "Paket listesi güncel değil" \
            "Son güncelleme $(($age / 3600)) saat önce" \
            "sudo apt update" \
            "updates"
    fi

    # Güvenlik güncellemelerini kontrol et
    print_subsection "Bekleyen Güncellemeler"

    local all_updates security_updates critical_updates
    all_updates=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" | tr -d '\n' || echo "0")
    security_updates=$(apt list --upgradable 2>/dev/null | grep -ci "security" | tr -d '\n' || echo "0")
    all_updates="${all_updates:-0}"
    security_updates="${security_updates:-0}"

    echo -e "    Toplam bekleyen: $all_updates"
    echo -e "    Güvenlik:        $security_updates"

    if [[ "$all_updates" =~ ^[0-9]+$ ]] && [[ "$security_updates" =~ ^[0-9]+$ ]] && [[ $security_updates -gt 10 ]]; then
        alert_critical "$security_updates güvenlik güncellemesi bekliyor" \
            "Kritik güvenlik yamaları uygulanmalı" \
            "sudo apt update && sudo apt upgrade" \
            "updates"
    elif [[ "$security_updates" =~ ^[0-9]+$ ]] && [[ $security_updates -gt 0 ]]; then
        alert_high "$security_updates güvenlik güncellemesi bekliyor" \
            "Güvenlik güncellemeleri mevcut" \
            "sudo apt update && sudo apt upgrade" \
            "updates"
    else
        alert_ok "Güvenlik güncellemeleri yüklü"
    fi

    # Unattended-upgrades kontrolü
    print_subsection "Otomatik Güncelleme Durumu"

    if command_exists unattended-upgrade; then
        local auto_enabled
        auto_enabled=$(grep -r "Unattended-Upgrade::Allowed-Origins" /etc/apt/apt.conf.d/ 2>/dev/null | grep -v "^#" | head -1)

        if [[ -n "$auto_enabled" ]]; then
            alert_ok "Otomatik güvenlik güncellemeleri aktif"
        else
            alert_medium "Otomatik güvenlik güncellemeleri devre dışı" \
                "unattended-upgrades kurulu ama yapılandırılmamış" \
                "sudo dpkg-reconfigure -plow unattended-upgrades" \
                "updates"
        fi
    else
        alert_medium "Otomatik güncelleme sistemi kurulu değil" \
            "unattended-upgrades paketi bulunamadı" \
            "sudo apt install unattended-upgrades" \
            "updates"
    fi

    # Kernel güncelleme kontrolü
    print_subsection "Kernel Durumu"

    local running_kernel installed_kernels
    running_kernel=$(uname -r)

    # Yüklü kernel'ları listele
    installed_kernels=$(dpkg -l 'linux-image-*' 2>/dev/null | grep "^ii" | awk '{print $2}' | grep -v "generic$" | sort -V)

    if [[ -n "$installed_kernels" ]]; then
        local latest_kernel
        latest_kernel=$(echo "$installed_kernels" | tail -1 | sed 's/linux-image-//')

        if [[ "$running_kernel" != "$latest_kernel" && -n "$latest_kernel" ]]; then
            alert_medium "Yeni kernel yüklü ama aktif değil" \
                "Çalışan: $running_kernel, Yüklü: $latest_kernel" \
                "Sistemi yeniden başlatın" \
                "updates"
        else
            alert_ok "Çalışan kernel güncel ($running_kernel)"
        fi
    fi

    # Eski kernel'ları temizle önerisi
    local kernel_count
    kernel_count=$(echo "$installed_kernels" | wc -l)
    if [[ $kernel_count -gt 3 ]]; then
        alert_low "$kernel_count eski kernel yüklü" \
            "Disk alanı kazanmak için eski kernel'lar kaldırılabilir" \
            "sudo apt autoremove" \
            "updates"
    fi

    # Reboot gerekli mi kontrolü
    if [[ -f /var/run/reboot-required ]]; then
        alert_high "Sistem yeniden başlatma bekliyor" \
            "Güvenlik güncellemeleri için yeniden başlatma gerekli" \
            "sudo reboot" \
            "updates"

        if [[ -f /var/run/reboot-required.pkgs ]]; then
            echo -e "    ${DIM}Güncellenmiş paketler:${NC}"
            head -5 /var/run/reboot-required.pkgs | while read -r pkg; do
                echo "      - $pkg"
            done
        fi
    fi

    # apt-daily timer kontrolü
    print_subsection "Güncelleme Zamanlayıcıları"

    if systemctl is-enabled apt-daily.timer &>/dev/null; then
        local next_run
        next_run=$(systemctl show apt-daily.timer --property=NextElapseUSecRealtime 2>/dev/null | cut -d= -f2)
        alert_ok "apt-daily timer aktif"
    else
        alert_low "apt-daily timer devre dışı" \
            "Otomatik paket listesi güncellemesi kapalı" \
            "sudo systemctl enable apt-daily.timer" \
            "updates"
    fi

    if systemctl is-enabled apt-daily-upgrade.timer &>/dev/null; then
        alert_ok "apt-daily-upgrade timer aktif"
    else
        alert_low "apt-daily-upgrade timer devre dışı" \
            "Otomatik güncelleme kapalı" \
            "sudo systemctl enable apt-daily-upgrade.timer" \
            "updates"
    fi

    # snap güncellemeleri (varsa)
    if command_exists snap; then
        print_subsection "Snap Güncellemeleri"

        local snap_updates
        snap_updates=$(snap refresh --list 2>/dev/null | grep -v "^Name" | wc -l | tr -d ' \n' || echo "0")
        snap_updates="${snap_updates:-0}"

        if [[ "$snap_updates" =~ ^[0-9]+$ ]] && [[ $snap_updates -gt 0 ]]; then
            alert_low "$snap_updates snap paketi güncellenebilir" \
                "Snap paketleri otomatik güncellenir ama bekleyenler var" \
                "sudo snap refresh" \
                "updates"
        else
            alert_ok "Snap paketleri güncel"
        fi
    fi

    # flatpak güncellemeleri (varsa)
    if command_exists flatpak; then
        print_subsection "Flatpak Güncellemeleri"

        local flatpak_updates
        flatpak_updates=$(flatpak remote-ls --updates 2>/dev/null | wc -l | tr -d ' \n' || echo "0")
        flatpak_updates="${flatpak_updates:-0}"

        if [[ "$flatpak_updates" =~ ^[0-9]+$ ]] && [[ $flatpak_updates -gt 0 ]]; then
            alert_low "$flatpak_updates flatpak paketi güncellenebilir" \
                "Flatpak güncellemeleri mevcut" \
                "flatpak update" \
                "updates"
        else
            alert_ok "Flatpak paketleri güncel"
        fi
    fi
}
