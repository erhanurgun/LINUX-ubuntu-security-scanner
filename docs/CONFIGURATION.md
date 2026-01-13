# Security Scanner - Yapılandırma Rehberi

Bu doküman, Security Scanner'ın yapılandırma seçeneklerini detaylı olarak açıklar.

## Yapılandırma Dosyaları

Scanner iki yapılandırma formatını destekler:

| Dosya | Format | Konum | Açıklama |
|-------|--------|-------|----------|
| `settings.json` | JSON | config/ | Modern, yapılı yapılandırma |
| `scanner.conf` | Shell | config/ | Geriye uyumlu shell değişkenleri |

**Öncelik Sırası:**
1. Komut satırı argümanları (en yüksek)
2. settings.json
3. scanner.conf
4. Varsayılan değerler (en düşük)

---

## settings.json

### Tam Örnek

```json
{
  "scan": {
    "parallel": false,
    "threads": 4,
    "timeout": 300,
    "quick_modules": ["network", "authentication", "services"]
  },
  "modules": {
    "enabled": ["all"],
    "disabled": ["gnome-extensions"]
  },
  "reporting": {
    "format": "terminal",
    "organize_by_date": true,
    "retention_days": 90,
    "open_html_after_scan": false
  },
  "notifications": {
    "desktop": true,
    "on_severity": ["critical", "high"],
    "sound": false
  },
  "fim": {
    "enabled": true,
    "directories": ["/usr/bin", "/usr/sbin", "/etc"],
    "exclude_patterns": ["*.log", "*.tmp"],
    "hash_algorithm": "sha256"
  },
  "filters": {
    "min_severity": "low",
    "exclude_categories": []
  },
  "interface": {
    "language": "tr",
    "color": true,
    "verbose": false
  }
}
```

### Bölüm Açıklamaları

#### scan

| Anahtar | Tip | Varsayılan | Açıklama |
|---------|-----|------------|----------|
| `parallel` | boolean | false | Paralel modül çalıştırma |
| `threads` | integer | 4 | Paralel thread sayısı |
| `timeout` | integer | 300 | Maksimum tarama süresi (saniye) |
| `quick_modules` | array | [...] | --quick ile çalışacak modüller |

#### modules

| Anahtar | Tip | Varsayılan | Açıklama |
|---------|-----|------------|----------|
| `enabled` | array | ["all"] | Etkin modüller listesi |
| `disabled` | array | [] | Devre dışı modüller |

**Modül İsimleri:**
```
system-info, security-updates, kernel-security, filesystem,
network, authentication, services, permissions, malware,
fim, gnome-extensions, containers, compliance
```

#### reporting

| Anahtar | Tip | Varsayılan | Açıklama |
|---------|-----|------------|----------|
| `format` | string | "terminal" | Varsayılan rapor formatı |
| `organize_by_date` | boolean | true | Tarihe göre dizin yapısı |
| `retention_days` | integer | 90 | Rapor saklama süresi (gün) |
| `open_html_after_scan` | boolean | false | HTML'i otomatik aç |

**Format Değerleri:** `terminal`, `json`, `html`, `txt`

#### notifications

| Anahtar | Tip | Varsayılan | Açıklama |
|---------|-----|------------|----------|
| `desktop` | boolean | true | Masaüstü bildirimi |
| `on_severity` | array | ["critical", "high"] | Bildirim tetikleyiciler |
| `sound` | boolean | false | Sesli bildirim |

#### fim

| Anahtar | Tip | Varsayılan | Açıklama |
|---------|-----|------------|----------|
| `enabled` | boolean | true | FIM modülü aktif mi |
| `directories` | array | [...] | İzlenecek dizinler |
| `exclude_patterns` | array | [] | Hariç tutulacak dosya paternleri |
| `hash_algorithm` | string | "sha256" | Hash algoritması |

#### filters

| Anahtar | Tip | Varsayılan | Açıklama |
|---------|-----|------------|----------|
| `min_severity` | string | "low" | Minimum rapor edilecek seviye |
| `exclude_categories` | array | [] | Hariç tutulacak kategoriler |

**Severity Değerleri:** `critical`, `high`, `medium`, `low`, `info`

#### interface

| Anahtar | Tip | Varsayılan | Açıklama |
|---------|-----|------------|----------|
| `language` | string | "tr" | Arayüz dili |
| `color` | boolean | true | Renkli çıktı |
| `verbose` | boolean | false | Detaylı çıktı |

---

## scanner.conf

Shell tabanlı yapılandırma dosyası. Her satır `KEY=VALUE` formatındadır.

### Tam Örnek

