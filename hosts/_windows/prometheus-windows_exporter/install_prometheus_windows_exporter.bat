@echo off

:: Syntax is as follows:
:: install_prometheus_windows_exporter.bat [DESTINATION_PATH] [PROMETHEUS_VERSION]

:: Check if a path is provided as an argument, otherwise use the default.
if "%1" == "" (
    set DESTINATION_PATH=C:\_Staging\_Toolchest\prometheus_windows_exporter
) else (
    set DESTINATION_PATH=%1
)

:: Check if Prometheus version is provided as an argument, otherwise use the default.
if "%2" == "" (
    set PROMETHEUS_VERSION=0.30.5
) else (
    set PROMETHEUS_VERSION=%2
)

set DOWNLOAD_URL=https://github.com/prometheus-community/windows_exporter/releases/download/v%PROMETHEUS_VERSION%/windows_exporter-%PROMETHEUS_VERSION%-amd64.exe

:: Create the destination path if it doesn't exist
powershell -Command "New-Item -Path '%DESTINATION_PATH%' -ItemType Directory -Force"

:: Download Windows Exporter executable to C:\_Staging\_Toolchest directory
powershell -Command "Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%DESTINATION_PATH%\prometheus_windows_exporter.exe'"

echo Done! Prometheus Windows Exporter version %PROMETHEUS_VERSION% has been downloaded and saved in the %DESTINATION_PATH% directory.

:: Add a task to Task Scheduler
powershell -Command "Register-ScheduledTask -xml (Get-Content '%DESTINATION_PATH%\prometheus-windows-exporter.xml' | Out-String) -TaskName 'prometheus-windows-exporter' -TaskPath '\SoFMeRight' -User kaiha -Password %password%"
powershell -Command "Start-ScheduledTask -TaskName \SoFMeRight\prometheus-windows-exporter"