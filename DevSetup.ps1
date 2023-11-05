[CmdletBinding()]
Param(
    [Parameter(Mandatory)]
    # Full Name required for Git Configuration
    [string] $FullName,

    [Parameter(Mandatory)]
    # Email address required for Git Configuration
    [string] $Email,

    [Parameter()]
    # Enable Developer Nerd Addons
    [switch] $NerdConfig
)

#Requires -RunAsAdministrator
#Requires -PSEdition Desktop

function InstallModule {
    Param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [hashtable]$AdditionalParameters
    )

    [hashtable]$parms = @{Name=$Name; Force=$true}
    if ($AdditionalParameters) {$parms += $AdditionalParameters}

    if ((Get-InstalledModule -Name $Name | Select -ExpandProperty Version) -lt (Find-Module -Name $Name | select -ExpandProperty Version))
    {
        Install-Module @parms
    }
}

function RemoveFolder {
    Param(
        [Parameter(Mandatory)]
        [string[]]$Path
    )

    foreach ($p in $Path)
    {
        if (Test-Path -Path $p)
        {
            Remove-Item -Path $p -Recurse -Force -Confirm:$false
        }
    }
}

function NewSettingsFile {
    Param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File,

        [Parameter()]
        [string]$Value = ""
    )

    try {
        New-Item -Path $File -ItemType File -Value $Value -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Could not create settings file: $File"
    }
}

function GetSettingsFromJsonFile {
    Param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File
    )

    try {
        Get-Content -Path $File -Raw -ErrorAction Stop | ConvertFrom-Json
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        $File = NewSettingsFile -File $File
        Get-Content -Path $File -Raw -ErrorAction Stop | ConvertFrom-Json
    }
}

function UpdatePowershellProfile {
    Param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$ProfilePath,

        [Parameter(Mandatory)]
        [string[]]$Content
    )

    if ($ProfilePath.Exists) { Add-Content -Path $ProfilePath -Value "`r" }
    Add-Content -Path $ProfilePath -Value $Content
}


# Update Nuget and PowerShellGet Package Providers
if ((Get-PackageProvider -Name Nuget | Select -ExpandProperty Version) -lt (Find-PackageProvider -Name nuget | select -ExpandProperty Version))
{
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force
}
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
InstallModule -Name PowerShellGet -AdditionalParameters @{AllowClobber=$true}
Remove-Module -Name PackageManagement,PowerShellGet -Force
Import-Module -Name PackageManagement -MinimumVersion 1.4.8.1
Import-Module -Name PowerShellGet -MinimumVersion 2.2.5
$PowershellGetPath = @(
"$env:SystemDrive\Program Files (x86)\WindowsPowerShell\Modules\PowerShellGet\1.0.0.1",
"$env:SystemDrive\Program Files\WindowsPowerShell\Modules\PowerShellGet\1.0.0.1"
)
RemoveFolder -Path $PowershellGetPath


# Update built-in PSReadLine module
Remove-Module -Name PSReadline -Force -ErrorAction SilentlyContinue
InstallModule -Name PSReadLine
$PsReadLinePath = @(
"$env:SystemDrive\Program Files (x86)\WindowsPowerShell\Modules\PSReadLine\2.0.0",
"$env:SystemDrive\Program Files\WindowsPowerShell\Modules\PSReadLine\2.0.0"
)
RemoveFolder -Path $PsReadLinePath


# Update Pester binaries
$PesterModules = @(
"$env:SystemDrive\Program Files\WindowsPowerShell\Modules\Pester\3.4.0",
"$env:SystemDrive\Program Files (x86)\WindowsPowerShell\Modules\Pester\3.4.0"
)
foreach ($module in $PesterModules) {
    if (Test-Path -Path $module) {
        takeown /F $module /A /R
        icacls $module /reset
        icacls $module /grant "*S-1-5-32-544:F" /inheritance:d /T
        Remove-Item -Path $module -Recurse -Force -Confirm:$false
    }
}
InstallModule -Name Pester

# Install Winget
if (-Not (Get-AppxPackage | ? {$_.PackageFamilyName -eq "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"}))
{
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
}

# Install Development software via Winget
winget install -s winget Microsoft.WindowsTerminal Microsoft.Powershell Git.Git Microsoft.VisualStudioCode Microsoft.DotNet.SDK.7

# Reload PATH environment
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Launch Windows Terminal to ensure default settings are loaded
# Couldn't figure out how to close.  The wt.exe process is passed to a child process and that PID is not returned.
Start-Process -FilePath wt.exe

# Git Config
git config --system init.defaultbranch main
git config --global user.name $FullName
git config --global user.email $Email
git config --global core.editor "\`"$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code\`" --wait"

# Generate SSH Key Pair
ssh-keygen -t ed25519 -C "SSH Key for Gitlab" -f $env:USERPROFILE/.ssh/gitlab -q -N '""'

# Powershell Core
# Update builtin PSReadLine Module
pwsh -Command {Install-Module -Name PSReadLine -Force}
# Install Pester
pwsh -Command {Install-Module -Name Pester -Force}

# Nerd Config - For super Dev Nerds
if ($NerdConfig.IsPresent)
{
    # Oh My Posh Installation
    winget install -s winget JanDeDobbeleer.OhMyPosh

    # Terminal Icons, Posh-Git Installation
    pwsh -Command {Install-Module -Name Terminal-Icons -Force}
    pwsh -Command {Install-Module -Name posh-git -Force}

    # Install a Nerd Font (for now Caskaydia Code only)
    $nerdFontName = "CaskaydiaCove Nerd Font Mono"
    & "$env:LOCALAPPDATA\Programs\oh-my-posh\bin\oh-my-posh.exe" font install CascadiaCode
    

    # Set Windows Terminal Default Font
    $terminalSettingsFile = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $terminalSettings = GetSettingsFromJsonFile -File $terminalSettingsFile
    if (-Not $terminalSettings.profiles.defaults.font) {
        $terminalSettings.profiles.defaults | Add-Member -MemberType NoteProperty -Name font -Value ([PSCustomObject]@{face="$nerdFontName"})
    }
    else
    {
        if (-Not $terminalSettings.profiles.defaults.font.face)
        {
            $terminalSettings.profiles.defaults.font | Add-Member -MemberType NoteProperty -Name face -Value "$nerdFontName"
        }
        else
        {
            $terminalSettings.profiles.defaults.font.face = $nerdFontName
        }
    }
    $terminalSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $terminalSettingsFile

    # Set VSCode Terminal Default Font
    $vsCodeSettingsFile = "$env:APPDATA\Code\User\settings.json"
    $vsCodeSettings = GetSettingsFromJsonFile -File $vsCodeSettingsFile
    if ($null -eq $vsCodeSettings) { [pscustomobject]$vsCodeSettings = @{} }
    if (-Not $vsCodeSettings.'terminal.integrated.fontFamily')
    {
        $vsCodeSettings | Add-Member -MemberType NoteProperty -Name 'terminal.integrated.fontFamily' -Value $nerdFontName
    }
    else
    {
        $vsCodeSettings.'terminal.integrated.fontFamily' = $nerdFontName
    }
    $vsCodeSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $vsCodeSettingsFile

    # Update Powershell PROFILE to load Oh My Posh, Terminal Icons, posh-git
    $powershellProfile = & pwsh -Command {$PROFILE}
    
    $addToProfile = @(
        "oh-my-posh init pwsh | Invoke-Expression",
        "Import-Module -Name Terminal-Icons",
        "Import-Module -Name posh-git"
    )


    UpdatePowershellProfile -ProfilePath $powershellProfile -Content $addToProfile
}