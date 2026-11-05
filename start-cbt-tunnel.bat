@echo off
title CBT Fallback Tunnel - smkyp79.my.id
echo ============================================
echo   CBT Fallback Tunnel (smkyp79.my.id)
echo   Press Ctrl+C to stop
echo ============================================
echo.
"C:\Users\Aqbil\Downloads\cloudflared.exe" tunnel run cbt-fallback
pause