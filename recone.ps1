$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$CURRENT_VERSION = "1.0.0"
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
    if (-not (Test-Path (Join-Path $ScriptDir $Tool))) {
        Write-Host "[!] Warning: $Tool not found in $ScriptDir." -ForegroundColor Red
    }
}

Write-Host "`n[+] MAINTENANCE" -ForegroundColor Cyan
$UPDATE_CHECK = Read-Host "[?] Update tools and Nuclei templates? (Y/n)"
if ($UPDATE_CHECK.ToLower() -ne 'n') {
    Write-Host "[i] Checking for updates..." -ForegroundColor Yellow
    foreach ($ToolName in $Tools) {
        $ToolPath = Join-Path $ScriptDir $ToolName
        if (Test-Path $ToolPath) {
            Write-Host "[-] Updating $ToolName..." -ForegroundColor Gray
            & $ToolPath -up -silent
            if ($ToolName -eq "nuclei.exe") {
                Write-Host "[-] Updating Nuclei Templates..." -ForegroundColor Gray
                & $ToolPath -ut -silent
            }
        }
    }
}

$RAW_TARGET = Read-Host "`n[?] Enter the target domain or IP"
if (-not $RAW_TARGET) { Write-Host "[!] Error: Target empty!" -ForegroundColor Red; exit }

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

$AllowedSeverities = @("critical", "high", "medium", "low", "info")
$SEV_VAL = Read-Host "`n[?] Select severities (comma-separated) [Enter for ALL]"

$RL_INPUT = Read-Host "`n[?] Enter Rate Limit (Requests/sec) [Enter for UNLIMITED]"
$RL_VAL = if ($RL_INPUT -eq "") { $null } else { $RL_INPUT }
$CONCURRENCY = "25"; $BULK = "10"
if ($null -eq $RL_VAL) { $CONCURRENCY = "100"; $BULK = "25" }

Write-Host "`n[+] Initiating Scan for: $TARGET" -ForegroundColor Green
Write-Host "----------------------------------------------" -ForegroundColor Green

$SUB_FILE = "$TARGET_DIR\subdomains.txt"
if ($FIND_SUBS.ToLower() -ne 'n') {
    Write-Host "[1/4] Discovering subdomains (Subfinder)..." -ForegroundColor Blue
    $subfinder = Join-Path $ScriptDir "subfinder.exe"
    & $subfinder -d $TARGET -o $SUB_FILE -silent
}

Add-Content -Path $SUB_FILE -Value $TARGET
$CleanedSubs = Get-Content $SUB_FILE | ForEach-Object { $_.Trim() -replace '[^a-zA-Z0-9.-]', '' } | Where-Object { $_ -ne "" } | Sort-Object -Unique
$CleanedSubs | Out-File $SUB_FILE -Encoding ASCII
Write-Host "[+] Total Subdomains Found: ($($CleanedSubs.Count))" -ForegroundColor Green

Write-Host "[2/4] Probing services..." -ForegroundColor Blue
$naabu = Join-Path $ScriptDir "naabu.exe"; $httpx = Join-Path $ScriptDir "httpx.exe"
$NAABU_ARGS = @("-silent", "-l", $SUB_FILE) 
if ($FULL_PORTS.ToLower() -eq 'y') { $NAABU_ARGS += "-p", "-" } else { $NAABU_ARGS += "-tp", "1000" }

$HTTPX_ARGS = @("-silent", "-mc", "200,301,302,403", "-fpt", "-nc")
if ($TECH_DETECT.ToLower() -eq 'y') { $HTTPX_ARGS += "-td", "-title", "-sc" }
if ($null -ne $RL_VAL) { $HTTPX_ARGS += "-rl", $RL_VAL }

$ALIVE_FILE = "$TARGET_DIR\alive.txt"
$HttpxOutput = & $naabu @NAABU_ARGS | & $httpx @HTTPX_ARGS
if (-not $HttpxOutput) { $HttpxOutput = Get-Content $SUB_FILE | & $httpx @HTTPX_ARGS }

if ($null -ne $HttpxOutput) {
    $HttpxOutput | Write-Host
    $HttpxOutput | ForEach-Object { ($_ -split ' ')[0] } | Sort-Object -Unique | Out-File $ALIVE_FILE -Encoding ASCII
} else {
    "http://$TARGET", "https://$TARGET" | Out-File $ALIVE_FILE -Encoding ASCII
}

$ENDPOINTS_FILE = "$TARGET_DIR\endpoints.txt"
if ($KATANA_PROMPT.ToLower() -eq "y") {
    Write-Host "[3/4] Starting Katana Crawling..." -ForegroundColor Blue
    $KAT_ARGS = @("-list", $ALIVE_FILE, "-silent", "-jc", "-kf", "all", "-d", "2", "-o", "$TARGET_DIR\endpoints_raw.txt")
    if ($null -ne $RL_VAL) { $KAT_ARGS += "-rl", $RL_VAL }
    & (Join-Path $ScriptDir "katana.exe") @KAT_ARGS
    if (Test-Path "$TARGET_DIR\endpoints_raw.txt") { 
        Get-Content "$TARGET_DIR\endpoints_raw.txt" | Sort-Object -Unique > $ENDPOINTS_FILE 
    }
}
if (-not (Test-Path $ENDPOINTS_FILE)) { Copy-Item $ALIVE_FILE $ENDPOINTS_FILE -Force }

$FinalCount = (Get-Content $ENDPOINTS_FILE | Measure-Object).Count
Write-Host "[4/4] Starting Nuclei Scan on $FinalCount targets..." -ForegroundColor Blue
$nuclei = Join-Path $ScriptDir "nuclei.exe"
$N_ARGS = @("-l", $ENDPOINTS_FILE, "-no-httpx", "-stats", "-ni", "-o", "$TARGET_DIR\all_vulnerabilities.txt")
$N_ARGS += "-c", $CONCURRENCY, "-bulk-size", $BULK
if ($null -ne $RL_VAL) { $N_ARGS += "-rl", $RL_VAL }
if ($SEV_VAL) { $N_ARGS += "-severity", $SEV_VAL }
if ($WAF_EXCLUDE.ToLower() -eq "y") { $N_ARGS += "-exclude-id", "dns-waf-detect,waf-detect" }
& $nuclei @N_ARGS

if (Test-Path "$TARGET_DIR\all_vulnerabilities.txt") {
    $AllVulns = Get-Content "$TARGET_DIR\all_vulnerabilities.txt"
    foreach ($sev in $AllowedSeverities) {
        $Match = $AllVulns | Select-String -Pattern "\[$sev\]"
        if ($Match) { $Match | Out-File -FilePath (Join-Path $VUL_DIR "$sev.txt") -Encoding UTF8 }
    }
}
Write-Host "`n[V] SCAN COMPLETE! CHECK THE '$TARGET' FOLDER." -ForegroundColor Green