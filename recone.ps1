$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$CURRENT_VERSION = "1.1.0"
$REPO_OWNER = "BERKVY"
$REPO_NAME  = "recone"
$FILE_NAME  = "recone.ps1"
$RAW_URL    = "https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/main/$FILE_NAME"

try {
    $RemoteCode = (Invoke-WebRequest -Uri $RAW_URL -UseBasicParsing -ErrorAction Stop).Content
    if ($RemoteCode -match '\$CURRENT_VERSION = "([^"]+)"') {
        $RemoteVersion = $Matches[1]
        if ($RemoteVersion -gt $CURRENT_VERSION) {
            Write-Host "[!] New version available: v$RemoteVersion" -ForegroundColor Yellow
            $choice = Read-Host "[?] Update now? (y/n)"
            if ($choice.ToLower() -eq 'y') {
                Set-Content -Path $MyInvocation.MyCommand.Path -Value $RemoteCode -Encoding UTF8
                Write-Host "[+] Updated! Please restart the script." -ForegroundColor Green
                exit
            }
        }
    }
} catch {}

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Get-Location }

function Install-Tool($ToolExe) {
    Write-Host "[!] $ToolExe not found. Downloading..." -ForegroundColor Yellow
    $RepoMap = @{
        "subfinder.exe" = "subfinder"; "naabu.exe" = "naabu"; "httpx.exe" = "httpx";
        "katana.exe" = "katana"; "nuclei.exe" = "nuclei"
    }
    $Repo = $RepoMap[$ToolExe]
    $TempDir = Join-Path $ScriptDir "temp_install"
    try {
        if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
        New-Item -ItemType Directory -Path $TempDir | Out-Null
        $ApiUrl = "https://api.github.com/repos/projectdiscovery/$Repo/releases/latest"
        $Release = Invoke-RestMethod -Uri $ApiUrl -ErrorAction Stop
        $Asset = $Release.assets | Where-Object { $_.name -match "windows" -and $_.name -match "amd64" -and $_.name -match "zip" } | Select-Object -First 1
        $ZipPath = Join-Path $TempDir "$Repo.zip"
        Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $ZipPath -ErrorAction Stop
        Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force
        Get-ChildItem -Path $TempDir -Filter "*.exe" -Recurse | Move-Item -Destination $ScriptDir -Force
        Remove-Item $TempDir -Recurse -Force
        Write-Host "[V] $ToolExe installed (clean)." -ForegroundColor Green
    } catch {
        if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
        Write-Host "[X] Failed to install $ToolExe." -ForegroundColor Red
    }
}

