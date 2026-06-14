Write-Host "=== Flutter EPUB Reader - Project Init ===" -ForegroundColor Cyan

Write-Host "[1/3] Removing stale v1 GeneratedPluginRegistrant..."
$pluginPath = "android\app\src\main\java\io\flutter\plugins"
if (Test-Path $pluginPath) {
    Remove-Item -Recurse -Force $pluginPath
    Write-Host "       Done."
} else {
    Write-Host "       Skipped (not found)."
}

Write-Host "[2/3] Configuring Gradle mirror (Tencent)..."
$propsPath = "android\gradle\wrapper\gradle-wrapper.properties"
$content = Get-Content $propsPath -Raw
$content = $content -replace 'https://services.gradle.org/distributions/', 'https://mirrors.cloud.tencent.com/gradle/'
Set-Content $propsPath $content -NoNewline

Write-Host "[3/3] Getting dependencies..."
flutter pub get

Write-Host "=== Init complete. Run 'flutter run' to start. ===" -ForegroundColor Green
