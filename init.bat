@echo off

echo === Flutter EPUB Reader - Project Init ===

echo [1/3] Removing stale v1 GeneratedPluginRegistrant...
if not exist "android\app\src\main\java\io\flutter\plugins" goto :skip_rmdir
rmdir /s /q "android\app\src\main\java\io\flutter\plugins"
echo       Done.
goto :after_rmdir
:skip_rmdir
echo       Skipped (not found).
:after_rmdir

echo [2/3] Configuring Gradle mirror (Tencent)...
powershell -Command "(Get-Content 'android\gradle\wrapper\gradle-wrapper.properties') -replace 'https\\://services.gradle.org/distributions/', 'https\\://mirrors.cloud.tencent.com/gradle/' | Set-Content 'android\gradle\wrapper\gradle-wrapper.properties'"

echo [3/3] Getting dependencies...
flutter pub get

echo === Init complete. Run 'flutter run' to start. ===
