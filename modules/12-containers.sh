#!/bin/bash
# Description: Docker ve container güvenliğini kontrol eder

scan() {
    print_section "Container Güvenliği"

    # === Docker Durumu ===
    print_subsection "Docker Daemon"

    if ! command_exists docker; then
        alert_ok "Docker kurulu değil"
        return
    fi

    if ! is_service_running docker; then
        alert_info "Docker servisi çalışmıyor"
        return
    fi

    alert_info "Docker servisi aktif"

    # Docker versiyon
    local docker_version
    docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
    echo -e "    Docker versiyonu: $docker_version"

    # Docker daemon güvenlik ayarları
    local docker_info
    docker_info=$(docker info 2>/dev/null)

    # === Root Olmayan Mod ===
    if echo "$docker_info" | grep -q "rootless"; then
        alert_ok "Docker rootless modda çalışıyor"
    else
        alert_medium "Docker root olarak çalışıyor" \
            "Rootless mod daha güvenli" \
            "Docker rootless kurulumunu değerlendirin" \
            "containers"
    fi

    # === Live Restore ===
    if echo "$docker_info" | grep -q "Live Restore Enabled: true"; then
        alert_ok "Docker live restore aktif"
    else
        alert_low "Docker live restore devre dışı" \
            "Daemon restart'ta containerlar durabilir" \
            "daemon.json: live-restore: true" \
            "containers"
    fi

    # === Çalışan Container'lar ===
    print_subsection "Çalışan Container'lar"

    local running_containers
    running_containers=$(docker ps --format "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null)

    if [[ -z "$running_containers" ]]; then
        alert_ok "Çalışan container yok"
    else
        local container_count
        container_count=$(echo "$running_containers" | wc -l)
        echo -e "    Çalışan container sayısı: $container_count"
        echo ""

        while IFS=$'\t' read -r id name image status; do
            echo -e "    ${CYAN}$name${NC} ($image)"

            # Container detayları
            local container_inspect
            container_inspect=$(docker inspect "$id" 2>/dev/null)

            # Privileged mod
            if echo "$container_inspect" | jq -r '.[0].HostConfig.Privileged' 2>/dev/null | grep -q "true"; then
                alert_critical "Privileged container: $name" \
                    "Tam host erişimi var" \
                    "Privileged modu kaldırın" \
                    "containers"
            fi

            # Root kullanıcı
            local user
            user=$(echo "$container_inspect" | jq -r '.[0].Config.User' 2>/dev/null)
            if [[ -z "$user" || "$user" == "root" || "$user" == "0" ]]; then
                alert_medium "Container root olarak çalışıyor: $name" \
                    "Non-root user kullanın" \
                    "USER direktifi ekleyin" \
                    "containers"
            fi

            # Host network
            local network_mode
            network_mode=$(echo "$container_inspect" | jq -r '.[0].HostConfig.NetworkMode' 2>/dev/null)
            if [[ "$network_mode" == "host" ]]; then
                alert_high "Host network modu: $name" \
                    "Container host ağını paylaşıyor" \
                    "Ayrı network kullanın" \
                    "containers"
            fi

            # PID namespace
            local pid_mode
            pid_mode=$(echo "$container_inspect" | jq -r '.[0].HostConfig.PidMode' 2>/dev/null)
            if [[ "$pid_mode" == "host" ]]; then
                alert_high "Host PID namespace: $name" \
                    "Container host süreçlerini görebilir" \
                    "PID namespace izolasyonu kullanın" \
                    "containers"
            fi

            # Mounted volumes
            local mounts
            mounts=$(echo "$container_inspect" | jq -r '.[0].Mounts[].Source' 2>/dev/null)

            if echo "$mounts" | grep -qE "^/$|^/etc|^/var|^/root|/docker.sock"; then
                alert_high "Tehlikeli volume mount: $name" \
                    "Hassas dizinler mount edilmiş" \
                    "Volume mount'ları gözden geçirin" \
                    "containers"
            fi

            # Docker socket mount
            if echo "$mounts" | grep -q "docker.sock"; then
                alert_critical "Docker socket mount edilmiş: $name" \
                    "Container tam Docker kontrolüne sahip" \
                    "Docker socket mount'u kaldırın" \
                    "containers"
            fi

            # Capabilities
            local cap_add
            cap_add=$(echo "$container_inspect" | jq -r '.[0].HostConfig.CapAdd[]?' 2>/dev/null)

            if [[ -n "$cap_add" ]]; then
                local dangerous_caps=("SYS_ADMIN" "NET_ADMIN" "SYS_PTRACE" "DAC_OVERRIDE")
                for cap in "${dangerous_caps[@]}"; do
                    if echo "$cap_add" | grep -q "$cap"; then
                        alert_high "Tehlikeli capability: $name ($cap)" \
                            "Gereksizse kaldırın" \
                            "--cap-drop ALL --cap-add gerekli" \
                            "containers"
                    fi
                done
            fi

            # Security options
            local seccomp
            seccomp=$(echo "$container_inspect" | jq -r '.[0].HostConfig.SecurityOpt[]?' 2>/dev/null | grep seccomp)

            if echo "$seccomp" | grep -q "unconfined"; then
                alert_high "Seccomp devre dışı: $name" \
                    "Syscall filtrelemesi yok" \
                    "Default seccomp profile kullanın" \
                    "containers"
            fi

            # AppArmor
            local apparmor
            apparmor=$(echo "$container_inspect" | jq -r '.[0].AppArmorProfile' 2>/dev/null)

            if [[ "$apparmor" == "unconfined" ]]; then
                alert_medium "AppArmor devre dışı: $name" \
                    "MAC koruması yok" \
                    "Default AppArmor profile kullanın" \
                    "containers"
            fi

            echo ""
        done <<< "$running_containers"
    fi

    # === Docker Images ===
    print_subsection "Docker Images"

    local image_count
    image_count=$(docker images -q 2>/dev/null | wc -l)
    echo -e "    Toplam image: $image_count"

    # Eski/dangling images
    local dangling
    dangling=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l)

    if [[ $dangling -gt 5 ]]; then
        alert_low "$dangling dangling image var" \
            "Disk alanı boşa kullanılıyor" \
            "docker image prune" \
            "containers"
    fi

    # Latest tag kullanımı
    local latest_images
    latest_images=$(docker images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep ":latest" | wc -l)

    if [[ $latest_images -gt 0 ]]; then
        alert_low "$latest_images image :latest tag kullanıyor" \
            "Versiyon takibi zorlaşır" \
            "Spesifik version tag'leri kullanın" \
            "containers"
    fi

    # === Docker Compose ===
    print_subsection "Docker Compose"

    if command_exists docker-compose || docker compose version &>/dev/null 2>&1; then
        # Çalışan compose projeler
        local compose_projects
        compose_projects=$(docker compose ls 2>/dev/null | tail -n +2 | wc -l || echo "0")
        echo -e "    Aktif compose projesi: $compose_projects"
    fi

    # === Docker Daemon Konfigürasyonu ===
    print_subsection "Daemon Konfigürasyonu"

    local daemon_config="/etc/docker/daemon.json"

    if [[ -f "$daemon_config" ]]; then
        # TLS
        if ! grep -q "tlsverify" "$daemon_config" 2>/dev/null; then
            alert_medium "Docker TLS doğrulaması yapılandırılmamış" \
                "Uzaktan erişim güvensiz olabilir" \
                "TLS sertifikaları yapılandırın" \
                "containers"
        fi

        # Userland proxy
        if grep -q '"userland-proxy": true' "$daemon_config" 2>/dev/null; then
            alert_low "Docker userland proxy aktif" \
                "Performans kaybı ve güvenlik riski" \
                "userland-proxy: false ayarlayın" \
                "containers"
        fi

        # Logging driver
        if ! grep -q "log-driver" "$daemon_config" 2>/dev/null; then
            alert_info "Custom logging driver yapılandırılmamış"
        fi
    else
        alert_info "Docker daemon.json bulunamadı"
    fi

    # === Docker Grup Üyeliği ===
    print_subsection "Docker Grup Üyeliği"

    local docker_users
    docker_users=$(getent group docker 2>/dev/null | cut -d: -f4)

    if [[ -n "$docker_users" ]]; then
        echo -e "    docker grubu üyeleri: $docker_users"

        # Mevcut kullanıcı docker grubunda mı?
        if groups | grep -q docker; then
            alert_info "Mevcut kullanıcı docker grubunda" \
                "Root-eşdeğeri yetki"
        fi
    fi

    # === Resource Limits ===
    print_subsection "Resource Limits"

    # Memory limit olmayan containerlar
    local no_mem_limit
    no_mem_limit=$(docker ps -q 2>/dev/null | xargs -I {} docker inspect {} 2>/dev/null | \
        jq -r '.[] | select(.HostConfig.Memory == 0) | .Name' | wc -l)

    if [[ $no_mem_limit -gt 0 ]]; then
        alert_low "$no_mem_limit container memory limit'siz" \
            "DoS riski oluşturabilir" \
            "--memory flag ile limit belirleyin" \
            "containers"
    fi

    # CPU limit olmayan containerlar
    local no_cpu_limit
    no_cpu_limit=$(docker ps -q 2>/dev/null | xargs -I {} docker inspect {} 2>/dev/null | \
        jq -r '.[] | select(.HostConfig.CpuShares == 0 or .HostConfig.CpuShares == 1024) | .Name' | wc -l)

    if [[ $no_cpu_limit -gt 0 ]]; then
        alert_info "$no_cpu_limit container CPU limit'siz"
    fi
}
