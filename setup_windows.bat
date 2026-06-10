@echo off
set TARGET=C:\admin\disability_app
if not exist C:\admin mkdir C:\admin
if exist %TARGET% (
  echo Folder already exists: %TARGET%
) else (
  mkdir %TARGET%
)
xcopy /E /I /Y . %TARGET%
echo Project copied to %TARGET%
echo Next: cd %TARGET%\backend && run_backend.bat
pause
