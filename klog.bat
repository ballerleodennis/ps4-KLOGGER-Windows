@echo off
setlocal
title PS4 KLOG Logger
cd /d "%~dp0"
chcp 65001 >nul

rem ---- Konfiguration ----
set "PORT=3232"
if not "%~2"=="" set "PORT=%~2"
set "IP=%~1"
set "SCRIPT=%~dp0klog_listener.ps1"
set "VERFILE=%~dp0klog_listener.ps1.ver"
set "VER=6"

if "%IP%"=="" set /p "IP=PS4-IP eingeben (z.B. 192.168.1.50): "
if "%IP%"=="" (
  echo Keine IP angegeben.
  pause
  exit /b 1
)

rem ---- Skript erzeugen, falls fehlend oder veraltet ----
set "NEED=1"
if not exist "%SCRIPT%" goto :build
if not exist "%VERFILE%" goto :build
set /p OLDVER=<"%VERFILE%"
if not "%OLDVER%"=="%VER%" goto :build
set "NEED=0"

:build
if "%NEED%"=="0" goto :run

echo Erzeuge Listener-Skript...
> "%SCRIPT%" echo # @echo off
>> "%SCRIPT%" echo # PS4 KLOG Listener - automatisch erzeugt von klog.bat (v%VER%)
>> "%SCRIPT%" echo param([string]$Ip,[int]$Port=3232)
>> "%SCRIPT%" echo $ErrorActionPreference='Stop'
>> "%SCRIPT%" echo function W-Log([string]$ts,[string]$lvl,[string]$col,[string]$msg){
>> "%SCRIPT%" echo   Write-Host '  [' -ForegroundColor DarkGray -NoNewline
>> "%SCRIPT%" echo   Write-Host $ts -ForegroundColor DarkCyan -NoNewline
>> "%SCRIPT%" echo   Write-Host '] ' -ForegroundColor DarkGray -NoNewline
>> "%SCRIPT%" echo   if($lvl -eq 'CRIT'){ Write-Host ('{0,-4} '-f $lvl) -ForegroundColor White -BackgroundColor DarkRed -NoNewline }
>> "%SCRIPT%" echo   else { Write-Host ('{0,-4} '-f $lvl) -ForegroundColor $col -NoNewline }
>> "%SCRIPT%" echo   Write-Host $msg -ForegroundColor Red
>> "%SCRIPT%" echo }
>> "%SCRIPT%" echo $dir=Join-Path $PSScriptRoot 'logs'
>> "%SCRIPT%" echo $null=New-Item -ItemType Directory -Force -Path $dir
>> "%SCRIPT%" echo $file=Join-Path $dir ('klog_'+($Ip -replace '\.','-')+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.log')
>> "%SCRIPT%" echo $sw=New-Object System.IO.StreamWriter($file,$true,(New-Object System.Text.UTF8Encoding($false)))
>> "%SCRIPT%" echo $sw.AutoFlush=$true
>> "%SCRIPT%" echo Write-Host ''
>> "%SCRIPT%" echo Write-Host '  [' -ForegroundColor DarkGray -NoNewline
>> "%SCRIPT%" echo Write-Host ' PS4 KLOG ' -ForegroundColor Black -BackgroundColor Cyan -NoNewline
>> "%SCRIPT%" echo Write-Host ']  Kernel-Log-Mitschnitt' -ForegroundColor DarkGray
>> "%SCRIPT%" echo Write-Host ('  '+('-'*56)) -ForegroundColor DarkGray
>> "%SCRIPT%" echo Write-Host '  Ziel    ' -ForegroundColor DarkGray -NoNewline
>> "%SCRIPT%" echo Write-Host "$Ip`:$Port" -ForegroundColor Cyan
>> "%SCRIPT%" echo Write-Host '  Logfile ' -ForegroundColor DarkGray -NoNewline
>> "%SCRIPT%" echo Write-Host $file -ForegroundColor Yellow
>> "%SCRIPT%" echo Write-Host '  Ende mit Strg+C' -ForegroundColor DarkGray
>> "%SCRIPT%" echo Write-Host ('  '+('-'*56)) -ForegroundColor DarkGray
>> "%SCRIPT%" echo Write-Host ''
>> "%SCRIPT%" echo while($true){
>> "%SCRIPT%" echo   $c=$null
>> "%SCRIPT%" echo   $sr=$null
>> "%SCRIPT%" echo   try{
>> "%SCRIPT%" echo     $c=New-Object System.Net.Sockets.TcpClient
>> "%SCRIPT%" echo     $c.Connect($Ip,$Port)
>> "%SCRIPT%" echo     Write-Host '  [verbunden] warte auf Kernel-Log...' -ForegroundColor Green
>> "%SCRIPT%" echo     $sr=New-Object System.IO.StreamReader($c.GetStream(),[System.Text.Encoding]::UTF8)
>> "%SCRIPT%" echo     while($true){
>> "%SCRIPT%" echo       $line=$sr.ReadLine()
>> "%SCRIPT%" echo       if($null -eq $line){break}
>> "%SCRIPT%" echo       $line=$line -replace '\x1b\[[0-9;]*[A-Za-z]',''
>> "%SCRIPT%" echo       $ts=Get-Date -Format 'HH:mm:ss.fff'
>> "%SCRIPT%" echo       $lvl='INFO'
>> "%SCRIPT%" echo       $col='Cyan'
>> "%SCRIPT%" echo       if($line -match '(?i)\b(panic^|fatal^|critical)\b'){$lvl='CRIT';$col='Magenta'}
>> "%SCRIPT%" echo       elseif($line -match '(?i)\b(error^|failed^|failure^|exception)\b'){$lvl='ERR';$col='Magenta'}
>> "%SCRIPT%" echo       elseif($line -match '(?i)\b(warn^|warning)\b'){$lvl='WARN';$col='Yellow'}
>> "%SCRIPT%" echo       elseif($line -match '(?i)\b(debug^|trace)\b'){$lvl='DBG';$col='DarkGray'}
>> "%SCRIPT%" echo       W-Log $ts $lvl $col $line
>> "%SCRIPT%" echo       $sw.WriteLine('['+$ts+'] '+$lvl+' '+$line)
>> "%SCRIPT%" echo     }
>> "%SCRIPT%" echo     Write-Host '  [getrennt] Gegenstelle hat geschlossen' -ForegroundColor Yellow
>> "%SCRIPT%" echo   }
>> "%SCRIPT%" echo   catch{
>> "%SCRIPT%" echo     Write-Host ('  [fehler] '+$_.Exception.Message) -ForegroundColor Red
>> "%SCRIPT%" echo   }
>> "%SCRIPT%" echo   finally{
>> "%SCRIPT%" echo     if($sr){$sr.Dispose()}
>> "%SCRIPT%" echo     if($c){$c.Close()}
>> "%SCRIPT%" echo   }
>> "%SCRIPT%" echo   Write-Host '  [neu] Versuch in 3s' -ForegroundColor DarkGray
>> "%SCRIPT%" echo   Start-Sleep -Seconds 3
>> "%SCRIPT%" echo }
> "%VERFILE%" echo %VER%

:run
echo.
echo PS4: %IP%   Port: %PORT%
echo Abbrechen mit Strg+C.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Ip "%IP%" -Port %PORT%
echo.
echo Beendet. Logs liegen im Ordner "logs".
pause