#!/bin/bash
# Description: Kernel güvenlik parametrelerini kontrol eder (ASLR, SMEP, SMAP, vb.)

scan() {
    print_section "Kernel Güvenliği"

    # === ASLR (Address Space Layout Randomization) ===
    print_subsection "Bellek Koruması"

    local aslr_value
    aslr_value=$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null || echo "0")

    case $aslr_value in
        2)
            alert_ok "ASLR tamamen aktif (full randomization)"
            ;;
        1)
            alert_medium "ASLR kısmen aktif" \
                "Sadece stack/libraries randomize ediliyor, heap değil" \
                "echo 2 | sudo tee /proc/sys/kernel/randomize_va_space" \
                "kernel"
            ;;
        *)
            alert_critical "ASLR devre dışı" \
                "Address Space Layout Randomization kapalı" \
                "echo 2 | sudo tee /proc/sys/kernel/randomize_va_space" \
                "kernel"
            ;;
    esac

    # === Kernel pointer restriction ===
    local kptr_value
    kptr_value=$(cat /proc/sys/kernel/kptr_restrict 2>/dev/null || echo "0")

    case $kptr_value in
        2)
            alert_ok "Kernel pointer'ları tamamen gizli"
            ;;
        1)
            alert_ok "Kernel pointer'ları root hariç gizli"
            ;;
        *)
            alert_medium "Kernel pointer'ları açık" \
                "Kernel adresleri tüm kullanıcılara görünür" \
                "echo 1 | sudo tee /proc/sys/kernel/kptr_restrict" \
                "kernel"
            ;;
    esac

    # === dmesg restriction ===
    local dmesg_value
    dmesg_value=$(cat /proc/sys/kernel/dmesg_restrict 2>/dev/null || echo "0")

    if [[ $dmesg_value -eq 1 ]]; then
        alert_ok "dmesg erişimi kısıtlı"
    else
        alert_low "dmesg herkese açık" \
            "Normal kullanıcılar kernel loglarını okuyabilir" \
            "echo 1 | sudo tee /proc/sys/kernel/dmesg_restrict" \
            "kernel"
    fi

    # === Kernel lockdown ===
    if [[ -f /sys/kernel/security/lockdown ]]; then
        local lockdown
        lockdown=$(cat /sys/kernel/security/lockdown 2>/dev/null)

        if [[ "$lockdown" == *"[none]"* ]]; then
            alert_medium "Kernel lockdown devre dışı" \
                "Secure Boot ile lockdown önerilir" \
                "Kernel parametresi: lockdown=integrity" \
                "kernel"
        else
            alert_ok "Kernel lockdown aktif: $lockdown"
        fi
    fi

    # === Exec shield / NX ===
    print_subsection "İşlemci Güvenlik Özellikleri"

    local cpu_flags
    cpu_flags=$(grep -m1 "^flags" /proc/cpuinfo 2>/dev/null || echo "")

    # NX bit
    if echo "$cpu_flags" | grep -q " nx "; then
        alert_ok "NX (No-Execute) bit aktif"
    else
        alert_high "NX bit desteklenmiyor veya devre dışı" \
            "Buffer overflow koruması azaltılmış" \
            "" \
            "kernel"
    fi

    # SMEP
    if echo "$cpu_flags" | grep -q " smep "; then
        alert_ok "SMEP (Supervisor Mode Exec Prevention) aktif"
    else
        alert_info "SMEP desteklenmiyor" \
            "Eski CPU veya sanal makine"
    fi

    # SMAP
    if echo "$cpu_flags" | grep -q " smap "; then
        alert_ok "SMAP (Supervisor Mode Access Prevention) aktif"
    else
        alert_info "SMAP desteklenmiyor" \
            "Eski CPU veya sanal makine"
    fi

    # === Kernel modül güvenliği ===
    print_subsection "Kernel Modül Güvenliği"

    # Module loading restriction
    local modules_disabled
    modules_disabled=$(cat /proc/sys/kernel/modules_disabled 2>/dev/null || echo "0")

    if [[ $modules_disabled -eq 1 ]]; then
        alert_ok "Kernel modül yükleme devre dışı"
    else
        alert_info "Kernel modül yükleme aktif" \
            "Çalışma zamanında modül yüklenebilir"
    fi

    # Signed modules
    if [[ -f /proc/sys/kernel/module_signature_required ]]; then
        local sig_required
        sig_required=$(cat /proc/sys/kernel/module_signature_required 2>/dev/null || echo "0")

        if [[ $sig_required -eq 1 ]]; then
            alert_ok "İmzalı modül zorunluluğu aktif"
        else
            alert_medium "İmzasız kernel modülleri yüklenebilir" \
                "Güvenlik riski oluşturabilir" \
                "Kernel yapılandırmasında CONFIG_MODULE_SIG_FORCE=y" \
                "kernel"
        fi
    fi

    # === Yüklü modüller analizi ===
    print_subsection "Yüklü Kernel Modülleri"

    local module_count
    module_count=$(lsmod | wc -l)
    echo -e "    Toplam modül: $((module_count - 1))"

    # Şüpheli modülleri kontrol et
    local suspicious_modules=("rootkit" "hide" "backdoor" "keylogger" "stealth")

    for pattern in "${suspicious_modules[@]}"; do
        local found
        found=$(lsmod | grep -i "$pattern" || true)
        if [[ -n "$found" ]]; then
            alert_critical "Şüpheli kernel modülü: $pattern" \
                "Potansiyel rootkit tespit edildi" \
                "Modülü kaldırın ve sistem bütünlüğünü doğrulayın" \
                "kernel"
        fi
    done

    # Out-of-tree modülleri
    local oot_modules
    oot_modules=$(lsmod | awk 'NR>1 {print $1}' | while read -r mod; do
        modinfo "$mod" 2>/dev/null | grep -q "intree:.*N" && echo "$mod"
    done || true)

    if [[ -n "$oot_modules" ]]; then
        local oot_count
        oot_count=$(echo "$oot_modules" | wc -l)
        alert_low "$oot_count harici (out-of-tree) kernel modülü" \
            "Bu modüller kernel kaynak ağacının dışından geliyor" \
            "" \
            "kernel"
    fi

    # === Sysctl güvenlik ayarları ===
    print_subsection "Sysctl Güvenlik Parametreleri"

    # Core dump restriction
    local core_pattern
    core_pattern=$(cat /proc/sys/kernel/core_pattern 2>/dev/null || echo "")

    if [[ "$core_pattern" == *"|"* ]]; then
        # Pipe to program (e.g., apport)
        alert_ok "Core dump program aracılığıyla işleniyor"
    elif [[ -z "$core_pattern" || "$core_pattern" == "core" ]]; then
        alert_low "Core dump dosyaları oluşturulabilir" \
            "Hassas veriler içerebilir" \
            "echo '|/bin/false' | sudo tee /proc/sys/kernel/core_pattern" \
            "kernel"
    fi

    # SysRq restriction
    local sysrq
    sysrq=$(cat /proc/sys/kernel/sysrq 2>/dev/null || echo "0")

    if [[ $sysrq -eq 0 ]]; then
        alert_ok "Magic SysRq devre dışı"
    elif [[ $sysrq -eq 1 ]]; then
        alert_low "Magic SysRq tamamen aktif" \
            "Fiziksel erişimi olan biri sistemi manipüle edebilir" \
            "echo 0 | sudo tee /proc/sys/kernel/sysrq" \
            "kernel"
    else
        alert_ok "Magic SysRq kısmen kısıtlı ($sysrq)"
    fi

    # ptrace scope
    local ptrace_scope
    ptrace_scope=$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || echo "0")

    case $ptrace_scope in
        3)
            alert_ok "ptrace tamamen devre dışı"
            ;;
        2)
            alert_ok "ptrace sadece admin için aktif"
            ;;
        1)
            alert_ok "ptrace sadece parent süreçler için aktif"
            ;;
        *)
            alert_medium "ptrace kısıtlaması yok" \
                "Tüm süreçler debug edilebilir" \
                "echo 1 | sudo tee /proc/sys/kernel/yama/ptrace_scope" \
                "kernel"
            ;;
    esac

    # Unprivileged user namespaces
    local userns
    userns=$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo "1")

    if [[ $userns -eq 0 ]]; then
        alert_ok "Unprivileged user namespaces devre dışı"
    else
        alert_info "Unprivileged user namespaces aktif" \
            "Container'lar için gerekli olabilir"
    fi

    # BPF JIT hardening
    if [[ -f /proc/sys/net/core/bpf_jit_harden ]]; then
        local bpf_harden
        bpf_harden=$(cat /proc/sys/net/core/bpf_jit_harden 2>/dev/null || echo "0")

        if [[ $bpf_harden -ge 1 ]]; then
            alert_ok "BPF JIT hardening aktif ($bpf_harden)"
        else
            alert_low "BPF JIT hardening devre dışı" \
                "Spectre benzeri saldırılara karşı koruma azaltılmış" \
                "echo 2 | sudo tee /proc/sys/net/core/bpf_jit_harden" \
                "kernel"
        fi
    fi
}
