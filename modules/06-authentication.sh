#!/bin/bash
# Description: Kimlik doğrulama güvenliğini kontrol eder (SSH, PAM, sudo, password policy)

scan() {
    print_section "Kimlik Doğrulama Güvenliği"

    # === SSH Yapılandırması ===
    print_subsection "SSH Sunucu Yapılandırması"

    local sshd_config="/etc/ssh/sshd_config"
    local sshd_active=false

    if is_service_running ssh || is_service_running sshd; then
        sshd_active=true
        alert_info "SSH sunucusu çalışıyor"
    fi

    if [[ -f "$sshd_config" ]]; then
        # Root login
        local root_login
        root_login=$(get_sshd_param "PermitRootLogin" "prohibit-password" "$sshd_config")

        case "$root_login" in
            "yes")
                alert_high "SSH root login aktif" \
                    "PermitRootLogin yes ayarlı" \
                    "PermitRootLogin no olarak değiştirin" \
                    "authentication"
                ;;
            "no")
                alert_ok "SSH root login devre dışı"
                ;;
            *)
                alert_ok "SSH root login kısıtlı ($root_login)"
                ;;
        esac

        # Password authentication
        local pass_auth
        pass_auth=$(get_sshd_param "PasswordAuthentication" "yes" "$sshd_config")

        if [[ "$pass_auth" == "yes" ]]; then
            alert_medium "SSH password authentication aktif" \
                "Key-based authentication daha güvenli" \
                "PasswordAuthentication no olarak değiştirin" \
                "authentication"
        else
            alert_ok "SSH password authentication devre dışı"
        fi

        # Empty passwords
        local empty_pass
        empty_pass=$(get_sshd_param "PermitEmptyPasswords" "no" "$sshd_config")

        if [[ "$empty_pass" == "yes" ]]; then
            alert_critical "SSH boş şifre izni aktif" \
                "Ciddi güvenlik riski!" \
                "PermitEmptyPasswords no olarak değiştirin" \
                "authentication"
        else
            alert_ok "SSH boş şifre izni kapalı"
        fi

        # X11 Forwarding
        local x11_fwd
        x11_fwd=$(get_sshd_param "X11Forwarding" "yes" "$sshd_config")

        if [[ "$x11_fwd" == "yes" && "$sshd_active" == "true" ]]; then
            alert_low "SSH X11 forwarding aktif" \
                "Gerekli değilse kapatın" \
                "X11Forwarding no olarak değiştirin" \
                "authentication"
        fi

        # Protocol version
        local protocol
        protocol=$(get_sshd_param "Protocol" "2" "$sshd_config")

        if [[ "$protocol" == *"1"* ]]; then
            alert_critical "SSH Protocol 1 aktif" \
                "Güvensiz protokol versiyonu" \
                "Protocol 2 olarak değiştirin" \
                "authentication"
        fi

        # MaxAuthTries
        local max_auth
        max_auth=$(get_sshd_param "MaxAuthTries" "6" "$sshd_config")

        if [[ $max_auth -gt 6 ]]; then
            alert_low "SSH MaxAuthTries yüksek ($max_auth)" \
                "Brute force saldırılarına açık" \
                "MaxAuthTries 3-4 olarak ayarlayın" \
                "authentication"
        fi

        # AllowUsers/AllowGroups kontrolü
        local allow_users allow_groups
        allow_users=$(grep -E "^AllowUsers" "$sshd_config" 2>/dev/null || true)
        allow_groups=$(grep -E "^AllowGroups" "$sshd_config" 2>/dev/null || true)

        if [[ -z "$allow_users" && -z "$allow_groups" ]]; then
            alert_low "SSH kullanıcı kısıtlaması yok" \
                "AllowUsers veya AllowGroups tanımlı değil" \
                "AllowUsers veya AllowGroups ile kısıtlayın" \
                "authentication"
        else
            alert_ok "SSH kullanıcı kısıtlaması aktif"
        fi

        # Banner
        local banner
        banner=$(get_sshd_param "Banner" "" "$sshd_config")

        if [[ -z "$banner" || "$banner" == "none" ]]; then
            alert_info "SSH banner tanımlı değil" \
                "Legal uyarı banner'ı önerilir"
        fi
    fi

    # === Şifre Politikası ===
    print_subsection "Şifre Politikası"

    # login.defs kontrolü
    if [[ -f /etc/login.defs ]]; then
        local pass_max_days pass_min_days pass_min_len pass_warn_age

        pass_max_days=$(get_login_defs "PASS_MAX_DAYS" "99999")
        pass_min_days=$(get_login_defs "PASS_MIN_DAYS" "0")
        pass_min_len=$(get_login_defs "PASS_MIN_LEN" "5")
        pass_warn_age=$(get_login_defs "PASS_WARN_AGE" "7")

        if [[ $pass_max_days -gt 365 ]]; then
            alert_medium "Şifre maksimum yaşı çok yüksek ($pass_max_days gün)" \
                "90-365 gün arası önerilir" \
                "/etc/login.defs'de PASS_MAX_DAYS=90 ayarlayın" \
                "authentication"
        else
            alert_ok "Şifre maksimum yaşı: $pass_max_days gün"
        fi

        if [[ $pass_min_len -lt 8 ]]; then
            alert_medium "Minimum şifre uzunluğu düşük ($pass_min_len)" \
                "En az 8 karakter önerilir" \
                "PASS_MIN_LEN=8 ayarlayın" \
                "authentication"
        fi
    fi

    # pwquality kontrolü
    if [[ -f /etc/security/pwquality.conf ]]; then
        local minlen minclass
        minlen=$(grep "^minlen" /etc/security/pwquality.conf 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo "8")

        if [[ $minlen -lt 12 ]]; then
            alert_low "pwquality minimum uzunluk düşük ($minlen)" \
                "12+ karakter önerilir" \
                "minlen = 12 ayarlayın" \
                "authentication"
        else
            alert_ok "pwquality minimum uzunluk: $minlen"
        fi
    else
        alert_low "pwquality yapılandırması bulunamadı" \
            "Güçlü şifre politikası için yapılandırın" \
            "sudo apt install libpam-pwquality" \
            "authentication"
    fi

    # === Boş Şifreli Hesaplar ===
    print_subsection "Hesap Güvenliği"

    local empty_passwords
    empty_passwords=$(sudo awk -F: '($2 == "" || $2 == "!") {print $1}' /etc/shadow 2>/dev/null || true)

    if [[ -n "$empty_passwords" ]]; then
        echo "$empty_passwords" | while read -r user; do
            if [[ "$user" != "nobody" ]]; then
                alert_high "Boş şifreli hesap: $user" \
                    "Bu hesaba şifresiz giriş yapılabilir" \
                    "passwd $user ile şifre belirleyin veya hesabı kilitleyin" \
                    "authentication"
            fi
        done
    else
        alert_ok "Boş şifreli hesap yok"
    fi

    # Süresi dolmuş hesaplar
    local expired_accounts
    expired_accounts=$(sudo awk -F: '{if ($8 != "" && $8 <= 0) print $1}' /etc/shadow 2>/dev/null || true)

    if [[ -n "$expired_accounts" ]]; then
        alert_info "Süresi dolmuş hesaplar var: $expired_accounts"
    fi

    # === Sudo Yapılandırması ===
    print_subsection "Sudo Yapılandırması"

    # NOPASSWD kontrolü
    local nopasswd_entries
    nopasswd_entries=$(sudo grep -r "NOPASSWD" /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -v "^#" || true)

    if [[ -n "$nopasswd_entries" ]]; then
        local nopasswd_count
        nopasswd_count=$(echo "$nopasswd_entries" | wc -l)
        alert_medium "$nopasswd_count NOPASSWD sudo kuralı var" \
            "Şifresiz sudo komutları güvenlik riski" \
            "NOPASSWD kurallarını gözden geçirin" \
            "authentication"
    else
        alert_ok "NOPASSWD sudo kuralı yok"
    fi

    # ALL ALL kontrolü
    local dangerous_sudo
    dangerous_sudo=$(sudo grep -E "ALL.*ALL.*ALL" /etc/sudoers /etc/sudoers.d/* 2>/dev/null | grep -v "^#" | grep -v "%sudo\|%admin\|root" || true)

    if [[ -n "$dangerous_sudo" ]]; then
        alert_high "Tehlikeli sudo kuralı tespit edildi" \
            "Tüm komutlara erişim veren kurallar" \
            "En az yetki prensibini uygulayın" \
            "authentication"
    fi

    # Sudo grubu üyeleri
    local sudo_users
    sudo_users=$(getent group sudo 2>/dev/null | cut -d: -f4)
    local admin_users
    admin_users=$(getent group admin 2>/dev/null | cut -d: -f4)

    echo -e "    sudo grubu üyeleri: ${sudo_users:-yok}"
    echo -e "    admin grubu üyeleri: ${admin_users:-yok}"

    # === PAM Yapılandırması ===
    print_subsection "PAM Yapılandırması"

    # pam_faillock (account lockout)
    if grep -rq "pam_faillock\|pam_tally2" /etc/pam.d/ 2>/dev/null; then
        alert_ok "Hesap kilitleme (faillock) aktif"
    else
        alert_medium "Hesap kilitleme yapılandırılmamış" \
            "Brute force saldırılarına karşı koruma yok" \
            "pam_faillock modülünü yapılandırın" \
            "authentication"
    fi

    # pam_wheel (su restriction)
    if grep -q "pam_wheel" /etc/pam.d/su 2>/dev/null; then
        local wheel_required
        wheel_required=$(grep "pam_wheel" /etc/pam.d/su | grep -v "^#" | grep "required" || true)

        if [[ -n "$wheel_required" ]]; then
            alert_ok "su komutu wheel grubuyla kısıtlı"
        else
            alert_low "pam_wheel mevcut ama zorlanmıyor"
        fi
    else
        alert_info "su komutu wheel grubuyla kısıtlı değil"
    fi

    # === Son Giriş Denemeleri ===
    print_subsection "Giriş Denemeleri"

    # lastlog kontrolü
    local never_logged
    never_logged=$(lastlog 2>/dev/null | grep "Never logged in" | wc -l || echo "0")
    echo -e "    Hiç giriş yapmamış hesap: $never_logged"

    # Başarısız giriş sayısı (son 24 saat)
    local failed_logins
    failed_logins=$(journalctl -q --since "24 hours ago" 2>/dev/null | \
        grep -iE "failed|invalid|authentication failure" | wc -l || echo "0")

    if [[ $failed_logins -gt 50 ]]; then
        alert_high "Son 24 saatte $failed_logins başarısız giriş" \
            "Brute force saldırısı olabilir" \
            "Fail2ban kurun ve logları inceleyin" \
            "authentication"
    elif [[ $failed_logins -gt 10 ]]; then
        alert_medium "Son 24 saatte $failed_logins başarısız giriş" \
            "Normal üstü başarısız giriş" \
            "journalctl ile detayları inceleyin" \
            "authentication"
    else
        alert_ok "Başarısız giriş sayısı normal ($failed_logins)"
    fi

    # Fail2ban kontrolü
    if is_service_running fail2ban; then
        alert_ok "Fail2ban servisi aktif"

        # Yasaklı IP sayısı
        local banned_ips
        banned_ips=$(sudo fail2ban-client status 2>/dev/null | grep -oP "Total banned:\s+\K\d+" || echo "0")
        echo -e "    Yasaklı IP sayısı: $banned_ips"
    else
        if [[ $failed_logins -gt 10 ]]; then
            alert_medium "Fail2ban kurulu değil veya çalışmıyor" \
                "Brute force koruması önerilir" \
                "sudo apt install fail2ban && sudo systemctl enable fail2ban" \
                "authentication"
        fi
    fi
}
