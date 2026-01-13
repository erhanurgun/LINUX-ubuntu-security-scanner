#!/bin/bash
# Description: Dosya sistemi güvenliğini kontrol eder (mount options, SUID, world-writable)

scan() {
    print_section "Dosya Sistemi Güvenliği"

    # === Mount Options Kontrolü ===
    print_subsection "Mount Seçenekleri"

    # /tmp kontrolü
    local tmp_mount
    tmp_mount=$(mount | grep " /tmp " || true)

    if [[ -n "$tmp_mount" ]]; then
        if echo "$tmp_mount" | grep -q "noexec"; then
            alert_ok "/tmp noexec ile mount edilmiş"
        else
            alert_medium "/tmp noexec olmadan mount edilmiş" \
                "Kötü amaçlı script'ler çalıştırılabilir" \
                "/etc/fstab'da /tmp için noexec,nosuid,nodev ekleyin" \
                "filesystem"
        fi
    else
        alert_low "/tmp ayrı bir partition değil" \
            "Ayrı partition güvenlik açısından önerilir" \
            "" \
            "filesystem"
    fi

    # /var/tmp kontrolü
    local var_tmp_mount
    var_tmp_mount=$(mount | grep " /var/tmp " || true)

    if [[ -n "$var_tmp_mount" ]]; then
        if echo "$var_tmp_mount" | grep -q "noexec"; then
            alert_ok "/var/tmp noexec ile mount edilmiş"
        else
            alert_medium "/var/tmp noexec olmadan mount edilmiş" \
                "Kötü amaçlı script'ler çalıştırılabilir" \
                "" \
                "filesystem"
        fi
    fi

    # /dev/shm kontrolü
    local shm_mount
    shm_mount=$(mount | grep " /dev/shm " || true)

    if [[ -n "$shm_mount" ]]; then
        if echo "$shm_mount" | grep -q "noexec"; then
            alert_ok "/dev/shm noexec ile mount edilmiş"
        else
            alert_medium "/dev/shm noexec olmadan mount edilmiş" \
                "Bellekte çalıştırılabilir kod konabilir" \
                "/etc/fstab: tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0" \
                "filesystem"
        fi
    fi

    # /home kontrolü
    local home_mount
    home_mount=$(mount | grep " /home " || true)

    if [[ -n "$home_mount" ]]; then
        if echo "$home_mount" | grep -q "nosuid"; then
            alert_ok "/home nosuid ile mount edilmiş"
        else
            alert_low "/home nosuid olmadan mount edilmiş" \
                "SUID dosyaları oluşturulabilir" \
                "" \
                "filesystem"
        fi
    fi

    # === SUID/SGID Dosyaları ===
    print_subsection "SUID/SGID Dosyaları"

    # Bilinen tehlikeli SUID'ler
    local dangerous_suids=(
        "/usr/bin/nmap"
        "/usr/bin/vim.basic"
        "/usr/bin/find"
        "/usr/bin/bash"
        "/usr/bin/python"
        "/usr/bin/python3"
        "/usr/bin/perl"
        "/usr/bin/ruby"
        "/usr/bin/less"
        "/usr/bin/more"
        "/usr/bin/awk"
        "/usr/bin/gdb"
    )

    for suid_file in "${dangerous_suids[@]}"; do
        if [[ -f "$suid_file" ]]; then
            local perms
            perms=$(stat -c %a "$suid_file" 2>/dev/null || echo "000")
            if [[ $perms -ge 4000 ]]; then
                alert_high "Tehlikeli SUID dosyası: $suid_file" \
                    "Bu dosya privilege escalation için kullanılabilir" \
                    "sudo chmod u-s $suid_file" \
                    "filesystem"
            fi
        fi
    done

    # Toplam SUID dosya sayısı
    local suid_count
    suid_count=$(find /usr /bin /sbin -perm -4000 2>/dev/null | wc -l)
    echo -e "    Toplam SUID dosya: $suid_count"

    # SGID dosyaları
    local sgid_count
    sgid_count=$(find /usr /bin /sbin -perm -2000 2>/dev/null | wc -l)
    echo -e "    Toplam SGID dosya: $sgid_count"

    # === World-Writable Dosyalar ===
    print_subsection "World-Writable Dosyalar"

    # Sistem dizinlerinde world-writable
    local system_ww
    system_ww=$(find /etc /usr /bin /sbin -type f -perm -o+w 2>/dev/null | head -10 || true)

    if [[ -n "$system_ww" ]]; then
        echo "$system_ww" | while read -r file; do
            alert_high "Sistem dizininde world-writable dosya: $file" \
                "Herkes bu dosyayı değiştirebilir" \
                "sudo chmod o-w $file" \
                "filesystem"
        done
    else
        alert_ok "Sistem dizinlerinde world-writable dosya yok"
    fi

    # Home dizininde world-writable (sınırlı)
    local home_ww_count
    home_ww_count=$(find "$HOME" -type f -perm -o+w \
        ! -path "*/node_modules/*" \
        ! -path "*/.cache/*" \
        ! -path "*/.local/share/Trash/*" \
        2>/dev/null | wc -l || echo "0")

    if [[ $home_ww_count -gt 0 ]]; then
        alert_low "$home_ww_count world-writable dosya home dizininde" \
            "" \
            "find ~ -type f -perm -o+w -exec chmod o-w {} \\;" \
            "filesystem"
    fi

    # === World-Writable Dizinler (sticky bit olmadan) ===
    print_subsection "World-Writable Dizinler"

    local ww_dirs
    ww_dirs=$(find / -type d -perm -0002 ! -perm -1000 \
        -not -path "/proc/*" \
        -not -path "/sys/*" \
        -not -path "/run/*" \
        2>/dev/null | head -10 || true)

    if [[ -n "$ww_dirs" ]]; then
        echo "$ww_dirs" | while read -r dir; do
            alert_medium "World-writable dizin (sticky bit yok): $dir" \
                "Herkes dosya silebilir" \
                "sudo chmod +t $dir" \
                "filesystem"
        done
    else
        alert_ok "Sticky bit olmayan world-writable dizin yok"
    fi

    # === Unowned Files ===
    print_subsection "Sahipsiz Dosyalar"

    local unowned_count
    unowned_count=$(find / -type f \( -nouser -o -nogroup \) \
        -not -path "/proc/*" \
        -not -path "/sys/*" \
        2>/dev/null | wc -l || echo "0")

    if [[ $unowned_count -gt 0 ]]; then
        alert_medium "$unowned_count sahipsiz dosya var" \
            "Silinmiş kullanıcılara ait olabilir" \
            "find / -nouser -o -nogroup 2>/dev/null | xargs chown root:root" \
            "filesystem"
    else
        alert_ok "Sahipsiz dosya yok"
    fi

    # === Kritik Dosya İzinleri ===
    print_subsection "Kritik Dosya İzinleri"

    # /etc/passwd
    check_file_perms "/etc/passwd" "644" "root" "root"
    # /etc/shadow
    check_file_perms "/etc/shadow" "640" "root" "shadow"
    # /etc/group
    check_file_perms "/etc/group" "644" "root" "root"
    # /etc/gshadow
    check_file_perms "/etc/gshadow" "640" "root" "shadow"
    # /etc/sudoers
    check_file_perms "/etc/sudoers" "440" "root" "root"

    # === SSH Key İzinleri ===
    print_subsection "SSH Key İzinleri"

    if [[ -d "$HOME/.ssh" ]]; then
        local ssh_dir_perms
        ssh_dir_perms=$(stat -c %a "$HOME/.ssh" 2>/dev/null || echo "777")

        if [[ "$ssh_dir_perms" == "700" ]]; then
            alert_ok ".ssh dizin izinleri doğru (700)"
        else
            alert_high ".ssh dizin izinleri yanlış: $ssh_dir_perms" \
                "700 olmalı" \
                "chmod 700 ~/.ssh" \
                "filesystem"
        fi

        # Private key kontrolü
        for key_file in "$HOME"/.ssh/id_*; do
            [[ ! -f "$key_file" ]] && continue
            [[ "$key_file" == *.pub ]] && continue

            local key_perms
            key_perms=$(stat -c %a "$key_file" 2>/dev/null || echo "777")

            if [[ "$key_perms" == "600" ]]; then
                alert_ok "$(basename "$key_file") izinleri doğru (600)"
            else
                alert_high "SSH key izinleri yanlış: $key_file ($key_perms)" \
                    "600 olmalı" \
                    "chmod 600 $key_file" \
                    "filesystem"
            fi
        done

        # authorized_keys kontrolü
        if [[ -f "$HOME/.ssh/authorized_keys" ]]; then
            local auth_perms
            auth_perms=$(stat -c %a "$HOME/.ssh/authorized_keys" 2>/dev/null || echo "777")

            if [[ "$auth_perms" == "600" || "$auth_perms" == "644" ]]; then
                alert_ok "authorized_keys izinleri doğru ($auth_perms)"
            else
                alert_medium "authorized_keys izinleri yanlış: $auth_perms" \
                    "600 veya 644 olmalı" \
                    "chmod 600 ~/.ssh/authorized_keys" \
                    "filesystem"
            fi
        fi
    fi
}

