@echo off
setlocal

echo === Flutter EPUB Reader - Project Init ===

echo [1/4] Regenerating Android build files...
flutter create --org com.colin2wang . >nul 2>&1

echo [2/4] Removing stale v1 GeneratedPluginRegistrant...
if exist "android\app\src\main\java\io\flutter\plugins" (
    rmdir /s /q "android\app\src\main\java\io\flutter\plugins"
    echo       Done.
) else (
    echo       Skipped (not found).
)

echo [3/4] Configuring Gradle mirror (Tencent)...
powershell -Command "(Get-Content 'android\gradle\wrapper\gradle-wrapper.properties') -replace 'https\\://services.gradle.org/distributions/', 'https\\://mirrors.cloud.tencent.com/gradle/' | Set-Content 'android\gradle\wrapper\gradle-wrapper.properties'"

echo [4/4] Getting dependencies...
flutter pub get

echo === Init complete. Run 'flutter build apk' to build. ===
