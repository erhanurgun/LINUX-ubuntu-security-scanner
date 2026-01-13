#!/bin/bash
# Description: CIS Benchmark uyumluluk kontrolleri (Ubuntu 24.04 LTS)

scan() {
    print_section "CIS Benchmark Uyumluluk"

    local passed=0
    local failed=0
    local skipped=0

    echo -e "    ${DIM}CIS Ubuntu 24.04 LTS Benchmark kontrolleri${NC}"
    echo ""

    # === 1. Başlangıç Yapılandırması ===
    print_subsection "1. Başlangıç Yapılandırması"

    # 1.1.1.1 - cramfs modülü devre dışı
    if lsmod | grep -q cramfs 2>/dev/null; then
        alert_medium "CIS 1.1.1.1: cramfs modülü yüklü" \
            "Gereksiz dosya sistemi modülü" \
            "echo 'install cramfs /bin/true' >> /etc/modprobe.d/CIS.conf" \
            "compliance"
        failed=$((failed + 1))
    else
        alert_ok "CIS 1.1.1.1: cramfs devre dışı"
        passed=$((passed + 1))
    fi

    # 1.1.2 - /tmp ayrı partition
    if mount | grep -q " /tmp "; then
        alert_ok "CIS 1.1.2: /tmp ayrı partition"
        passed=$((passed + 1))
    else
        alert_low "CIS 1.1.2: /tmp ayrı partition değil" \
            "" \
            "Ayrı partition oluşturun veya tmpfs kullanın" \
            "compliance"
        failed=$((failed + 1))
    fi

    # 1.3.1 - AIDE kurulu
    if command_exists aide; then
        alert_ok "CIS 1.3.1: AIDE kurulu"
        passed=$((passed + 1))
    else
        alert_medium "CIS 1.3.1: AIDE kurulu değil" \
            "Dosya bütünlüğü izleme aracı" \
            "sudo apt install aide" \
            "compliance"
        failed=$((failed + 1))
    fi

    # 1.4.1 - Bootloader şifre koruması
    if grep -q "^set superusers" /boot/grub/grub.cfg 2>/dev/null; then
        alert_ok "CIS 1.4.1: GRUB şifre koruması aktif"
        passed=$((passed + 1))
    else
        alert_medium "CIS 1.4.1: GRUB şifre koruması yok" \
            "Boot parametreleri değiştirilebilir" \
            "grub-mkpasswd-pbkdf2 ile şifre oluşturun" \
            "compliance"
        failed=$((failed + 1))
    fi

    # 1.5.1 - core dump kısıtlaması
    if grep -q "hard core 0" /etc/security/limits.conf 2>/dev/null; then
        alert_ok "CIS 1.5.1: Core dump kısıtlı"
        passed=$((passed + 1))
    else
        alert_low "CIS 1.5.1: Core dump kısıtlanmamış" \
            "Hassas veri sızabilir" \
            "echo '* hard core 0' >> /etc/security/limits.conf" \
            "compliance"
        failed=$((failed + 1))
    fi

    # === 2. Servisler ===
    print_subsection "2. Servis Yapılandırması"

    # 2.1.1 - xinetd
    if is_service_running xinetd || is_service_enabled xinetd 2>/dev/null; then
        alert_medium "CIS 2.1.1: xinetd aktif" \
            "Legacy servis, systemd kullanın" \
            "sudo systemctl disable xinetd" \
            "compliance"
        failed=$((failed + 1))
    else
        alert_ok "CIS 2.1.1: xinetd devre dışı"
        passed=$((passed + 1))
    fi

    # 2.2.1 - X Window System
    if dpkg -l xserver-xorg* 2>/dev/null | grep -q "^ii" && ! pgrep -x gnome-shell &>/dev/null; then
        alert_info "CIS 2.2.1: X Window System kurulu (sunucu için gereksiz)"
    fi

    # 2.2.3 - avahi-daemon
    if is_service_running avahi-daemon; then
        alert_low "CIS 2.2.3: avahi-daemon çalışıyor" \
            "mDNS servisi, gerekli değilse kapatın" \
            "sudo systemctl disable avahi-daemon" \
            "compliance"
        failed=$((failed + 1))
    else
        alert_ok "CIS 2.2.3: avahi-daemon devre dışı"
        passed=$((passed + 1))
    fi

    # 2.2.4 - CUPS
    if is_service_running cups; then
        alert_info "CIS 2.2.4: CUPS çalışıyor (yazıcı servisi)"
    fi

    # === 3. Ağ Yapılandırması ===
    print_subsection "3. Ağ Yapılandırması"

    # 3.1.1 - IP forwarding
    local ip_forward
    ip_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
    if [[ "$ip_forward" == "0" ]]; then
        alert_ok "CIS 3.1.1: IPv4 forwarding devre dışı"
        passed=$((passed + 1))
    else
        alert_medium "CIS 3.1.1: IPv4 forwarding aktif" \
            "Router işlevi gerekli değilse kapatın" \
            "sysctl -w net.ipv4.ip_forward=0" \
            "compliance"
        failed=$((failed + 1))
    fi

    # 3.2.1 - Source routed packets
    local source_route
    source_route=$(sysctl -n net.ipv4.conf.all.accept_source_route 2>/dev/null || echo "1")
    if [[ "$source_route" == "0" ]]; then
        alert_ok "CIS 3.2.1: Source routing devre dışı"
        passed=$((passed + 1))
    else
        alert_medium "CIS 3.2.1: Source routing aktif" \
            "Spoofing saldırılarına açık" \
            "sysctl -w net.ipv4.conf.all.accept_source_route=0" \
            "compliance"
        failed=$((failed + 1))
    fi

    # 3.2.2 - ICMP redirects
    local icmp_redirect
    icmp_redirect=$(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null || echo "1")
    if [[ "$icmp_redirect" == "0" ]]; then
        alert_ok "CIS 3.2.2: ICMP redirects devre dışı"
        passed=$((passed + 1))
    else
        alert_low "CIS 3.2.2: ICMP redirects aktif" \
            "MITM saldırılarına açık" \
            "sysctl -w net.ipv4.conf.all.accept_redirects=0" \
            "compliance"
        failed=$((failed + 1))
    fi

    # 3.3.1 - TCP SYN Cookies
    local syn_cookies
    syn_cookies=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || echo "0")
    if [[ "$syn_cookies" == "1" ]]; then
        alert_ok "CIS 3.3.1: TCP SYN cookies aktif"
        passed=$((passed + 1))
    else
        alert_medium "CIS 3.3.1: TCP SYN cookies devre dışı" \
            "SYN flood saldırılarına açık" \
            "sysctl -w net.ipv4.tcp_syncookies=1" \
            "compliance"
        failed=$((failed + 1))
    fi

    # === 4. Logging ve Auditing ===
    print_subsection "4. Logging ve Auditing"

    # 4.1.1 - auditd
    if is_service_running auditd; then
        alert_ok "CIS 4.1.1: auditd çalışıyor"
        passed=$((passed + 1))
    else
        alert_medium "CIS 4.1.1: auditd çalışmıyor" \
            "Sistem denetimi için gerekli" \
            "sudo apt install auditd && sudo systemctl enable auditd" \
            "compliance"
        failed=$((failed + 1))
    fi

    # 4.2.1 - rsyslog
    if is_service_running rsyslog || is_service_running systemd-journald; then
        alert_ok "CIS 4.2.1: Logging servisi aktif"
        passed=$((passed + 1))
    else
        alert_high "CIS 4.2.1: Logging servisi yok" \
            "Sistem logları toplanmıyor" \
            "sudo systemctl enable rsyslog" \
            "compliance"
        failed=$((failed + 1))
    fi

    # 4.2.3 - /var/log izinleri
    local varlog_perms
    varlog_perms=$(stat -c %a /var/log 2>/dev/null || echo "777")
    if [[ $varlog_perms -le 755 ]]; then
        alert_ok "CIS 4.2.3: /var/log izinleri uygun"
        passed=$((passed + 1))
    else
        alert_medium "CIS 4.2.3: /var/log izinleri gevşek ($varlog_perms)" \
            "755 veya daha kısıtlı olmalı" \
            "chmod 755 /var/log" \
            "compliance"
        failed=$((failed + 1))
    fi

    # === 5. Erişim ve Kimlik Doğrulama ===
    print_subsection "5. Erişim ve Kimlik Doğrulama"

    # 5.1.1 - cron daemon
    if is_service_enabled cron; then
        alert_ok "CIS 5.1.1: cron daemon aktif"
        passed=$((passed + 1))
    fi

    # 5.2.1 - /etc/ssh/sshd_config izinleri
    if [[ -f /etc/ssh/sshd_config ]]; then
        local sshd_perms
        sshd_perms=$(stat -c %a /etc/ssh/sshd_config 2>/dev/null || echo "644")
        if [[ $sshd_perms -le 600 ]]; then
            alert_ok "CIS 5.2.1: sshd_config izinleri uygun"
            passed=$((passed + 1))
        else
            alert_medium "CIS 5.2.1: sshd_config izinleri gevşek ($sshd_perms)" \
                "600 olmalı" \
                "chmod 600 /etc/ssh/sshd_config" \
                "compliance"
            failed=$((failed + 1))
        fi
    fi

    # 5.2.4 - SSH X11 forwarding
    if grep -qE "^X11Forwarding\s+no" /etc/ssh/sshd_config 2>/dev/null; then
        alert_ok "CIS 5.2.4: SSH X11 forwarding devre dışı"
        passed=$((passed + 1))
    else
        alert_low "CIS 5.2.4: SSH X11 forwarding aktif" \
            "Gerekli değilse kapatın" \
            "X11Forwarding no" \
            "compliance"
        failed=$((failed + 1))
    fi

    # 5.2.5 - SSH MaxAuthTries
    local max_auth
    max_auth=$(grep -E "^MaxAuthTries" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "6")
    if [[ $max_auth -le 4 ]]; then
        alert_ok "CIS 5.2.5: SSH MaxAuthTries uygun ($max_auth)"
        passed=$((passed + 1))
    else
        alert_low "CIS 5.2.5: SSH MaxAuthTries yüksek ($max_auth)" \
            "4 veya daha az olmalı" \
            "MaxAuthTries 4" \
            "compliance"
        failed=$((failed + 1))
    fi

    # 5.3.1 - Password policy (pwquality)
    if [[ -f /etc/security/pwquality.conf ]]; then
        local minlen
        minlen=$(grep "^minlen" /etc/security/pwquality.conf 2>/dev/null | cut -d= -f2 | tr -d ' ' || echo "8")
        if [[ $minlen -ge 14 ]]; then
            alert_ok "CIS 5.3.1: Minimum şifre uzunluğu uygun ($minlen)"
            passed=$((passed + 1))
        else
            alert_medium "CIS 5.3.1: Minimum şifre uzunluğu düşük ($minlen)" \
                "14+ karakter önerilir" \
                "minlen = 14" \
                "compliance"
            failed=$((failed + 1))
        fi
    fi

    # === 6. Sistem Bakımı ===
    print_subsection "6. Sistem Bakımı"

    # 6.1.1 - /etc/passwd izinleri
    local passwd_perms
    passwd_perms=$(stat -c %a /etc/passwd 2>/dev/null || echo "666")
    if [[ $passwd_perms -le 644 ]]; then
        alert_ok "CIS 6.1.1: /etc/passwd izinleri uygun"
        passed=$((passed + 1))
    else
        alert_high "CIS 6.1.1: /etc/passwd izinleri gevşek ($passwd_perms)" \
            "644 olmalı" \
            "chmod 644 /etc/passwd" \
            "compliance"
        failed=$((failed + 1))
    fi

    # 6.1.2 - /etc/shadow izinleri
    local shadow_perms
    shadow_perms=$(stat -c %a /etc/shadow 2>/dev/null || echo "666")
    if [[ $shadow_perms -le 640 ]]; then
        alert_ok "CIS 6.1.2: /etc/shadow izinleri uygun"
        passed=$((passed + 1))
    else
        alert_critical "CIS 6.1.2: /etc/shadow izinleri gevşek ($shadow_perms)" \
            "640 veya daha kısıtlı olmalı" \
            "chmod 640 /etc/shadow" \
            "compliance"
        failed=$((failed + 1))
    fi

    # 6.2.1 - UID 0 hesapları
    local uid0_count
    uid0_count=$(awk -F: '($3 == 0) {print}' /etc/passwd 2>/dev/null | wc -l)
    if [[ $uid0_count -eq 1 ]]; then
        alert_ok "CIS 6.2.1: Tek UID 0 hesabı (root)"
        passed=$((passed + 1))
    else
        alert_high "CIS 6.2.1: $uid0_count UID 0 hesabı var" \
            "Sadece root olmalı" \
            "Fazla root hesaplarını kaldırın" \
            "compliance"
        failed=$((failed + 1))
    fi

    # === ÖZET ===
    print_subsection "CIS Uyumluluk Özeti"

    local total=$((passed + failed + skipped))
    local score=0
    if [[ $total -gt 0 ]]; then
        score=$((passed * 100 / total))
    fi

    echo ""
    echo -e "    ${GREEN}Geçen:${NC}   $passed"
    echo -e "    ${RED}Kalan:${NC}   $failed"
    echo -e "    ${DIM}Atlanan:${NC} $skipped"
    echo ""
    echo -e "    ${BOLD}Uyumluluk Skoru: ${NC}"

    if [[ $score -ge 80 ]]; then
        echo -e "    ${GREEN}$score%${NC}"
    elif [[ $score -ge 60 ]]; then
        echo -e "    ${YELLOW}$score%${NC}"
    else
        echo -e "    ${RED}$score%${NC}"
    fi
}
