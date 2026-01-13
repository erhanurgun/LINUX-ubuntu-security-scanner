#!/bin/bash
# Description: File Integrity Monitoring - Dosya bütünlüğü izleme ve baseline karşılaştırma

# FIM yapılandırması
FIM_BASELINE="${DATA_DIR:-$HOME/.local/share/security-scanner/data}/baseline.json"
FIM_WHITELIST="${DATA_DIR:-$HOME/.local/share/security-scanner/data}/fim_whitelist.conf"

# İzlenecek dizinler
FIM_DIRECTORIES=(
    "/usr/bin"
    "/usr/sbin"
    "/bin"
    "/sbin"
    "/etc/passwd"
    "/etc/shadow"
    "/etc/group"
    "/etc/sudoers"
    "/etc/ssh/sshd_config"
    "/etc/crontab"
)

scan() {
    print_section "File Integrity Monitoring (FIM)"

    local mode="${FIM_MODE:-check}"

    case "$mode" in
        init)
            fim_init_baseline
            ;;
        update)
            fim_update_baseline
            ;;
        check|*)
            fim_check_integrity
            ;;
    esac
}

# Baseline oluştur
fim_init_baseline() {
    print_subsection "Baseline Oluşturuluyor"

    if [[ -f "$FIM_BASELINE" ]]; then
        local backup="${FIM_BASELINE}.$(date +%Y%m%d_%H%M%S).bak"
        mv "$FIM_BASELINE" "$backup"
        echo -e "    ${DIM}Eski baseline yedeklendi: $backup${NC}"
    fi

    echo "{" > "$FIM_BASELINE"
    echo '  "created": "'$(date -Iseconds)'",' >> "$FIM_BASELINE"
    echo '  "version": "1.0",' >> "$FIM_BASELINE"
    echo '  "files": {' >> "$FIM_BASELINE"

    local total_files=0
    local first_entry=true
    local dir_count=0
    local total_dirs=${#FIM_DIRECTORIES[@]}

    for target in "${FIM_DIRECTORIES[@]}"; do
        dir_count=$((dir_count + 1))

        # İlerleme göster (dizin bazlı)
        show_progress "$dir_count" "$total_dirs" 40 "Taranıyor..."

        if [[ -f "$target" ]]; then
            # Tek dosya
            local hash perms owner mtime
            hash=$(sha256sum "$target" 2>/dev/null | cut -d' ' -f1)
            perms=$(stat -c %a "$target" 2>/dev/null)
            owner=$(stat -c %U:%G "$target" 2>/dev/null)
            mtime=$(stat -c %Y "$target" 2>/dev/null)

            if [[ -n "$hash" ]]; then
                [[ "$first_entry" == "false" ]] && echo "," >> "$FIM_BASELINE"
                first_entry=false

                cat >> "$FIM_BASELINE" <<EOF
    "$target": {
      "hash": "$hash",
      "perms": "$perms",
      "owner": "$owner",
      "mtime": $mtime
    }
EOF
                total_files=$((total_files + 1))
            fi
        elif [[ -d "$target" ]]; then
            # Dizin - tüm dosyaları tara
            while IFS= read -r -d '' file; do
                [[ ! -f "$file" ]] && continue

                local hash perms owner mtime
                hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
                perms=$(stat -c %a "$file" 2>/dev/null)
                owner=$(stat -c %U:%G "$file" 2>/dev/null)
                mtime=$(stat -c %Y "$file" 2>/dev/null)

                if [[ -n "$hash" ]]; then
                    [[ "$first_entry" == "false" ]] && echo "," >> "$FIM_BASELINE"
                    first_entry=false

                    cat >> "$FIM_BASELINE" <<EOF
    "$file": {
      "hash": "$hash",
      "perms": "$perms",
      "owner": "$owner",
      "mtime": $mtime
    }
EOF
                    total_files=$((total_files + 1))
                fi
            done < <(find "$target" -type f -print0 2>/dev/null)
        fi
    done

    echo "" >> "$FIM_BASELINE"
    echo "  }" >> "$FIM_BASELINE"
    echo "}" >> "$FIM_BASELINE"

    echo ""
    alert_ok "Baseline oluşturuldu: $total_files dosya"
    echo -e "    ${DIM}Dosya: $FIM_BASELINE${NC}"
}

# Baseline güncelle
fim_update_baseline() {
    print_subsection "Baseline Güncelleniyor"

    if [[ ! -f "$FIM_BASELINE" ]]; then
        echo -e "    ${YELLOW}Baseline bulunamadı, yeni oluşturuluyor...${NC}"
        fim_init_baseline
        return
    fi

    # Önce kontrol et, sonra güncelle
    fim_check_integrity

    # Kullanıcıya sor (non-interactive modda otomatik güncelle)
    if [[ -t 0 ]]; then
        echo ""
        read -p "Baseline'ı güncellemek istiyor musunuz? [e/H] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ee]$ ]]; then
            echo "Güncelleme iptal edildi."
            return
        fi
    fi

    fim_init_baseline
}

# Bütünlük kontrolü
fim_check_integrity() {
    print_subsection "Bütünlük Kontrolü"

    if [[ ! -f "$FIM_BASELINE" ]]; then
        alert_medium "FIM baseline bulunamadı" \
            "İlk çalıştırmada baseline oluşturun" \
            "security-scanner --fim-init" \
            "fim"
        return
    fi

    # Baseline yaşı kontrolü
    local baseline_mtime
    baseline_mtime=$(stat -c %Y "$FIM_BASELINE" 2>/dev/null || echo "0")
    local current_time
    current_time=$(date +%s)
    local age_days=$(( (current_time - baseline_mtime) / 86400 ))

    if [[ $age_days -gt 30 ]]; then
        alert_low "Baseline $age_days gün eski" \
            "Düzenli güncelleme önerilir" \
            "security-scanner --fim-update" \
            "fim"
    fi

    local added=0
    local modified=0
    local deleted=0
    local permission_changed=0

    # Mevcut dosyaları kontrol et
    for target in "${FIM_DIRECTORIES[@]}"; do
        if [[ -f "$target" ]]; then
            check_file_integrity "$target"
        elif [[ -d "$target" ]]; then
            while IFS= read -r -d '' file; do
                [[ ! -f "$file" ]] && continue
                check_file_integrity "$file"
            done < <(find "$target" -type f -print0 2>/dev/null)
        fi
    done

    # Silinen dosyaları kontrol et
    if command_exists jq; then
        local baseline_files
        baseline_files=$(jq -r '.files | keys[]' "$FIM_BASELINE" 2>/dev/null)

        while read -r file; do
            if [[ ! -f "$file" ]]; then
                alert_high "Dosya silindi: $file" \
                    "Baseline'da var ama sistemde yok" \
                    "Silinme nedenini araştırın" \
                    "fim"
                deleted=$((deleted + 1))
            fi
        done <<< "$baseline_files"
    fi

    echo ""

    if [[ $modified -eq 0 && $deleted -eq 0 && $added -eq 0 && $permission_changed -eq 0 ]]; then
        alert_ok "Dosya bütünlüğü doğrulandı"
    else
        echo -e "    ${BOLD}FIM Özeti:${NC}"
        echo -e "    Değişen:  $modified"
        echo -e "    Silinen:  $deleted"
        echo -e "    Yeni:     $added"
        echo -e "    İzin:     $permission_changed"
    fi
}

# Tek dosya bütünlük kontrolü
check_file_integrity() {
    local file="$1"

    if ! command_exists jq; then
        log_warn "jq kurulu değil, FIM kontrolü atlanıyor"
        return
    fi

    # Whitelist kontrolü
    if [[ -f "$FIM_WHITELIST" ]]; then
        if grep -qF "$file" "$FIM_WHITELIST" 2>/dev/null; then
            return
        fi
    fi

    local baseline_entry
    baseline_entry=$(jq -r ".files[\"$file\"] // empty" "$FIM_BASELINE" 2>/dev/null)

    if [[ -z "$baseline_entry" ]]; then
        # Yeni dosya
        alert_medium "Yeni dosya tespit edildi: $file" \
            "Baseline'da yok" \
            "Meşru ise baseline'ı güncelleyin" \
            "fim"
        added=$((added + 1))
        return
    fi

    # Mevcut değerleri al
    local current_hash current_perms current_owner current_mtime
    current_hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
    current_perms=$(stat -c %a "$file" 2>/dev/null)
    current_owner=$(stat -c %U:%G "$file" 2>/dev/null)
    current_mtime=$(stat -c %Y "$file" 2>/dev/null)

    # Baseline değerlerini al
    local baseline_hash baseline_perms baseline_owner baseline_mtime
    baseline_hash=$(echo "$baseline_entry" | jq -r '.hash')
    baseline_perms=$(echo "$baseline_entry" | jq -r '.perms')
    baseline_owner=$(echo "$baseline_entry" | jq -r '.owner')
    baseline_mtime=$(echo "$baseline_entry" | jq -r '.mtime')

    # Hash karşılaştır
    if [[ "$current_hash" != "$baseline_hash" ]]; then
        alert_high "Dosya içeriği değişti: $file" \
            "Hash farklı - dosya modifiye edilmiş" \
            "Değişikliği doğrulayın" \
            "fim"
        modified=$((modified + 1))
        return
    fi

    # İzin karşılaştır
    if [[ "$current_perms" != "$baseline_perms" ]]; then
        alert_medium "Dosya izinleri değişti: $file" \
            "Önceki: $baseline_perms, Şimdiki: $current_perms" \
            "chmod $baseline_perms $file" \
            "fim"
        permission_changed=$((permission_changed + 1))
    fi

    # Sahiplik karşılaştır
    if [[ "$current_owner" != "$baseline_owner" ]]; then
        alert_medium "Dosya sahipliği değişti: $file" \
            "Önceki: $baseline_owner, Şimdiki: $current_owner" \
            "chown $baseline_owner $file" \
            "fim"
        permission_changed=$((permission_changed + 1))
    fi
}

# Whitelist yönetimi
fim_add_whitelist() {
    local file="$1"

    mkdir -p "$(dirname "$FIM_WHITELIST")"

    if ! grep -qF "$file" "$FIM_WHITELIST" 2>/dev/null; then
        echo "$file" >> "$FIM_WHITELIST"
        echo "Whitelist'e eklendi: $file"
    fi
}

fim_remove_whitelist() {
    local file="$1"

    if [[ -f "$FIM_WHITELIST" ]]; then
        sed -i "\|^${file}$|d" "$FIM_WHITELIST"
        echo "Whitelist'ten kaldırıldı: $file"
    fi
}

fim_list_whitelist() {
    if [[ -f "$FIM_WHITELIST" ]]; then
        echo "FIM Whitelist:"
        cat "$FIM_WHITELIST"
    else
        echo "Whitelist boş"
    fi
}
