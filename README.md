# Ubuntu Security Scanner

<p align="center">
  <img src="https://img.shields.io/badge/version-0.1.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/platform-Ubuntu%2020.04%2B-orange.svg" alt="Platform">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
  <img src="https://img.shields.io/badge/bash-4.0%2B-brightgreen.svg" alt="Bash">
</p>

Ubuntu ve Debian tabanlı sistemler için kapsamlı güvenlik tarama aracı. 13 farklı modülü ile sisteminizi analiz eder ve interaktif HTML raporlar oluşturur.

## Özellikler

- **13 Güvenlik Modülü**: Sistem, kernel, ağ, kimlik doğrulama, servisler ve daha fazlası
- **İnteraktif HTML Raporlar**: Tab-based navigasyon, arama, sıralama
- **Adım Adım Çözüm Rehberleri**: Her bulgu için detaylı düzeltme talimatları
- **Kopyalanabilir Komutlar**: Tek tıkla terminal komutlarını kopyala
- **File Integrity Monitoring (FIM)**: Kritik dosyalarda değişiklik takibi
- **Çoklu Rapor Formatı**: Terminal, JSON, HTML, TXT
- **Portable veya Kurulabilir**: İstediğiniz şekilde kullanın
- **Otomatik Tarama**: Systemd timer ile günlük taramalar

## Hızlı Başlangıç

### Portable Kullanım (Kurulum Gerektirmez)

Portable mod, herhangi bir kurulum yapmadan doğrudan repository'den scanner'ı kullanmanıza olanak tanır.

```bash
# Repository'yi klonlayın
git clone https://github.com/erhanurgun/LINUX-ubuntu-security-scanner.git
cd LINUX-ubuntu-security-scanner

# Doğrudan çalıştırın
./bin/security-scanner --quick

# HTML rapor oluşturun
./bin/security-scanner -f html
```

#### Herhangi Bir Dizinden Çalıştırma

**Yöntem 1: Tam Yol ile Çalıştırma**

```bash
# Absolute path kullanarak
/path/to/LINUX-ubuntu-security-scanner/bin/security-scanner --quick
```

**Yöntem 2: Alias Tanımlama (Önerilen)**

Shell yapılandırma dosyanıza (`~/.bashrc` veya `~/.zshrc`) ekleyin:

```bash
# Security Scanner Portable Aliases
export SCANNER_HOME="$HOME/path/to/LINUX-ubuntu-security-scanner"

# Ana komut
alias security-scanner="$SCANNER_HOME/bin/security-scanner"

# Kısa alias'lar
alias scan='security-scanner'
alias scan-quick='security-scanner --quick'
alias scan-full='security-scanner --full'
alias scan-html='security-scanner -f html'
alias scan-json='security-scanner -f json'
alias scan-all='security-scanner -f json,html,txt'

# FIM komutları
alias scan-fim-init='security-scanner --fim-init'
alias scan-fim='security-scanner --fim-check'

# Modül bazlı tarama
alias scan-net='security-scanner --modules network'
alias scan-auth='security-scanner --modules authentication'
alias scan-services='security-scanner --modules services'
```

Ardından terminali yenileyin:
```bash
source ~/.bashrc  # veya ~/.zshrc
```

**Yöntem 3: Symlink Oluşturma**

```bash
# ~/.local/bin dizinini oluşturun (yoksa)
mkdir -p ~/.local/bin

# Symlink oluşturun
ln -sf "/path/to/LINUX-ubuntu-security-scanner/bin/security-scanner" ~/.local/bin/security-scanner

# PATH'te değilse ekleyin (~/.bashrc veya ~/.zshrc)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### Portable Modda Raporlar

Portable modda raporlar repository içindeki `.reports/` klasörüne kaydedilir:

```
LINUX-ubuntu-security-scanner/
+-- .reports/
    +-- 2024-01-15/
    |   +-- html/scan_abc123.html
    |   +-- json/scan_abc123.json
    |   +-- txt/scan_abc123.txt
    +-- 2024-01-16/
        +-- ...
