@echo off
title Gym System Launcher
echo ===================================================
echo           LA FITNESS GYM SYSTEM - LAUNCHER
echo ===================================================
echo [1/2] Starting Backend Server (Port 5000)...
start "Gym Backend" cmd /k "cd /d D:\GYMSYSTEM\backend && npm start"

timeout /t 2 >nul

echo [2/2] Starting Admin App (Windows Desktop)...
start "Gym Admin Frontend" cmd /k "cd /d D:\GYMSYSTEM\frontend && flutter run -d windows"

echo ===================================================
echo Backend + Admin Desktop App launched!
echo NOTE: The Tablet/Mobile App is already installed
echo independently on your phone/emulator as "Tablet App"
echo and connects automatically whenever opened!
echo ===================================================
pause


   