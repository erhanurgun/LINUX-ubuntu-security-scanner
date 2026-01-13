#!/bin/bash
# Description: Ağ güvenliğini kontrol eder (açık portlar, firewall, sysctl ayarları)

scan() {
    print_section "Ağ Güvenliği"

    # === Açık Portlar ===
    print_subsection "Dinleyen Portlar"

    # TCP portları
    local listening_tcp
    listening_tcp=$(ss -tlnp 2>/dev/null | tail -n +2 || true)

    if [[ -n "$listening_tcp" ]]; then
        echo -e "    ${DIM}TCP Portları:${NC}"

        echo "$listening_tcp" | while read -r line; do
            local addr port process
            addr=$(echo "$line" | awk '{print $4}')
            port=$(echo "$addr" | rev | cut -d: -f1 | rev)
            process=$(echo "$line" | awk '{print $6}' | grep -oP '"\K[^"]+' | head -1)

            # Tüm arayüzlerde dinleyen portlar
            if echo "$addr" | grep -qE "^0\.0\.0\.0:|^\*:|^:::" ; then
                case $port in
                    22)
                        alert_medium "SSH (22) tüm arayüzlerde açık" \
                            "Process: $process" \
                            "sshd_config'de ListenAddress ile kısıtlayın" \
                            "network"
                        ;;
                    3306)
                        alert_high "MySQL (3306) tüm arayüzlerde açık" \
                            "Process: $process" \
                            "my.cnf'de bind-address = 127.0.0.1 ayarlayın" \
                            "network"
                        ;;
                    5432)
                        alert_high "PostgreSQL (5432) tüm arayüzlerde açık" \
                            "Process: $process" \
                            "postgresql.conf'de listen_addresses = 'localhost' ayarlayın" \
                            "network"
                        ;;
                    6379)
                        alert_critical "Redis (6379) tüm arayüzlerde açık" \
                            "Process: $process - ŞİFRESİZ ERİŞİM RİSKİ!" \
                            "redis.conf'de bind 127.0.0.1 ve requirepass ayarlayın" \
                            "network"
                        ;;
                    27017)
                        alert_high "MongoDB (27017) tüm arayüzlerde açık" \
                            "Process: $process" \
                            "mongod.conf'de bindIp: 127.0.0.1 ayarlayın" \
                            "network"
                        ;;
                    21)
                        alert_high "FTP (21) açık" \
                            "Process: $process - Güvensiz protokol" \
                            "SFTP veya SCP kullanın" \
                            "network"
                        ;;
                    23)
                        alert_critical "Telnet (23) açık" \
                            "Process: $process - ASLA kullanmayın!" \
                            "SSH kullanın ve telnet'i devre dışı bırakın" \
                            "network"
                        ;;
                    80|443|8080|8443)
                        alert_info "Web server ($port) açık" \
                            "Process: $process"
                        ;;
                    *)
                        if [[ $port -lt 1024 ]]; then
                            alert_low "Port $port tüm arayüzlerde açık" \
                                "Process: $process" \
                                "" \
                                "network"
                        fi
                        ;;
                esac
            else
                echo -e "      ${GREEN}[+]${NC} $addr ($process)"
            fi
        done
    else
        alert_ok "Açık TCP portu bulunamadı"
    fi

    # UDP portları
    local listening_udp
    listening_udp=$(ss -ulnp 2>/dev/null | tail -n +2 | grep -E "^0\.0\.0\.0:|^\*:|^:::" || true)

    if [[ -n "$listening_udp" ]]; then
        echo ""
        echo -e "    ${DIM}UDP Portları (tüm arayüzler):${NC}"
        echo "$listening_udp" | while read -r line; do
            local port process
            port=$(echo "$line" | awk '{print $4}' | rev | cut -d: -f1 | rev)
            process=$(echo "$line" | awk '{print $6}' | grep -oP '"\K[^"]+' | head -1)
            echo -e "      ${YELLOW}!${NC} UDP $port ($process)"
        done
    fi

    # === Firewall Durumu ===
    print_subsection "Firewall"

    local fw_active=false

    # UFW
    if command_exists ufw; then
        local ufw_status
        ufw_status=$(sudo ufw status 2>/dev/null || ufw status 2>/dev/null || echo "inactive")

        if echo "$ufw_status" | grep -q "Status: active"; then
            alert_ok "UFW firewall aktif"
            fw_active=true

            # Kuralları göster
            local rule_count
            rule_count=$(sudo ufw status numbered 2>/dev/null | grep -c "^\[" || echo "0")
            echo -e "      Kural sayısı: $rule_count"
        else
            alert_high "UFW firewall devre dışı" \
                "Sistem güvenlik duvarı olmadan çalışıyor" \
                "sudo ufw enable" \
                "network"
        fi
    fi

    # iptables
    if ! $fw_active && command_exists iptables; then
        local ipt_rules
        ipt_rules=$(sudo iptables -L 2>/dev/null | grep -v "^Chain\|^target\|^$" | wc -l || echo "0")

        if [[ $ipt_rules -gt 0 ]]; then
            alert_ok "iptables kuralları mevcut ($ipt_rules kural)"
            fw_active=true
        fi
    fi

    # nftables
    if ! $fw_active && command_exists nft; then
        local nft_rules
        nft_rules=$(sudo nft list ruleset 2>/dev/null | wc -l || echo "0")

        if [[ $nft_rules -gt 5 ]]; then
            alert_ok "nftables kuralları mevcut"
            fw_active=true
        fi
    fi

    if ! $fw_active; then
        alert_high "Aktif firewall bulunamadı" \
            "Sistem güvenlik duvarı koruması yok" \
            "sudo apt install ufw && sudo ufw enable" \
            "network"
    fi

    # === Kernel Ağ Parametreleri ===
    print_subsection "Kernel Ağ Güvenliği"

    # IP Forwarding
    local ip_forward
    ip_forward=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "0")

    if [[ $ip_forward -eq 1 ]]; then
        alert_medium "IPv4 forwarding aktif" \
            "Bu sistem router olarak çalışabilir" \
            "echo 0 | sudo tee /proc/sys/net/ipv4/ip_forward" \
            "network"
    else
        alert_ok "IPv4 forwarding devre dışı"
    fi

    # ICMP redirects
    local icmp_redirect
    icmp_redirect=$(cat /proc/sys/net/ipv4/conf/all/accept_redirects 2>/dev/null || echo "1")

    if [[ $icmp_redirect -eq 1 ]]; then
        alert_low "ICMP redirects kabul ediliyor" \
            "MITM saldırılarına açık olabilir" \
            "echo 0 | sudo tee /proc/sys/net/ipv4/conf/all/accept_redirects" \
            "network"
    else
        alert_ok "ICMP redirects devre dışı"
    fi

    # Source routing
    local source_route
    source_route=$(cat /proc/sys/net/ipv4/conf/all/accept_source_route 2>/dev/null || echo "1")

    if [[ $source_route -eq 1 ]]; then
        alert_medium "Source routing kabul ediliyor" \
            "Güvenlik riski oluşturabilir" \
            "echo 0 | sudo tee /proc/sys/net/ipv4/conf/all/accept_source_route" \
            "network"
    else
        alert_ok "Source routing devre dışı"
    fi

    # SYN cookies
    local syn_cookies
    syn_cookies=$(cat /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null || echo "0")

    if [[ $syn_cookies -eq 1 ]]; then
        alert_ok "SYN cookies aktif (SYN flood koruması)"
    else
        alert_medium "SYN cookies devre dışı" \
            "SYN flood saldırılarına karşı savunmasız" \
            "echo 1 | sudo tee /proc/sys/net/ipv4/tcp_syncookies" \
            "network"
    fi

    # Reverse path filtering
    local rp_filter
    rp_filter=$(cat /proc/sys/net/ipv4/conf/all/rp_filter 2>/dev/null || echo "0")

    if [[ $rp_filter -ge 1 ]]; then
        alert_ok "Reverse path filtering aktif"
    else
        alert_low "Reverse path filtering devre dışı" \
            "IP spoofing saldırılarına daha açık" \
            "echo 1 | sudo tee /proc/sys/net/ipv4/conf/all/rp_filter" \
            "network"
    fi

    # === Aktif Bağlantılar ===
    print_subsection "Aktif Bağlantılar"

    # Established connections (dış IP'ler)
    local external_conns
    external_conns=$(ss -tnp state established 2>/dev/null | \
        grep -v "127.0.0.1\|::1" | \
        awk 'NR>1 {print $4}' | \
        cut -d: -f1 | \
        sort -u | head -10 || true)

    if [[ -n "$external_conns" ]]; then
        local conn_count
        conn_count=$(echo "$external_conns" | wc -l)
        echo -e "    Dış bağlantı sayısı: $conn_count"

        # Şüpheli portlara bağlantıları kontrol et
        local suspicious_conns
        suspicious_conns=$(ss -tnp 2>/dev/null | grep -E ":4444|:5555|:1337|:31337" || true)

        if [[ -n "$suspicious_conns" ]]; then
            alert_high "Şüpheli port bağlantısı tespit edildi" \
                "Bilinen backdoor portları (4444, 5555, 1337, 31337)" \
                "Bağlantıları inceleyin: ss -tnp" \
                "network"
        fi
    fi

    # === DNS Ayarları ===
    print_subsection "DNS Yapılandırması"

    if [[ -f /etc/resolv.conf ]]; then
        local dns_servers
        dns_servers=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | head -3)

        echo -e "    DNS Sunucuları:"
        while read -r dns; do
            if [[ "$dns" == "127.0.0.53" ]]; then
                echo -e "      - $dns (systemd-resolved)"
            elif [[ "$dns" == "127.0.0.1" ]]; then
                echo -e "      - $dns (local resolver)"
            elif [[ "$dns" =~ ^(8\.8\.|1\.1\.1\.|9\.9\.9\.) ]]; then
                echo -e "      - $dns (public DNS)"
            else
                echo -e "      - $dns"
            fi
        done <<< "$dns_servers"
    fi

    # DNSSEC kontrolü (systemd-resolved)
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        local dnssec_status
        dnssec_status=$(resolvectl status 2>/dev/null | grep -i "DNSSEC" | head -1 || echo "")

        if echo "$dnssec_status" | grep -qi "yes"; then
            alert_ok "DNSSEC aktif"
        else
            alert_info "DNSSEC devre dışı veya desteklenmiyor"
        fi
    fi

    # === Network Manager Bağlantıları ===
    if command_exists nmcli; then
        print_subsection "NetworkManager"

        local active_conns
        active_conns=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | head -5)

        if [[ -n "$active_conns" ]]; then
            echo -e "    Aktif bağlantılar:"
            while IFS=: read -r name type; do
                echo -e "      - $name ($type)"
            done <<< "$active_conns"
        fi
    fi
}
