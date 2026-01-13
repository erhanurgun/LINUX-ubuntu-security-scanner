#!/bin/bash
# Description: Dosya ve dizin izinlerini denetler

scan() {
    print_section "İzin Denetimi"

    # === Kritik Sistem Dosyaları ===
    print_subsection "Kritik Sistem Dosyaları"

    # Dosya izin kontrol listesi: dosya:beklenen_izin:beklenen_sahip:beklenen_grup
    local critical_files=(
        "/etc/passwd:644:root:root"
        "/etc/shadow:640:root:shadow"
        "/etc/group:644:root:root"
        "/etc/gshadow:640:root:shadow"
        "/etc/sudoers:440:root:root"
        "/etc/ssh/sshd_config:600:root:root"
        "/etc/crontab:644:root:root"
        "/etc/hosts:644:root:root"
        "/etc/hostname:644:root:root"
        "/etc/fstab:644:root:root"
        "/boot/grub/grub.cfg:600:root:root"
    )

    for entry in "${critical_files[@]}"; do
        local file expected_perms expected_owner expected_group
        IFS=':' read -r file expected_perms expected_owner expected_group <<< "$entry"

        if [[ ! -f "$file" ]]; then
            continue
        fi

        local actual_perms actual_owner actual_group
        actual_perms=$(stat -c %a "$file" 2>/dev/null || echo "000")
        actual_owner=$(stat -c %U "$file" 2>/dev/null || echo "unknown")
        actual_group=$(stat -c %G "$file" 2>/dev/null || echo "unknown")

        local issues=()

        # İzin kontrolü (daha gevşek izinler sorunlu)
        if [[ $actual_perms -gt $expected_perms ]]; then
            issues+=("izin=$actual_perms (beklenen: $expected_perms)")
        fi

        if [[ "$actual_owner" != "$expected_owner" ]]; then
            issues+=("sahip=$actual_owner (beklenen: $expected_owner)")
        fi

        if [[ "$actual_group" != "$expected_group" ]]; then
            issues+=("grup=$actual_group (beklenen: $expected_group)")
        fi

        if [[ ${#issues[@]} -gt 0 ]]; then
            local severity="medium"
            # shadow ve sudoers için kritik
            if [[ "$file" == *"shadow"* || "$file" == *"sudoers"* ]]; then
                severity="high"
            fi

            if [[ "$severity" == "high" ]]; then
                alert_high "Yanlış izinler: $file" \
                    "${issues[*]}" \
                    "sudo chmod $expected_perms $file && sudo chown $expected_owner:$expected_group $file" \
                    "permissions"
            else
                alert_medium "Yanlış izinler: $file" \
                    "${issues[*]}" \
                    "sudo chmod $expected_perms $file" \
                    "permissions"
            fi
        else
            alert_ok "$file izinleri doğru"
        fi
    done

    # === Home Dizinleri ===
    print_subsection "Home Dizinleri"

    # Her kullanıcının home dizini kontrolü
    while IFS=: read -r username _ uid _ _ home shell; do
        # Sistem kullanıcılarını atla
        [[ $uid -lt 1000 ]] && continue
        [[ "$shell" == *"nologin"* || "$shell" == *"false"* ]] && continue
        [[ ! -d "$home" ]] && continue

        local home_perms
        home_perms=$(stat -c %a "$home" 2>/dev/null || echo "777")

        # Home dizini başkaları tarafından yazılabilir mi?
        if [[ $((home_perms & 2)) -ne 0 ]]; then
            alert_high "Home dizini world-writable: $home ($username)" \
                "izin=$home_perms" \
                "sudo chmod o-w $home" \
                "permissions"
        elif [[ $((home_perms & 4)) -ne 0 && $((home_perms & 1)) -ne 0 ]]; then
            # Okunabilir ve çalıştırılabilir
            alert_low "Home dizini herkese açık: $home ($username)" \
                "izin=$home_perms" \
                "chmod 750 $home" \
                "permissions"
        else
            alert_ok "$username home dizini izinleri uygun ($home_perms)"
        fi
    done < /etc/passwd

    # === Log Dosyaları ===
    print_subsection "Log Dosyaları"

    local log_dirs=("/var/log" "$HOME/.local/share/security-scanner/logs")

    for log_dir in "${log_dirs[@]}"; do
        if [[ -d "$log_dir" ]]; then
            # World-writable log dosyaları
            local ww_logs
            ww_logs=$(find "$log_dir" -type f -perm -o+w 2>/dev/null | head -5 || true)

            if [[ -n "$ww_logs" ]]; then
                echo "$ww_logs" | while read -r log_file; do
                    alert_medium "World-writable log: $log_file" \
                        "Log manipülasyonu mümkün" \
                        "sudo chmod o-w $log_file" \
                        "permissions"
                done
            fi
        fi
    done

    # /var/log izinleri
    local varlog_perms
    varlog_perms=$(stat -c %a /var/log 2>/dev/null || echo "777")

    if [[ $varlog_perms -gt 755 ]]; then
        alert_medium "/var/log izinleri gevşek ($varlog_perms)" \
            "755 olmalı" \
            "sudo chmod 755 /var/log" \
            "permissions"
    fi

    # === Config Dizinleri ===
    print_subsection "Yapılandırma Dizinleri"

    local config_dirs=(
        "/etc/ssh:755"
        "/etc/ssl/private:700"
        "/etc/sudoers.d:750"
        "/etc/cron.d:755"
    )

    for entry in "${config_dirs[@]}"; do
        local dir expected_perms
        IFS=':' read -r dir expected_perms <<< "$entry"

        if [[ ! -d "$dir" ]]; then
            continue
        fi

        local actual_perms
        actual_perms=$(stat -c %a "$dir" 2>/dev/null || echo "777")

        if [[ $actual_perms -gt $expected_perms ]]; then
            alert_medium "Dizin izinleri gevşek: $dir" \
                "izin=$actual_perms (beklenen: $expected_perms)" \
                "sudo chmod $expected_perms $dir" \
                "permissions"
        else
            alert_ok "$dir izinleri doğru ($actual_perms)"
        fi
    done

    # === SSL/TLS Sertifikaları ===
    print_subsection "SSL/TLS Dosyaları"

    # Private key dosyaları
    local private_keys
    private_keys=$(find /etc/ssl/private /etc/letsencrypt/live -name "*.key" -o -name "privkey*.pem" 2>/dev/null || true)

    if [[ -n "$private_keys" ]]; then
        echo "$private_keys" | while read -r key_file; do
            local key_perms key_owner
            key_perms=$(stat -c %a "$key_file" 2>/dev/null || echo "644")
            key_owner=$(stat -c %U "$key_file" 2>/dev/null || echo "unknown")

            if [[ $key_perms -gt 600 ]]; then
                alert_high "SSL private key izinleri gevşek: $key_file" \
                    "izin=$key_perms (600 olmalı)" \
                    "sudo chmod 600 $key_file" \
                    "permissions"
            else
                alert_ok "$(basename "$key_file") izinleri doğru"
            fi
        done
    fi

    # === Executable Paths ===
    print_subsection "PATH Güvenliği"

    # PATH'deki world-writable dizinler
    local path_dirs
    IFS=':' read -ra path_dirs <<< "$PATH"

    for dir in "${path_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local dir_perms
            dir_perms=$(stat -c %a "$dir" 2>/dev/null || echo "777")

            if [[ $((dir_perms & 2)) -ne 0 ]]; then
                alert_high "PATH'de world-writable dizin: $dir" \
                    "Kötü amaçlı binary yerleştirilebilir" \
                    "sudo chmod o-w $dir" \
                    "permissions"
            fi
        fi
    done

    # Geçerli dizin PATH'de mi?
    if echo "$PATH" | grep -q "^\.\|:\.:"; then
        alert_high "PATH'de . (geçerli dizin) var" \
            "Trojan saldırılarına açık" \
            "PATH'den . kaldırın" \
            "permissions"
    fi

    # === Setuid/Setgid Scripts ===
    print_subsection "SUID/SGID Scripts"

    # SUID shell scripts
    local suid_scripts
    suid_scripts=$(find /usr /bin /sbin -type f \( -perm -4000 -o -perm -2000 \) \
        \( -name "*.sh" -o -name "*.py" -o -name "*.pl" -o -name "*.rb" \) 2>/dev/null || true)

    if [[ -n "$suid_scripts" ]]; then
        echo "$suid_scripts" | while read -r script; do
            alert_critical "SUID/SGID script: $script" \
                "Güvenlik riski - script SUID olmamalı" \
                "sudo chmod u-s,g-s $script" \
                "permissions"
        done
    else
        alert_ok "SUID/SGID script bulunamadı"
    fi

    # === Umask Kontrolü ===
    print_subsection "Umask Ayarları"

    local current_umask
    current_umask=$(umask)

    case "$current_umask" in
        "0022"|"022")
            alert_ok "Umask değeri uygun ($current_umask)"
            ;;
        "0077"|"077")
            alert_ok "Umask değeri sıkı ($current_umask)"
            ;;
        "0000"|"000"|"0002"|"002")
            alert_medium "Umask değeri gevşek ($current_umask)" \
                "Yeni dosyalar fazla açık oluşturulabilir" \
                "umask 022 veya umask 077 kullanın" \
                "permissions"
            ;;
        *)
            alert_info "Umask değeri: $current_umask"
            ;;
    esac

    # /etc/login.defs umask
    if [[ -f /etc/login.defs ]]; then
        local system_umask
        system_umask=$(grep "^UMASK" /etc/login.defs 2>/dev/null | awk '{print $2}' || echo "022")

        if [[ "$system_umask" == "000" || "$system_umask" == "002" ]]; then
            alert_medium "Sistem umask değeri gevşek ($system_umask)" \
                "/etc/login.defs UMASK ayarı" \
                "UMASK 027 veya UMASK 077 ayarlayın" \
                "permissions"
        fi
    fi

    # === Sticky Bit Kontrolü ===
    print_subsection "Sticky Bit"

    local sticky_dirs=("/tmp" "/var/tmp")

    for dir in "${sticky_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            if [[ -k "$dir" ]]; then
                alert_ok "$dir sticky bit aktif"
            else
                alert_high "$dir sticky bit yok" \
                    "Kullanıcılar birbirinin dosyalarını silebilir" \
                    "sudo chmod +t $dir" \
                    "permissions"
            fi
        fi
    done
}
