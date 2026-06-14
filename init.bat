@echo off

echo === Flutter EPUB Reader - Project Init ===

echo [1/5] Removing stale v1 GeneratedPluginRegistrant...
if not exist "android\app\src\main\java\io\flutter\plugins" goto :skip_rmdir
rmdir /s /q "android\app\src\main\java\io\flutter\plugins"
echo       Done.
goto :after_rmdir
:skip_rmdir
echo       Skipped (not found).
:after_rmdir

echo [2/5] Regenerating Android platform...
flutter create --platforms android .
echo       Done.

echo [3/5] Replacing android/build.gradle repositories with Aliyun mirrors...
if exist "android\build.gradle" (
    powershell -Command ^
        "$content = [System.IO.File]::ReadAllText('android/build.gradle'); " ^
        "$oldBlock = 'buildscript {'; " ^
        "$newBlock = 'buildscript {$\r    repositories {$\r        maven{ url ''https://maven.aliyun.com/repository/public/'' }$\r        maven{ url ''https://maven.aliyun.com/repository/google/'' }$\r        maven{ url ''https://maven.aliyun.com/repository/gradle-plugin/'' }$\r    }'; " ^
        "$content = $content -replace [regex]::Escape($oldBlock), $newBlock; " ^
        "$oldBlock2 = 'allprojects {'; " ^
        "$newBlock2 = 'allprojects {$\r    repositories {$\r        maven{ url ''https://maven.aliyun.com/repository/public/'' }$\r        maven{ url ''https://maven.aliyun.com/repository/google/'' }$\r        maven{ url ''https://maven.aliyun.com/repository/gradle-plugin/'' }$\r    }'; " ^
        "$content = $content -replace [regex]::Escape($oldBlock2), $newBlock2; " ^
        "[System.IO.File]::WriteAllText('android/build.gradle', $content)" 
    echo       Done.
) else (
    echo       Skipped (android/build.gradle not found).
)
echo.

echo [4/5] Replacing Gradle distribution URL with Aliyun mirror...
if exist "android\gradle\wrapper\gradle-wrapper.properties" (
    powershell -Command ^
        "(Get-Content 'android/gradle/wrapper/gradle-wrapper.properties') -replace 'https\\://services\\.gradle\\.org/distributions/gradle-.+', 'distributionUrl=https\://mirrors.aliyun.com/maven/gradle/gradle-8.14-all.zip' | Set-Content 'android/gradle/wrapper/gradle-wrapper.properties'"
    echo       Done.
) else (
    echo       Skipped (gradle-wrapper.properties not found).
)
echo.

echo [5/5] Getting dependencies...
flutter pub get

echo === Init complete (5/5). Run 'flutter run' to start. ===
