# Changelog

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
