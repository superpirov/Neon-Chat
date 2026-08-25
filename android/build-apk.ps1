# Пересборка APK: копирует веб-файлы в Android-проект и собирает подписанный APK
# Запуск из корня репозитория: powershell -File android\build-apk.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$assets = Join-Path $PSScriptRoot 'app\src\main\assets\public'

Write-Host '>> Копирую веб-файлы...'
New-Item -ItemType Directory -Force -Path $assets | Out-Null
foreach ($f in 'index.html','sw.js','manifest.json','icon-192.png','icon-512.png') {
    Copy-Item (Join-Path $root $f) $assets -Force
}

$gradle = Join-Path $env:LOCALAPPDATA 'Programs\gradle-8.11.1\bin\gradle.bat'
if (-not (Test-Path $gradle)) {
    Write-Host '>> Gradle не найден, скачай и распакуй в %LOCALAPPDATA%\Programs:' -ForegroundColor Yellow
    Write-Host '   https://services.gradle.org/distributions/gradle-8.11.1-bin.zip'
    exit 1
}

Write-Host '>> Собираю APK...'
& $gradle assembleRelease --console=plain
if ($LASTEXITCODE -ne 0) { Write-Host '>> Сборка не удалась' -ForegroundColor Red; exit 1 }

$out = Join-Path $PSScriptRoot 'app\build\outputs\apk\release\app-release.apk'
$dst = Join-Path $root 'NeonChat.apk'
Copy-Item $out $dst -Force
Write-Host ">> Готово: $dst" -ForegroundColor Green
