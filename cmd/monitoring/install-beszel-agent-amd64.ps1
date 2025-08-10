#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Beszel Agent In-Place Installer/Updater
.DESCRIPTION
    Downloads and installs/updates Beszel Agent, managing the Windows service automatically
.PARAMETER Version
    Version to install (e.g., "v0.12.3"). If not specified, prompts user.
.PARAMETER Source
    Download source: "github" or "gitlab". Default is "github"
.PARAMETER Key
    Beszel public key for the service. If not specified, uses existing or prompts.
.PARAMETER Force
    Force reinstall even if same version is already installed
.EXAMPLE
    .\Install-BeszelAgent.ps1 -Version "v0.12.3" -Key "your-public-key"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("github", "gitlab")]
    [string]$Source = "github",
    
    [Parameter(Mandatory=$false)]
    [string]$Key,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Configuration
$INSTALL_PATH = "C:\_Staging\_Toolchest\beszel-agent"
$SERVICE_NAME = "beszelagent"
$BINARY_NAME = "beszel-agent_windows_amd64.exe"
$TEMP_DIR = "$env:TEMP\beszel-install"

# GitLab Configuration
$GITLAB_DOMAIN = "https://gitlab.prplanit.com"
$GITLAB_PROJECT_ID = "33"
$GITLAB_TOKEN = $env:GITLAB_TOKEN       # Set this environment variable

