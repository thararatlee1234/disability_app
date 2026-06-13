@echo off
set ROOT_DIR=%~dp0
echo ========================================
echo STEP 1: Building Flutter Web...
echo ========================================
cd /d "%ROOT_DIR%flutter_app"
call flutter build web --release --base-href "/static/web/" --no-tree-shake-icons

echo.
echo ========================================
echo STEP 2: Syncing to Django Static...
echo ========================================
if exist "..\backend\disabilities\static\web" (
    powershell -Command "Remove-Item -Recurse -Force ..\backend\disabilities\static\web\*"
) else (
    mkdir "..\backend\disabilities\static\web"
)
powershell -Command "Copy-Item -Recurse -Force build\web\* ..\backend\disabilities\static\web"

echo.
echo ========================================
echo STEP 3: Creating ZIP for PythonAnywhere...
echo ========================================
cd /d "%ROOT_DIR%backend"
if exist "..\backend.zip" del "..\backend.zip"
@rem ZIP the backend content into backend.zip
powershell -Command "Compress-Archive -Path config, disabilities, data, manage.py, requirements.txt, update_pa.sh -DestinationPath ..\backend.zip -Force"

echo.
echo ========================================
echo DONE! Please upload 'backend.zip' to PythonAnywhere.
echo File location: %ROOT_DIR%backend.zip
echo ========================================
pause