```

#### Portable vs Kurulum Karşılaştırması

| Özellik | Portable | Kurulum |
|---------|----------|---------|
| Git clone yeterli | Evet | Hayır |
| Kurulum scripti gerekli | Hayır | Evet |
| Raporlar proje içinde | Evet | Hayır (ayrı dizin) |
| `security-scanner` komutu | Manuel alias | Otomatik |
| Günlük otomatik tarama | Hayır | Evet (opsiyonel) |
| Kaldırma | Dizini sil | uninstall.sh |
| Güncelleme | `git pull` | Tekrar install.sh |

### System-Wide Kurulum

```bash
# Kurulum scriptini çalıştırın
./install.sh
```

Kurulum seçenekleri:
1. **Sadece manuel**: `security-scanner` komutu ile manuel kullanım
2. **Manuel + Otomatik**: Günlük otomatik tarama (systemd timer)

## Kullanım

### Temel Komutlar

```bash
# Hızlı tarama (kritik kontroller)
security-scanner --quick

# Tam tarama
security-scanner --full

# Belirli modülleri çalıştır
security-scanner --modules network,authentication

# HTML rapor oluştur
security-scanner -f html

# Çoklu format (JSON + HTML)
security-scanner -f json,html

# Severity filtreleme
security-scanner --high        # Sadece kritik ve yüksek
security-scanner --medium      # Orta ve üstü
security-scanner --only high   # Sadece belirli seviye
```

### Raporlama

```bash
# Rapor formatlarını belirt
security-scanner -f terminal      # Varsayılan - terminale yazdır
security-scanner -f json          # JSON rapor
security-scanner -f html          # İnteraktif HTML rapor
security-scanner -f txt           # Düz metin rapor
security-scanner -f json,html,txt # Hepsini oluştur

# Raporları listele
security-scanner --list-reports
```

Raporlar tarihe göre organize edilir:
```
.reports/
  2024-01-15/
    html/scan_abc123.html
    json/scan_abc123.json
    txt/scan_abc123.txt
```

### File Integrity Monitoring (FIM)

```bash
# Baseline oluştur
security-scanner --fim-init

# Değişiklikleri kontrol et
security-scanner --fim-check

# Baseline'ı güncelle
security-scanner --fim-update
```

### Yardım

```bash
security-scanner --help
security-scanner --version
```

## Modüller

| # | Modül | Açıklama |
|---|-------|----------|
| 01 | system-info | Sistem bilgileri ve genel durum |
| 02 | security-updates | Güvenlik güncellemeleri kontrolü |
| 03 | kernel-security | Kernel parametreleri ve ASLR/SMEP |
| 04 | filesystem | Dosya sistemi izinleri ve mount seçenekleri |
| 05 | network | Ağ yapılandırması, firewall, açık portlar |
| 06 | authentication | SSH, PAM, şifre politikaları |
| 07 | services | Çalışan servisler ve yapılandırmaları |
| 08 | permissions | SUID/SGID, world-writable dosyalar |
| 09 | malware | Şüpheli dosya ve process taraması |
| 10 | fim | File Integrity Monitoring |
| 11 | gnome-extensions | GNOME uzantı güvenlik analizi |
| 12 | containers | Docker/LXD konteyner güvenliği |
| 13 | compliance | CIS benchmark uyumluluk kontrolleri |

Detaylı modül dokümantasyonu: [docs/MODULES.md](docs/MODULES.md)

## HTML Rapor Özellikleri

Yeni HTML raporlar aşağıdaki özellikleri içerir:

### Tab Navigasyonu
Bulguları severity'ye göre filtreleyin: Tümü, Kritik, Yüksek, Orta, Düşük, Bilgi

### Arama ve Filtreleme
- Metin aramasıyla bulguları filtreleyin
- Kategoriye göre filtreleme
- Sütun başlıklarını tıklayarak sıralama

### Kopyalanabilir Komutlar
Her çözüm adımındaki terminal komutlarını tek tıkla kopyalayın.

### Adım Adım Çözüm Rehberleri
Her bulgu için:
- Sorunun etkisi
- Adım adım çözüm talimatları
- Doğrulama komutu
- İpuçları ve notlar

## Yapılandırma

### settings.json

```json
{
  "scan": {
    "parallel": false,
    "threads": 4,
    "timeout": 300
  },
  "modules": {
    "enabled": ["all"],
    "disabled": []
  },
  "reporting": {
    "format": "terminal",
    "organize_by_date": true,
    "retention_days": 90
  },
  "notifications": {
    "desktop": true,
    "on_severity": ["critical", "high"]
  },
  "filters": {
    "min_severity": "low"
  }
}
```

### scanner.conf (Shell)

```bash
# Rapor ayarları
REPORT_FORMAT="terminal"
REPORT_RETENTION_DAYS=90

