# Security Scanner - Modül Dokümantasyonu

Bu doküman, Security Scanner'ın 13 güvenlik modülünü detaylı olarak açıklar.

## Modül Listesi

| # | Modül Dosyası | Kısa Açıklama |
|---|---------------|---------------|
| 01 | system-info.sh | Sistem bilgileri toplama |
| 02 | security-updates.sh | Güvenlik güncellemesi kontrolü |
| 03 | kernel-security.sh | Kernel güvenlik parametreleri |
| 04 | filesystem.sh | Dosya sistemi güvenliği |
| 05 | network.sh | Ağ yapılandırması güvenliği |
| 06 | authentication.sh | Kimlik doğrulama güvenliği |
| 07 | services.sh | Servis güvenliği |
| 08 | permissions.sh | Dosya/dizin izinleri |
| 09 | malware.sh | Zararlı yazılım taraması |
| 10 | fim.sh | File Integrity Monitoring |
| 11 | gnome-extensions.sh | GNOME uzantı güvenliği |
| 12 | containers.sh | Konteyner güvenliği |
| 13 | compliance.sh | CIS benchmark uyumluluğu |

---

## 01 - System Info (system-info.sh)

**Amaç:** Sistem hakkında genel bilgi toplar ve tarama için başlangıç noktası oluşturur.

**Kontrol Edilen Konular:**
- İşletim sistemi ve sürüm bilgisi
- Kernel sürümü
- Sistem uptime
- Bellek ve disk kullanımı
- Kullanıcı bilgileri
- Son başarılı/başarısız giriş denemeleri

**Severity:** Çoğunlukla INFO seviyesinde bulgular

**Örnek Bulgular:**
- Sistem 90 günden fazla süredir yeniden başlatılmadı
- Root hesabı son 30 günde kullanıldı
- Swap alanı yetersiz

---

## 02 - Security Updates (security-updates.sh)

**Amaç:** Bekleyen güvenlik güncellemelerini tespit eder.

**Kontrol Edilen Konular:**
- apt paket listesi güncelliği
- Bekleyen güvenlik yamaları
- Kernel güncellemeleri
- Unattended-upgrades yapılandırması
- Otomatik güncelleme durumu

**Severity:** HIGH/CRITICAL (güvenlik yamaları için)

**Örnek Bulgular:**
- X adet güvenlik güncellemesi bekliyor
- Kernel güncellemesi mevcut, yeniden başlatma gerekli
- Otomatik güvenlik güncellemeleri devre dışı

**Bağımlılıklar:** apt, apt-check

---

## 03 - Kernel Security (kernel-security.sh)

**Amaç:** Kernel seviyesinde güvenlik parametrelerini kontrol eder.

**Kontrol Edilen Konular:**
- ASLR (Address Space Layout Randomization)
- SMEP/SMAP (Intel/AMD koruma)
- Kernel modülü imzalama
- dmesg erişim kısıtlamaları
- ptrace scope
- Kernel version güvenliği

**Severity:** MEDIUM/HIGH

**Örnek Bulgular:**
- ASLR devre dışı
- Kernel 4.x, bilinen CVE'ler mevcut
- ptrace tamamen açık (container escape riski)

**Sysctl Parametreleri:**
```
kernel.randomize_va_space
kernel.dmesg_restrict
kernel.kptr_restrict
kernel.yama.ptrace_scope
```

---

## 04 - Filesystem (filesystem.sh)

**Amaç:** Dosya sistemi yapılandırması ve izinlerini kontrol eder.

**Kontrol Edilen Konular:**
- /tmp noexec mount seçeneği
- /home ayrı partition mı
- /var/log izinleri
- World-writable dizinler
- Sticky bit kontrolü
- Hassas dosya izinleri

**Severity:** MEDIUM/HIGH

**Örnek Bulgular:**
- /tmp noexec ile mount edilmemiş
- /var/tmp sticky bit eksik
- /etc/shadow izinleri yanlış (644 yerine 640 olmalı)

