@echo off
echo [1/3] Building Flutter Web (Release)...
call flutter build web --release --base-href "/static/web/" --no-tree-shake-icons

echo [2/3] Cleaning old static files...
if exist "..\backend\disabilities\static\web" (
    powershell -Command "Remove-Item -Recurse -Force ..\backend\disabilities\static\web\*"
) else (
    mkdir "..\backend\disabilities\static\web"
)

echo [3/3] Syncing new files to Django...
powershell -Command "Copy-Item -Recurse -Force build\web\* ..\backend\disabilities\static\web"

echo ========================================
echo SUCCESS: Flutter Web and Static/Web are now 100%% synced!
echo ========================================
pause
