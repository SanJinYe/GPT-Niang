@echo off
pwsh.exe -NoProfile -File "%~dp0scripts\Start-CloudMusic.ps1" -CloudMusicPath "%ProgramFiles%\NetEase\CloudMusic\cloudmusic.exe" -Port 9223 -Restart
if errorlevel 1 pause