```bash
# ==============================================
# Security Scanner Yapılandırma Dosyası
# ==============================================

# --- RAPOR AYARLARI ---
# Varsayılan rapor formatı (terminal, json, html, txt)
REPORT_FORMAT="terminal"

# Rapor saklama süresi (gün)
REPORT_RETENTION_DAYS=90

# Tarihe göre organize et
ORGANIZE_BY_DATE=true

# --- TARAMA AYARLARI ---
# Maksimum tarama süresi (saniye)
SCAN_TIMEOUT=300

# Paralel tarama
PARALLEL_SCAN=false

# Thread sayısı
SCAN_THREADS=4

# --- MODÜL AYARLARI ---
# Hızlı taramada çalışacak modüller
QUICK_MODULES="system-info,security-updates,network,authentication,services"

# Devre dışı modüller (virgül ile ayrılmış)
DISABLED_MODULES=""

# --- FIM AYARLARI ---
# File Integrity Monitoring aktif mi
FIM_ENABLED=true

# İzlenecek dizinler (boşlukla ayrılmış)
FIM_DIRECTORIES="/usr/bin /usr/sbin /etc"

# Hash algoritması (md5, sha1, sha256)
FIM_HASH_ALGORITHM="sha256"

# --- BİLDİRİM AYARLARI ---
# Masaüstü bildirimleri
DESKTOP_NOTIFICATIONS=true

# Hangi seviyelerde bildirim gönder
NOTIFY_ON_SEVERITY="critical,high"

# --- FİLTRELEME ---
# Minimum rapor edilecek seviye
MIN_SEVERITY="low"

# --- LOG AYARLARI ---
# Log saklama süresi (gün)
LOG_RETENTION_DAYS=30

# Detaylı log
VERBOSE=false
```

### Ortam Değişkenleri

Bu değişkenler ortam değişkeni olarak da ayarlanabilir:

```bash
export SECURITY_SCANNER_REPORT_FORMAT="html"
export SECURITY_SCANNER_MIN_SEVERITY="medium"
```

---

## Komut Satırı Argümanları

Yapılandırma dosyalarını geçersiz kılarlar.

### Tarama Modu

```bash
--quick, -q         # Hızlı tarama (temel kontroller)
--full              # Tam tarama (tüm modüller)
--modules LIST      # Belirli modüller (virgül ile)
--exclude LIST      # Modül hariç tut
```

### Raporlama

```bash
-f, --format FORMAT  # Rapor formatı (json,html,txt)
-o, --output FILE    # Çıktı dosyası
--list-reports       # Mevcut raporları listele
```

### Filtreleme

```bash
--critical           # Sadece kritik
--high               # Kritik + yüksek
--medium             # Orta ve üstü
--low                # Düşük ve üstü (varsayılan)
--only LEVEL         # Sadece belirtilen seviye
```

### FIM

```bash
--fim-init           # FIM baseline oluştur
--fim-check          # Değişiklikleri kontrol et
--fim-update         # Baseline'ı güncelle
```

### Diğer

```bash
--no-color           # Renksiz çıktı
--verbose, -v        # Detaylı çıktı
--quiet              # Sessiz mod
--version            # Sürüm bilgisi
--help               # Yardım
```

---

## Özel Senaryolar

### Sadece Ağ Kontrolleri

```bash
security-scanner --modules network -f json
```

### Günlük Otomatik Tarama (Cron)

```bash
# /etc/cron.d/security-scanner
0 9 * * * user /home/user/.local/bin/security-scanner --quick -f json,html
```

### CI/CD Pipeline

```bash
# Sadece kritik bulgularda hata kodu döndür
security-scanner --quick --critical --format json -o report.json
if grep -q '"severity": "critical"' report.json; then
    exit 1
fi
```

### Docker Container İçinde

```bash
docker run -v /:/host:ro security-scanner --quick
```

---

## Yapılandırma Önceliği

1. **Komut satırı**: Her zaman en yüksek öncelik
2. **settings.json**: JSON yapılandırma
3. **scanner.conf**: Shell yapılandırma
4. **Varsayılanlar**: Kod içindeki varsayılan değerler

Örnek:
```bash
# settings.json: format = "terminal"
# scanner.conf: REPORT_FORMAT="json"
# Komut satırı: -f html

# Sonuç: HTML rapor oluşturulur (komut satırı kazanır)
security-scanner -f html
```

---

## Geçerli Değerler

### Severity Seviyeleri

| Seviye | Sayı | Açıklama |
|--------|------|----------|
| critical | 5 | Kritik güvenlik açığı |
| high | 4 | Yüksek öncelikli sorun |
| medium | 3 | Orta öncelikli sorun |
| low | 2 | Düşük öncelikli sorun |
| info | 1 | Bilgilendirme |
| pass | 0 | Kontrol başarılı |

### Kategoriler

```
system, kernel, network, authentication,
services, permissions, filesystem, malware,
fim, gnome, containers, compliance, general
```

### Rapor Formatları

| Format | Uzantı | Açıklama |
|--------|--------|----------|
| terminal | - | Terminale renkli çıktı |
| json | .json | Yapılandırılmış JSON |
| html | .html | İnteraktif HTML rapor |
| txt | .txt | Düz metin |

---

## Sorun Giderme

### Yapılandırma Yüklenmedi

```bash
# Yapılandırma dosyasının yerini kontrol et
ls -la ~/.local/share/security-scanner/config/

# Verbose modda çalıştır
security-scanner --verbose --quick
```

### JSON Parse Hatası

```bash
# JSON dosyasını doğrula
jq . config/settings.json

# Sorunlu satırı bul
python3 -m json.tool config/settings.json
```

### Modül Bulunamadı

```bash
# Mevcut modülleri listele
ls -la modules/

# Modül adlarını kontrol et
security-scanner --help | grep -A 20 "Modules:"
```
