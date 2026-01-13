#!/bin/bash
# Description: GNOME Shell eklentilerinin güvenlik analizi

scan() {
    print_section "GNOME Eklenti Güvenliği"

    local ext_dir="$HOME/.local/share/gnome-shell/extensions"
    local system_ext_dir="/usr/share/gnome-shell/extensions"

    # GNOME çalışıyor mu?
    if ! pgrep -x gnome-shell &>/dev/null; then
        alert_info "GNOME Shell çalışmıyor" \
            "Eklenti analizi yine de yapılacak"
    fi

    # === Kullanıcı Eklentileri ===
    print_subsection "Kullanıcı Eklentileri"

    if [[ ! -d "$ext_dir" ]]; then
        alert_ok "Kullanıcı eklentisi yok"
    else
        local user_ext_count=0
        local dangerous_count=0

        for ext_path in "$ext_dir"/*/; do
            [[ ! -d "$ext_path" ]] && continue

            local ext_name
            ext_name=$(basename "$ext_path")
            user_ext_count=$((user_ext_count + 1))

            # metadata.json kontrolü
            local metadata="$ext_path/metadata.json"
            if [[ -f "$metadata" ]]; then
                local ext_uuid ext_version ext_url
                ext_uuid=$(jq -r '.uuid // "unknown"' "$metadata" 2>/dev/null)
                ext_version=$(jq -r '.version // "?"' "$metadata" 2>/dev/null)
                ext_url=$(jq -r '.url // ""' "$metadata" 2>/dev/null)

                echo -e "    ${DIM}$ext_uuid (v$ext_version)${NC}"
            else
                alert_low "metadata.json eksik: $ext_name" \
                    "Geçersiz eklenti yapısı" \
                    "" \
                    "gnome-extensions"
            fi

            # === Tehlikeli Kod Kalıpları ===
            local js_files
            js_files=$(find "$ext_path" -name "*.js" 2>/dev/null)

            if [[ -n "$js_files" ]]; then
                # pkexec - root yetki talebi
                if grep -rql "pkexec\|polkit" "$ext_path" --include="*.js" 2>/dev/null; then
                    alert_critical "Eklenti root yetkisi talep ediyor: $ext_name" \
                        "pkexec/polkit kullanımı tespit edildi" \
                        "Eklentiyi kaldırın veya güvenilirliğini doğrulayın" \
                        "gnome-extensions"
                    dangerous_count=$((dangerous_count + 1))
                fi

                # Shell komut çalıştırma
                if grep -rqE "Gio\.Subprocess|GLib\.spawn|spawn_command_line|spawn_async" "$ext_path" --include="*.js" 2>/dev/null; then
                    alert_high "Eklenti shell komutları çalıştırıyor: $ext_name" \
                        "Subprocess spawn tespit edildi" \
                        "Eklentinin kodunu inceleyin" \
                        "gnome-extensions"
                    dangerous_count=$((dangerous_count + 1))
                fi

                # Dinamik kod çalıştırma (kod enjeksiyon riski)
                if grep -rqE "Function\s*\(|new\s+Function" "$ext_path" --include="*.js" 2>/dev/null; then
                    alert_high "Eklenti dinamik kod çalıştırıyor: $ext_name" \
                        "Kod enjeksiyonu riski" \
                        "Eklentiyi kaldırın" \
                        "gnome-extensions"
                    dangerous_count=$((dangerous_count + 1))
                fi

                # Ağ istekleri
                if grep -rqE "Soup\.|fetch\(|XMLHttpRequest|WebSocket" "$ext_path" --include="*.js" 2>/dev/null; then
                    alert_medium "Eklenti ağ bağlantısı yapıyor: $ext_name" \
                        "Dışarıya veri gönderebilir" \
                        "Hangi URL'lere bağlandığını kontrol edin" \
                        "gnome-extensions"
                fi

                # Dosya sistemi erişimi
                if grep -rqE "Gio\.File|GLib\.file_get_contents|GLib\.file_set_contents" "$ext_path" --include="*.js" 2>/dev/null; then
                    alert_low "Eklenti dosya sistemi erişimi yapıyor: $ext_name" \
                        "Okuma/yazma işlemleri tespit edildi" \
                        "" \
                        "gnome-extensions"
                fi

                # Keylogger belirtileri
                if grep -rqE "global\.stage\.connect.*key|Clutter\.KeyEvent|grab_key" "$ext_path" --include="*.js" 2>/dev/null; then
                    alert_high "Eklenti klavye olaylarını yakalıyor: $ext_name" \
                        "Potansiyel keylogger" \
                        "Eklentiyi dikkatlice inceleyin" \
                        "gnome-extensions"
                    dangerous_count=$((dangerous_count + 1))
                fi

                # Clipboard erişimi
                if grep -rqE "St\.Clipboard|Meta\.Selection" "$ext_path" --include="*.js" 2>/dev/null; then
                    alert_medium "Eklenti clipboard erişimi yapıyor: $ext_name" \
                        "Panoya erişim tespit edildi" \
                        "" \
                        "gnome-extensions"
                fi
            fi

            # === Script Dosyaları ===
            local shell_scripts
            shell_scripts=$(find "$ext_path" -name "*.sh" -type f 2>/dev/null)

            if [[ -n "$shell_scripts" ]]; then
                echo "$shell_scripts" | while read -r script; do
                    local script_perms
                    script_perms=$(stat -c %a "$script" 2>/dev/null || echo "644")

                    if [[ $((script_perms & 2)) -ne 0 ]]; then
                        alert_critical "World-writable script: $script" \
                            "Herkes bu scripti değiştirebilir" \
                            "chmod o-w $script" \
                            "gnome-extensions"
                    fi

                    # Script içeriği kontrolü
                    if grep -qE "rm -rf|curl.*\|.*bash|wget.*\|.*sh|>/dev/tcp" "$script" 2>/dev/null; then
                        alert_high "Tehlikeli script içeriği: $script" \
                            "Potansiyel zararlı komutlar" \
                            "Script içeriğini inceleyin" \
                            "gnome-extensions"
                    fi
                done
            fi
        done

        echo ""
        echo -e "    Toplam: $user_ext_count eklenti, ${RED}$dangerous_count${NC} tehlikeli"
    fi

    # === Sistem Eklentileri ===
    print_subsection "Sistem Eklentileri"

    if [[ -d "$system_ext_dir" ]]; then
        local system_ext_count
        system_ext_count=$(find "$system_ext_dir" -maxdepth 1 -type d | wc -l)
        system_ext_count=$((system_ext_count - 1))

        alert_ok "$system_ext_count sistem eklentisi (güvenilir)"
    fi

    # === Eklenti Yetkileri ===
    print_subsection "Eklenti İzinleri"

    # GNOME Extensions app üzerinden yetki kontrolü
    if command_exists gnome-extensions; then
        local enabled_extensions
        enabled_extensions=$(gnome-extensions list --enabled 2>/dev/null | wc -l || echo "0")
        local disabled_extensions
        disabled_extensions=$(gnome-extensions list --disabled 2>/dev/null | wc -l || echo "0")

        echo -e "    Etkin eklentiler: $enabled_extensions"
        echo -e "    Devre dışı: $disabled_extensions"
    fi

    # === Bilinmeyen Kaynaklar ===
    print_subsection "Kaynak Doğrulama"

    # extensions.gnome.org dışından yüklenenler
    for ext_path in "$ext_dir"/*/; do
        [[ ! -d "$ext_path" ]] && continue

        local metadata="$ext_path/metadata.json"
        if [[ -f "$metadata" ]]; then
            local ext_url
            ext_url=$(jq -r '.url // ""' "$metadata" 2>/dev/null)

            if [[ -z "$ext_url" ]]; then
                local ext_name
                ext_name=$(basename "$ext_path")
                alert_low "Kaynak URL'si yok: $ext_name" \
                    "Eklenti kaynağı doğrulanamıyor" \
                    "" \
                    "gnome-extensions"
            fi
        fi
    done

    # === GNOME Shell Güvenliği ===
    print_subsection "GNOME Shell Güvenliği"

    # Extension validation
    local disable_extension_version_validation
    disable_extension_version_validation=$(gsettings get org.gnome.shell disable-extension-version-validation 2>/dev/null || echo "false")

    if [[ "$disable_extension_version_validation" == "true" ]]; then
        alert_medium "Eklenti versiyon doğrulaması devre dışı" \
            "Uyumsuz eklentiler yüklenebilir" \
            "gsettings set org.gnome.shell disable-extension-version-validation false" \
            "gnome-extensions"
    else
        alert_ok "Eklenti versiyon doğrulaması aktif"
    fi

    # Looking glass erişimi
    if gsettings get org.gnome.shell development-tools 2>/dev/null | grep -q "true"; then
        alert_low "GNOME Looking Glass etkin" \
            "Geliştirici araçları aktif" \
            "" \
            "gnome-extensions"
    fi
}