# Tarama ayarları
SCAN_TIMEOUT=300
PARALLEL_SCAN=false

# FIM ayarları
FIM_ENABLED=true
FIM_DIRECTORIES="/usr/bin /usr/sbin /etc"
```

Detaylı yapılandırma rehberi: [docs/CONFIGURATION.md](docs/CONFIGURATION.md)

## Otomatik Tarama (Systemd Timer)

Kurulum sırasında seçilirse, günlük otomatik tarama etkinleştirilir:

```bash
# Timer durumunu kontrol et
systemctl --user status security-scanner.timer

# Sonraki tarama zamanını gör
systemctl --user list-timers security-scanner.timer

# Manuel tarama başlat
systemctl --user start security-scanner.service

# Tarama loglarını gör
journalctl --user -u security-scanner.service -f
```

## Dizin Yapısı

```
LINUX-ubuntu-security-scanner/
├── bin/
│   └── security-scanner      # Ana çalıştırılabilir
├── lib/
│   ├── core.sh               # Modül orkestrasyonu
│   ├── utils.sh              # Yardımcı fonksiyonlar
│   ├── reporting.sh          # Rapor oluşturma
│   └── config.sh             # Yapılandırma yükleyici
├── modules/                   # 13 tarama modülü
├── config/
│   ├── scanner.conf          # Shell yapılandırma
│   └── settings.json         # JSON yapılandırma
├── templates/
│   ├── css/styles.css        # HTML rapor stilleri
│   ├── js/report.js          # İnteraktif özellikler
│   └── remediation/          # Çözüm rehberleri (JSON)
├── data/                      # FIM baseline vb.
├── .reports/                  # Oluşturulan raporlar
├── docs/                      # Dokümantasyon
├── install.sh                 # Kurulum scripti
├── uninstall.sh               # Kaldırma scripti
└── README.md
```

## Bağımlılıklar

### Zorunlu
- Bash 4.0+
- Standart Unix araçları (grep, awk, find, etc.)

### Önerilen
- `jq` - JSON işleme (daha iyi rapor oluşturma)
- `notify-send` - Masaüstü bildirimleri
- `rkhunter` - Rootkit taraması (09-malware modülü)
- `chkrootkit` - Rootkit taraması (09-malware modülü)
- `lynis` - Ek güvenlik kontrolleri

```bash
# Önerilen paketleri kur
sudo apt install jq libnotify-bin rkhunter chkrootkit
```

## Kaldırma

```bash
./uninstall.sh
```

Seçenekler:
1. Sadece systemd timer'ı kaldır (manuel kullanım devam eder)
2. Tam kaldırma (veriler yedeklenir)
3. Tam kaldırma (yedekleme olmadan)

## Sorun Giderme

### "security-scanner: command not found"

PATH'e `~/.local/bin` ekleyin:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### jq hatası

jq kurulu değilse, JSON işlemleri sınırlı olacaktır:
```bash
sudo apt install jq
```

### İzin hatası

Root gerektiren kontroller için:
```bash
sudo security-scanner --quick
```

## Güvenlik Notları

- Scanner root olarak çalıştırıldığında daha kapsamlı sonuçlar verir
- Hassas bilgiler içeren raporları güvenli saklayın
- Otomatik tarama raporları `~/.local/share/security-scanner/reports/` altında saklanır
- Çözüm adımlarını uygulamadan önce yedek alın

## Katkıda Bulunma

1. Fork edin
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Değişikliklerinizi commit edin (`git commit -m 'Add amazing feature'`)
4. Branch'ı push edin (`git push origin feature/amazing-feature`)
5. Pull Request açın

## Lisans

MIT License - Detaylar için [LICENSE](LICENSE) dosyasına bakın.

## Yazar

**Erhan Urgun**
- GitHub: [@erhanurgun](https://github.com/erhanurgun)

## Teşekkürler

- CIS Benchmarks
- Lynis Security Auditing
- Ubuntu Security Team

---

<p align="center">
  <sub>Ubuntu sistemlerinizi güvenli tutun!</sub>
</p>
