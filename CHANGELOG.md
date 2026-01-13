# Changelog

## [0.3.5] - 2026-01-13
### Fixed
- Alert-remediation tam eşleştirme: "Son 24 saatte X başarısız giriş" artık çözüm adımları gösteriyor
### Added
- templates/remediation/security-updates.json: 10 entry (güvenlik güncellemeleri modülü)
- templates/remediation/kernel-security.json: 13 entry (kernel güvenliği modülü)
- authentication.json: +14 entry (başarısız giriş, SSH ayarları, şifre politikası)
- filesystem.json: +13 entry (mount seçenekleri, SUID, SSH dizin izinleri)
- permissions.json: +13 entry (umask, world-writable, PATH güvenliği)
### Changed
- helpers.sh: security-updates ve kernel-security kategorileri ayrı JSON dosyalarına yönlendirildi

## [0.3.4] - 2026-01-13
### Fixed
- Remediation sistemi tam düzeltme: "Çözüm Adımları" artık doğru çalışıyor
### Added
- helpers.sh: 6 yeni kategori eşleştirmesi (malware, gnome, containers, compliance, fim, system)
- templates/remediation/fim.json: 7 yeni entry (FIM modülü için)
- templates/remediation/system.json: 7 yeni entry (system/kernel modülü için)
- templates/remediation/network.json: +10 entry (toplam 15)
- templates/remediation/compliance.json: +20 CIS entry (toplam 26)
- templates/remediation/services.json: +12 entry (toplam 17)
- templates/remediation/containers.json: +13 entry (toplam 18)
- templates/remediation/malware.json: +13 entry (toplam 17)
### Changed
- Tüm remediation pattern'ları Türkçe karakter desteği ile güncellendi (ş, ç, ğ, ü, ö, ı)

## [0.3.3] - 2026-01-13
### Fixed
- CRLF line endings lib/reporting/ dosyalarinda (Windows satir sonlari LF'ye donusturuldu)
- modules/05-network.sh: wc -l ciktisi normalizasyonu (iptables/nftables kural sayisi)

## [0.3.2] - 2026-01-13
### Added
- data/README.md, whitelist.conf.example, fim_whitelist.conf.example
- templates/remediation/: gnome.json, malware.json, containers.json, compliance.json
### Changed
- Config tek kaynak prensibi: settings.json genişletildi, scanner.conf deprecated
- settings.json'a exit_codes, gnome.trusted_extensions, webhook ayarları eklendi

## [0.3.0] - 2026-01-13
### Changed
- **SRP Refactoring:** lib/reporting.sh 1055 satırdan 35 satırlık wrapper'a dönüştürüldü
- lib/reporting/ dizini oluşturuldu:
  - `helpers.sh` - Yardımcı fonksiyonlar (html_escape, severity_to_turkish, SVG ikonlar)
  - `json.sh` - JSON rapor oluşturma
  - `html.sh` - HTML rapor oluşturma (TailwindCSS)
  - `management.sh` - Rapor yönetimi, listeleme, temizleme
- KISS: modules/01-system-info.sh - gereksiz "nonenone" kontrolü temizlendi

## [0.2.2] - 2026-01-13
### Fixed
- Türkçe karakter düzeltmeleri (icin->için, cozum->çözüm, vb.)
- Versiyon tutarsızlığı (header yorumlarda v0.1.0->v0.2.2)
- Pattern matching'de gereksiz ASCII fallback'ler kaldırıldı
### Added
- DRY helper fonksiyonlar (get_sshd_param, get_sysctl, get_login_defs)
### Changed
- modules/06-authentication.sh: 11 tekrar eden pattern refactor edildi
- modules/05-network.sh: 5 tekrar eden pattern refactor edildi

## [0.2.1] - 2026-01-13
### Fixed
- Tab active state bug fix (hardcoded class sorunu)
### Changed
- "Tümü Aç/Kapat" butonları kaldırıldı
### Added
- Her satıra "Detay" butonu eklendi

## [0.2.0] - 2026-01-13
### Added
- Modal Dialog ile çözüm rehberi
- ESC tuşu ve backdrop ile modal kapatma
- Kopyala butonu (çözüm adımları için)
### Fixed
- Tab active state CSS düzeltmesi
- hidden/show class yönetimi düzeltmesi

## [0.1.0] - 2026-01-13
### Added
- İlk sürüm
- JSON rapor yapısı (meta, scan, host, summary, findings_by_category)
- HTML rapor (TailwindCSS, SVG ikonlar)
- Terminal çıktısı
### Removed
- TXT rapor formatı kaldırıldı