---

## 05 - Network (network.sh)

**Amaç:** Ağ yapılandırması ve firewall durumunu analiz eder.

**Kontrol Edilen Konular:**
- UFW/iptables firewall durumu
- Açık portlar ve dinleyen servisler
- IP forwarding
- ICMP redirect ayarları
- IPv6 durumu
- DNS yapılandırması
- Bilinen tehlikeli portlar

**Severity:** HIGH/CRITICAL (firewall için)

**Örnek Bulgular:**
- Firewall devre dışı
- MySQL (3306) tüm arayüzlerde dinliyor
- IP forwarding aktif
- Bilinmeyen port 31337 açık

**Kontrol Edilen Portlar:**
- 22 (SSH), 23 (Telnet), 25 (SMTP)
- 80/443 (HTTP/HTTPS)
- 3306 (MySQL), 5432 (PostgreSQL)
- 6379 (Redis), 27017 (MongoDB)

---

## 06 - Authentication (authentication.sh)

**Amaç:** Kimlik doğrulama ve erişim kontrollerini denetler.

**Kontrol Edilen Konular:**
- SSH yapılandırması
  - PermitRootLogin
  - PasswordAuthentication
  - Protocol version
  - X11Forwarding
- PAM yapılandırması
- Şifre politikaları (pwquality)
- Hesap kilitleme (faillock)
- Fail2ban durumu
- Boş şifreli hesaplar
- UID 0 hesaplar

**Severity:** HIGH/CRITICAL

**Örnek Bulgular:**
- SSH root girişi aktif
- Şifre minimum uzunluğu 8'den az
- Fail2ban kurulu değil
- Boş şifreli hesap tespit edildi

---

## 07 - Services (services.sh)

**Amaç:** Çalışan servisleri ve yapılandırmalarını analiz eder.

**Kontrol Edilen Konular:**
- Gereksiz servisler
  - avahi-daemon
  - cups
  - bluetooth
  - telnet
- Veritabanı güvenliği
  - MySQL root şifresi
  - Redis authentication
  - MongoDB authentication
- Web sunucu güvenliği
- SSH daemon durumu

**Severity:** MEDIUM/CRITICAL

**Örnek Bulgular:**
- Telnet servisi aktif (kritik)
- MySQL root şifresi ayarlanmamış
- Redis authentication yok
- Gereksiz avahi-daemon çalışıyor

---

## 08 - Permissions (permissions.sh)

**Amaç:** Dosya ve dizin izinlerini denetler.

**Kontrol Edilen Konular:**
- SUID/SGID dosyalar
- World-writable dosyalar
- Sahipsiz dosyalar (nouser/nogroup)
- Home dizini izinleri
- SSH anahtar izinleri
- Cron dosya izinleri
- Log dosya izinleri
- PATH dizini izinleri

**Severity:** MEDIUM/HIGH

**Örnek Bulgular:**
- Şüpheli SUID dosyası: /usr/bin/xxx
- Home dizini 755 izinli (700 olmalı)
- SSH özel anahtar 644 izinli (600 olmalı)
- World-writable dosya PATH'te

---

## 09 - Malware (malware.sh)

**Amaç:** Zararlı yazılım belirtilerini arar.

**Kontrol Edilen Konular:**
- Şüpheli process'ler
- Gizli dosyalar /tmp ve /var/tmp'de
- Rootkit tarayıcılar (rkhunter, chkrootkit)
- Cron'da şüpheli girişler
- Bilinen malware imzaları
- Kripto miner belirtileri

**Severity:** CRITICAL/HIGH

**Örnek Bulgular:**
- Şüpheli gizli dosya: /tmp/.x
- Rootkit belirtisi tespit edildi
- Kripto miner process'i çalışıyor

**Bağımlılıklar:** rkhunter, chkrootkit (opsiyonel)

---

## 10 - FIM (fim.sh)

