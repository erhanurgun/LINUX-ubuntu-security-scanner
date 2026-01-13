#!/bin/bash
# Description: Servis güvenliğini kontrol eder (riskli servisler, cron, systemd)

scan() {
    print_section "Servis Güvenliği"

    # === Riskli Servisler ===
    print_subsection "Riskli Servisler"

    local risky_services=(
        "telnet:Güvensiz protokol, SSH kullanın"
        "rsh:Güvensiz protokol, SSH kullanın"
        "rlogin:Güvensiz protokol, SSH kullanın"
        "rexec:Güvensiz protokol, SSH kullanın"
        "tftp:Güvensiz dosya transfer protokolü"
        "vsftpd:FTP güvensiz, SFTP tercih edin"
        "proftpd:FTP güvensiz, SFTP tercih edin"
        "pure-ftpd:FTP güvensiz, SFTP tercih edin"
        "xinetd:Legacy super-server, systemd kullanın"
        "inetd:Legacy super-server"
    )

    local found_risky=false

    for entry in "${risky_services[@]}"; do
        local service reason
        service="${entry%%:*}"
        reason="${entry#*:}"

        if is_service_running "$service"; then
            alert_high "Riskli servis çalışıyor: $service" \
                "$reason" \
                "sudo systemctl stop $service && sudo systemctl disable $service" \
                "services"
            found_risky=true
        fi
    done

    if ! $found_risky; then
        alert_ok "Riskli servis çalışmıyor"
    fi

    # === Remote Desktop ===
    print_subsection "Remote Desktop Servisleri"

    # VNC
    if is_service_running vncserver || pgrep -x Xvnc &>/dev/null; then
        alert_medium "VNC server çalışıyor" \
            "Şifreli bağlantı (SSH tunnel) kullanın" \
            "" \
            "services"
    fi

    # GNOME Remote Desktop
    if is_service_running gnome-remote-desktop; then
        alert_medium "GNOME Remote Desktop aktif" \
            "Uzaktan erişim açık" \
            "Gerekli değilse devre dışı bırakın" \
            "services"
    fi

    # xrdp
    if is_service_running xrdp; then
        alert_medium "XRDP (RDP) server çalışıyor" \
            "Güvenli ağda kullanın" \
            "" \
            "services"
    fi

    # === Veritabanı Servisleri ===
    print_subsection "Veritabanı Servisleri"

    # MySQL/MariaDB
    if is_service_running mysql || is_service_running mariadb; then
        alert_info "MySQL/MariaDB çalışıyor"

        # Root şifre kontrolü
        if mysql -u root -e "SELECT 1" &>/dev/null 2>&1; then
            alert_critical "MySQL root şifresi yok" \
                "Şifresiz root erişimi mümkün" \
                "mysql_secure_installation çalıştırın" \
                "services"
        fi

        # Binding kontrolü
        local mysql_bind
        mysql_bind=$(grep -E "^bind-address" /etc/mysql/mysql.conf.d/mysqld.cnf 2>/dev/null || \
                     grep -E "^bind-address" /etc/mysql/mariadb.conf.d/*.cnf 2>/dev/null || true)

        if [[ -z "$mysql_bind" ]] || echo "$mysql_bind" | grep -q "0.0.0.0"; then
            alert_high "MySQL tüm arayüzlerde dinliyor" \
                "Sadece gerekli IP'lerde dinlemeli" \
                "bind-address = 127.0.0.1 ayarlayın" \
                "services"
        fi
    fi

    # PostgreSQL
    if is_service_running postgresql; then
        alert_info "PostgreSQL çalışıyor"

        # pg_hba.conf kontrolü
        local pg_trust
        pg_trust=$(sudo grep -r "trust" /etc/postgresql/*/main/pg_hba.conf 2>/dev/null | grep -v "^#" || true)

        if [[ -n "$pg_trust" ]]; then
            alert_high "PostgreSQL trust authentication kullanıyor" \
                "Şifresiz erişim mümkün" \
                "pg_hba.conf'da trust yerine md5/scram-sha-256 kullanın" \
                "services"
        fi
    fi

    # Redis
    if is_service_running redis || is_service_running redis-server; then
        alert_info "Redis çalışıyor"

        # Redis şifre kontrolü
        local redis_pass
        redis_pass=$(grep -E "^requirepass" /etc/redis/redis.conf 2>/dev/null || true)

        if [[ -z "$redis_pass" ]]; then
            alert_high "Redis şifre koruması yok" \
                "Şifresiz erişim mümkün" \
                "redis.conf'da requirepass ayarlayın" \
                "services"
        fi

        # Redis binding
        local redis_bind
        redis_bind=$(grep -E "^bind" /etc/redis/redis.conf 2>/dev/null || true)

        if [[ -z "$redis_bind" ]] || echo "$redis_bind" | grep -q "0.0.0.0"; then
            alert_high "Redis tüm arayüzlerde açık" \
                "Dışarıdan erişilebilir" \
                "bind 127.0.0.1 ayarlayın" \
                "services"
        fi
    fi

    # MongoDB
    if is_service_running mongod; then
        alert_info "MongoDB çalışıyor"

        # Auth kontrolü
        local mongo_auth
        mongo_auth=$(grep -E "authorization:" /etc/mongod.conf 2>/dev/null | grep "enabled" || true)

        if [[ -z "$mongo_auth" ]]; then
            alert_high "MongoDB authentication devre dışı" \
                "Şifresiz erişim mümkün" \
                "mongod.conf'da authorization: enabled ayarlayın" \
                "services"
        fi
    fi

    # === Cron Jobs ===
    print_subsection "Zamanlanmış Görevler (Cron)"

    # Kullanıcı cron
    local user_crons
    user_crons=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" || true)

    if [[ -n "$user_crons" ]]; then
        echo -e "    ${DIM}Kullanıcı cron işleri:${NC}"
        echo "$user_crons" | head -5 | while read -r job; do
            echo "      $job"

            # Şüpheli kalıpları kontrol et
            if echo "$job" | grep -qE "curl|wget|bash|sh|python" && echo "$job" | grep -qE "http|ftp"; then
                alert_medium "Şüpheli cron job: uzaktan script çalıştırma" \
                    "$job" \
                    "Bu job'ı inceleyin" \
                    "services"
            fi
        done
    else
        alert_ok "Kullanıcı cron işi yok"
    fi

    # Sistem cron dizinleri
    local cron_dirs=("/etc/cron.d" "/etc/cron.daily" "/etc/cron.hourly" "/etc/cron.weekly" "/etc/cron.monthly")

    for cron_dir in "${cron_dirs[@]}"; do
        if [[ -d "$cron_dir" ]]; then
            local cron_count
            cron_count=$(find "$cron_dir" -type f ! -name ".*" 2>/dev/null | wc -l)
            if [[ $cron_count -gt 0 ]]; then
                echo -e "    $(basename "$cron_dir"): $cron_count iş"
            fi
        fi
    done

    # Cron dosya izinleri
    for cron_file in /etc/crontab /etc/cron.allow /etc/cron.deny; do
        if [[ -f "$cron_file" ]]; then
            local cron_perms
            cron_perms=$(stat -c %a "$cron_file" 2>/dev/null || echo "777")
            if [[ $cron_perms -gt 644 ]]; then
                alert_medium "$cron_file izinleri gevşek ($cron_perms)" \
                    "644 veya daha kısıtlı olmalı" \
                    "sudo chmod 644 $cron_file" \
                    "services"
            fi
        fi
    done

    # === Systemd Timers ===
    print_subsection "Systemd Timers"

    local user_timers
    user_timers=$(systemctl --user list-timers --all 2>/dev/null | grep -v "^$\|^NEXT\|timers listed" | wc -l || echo "0")

    echo -e "    Kullanıcı timer'ları: $user_timers"

    # Kullanıcı timer'larını listele
    if [[ $user_timers -gt 0 ]]; then
        systemctl --user list-timers --all 2>/dev/null | grep -v "^$\|^NEXT\|timers listed" | head -5 | while read -r line; do
            local timer_name
            timer_name=$(echo "$line" | awk '{print $NF}')
            echo "      - $timer_name"
        done
    fi

    # === Başlangıç Servisleri ===
    print_subsection "Başlangıç Servisleri"

    local enabled_count
    enabled_count=$(systemctl list-unit-files --type=service --state=enabled 2>/dev/null | grep -c "enabled" || echo "0")
    echo -e "    Etkin servis sayısı: $enabled_count"

    # Şüpheli servisler
    local suspicious_services
    suspicious_services=$(systemctl list-unit-files --type=service --state=enabled 2>/dev/null | \
        grep -iE "backdoor|malware|miner|botnet" || true)

    if [[ -n "$suspicious_services" ]]; then
        alert_critical "Şüpheli servis tespit edildi" \
            "$suspicious_services" \
            "Bu servisleri hemen inceleyin" \
            "services"
    fi

    # === Socket Aktivasyonları ===
    print_subsection "Socket Aktivasyonları"

    local listening_sockets
    listening_sockets=$(systemctl list-sockets --all 2>/dev/null | grep -c "LISTENING" || echo "0")
    echo -e "    Aktif socket: $listening_sockets"

    # Tehlikeli socketler
    local dangerous_sockets=("docker.socket" "snapd.socket")

    for sock in "${dangerous_sockets[@]}"; do
        if systemctl is-active --quiet "$sock" 2>/dev/null; then
            alert_info "$sock aktif" \
                "Gerekli değilse devre dışı bırakın"
        fi
    done

    # === Web Servisleri ===
    print_subsection "Web Servisleri"

    # Apache
    if is_service_running apache2; then
        alert_info "Apache2 çalışıyor"

        # Server signature
        if grep -rq "ServerSignature On" /etc/apache2/ 2>/dev/null; then
            alert_low "Apache ServerSignature açık" \
                "Versiyon bilgisi sızdırılıyor" \
                "ServerSignature Off ayarlayın" \
                "services"
        fi
    fi

    # Nginx
    if is_service_running nginx; then
        alert_info "Nginx çalışıyor"

        # Server tokens
        if ! grep -rq "server_tokens off" /etc/nginx/ 2>/dev/null; then
            alert_low "Nginx server_tokens açık" \
                "Versiyon bilgisi sızdırılıyor" \
                "server_tokens off; ekleyin" \
                "services"
        fi
    fi

    # PHP-FPM
    if is_service_running php*-fpm 2>/dev/null || pgrep php-fpm &>/dev/null; then
        alert_info "PHP-FPM çalışıyor"

        # expose_php kontrolü
        local php_ini
        php_ini=$(find /etc/php -name "php.ini" -path "*/fpm/*" 2>/dev/null | head -1)

        if [[ -f "$php_ini" ]]; then
            if grep -q "expose_php = On" "$php_ini" 2>/dev/null; then
                alert_low "PHP expose_php açık" \
                    "PHP versiyonu HTTP header'da görünür" \
                    "expose_php = Off ayarlayın" \
                    "services"
            fi
        fi
    fi
}