Write-Host @"
                                   
  _ __ ___  ___ ___  _ __   ___  
 | '__/ _ \/ __/ _ \| '_ \ / _ \ 
 | | |  __/ (_| (_) | | | |  __/ 
 |_|  \___|\___\___/|_| |_|\___| v$CURRENT_VERSION

==============================================
      ADVANCED RECON & VULNERABILITY SCAN      
==============================================
"@ -ForegroundColor Blue

$Tools = @("subfinder.exe", "naabu.exe", "httpx.exe", "katana.exe", "nuclei.exe")
foreach ($Tool in $Tools) {
    if (-not (Test-Path (Join-Path $ScriptDir $Tool))) { Install-Tool -ToolExe $Tool }
}

Write-Host "`n[+] MAINTENANCE" -ForegroundColor Cyan
$UPDATE_CHECK = Read-Host "[?] Update tools and Nuclei templates? (Y/n)"
if ($UPDATE_CHECK.ToLower() -ne 'n') {
    Write-Host "[i] Checking for updates..." -ForegroundColor Yellow
    foreach ($ToolName in $Tools) {
        $ToolPath = Join-Path $ScriptDir $ToolName
        if (Test-Path $ToolPath) {
            & $ToolPath -up -silent
            if ($ToolName -eq "nuclei.exe") { & $ToolPath -ut -silent }
        }
    }
}

$RAW_TARGET = Read-Host "`n[?] Enter the target domain or IP"
if (-not $RAW_TARGET) { exit }

$TARGET = $RAW_TARGET.Trim() -replace '[^a-zA-Z0-9.-]', ''
$TARGET = $TARGET.Replace("http", "").Replace("https", "").Replace("://", "").Trim('.')

Write-Host "[i] Sanitized Target: $TARGET" -ForegroundColor Gray
$FIND_SUBS = Read-Host "[?] Do you want to perform subdomain enumeration? (Y/n)"

$TARGET_DIR = Join-Path $ScriptDir $TARGET
$VUL_DIR = Join-Path $TARGET_DIR "Severities"

if (Test-Path $TARGET_DIR) {
    Write-Host "[!] Previous scan data found. Wiping old files..." -ForegroundColor Yellow
    $FilesToClean = @("subdomains.txt", "alive.txt", "endpoints.txt", "endpoints_raw.txt", "all_vulnerabilities.txt")
    foreach ($FileName in $FilesToClean) {
        $FilePath = Join-Path $TARGET_DIR $FileName
        if (Test-Path $FilePath) { Remove-Item $FilePath -Force }
    }
    if (Test-Path $VUL_DIR) { Remove-Item (Join-Path $VUL_DIR "*") -Force -ErrorAction SilentlyContinue }
} else {
    New-Item -ItemType Directory -Path $TARGET_DIR | Out-Null
}
if (-not (Test-Path $VUL_DIR)) { New-Item -ItemType Directory -Path $VUL_DIR | Out-Null }

Write-Host "`n[+] SCAN CONFIGURATION" -ForegroundColor Cyan
$INTENSIVE_SUB = "n"; if ($FIND_SUBS.ToLower() -ne 'n') { $INTENSIVE_SUB = Read-Host "[?] 1. Run INTENSIVE subdomain scan? (y/N)" }
$FULL_PORTS    = Read-Host "[?] 2. Scan ALL 65535 ports? (y/N)"
$TECH_DETECT   = Read-Host "[?] 3. Fingerprint technologies & titles? (y/N)"
$KATANA_PROMPT = Read-Host "[?] 4. Use Katana for deep crawling? (y/N)"
$WAF_EXCLUDE   = Read-Host "[?] 5. Exclude WAF detection templates? (y/N)"

$AllowedSeverities = @("critical", "high", "medium", "low", "info", "unknown")
Write-Host "`n[+] SEVERITY SUGGESTIONS" -ForegroundColor Yellow
Write-Host "  [critical] - RCE, SQLi, Takeovers (Immediate Action)"
Write-Host "  [high]     - Broken Auth, LFI, Sensitive Leaks"
Write-Host "  [medium]   - XSS, CSRF, Misconfigurations"
Write-Host "  [low]      - Open Redirects, Missing Headers"
Write-Host "  [info]     - Technology detection & Versioning"
Write-Host "  [Enter]    - ALL SEVERITIES (Default Search)"

$SEV_VAL = Read-Host "`n[?] Select severities (comma-separated) [Enter for ALL]"

Write-Host "`n[+] RATE LIMIT SUGGESTIONS" -ForegroundColor Yellow
Write-Host "  [1-5]   - ULTRA GHOST (Internal IPS Bypass / High Stealth)"
Write-Host "  [15-25] - STEALTH (WAF Bypass for public sites)"
Write-Host "  [50-100]- CORPORATE (Standard for internal audits)"
Write-Host "  [Enter] - UNLIMITED (Max Speed - Use only if whitelisted!)"

$RL_INPUT = Read-Host "`n[?] Enter Rate Limit (Requests/sec) [Enter for UNLIMITED]"
if ($RL_INPUT -eq "") { 
    $RL_VAL = $null 
    Write-Host "[!] UNLIMITED MODE ACTIVATED - Full Speed." -ForegroundColor Red
} else { 
    $RL_VAL = $RL_INPUT 
}

$CONCURRENCY = "25"; $BULK = "10"
if ($null -eq $RL_VAL) { $CONCURRENCY = "100"; $BULK = "25" }

Write-Host "`n[+] Initiating Scan for: $TARGET" -ForegroundColor Green
Write-Host "----------------------------------------------" -ForegroundColor Green

$SUB_FILE = "$TARGET_DIR\subdomains.txt"
if ($FIND_SUBS.ToLower() -ne 'n') {
    Write-Host "[1/4] Discovering subdomains..." -ForegroundColor Blue
    $SUB_ARGS = @("-d", $TARGET, "-o", $SUB_FILE, "-silent")
    if ($INTENSIVE_SUB.ToLower() -eq 'y') { $SUB_ARGS += "-all" }
    & (Join-Path $ScriptDir "subfinder.exe") @SUB_ARGS
}
Add-Content -Path $SUB_FILE -Value $TARGET
$CleanedSubs = Get-Content $SUB_FILE | Sort-Object -Unique
$CleanedSubs | Out-File $SUB_FILE -Encoding ASCII

Write-Host "[2/4] Probing services..." -ForegroundColor Blue
$NAABU_ARGS = @("-silent", "-l", $SUB_FILE)
if ($FULL_PORTS.ToLower() -eq 'y') { $NAABU_ARGS += "-p", "-" } else { $NAABU_ARGS += "-tp", "1000" }

$HTTPX_ARGS = @("-silent", "-nc")
if ($TECH_DETECT.ToLower() -eq 'y') { $HTTPX_ARGS += "-td", "-title", "-sc" }
if ($null -ne $RL_VAL) { $HTTPX_ARGS += "-rl", $RL_VAL }

$ALIVE_FILE = "$TARGET_DIR\alive.txt"
$HttpxOutput = & (Join-Path $ScriptDir "naabu.exe") @NAABU_ARGS | & (Join-Path $ScriptDir "httpx.exe") @HTTPX_ARGS
if ($null -ne $HttpxOutput) {
    $HttpxOutput | Write-Host
    $HttpxOutput | ForEach-Object { ($_ -split ' ')[0] } | Sort-Object -Unique | Out-File $ALIVE_FILE -Encoding ASCII
} else {
    "http://$TARGET", "https://$TARGET" | Out-File $ALIVE_FILE -Encoding ASCII
}

$ENDPOINTS_FILE = "$TARGET_DIR\endpoints.txt"
if ($KATANA_PROMPT.ToLower() -eq "y") {
    Write-Host "[3/4] Starting Katana Crawling..." -ForegroundColor Blue
    $KAT_ARGS = @("-list", $ALIVE_FILE, "-silent", "-nc", "-jc", "-kf", "all", "-d", "2", "-o", "$TARGET_DIR\endpoints_raw.txt")
    if ($null -ne $RL_VAL) { $KAT_ARGS += "-rl", $RL_VAL }
    & (Join-Path $ScriptDir "katana.exe") @KAT_ARGS
    if (Test-Path "$TARGET_DIR\endpoints_raw.txt") { Get-Content "$TARGET_DIR\endpoints_raw.txt" | Sort-Object -Unique > $ENDPOINTS_FILE }
}
if (-not (Test-Path $ENDPOINTS_FILE)) { Copy-Item $ALIVE_FILE $ENDPOINTS_FILE -Force }

$FinalCount = (Get-Content $ENDPOINTS_FILE | Measure-Object).Count
Write-Host "[4/4] Starting Nuclei Scan on $FinalCount targets..." -ForegroundColor Blue
$N_ARGS = @("-l", $ENDPOINTS_FILE, "-no-httpx", "-stats", "-ni", "-nc", "-o", "$TARGET_DIR\all_vulnerabilities.txt")
$N_ARGS += "-c", $CONCURRENCY, "-bulk-size", $BULK
if ($null -ne $RL_VAL) { $N_ARGS += "-rl", $RL_VAL }
if ($SEV_VAL) { $N_ARGS += "-severity", $SEV_VAL }
if ($WAF_EXCLUDE.ToLower() -eq "y") { $N_ARGS += "-exclude-id", "dns-waf-detect,waf-detect" }
& (Join-Path $ScriptDir "nuclei.exe") @N_ARGS

if (Test-Path "$TARGET_DIR\all_vulnerabilities.txt") {
    $AllVulns = Get-Content "$TARGET_DIR\all_vulnerabilities.txt"
    foreach ($sev in $AllowedSeverities) {
        $Match = $AllVulns | Select-String -Pattern "\[$sev\]"
        if ($Match) { $Match | Out-File -FilePath (Join-Path $VUL_DIR "$sev.txt") -Encoding UTF8 }
    }
}
Write-Host "`n[V] SCAN COMPLETE! CHECK THE '$TARGET' FOLDER." -ForegroundColor Green