# Dosya izni kontrol fonksiyonu
check_file_perms() {
    local file="$1"
    local expected_perms="$2"
    local expected_owner="$3"
    local expected_group="$4"

    if [[ ! -f "$file" ]]; then
        return
    fi

    local actual_perms actual_owner actual_group
    actual_perms=$(stat -c %a "$file" 2>/dev/null || echo "000")
    actual_owner=$(stat -c %U "$file" 2>/dev/null || echo "unknown")
    actual_group=$(stat -c %G "$file" 2>/dev/null || echo "unknown")

    local issues=""

    if [[ "$actual_perms" != "$expected_perms" ]]; then
        issues+="izin=$actual_perms (beklenen: $expected_perms) "
    fi

    if [[ "$actual_owner" != "$expected_owner" ]]; then
        issues+="sahip=$actual_owner (beklenen: $expected_owner) "
    fi

    if [[ "$actual_group" != "$expected_group" ]]; then
        issues+="grup=$actual_group (beklenen: $expected_group) "
    fi

    if [[ -n "$issues" ]]; then
        alert_high "Yanlış izinler: $file" \
            "$issues" \
            "sudo chmod $expected_perms $file && sudo chown $expected_owner:$expected_group $file" \
            "filesystem"
    else
        alert_ok "$file izinleri doğru"
    fi
}