function Write-Header {
    param([string]$Message)
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Yellow
    Write-Host "=" * 80 -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n🔄 $Message" -ForegroundColor Green
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Test-NSMExists {
    try {
        $null = Get-Command nssm -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Get-ServiceStatus {
    try {
        $service = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
        return $service.Status
    } catch {
        return "NotInstalled"
    }
}

function Get-CurrentVersion {
    # Look for any beszel*.exe in the install directory
    $beszelExes = Get-ChildItem -Path $INSTALL_PATH -Filter "beszel*.exe" -ErrorAction SilentlyContinue
    if ($beszelExes) {
        $exePath = $beszelExes[0].FullName
        try {
            $version = & $exePath --version 2>$null
            if ($version -match "v?\d+\.\d+\.\d+") {
                return $matches[0]
            }
        } catch {}
    }
    return $null
}

function Get-DownloadUrl {
    param([string]$Version, [string]$Source)
    
    $zipName = "beszel-agent_windows_amd64-$Version.zip"
    
    switch ($Source) {
        "github" {
            return "https://github.com/henrygd/beszel/releases/download/$Version/beszel-agent_windows_amd64.zip"
        }
        "gitlab" {
            if (-not $GITLAB_TOKEN) {
                throw "GITLAB_TOKEN environment variable is required for GitLab downloads"
            }
            return "$GITLAB_DOMAIN/api/v4/projects/$GITLAB_PROJECT_ID/packages/generic/beszel-agent/$Version/$zipName"
        }
    }
}

function Download-BeszelAgent {
    param([string]$Url, [string]$Source)
    
    Write-Step "Downloading from $Source..."
    Write-Host "URL: $Url" -ForegroundColor Gray
    
    # Create temp directory
    if (Test-Path $TEMP_DIR) {
        Remove-Item $TEMP_DIR -Recurse -Force
    }
    New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null
    
    $zipPath = Join-Path $TEMP_DIR "beszel-agent.zip"
    
    try {
        if ($Source -eq "gitlab" -and $GITLAB_TOKEN) {
            # GitLab with authentication - use -L flag for redirects
            $headers = @{ "PRIVATE-TOKEN" = $GITLAB_TOKEN }
            Invoke-WebRequest -Uri $Url -OutFile $zipPath -Headers $headers -MaximumRedirection 5
        } else {
            # GitHub public download
            Invoke-WebRequest -Uri $Url -OutFile $zipPath -MaximumRedirection 5
        }
        
        Write-Success "Downloaded successfully ($(Get-Item $zipPath | ForEach-Object { '{0:N2} MB' -f ($_.Length / 1MB) }))"
        return $zipPath
    } catch {
        throw "Failed to download: $($_.Exception.Message)"
    }
}

function Extract-Archive {
    param([string]$ZipPath)
    
    Write-Step "Extracting archive..."
    
    try {
        Expand-Archive -Path $ZipPath -DestinationPath $TEMP_DIR -Force
        
        # Find the extracted binary (look for any beszel*.exe)
        $extractedBinary = Get-ChildItem -Path $TEMP_DIR -Filter "beszel*.exe" -Recurse -File | Select-Object -First 1
        if (-not $extractedBinary) {
            # Fallback to specific name if pattern doesn't work
            $extractedBinary = Get-ChildItem -Path $TEMP_DIR -Recurse -File | Where-Object { $_.Name -eq $BINARY_NAME } | Select-Object -First 1
            if (-not $extractedBinary) {
                throw "No Beszel binary (beszel*.exe or $BINARY_NAME) found in archive"
            }
        }
        
        Write-Success "Found binary: $($extractedBinary.Name)"
        Write-Success "Extracted to temp directory"
        return $extractedBinary.FullName
    } catch {
        throw "Failed to extract: $($_.Exception.Message)"
    }

}

function Install-Binary {
    param([string]$SourcePath)
    
    Write-Step "Installing binary to $INSTALL_PATH..."
    
    # Create install directory
    if (-not (Test-Path $INSTALL_PATH)) {
        New-Item -ItemType Directory -Path $INSTALL_PATH -Force | Out-Null
    }
    
    # Get the actual filename from the source
    $sourceFileName = Split-Path $SourcePath -Leaf
    $targetPath = Join-Path $INSTALL_PATH $sourceFileName
    
    # Remove any existing beszel*.exe files to avoid conflicts
    Get-ChildItem -Path $INSTALL_PATH -Filter "beszel*.exe" | Remove-Item -Force -ErrorAction SilentlyContinue
    
    try {
        Copy-Item -Path $SourcePath -Destination $targetPath -Force
        Write-Success "Binary installed as: $sourceFileName"
        return $targetPath
    } catch {
        throw "Failed to copy binary: $($_.Exception.Message)"
    }
}

function Manage-Service {
    param(
        [string]$Action,
        [string]$Key = $null,
        [string]$BinaryPath = $null
    )

    $serviceStatus = Get-ServiceStatus

    switch ($Action) {
        "stop" {
            if ($serviceStatus -eq "Running") {
                Write-Step "Stopping service..."
                nssm stop $SERVICE_NAME | Out-Null
                Start-Sleep -Seconds 3
                Write-Success "Service stopped"
            } else {
                Write-Warning "Service is not running"
            }
        }

        "install" {
            if ($serviceStatus -eq "NotInstalled") {
                Write-Step "Installing service..."
                if (-not $BinaryPath) {
                    $beszelExes = Get-ChildItem -Path $INSTALL_PATH -Filter "beszel*.exe"
                    if (-not $beszelExes) {
                        throw "No Beszel binary found in $INSTALL_PATH"
                    }
                    $BinaryPath = $beszelExes[0].FullName
                }
                nssm install $SERVICE_NAME "`"$BinaryPath`""

                if ($Key) {
                    Write-Step "Setting environment variable..."
                    nssm set $SERVICE_NAME AppEnvironmentExtra "KEY=$Key"
                }

                Write-Success "Service installed with binary: $(Split-Path $BinaryPath -Leaf)"
            } else {
                Write-Warning "Service already exists"

                if ($BinaryPath) {
                    Write-Step "Updating service binary path..."
                    nssm set $SERVICE_NAME Application "`"$BinaryPath`""
                    Write-Success "Service binary path updated to: $(Split-Path $BinaryPath -Leaf)"
                }

                if ($Key) {
                    Write-Step "Updating environment variable..."
                    nssm set $SERVICE_NAME AppEnvironmentExtra "KEY=$Key"
                }
            }
        }

        "start" {
            Write-Step "Starting service..."
            try {
                & nssm start $SERVICE_NAME 2>$null | Out-Null
            } catch {
                # Ignore the expected error about START_PENDING
            }

            $maxWait = 30
            $elapsed = 0
            while ($elapsed -lt $maxWait) {
                $status = (Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue).Status
                if ($status -eq "Running") {
                    Write-Success "Service started successfully"
                    return
                }
                if ($status -eq "Stopped") {
                    Write-Error "Service stopped unexpectedly during startup"
                    return
                }
                Start-Sleep -Seconds 1
                $elapsed++
            }
            Write-Warning "Service did not reach Running state within $maxWait seconds"
        }
    }
}

function Get-UserInput {
    if (-not $Version) {
        Write-Host "`nAvailable Beszel versions can be found at:" -ForegroundColor Yellow
        Write-Host "GitHub: https://github.com/henrygd/beszel/releases" -ForegroundColor Green
        Write-Host "GitLab: $GITLAB_DOMAIN/precisionplanit/beszel-agent-win-amd64/-/releases" -ForegroundColor Green
        Write-Host ""
        $Version = Read-Host "Enter version to install (default: v0.12.3)"
        
        if (-not $Version) {
            $Version = "v0.12.3"
            Write-Host "Using default version: $Version" -ForegroundColor Yellow
        } elseif (-not $Version.StartsWith("v")) {
            $Version = "v$Version"
        }
    }
    
    if (-not $Key) {
        # Try to get existing key from service
        try {
            $existingEnv = nssm get $SERVICE_NAME AppEnvironmentExtra 2>$null
            if ($existingEnv -match "KEY=(.+)") {
                $existingKey = $matches[1]
                Write-Host "`nFound existing key: $($existingKey.Substring(0, 10))..." -ForegroundColor Green
                $useExisting = Read-Host "Use existing key? (Y/n)"
                
                if ($useExisting -ne "n" -and $useExisting -ne "N") {
                    $Key = $existingKey
                }
            }
        } catch {}
        
        if (-not $Key) {
            $Key = Read-Host "Enter your Beszel public key"
        }
    }
    
    return @{
        Version = $Version
        Key = $Key
    }
}

# Main execution
try {
    Write-Host ""
    Write-Host "Beszel Agent Installer/Updater (Provided by SoFMeRight of PrecisionPlanIT)" -ForegroundColor Green
    Write-Host "You can find my other promoted projects:" -ForegroundColor Yellow
    Write-Host "  GitHub: https://github.com/sofmeright" -ForegroundColor Green
    Write-Host "  Docker Hub: https://hub.docker.com/u/prplanit" -ForegroundColor Green
    Write-Host ""
    
    # Check if running as admin
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        throw "This script must be run as Administrator"
    }
    
    # Check for NSSM
    if (-not (Test-NSMExists)) {
        throw "NSSM is not installed or not in PATH. Please install NSSM first: https://nssm.cc/download"
    }
    
    # Get user input if needed
    $params = Get-UserInput
    $Version = $params.Version
    $Key = $params.Key
    
    # Check current version
    $currentVersion = Get-CurrentVersion
    if ($currentVersion -and $currentVersion -eq $Version -and -not $Force) {
        Write-Warning "Version $Version is already installed. Use -Force to reinstall."
        return
    }
    
    Write-Host "`n📋 Installation Summary:" -ForegroundColor Yellow
    Write-Host "   Version: $Version"
    Write-Host "   Source: $Source"
    Write-Host "   Install Path: $INSTALL_PATH"
    Write-Host "   Current Version: $(if($currentVersion) { $currentVersion } else { 'Not installed' })"
    Write-Host ""
    
    $confirm = Read-Host "Proceed with installation? (Y/n)"
    if ($confirm -eq "n" -or $confirm -eq "N") {
        Write-Host "Installation cancelled."
        return
    }
    
    # Stop service if running
    Manage-Service -Action "stop"
    
    # Download and extract
    $downloadUrl = Get-DownloadUrl -Version $Version -Source $Source
    $zipPath = Download-BeszelAgent -Url $downloadUrl -Source $Source
    $binaryPath = Extract-Archive -ZipPath $zipPath
    
    # Install binary
    $installedBinaryPath = Install-Binary -SourcePath $binaryPath

    # --- Begin fix: Force executable filename ---
    $forcedExePath = Join-Path $INSTALL_PATH $BINARY_NAME

    if ($installedBinaryPath -ne $forcedExePath) {
        # Remove existing forced name file if exists
        if (Test-Path $forcedExePath) {
            Remove-Item $forcedExePath -Force
        }
        # Rename or copy installed binary to forced name
        Rename-Item -Path $installedBinaryPath -NewName $BINARY_NAME -Force
        Write-Step "Renamed installed binary to fixed name: $BINARY_NAME"
    } else {
        Write-Step "Installed binary already has fixed name: $BINARY_NAME"
    }

    # Confirm forced binary path exists
    if (-not (Test-Path $forcedExePath)) {
        throw "Expected executable '$forcedExePath' not found after installation. Aborting."
    }

    # Use forced path from here on
    $installedBinaryPath = $forcedExePath
    Write-Step "Using installed binary: $BINARY_NAME"
    # --- End fix ---

    # Update NSSM to use the real binary path (safe to do even if service already exists).
    # Suppress any NSSM noise — we'll use Manage-Service and our start/polling logic to assert success.
    & nssm set $SERVICE_NAME Application "`"$installedBinaryPath`"" 2>$null | Out-Null
    Write-Success "Service binary path set to: $BINARY_NAME"

    # Now install/update the service config (this will also set AppEnvironmentExtra if $Key provided)
    Manage-Service -Action "install" -Key $Key -BinaryPath $installedBinaryPath

    # Start service (Manage-Service will poll and report actual Running/Stopped state)
    Manage-Service -Action "start"
    
    # Cleanup
    if (Test-Path $TEMP_DIR) {
        Remove-Item $TEMP_DIR -Recurse -Force
    }
    
    Write-Header "Installation Complete!"
    Write-Host "✅ Beszel Agent $Version installed successfully" -ForegroundColor Green
    Write-Host "✅ Service configured and started" -ForegroundColor Green
    Write-Host ""
    Write-Host "Service Status:" -ForegroundColor Yellow
    nssm dump $SERVICE_NAME
    
    Write-Host "`nInstallation completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Error $_.Exception.Message
    Write-Host "`n❌ Installation failed. Check the error above." -ForegroundColor Red
    exit 1
}

if ($Host.Name -eq 'ConsoleHost') {
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