**Amaç:** File Integrity Monitoring - kritik dosyalardaki değişiklikleri takip eder.

**Kontrol Edilen Konular:**
- /usr/bin, /usr/sbin değişiklikleri
- /etc yapılandırma değişiklikleri
- Sistem binary'leri
- Kernel modülleri

**Komutlar:**
```bash
# Baseline oluştur
security-scanner --fim-init

# Değişiklikleri kontrol et
security-scanner --fim-check

# Baseline'ı güncelle
security-scanner --fim-update
```

**Severity:** HIGH (beklenmeyen değişiklikler için)

**Örnek Bulgular:**
- /usr/bin/sudo değiştirilmiş
- Yeni dosya eklendi: /etc/cron.d/xxx
- Baseline 30 günden eski

---

## 11 - GNOME Extensions (gnome-extensions.sh)

**Amaç:** GNOME masaüstü uzantılarını güvenlik açısından analiz eder.

**Kontrol Edilen Konular:**
- Kurulu uzantılar
- Uzantı kaynakları (resmi/üçüncü parti)
- Uzantı izinleri
- Güncellilik durumu

**Severity:** LOW/MEDIUM

**Örnek Bulgular:**
- Üçüncü parti uzantı tespit edildi
- Uzantı 1 yıldır güncellenmemiş
- Bilinmeyen kaynak uzantısı

**Not:** Sadece GNOME masaüstü ortamında çalışır.

---

## 12 - Containers (containers.sh)

**Amaç:** Docker ve LXD konteyner güvenliğini denetler.

**Kontrol Edilen Konular:**
- Docker daemon yapılandırması
- Container'lar privileged mi?
- Root olarak çalışan container'lar
- Docker grup üyelikleri
- Network izolasyonu
- Volume mount'lar (hassas dizinler)
- Docker API erişimi
- LXD profilleri

**Severity:** HIGH/CRITICAL

**Örnek Bulgular:**
- Privileged container çalışıyor
- Docker socket world-readable
- Container root olarak çalışıyor
- /etc veya /root mount edilmiş

**Bağımlılıklar:** docker, lxc (opsiyonel)

---

## 13 - Compliance (compliance.sh)

**Amaç:** CIS Benchmark ve en iyi pratiklere uyumluluk kontrolü.

**Kontrol Edilen Konular:**
- CIS Ubuntu Benchmark kontrolleri
- Dosya sistemi yapılandırması
- Boot loader güvenliği
- Servis yapılandırmaları
- Ağ parametreleri
- Loglama yapılandırması
- Audit kuralları

**Severity:** Değişken (kontrol bazında)

**Örnek Bulgular:**
- CIS 1.1.1: /tmp ayrı partition değil
- CIS 5.2.1: SSH Protocol 2 kullanılmıyor
- Auditd kurulu değil

---

## Modülleri Seçmeli Çalıştırma

```bash
# Tek modül
security-scanner --modules network

# Birden fazla modül
security-scanner --modules network,authentication,services

# Modül hariç tutma
security-scanner --exclude gnome-extensions,containers
```

## Özel Modül Yazma

Kendi modülünüzü eklemek için:

1. `modules/` altında `XX-moduladi.sh` dosyası oluşturun
2. Aşağıdaki şablonu kullanın:

```bash
#!/bin/bash
# Modül: XX - Modül Adı
# Açıklama: Modülün ne yaptığını açıklayın

run_moduladi_checks() {
    print_module_header "MODÜL ADI"

    # Kontrol 1
    check_something() {
        local result
        # ... kontrol mantığı ...

        if [[ condition ]]; then
            add_finding "critical" "Başlık" "Açıklama" "category" "Çözüm önerisi"
        else
            add_pass "Kontrol başarılı"
        fi
    }

    check_something

    print_module_footer
}

# Ana fonksiyon
run_moduladi_checks
```

3. Modül otomatik olarak taramaya dahil edilecektir.
