#!/bin/bash
#
# Security Scanner v0.3.2 - Raporlama Modülü (Wrapper)
# reporting.sh - Alt modülleri yükleyen ana raporlama dosyası
#
# Bu dosya SRP (Single Responsibility Principle) uyumu için
# bölünmüş modülleri source eder:
#   - lib/reporting/helpers.sh  : Yardımcı fonksiyonlar
#   - lib/reporting/json.sh     : JSON rapor oluşturma
#   - lib/reporting/html.sh     : HTML rapor oluşturma
#   - lib/reporting/management.sh : Rapor yönetimi
#

# Modül dizinini belirle
REPORTING_DIR="${SCANNER_DIR:-$(dirname "$(dirname "$(realpath "$0")")")}/lib/reporting"

# Alt modülleri yükle
_load_reporting_module() {
    local module="$1"
    local module_path="${REPORTING_DIR}/${module}.sh"

    if [[ -f "$module_path" ]]; then
        # shellcheck source=/dev/null
        source "$module_path"
    else
        echo "HATA: Raporlama modülü bulunamadı: $module_path" >&2
        return 1
    fi
}

# Tüm modülleri yükle
_load_reporting_module "helpers"
_load_reporting_module "json"
_load_reporting_module "html"
_load_reporting_module "management"
