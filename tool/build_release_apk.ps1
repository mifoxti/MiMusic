# Release APK с production API (совпадает с PUBLIC_BASE_URL на сервере).
Set-Location (Split-Path $PSScriptRoot -Parent)
flutter build apk --release --dart-define=API_BASE_URL=https://api.mifoxti.ru
