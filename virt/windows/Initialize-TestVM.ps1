#Requires -RunAsAdministrator

[CmdletBinding(DefaultParameterSetName = 'OptOut')]
Param(
    [Parameter(ParameterSetName = 'OptOut')]
    [ValidateSet(
        'DotNet',
        'Office365',
        'PowerShell',
        'WindowsComponents',
        'WindowsDefender',
        'WindowsFeatures',
        'WindowsSecurity',
        'WindowsSettingsComputer',
        'WindowsSettingsUser',
        'WindowsUpdate'
    )]
    [String[]]$ExcludeTasks,

    [Parameter(ParameterSetName = 'OptIn', Mandatory)]
    [ValidateSet(
        'DotNet',
        'Office365',
        'PowerShell',
        'WindowsComponents',
        'WindowsDefender',
        'WindowsFeatures',
        'WindowsSecurity',
        'WindowsSettingsComputer',
        'WindowsSettingsUser',
        'WindowsUpdate'
    )]
    [String[]]$IncludeTasks
)

Function Optimize-DotNet {
    [CmdletBinding()]
    Param()

    Test-DotNetPresent

    if ($Script:DotNet20Present) {
        Write-Host -ForegroundColor Green '[DotNet] Applying .NET Framework 2.x/3.x settings ...'

        # Enable strong cryptography
        Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v2.0.50727' -Name 'SchUseStrongCrypto' -Type DWord -Value 1
        if ($Script:Wow64Present) {
            Set-RegistryValue -Path 'HKLM:\Software\Wow6432Node\Microsoft\.NETFramework\v2.0.50727' -Name 'SchUseStrongCrypto' -Type DWord -Value 1
        }

        # Let OS choose protocols
        Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v2.0.50727' -Name 'SystemDefaultTlsVersions' -Type DWord -Value 1 # DevSkim: ignore DS440000
        if ($Script:Wow64Present) {
            Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v2.0.50727' -Name 'SystemDefaultTlsVersions' -Type DWord -Value 1 # DevSkim: ignore DS440000
        }
    } else {
        Write-Warning -Message 'Skipping .NET Framework 2.x/3.x settings as not installed.'
    }

    if ($Script:DotNet40Present) {
        Write-Host -ForegroundColor Green '[DotNet] Applying .NET Framework 4.x settings ...'

        # Enable strong cryptography
        Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Type DWord -Value 1
        if ($Script:Wow64Present) {
            Set-RegistryValue -Path 'HKLM:\Software\Wow6432Node\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Type DWord -Value 1
        }

        # Let OS choose protocols
        Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v4.0.30319' -Name 'SystemDefaultTlsVersions' -Type DWord -Value 1 # DevSkim: ignore DS440000
        if ($Script:Wow64Present) {
            Set-RegistryValue -Path 'HKLM:\Software\Microsoft\.NETFramework\v4.0.30319' -Name 'SystemDefaultTlsVersions' -Type DWord -Value 1 # DevSkim: ignore DS440000
        }
    } else {
        Write-Warning -Message 'Skipping .NET Framework 4.x settings as not installed.'
    }
}

Function Optimize-Office365 {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green '[Office 365] Disabling automatic updates ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Office\16.0\Common\OfficeUpdate' -Name 'EnableAutomaticUpdates' -Type DWord -Value 0
}

Function Optimize-PowerShell {
    [CmdletBinding()]
    Param()

    if (!($PSVersionTable.PSVersion.Major -gt 5 -or ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -ge 1))) {
        Write-Warning 'Skipping PowerShell settings as version is not 5.1 or newer.'
        return
    }

    Write-Host -ForegroundColor Green '[PowerShell] Setting PSGallery repository to trusted ...'
    $null = Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

    Write-Host -ForegroundColor Green '[PowerShell] Installing NuGet package provider ...'
    $null = Install-PackageProvider -Name NuGet -Force

    Write-Host -ForegroundColor Green '[PowerShell] Installing PowerShellGet module ...'
    $null = Install-Module -Name PowerShellGet -Force
    Import-Module -Name PowerShellGet -Force

    Write-Host -ForegroundColor Green '[PowerShell] Determining modules to install ...'
    $Modules = @('SpeculationControl', 'PSWindowsUpdate', 'PSWinGlue', 'PSWinVitals')
    if (!(Get-Module -Name PSReadLine)) {
        $Modules += 'PSReadLine'
    }

    Write-Host -ForegroundColor Green '[PowerShell] Installing modules ...'
    foreach ($Module in $Modules) {
        Write-Host -ForegroundColor Grey ('[PowerShell] - {0}' -f $Module)
        $null = Install-Module -Name $Module -Force
    }

    if ($Modules -notcontains 'PSReadLine') {
        Write-Host -ForegroundColor Cyan '[PowerShell] To update PSReadLine run the following from an elevated Command Prompt:'
        Write-Host -ForegroundColor Cyan '             powershell -NoProfile -NonInteractive -Command "Install-Module -Name PSReadLine -AllowPrerelease -Force"'
    }
}

Function Optimize-WindowsComponents {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green -NoNewline '[Windows] Performing component store clean-up ...'
    & dism.exe /Online /Cleanup-Image /StartComponentCleanup
    Write-Host
}

Function Optimize-WindowsDefender {
    [CmdletBinding()]
    Param()

    $MpCmdRun = Join-Path -Path $env:ProgramFiles -ChildPath 'Windows Defender\MpCmdRun.exe'
    if (!(Test-Path -Path $MpCmdRun -PathType Leaf)) {
        Write-Warning -Message 'Skipping Windows Defender settings as unable to find MpCmdRun.exe.'
        return
    }

    $MpStatus = Get-MpComputerStatus
    if ($MpStatus.IsTamperProtected) {
        Write-Warning -Message 'Skipping Windows Defender settings as tamper protection is enabled.'
        return
    }

    Write-Host -ForegroundColor Green -NoNewline '[Windows Defender] Removing definitions ...'
    & $MpCmdRun -RemoveDefinitions -All
    Write-Host

    Write-Host -ForegroundColor Green '[Windows Defender] Disabling service ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows Defender' -Name 'DisableAntiSpyware' -Type DWord -Value 1
}

Function Optimize-WindowsFeatures {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green -NoNewline '[Windows] Installing .NET Framework 3.5 ...'
    & dism.exe /Online /Enable-Feature /FeatureName:NetFx3 /All
    Write-Host
}

Function Optimize-WindowsSecurity {
    [CmdletBinding()]
    Param()

    Test-Wow64Present

    Write-Host -ForegroundColor Green '[Windows] Applying security policy ...'
    $SecEditDb = Join-Path $env:windir 'Security\Local.sdb'
    $SecEditCfg = Join-Path $env:windir 'Temp\SecPol.cfg'

    Write-Host -ForegroundColor Gray '[SecEdit] - Exporting current security policy ...'
    & SecEdit.exe /export /cfg $SecEditCfg /quiet

    Write-Host -ForegroundColor Gray '[SecEdit] - Updating security policy template ...'
    $SecPol = Get-Content -Path $SecEditCfg | ForEach-Object {
        $_ -replace '^(MinimumPasswordAge) *= *.+', '$1 = 0' `
            -replace '^(MaximumPasswordAge) *= *.+', '$1 = -1' `
            -replace '^(PasswordComplexity) *= *.+', '$1 = 0'
    }
    $SecPol | Set-Content -Path $SecEditCfg

    Write-Host -ForegroundColor Gray '[SecEdit] - Applying updated security policy ...'
    & SecEdit.exe /configure /db $SecEditDb /cfg $SecEditCfg /quiet

    Write-Host -ForegroundColor Gray '[SecEdit] - Cleaning-up ...'
    Remove-Item $SecEditCfg

    Write-Host -ForegroundColor Green '[Windows] Applying security settings ...'

    # Set WinHTTP default protocols to: TLS 1.0, TLS 1.1, TLS 1.2
    Set-RegistryValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp' -Name 'DefaultSecureProtocols' -Type DWord -Value 2688
    if ($Script:Wow64Present) {
        Set-RegistryValue -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp' -Name 'DefaultSecureProtocols' -Type DWord -Value 2688
    }
}

Function Optimize-WindowsSettingsComputer {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green '[Windows] Applying computer settings ...'

    # Disable automatic maintenance
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\ScheduledDiagnostics' -Name 'EnabledExecution' -Type DWord -Value 0

    # Do not display Server Manager automatically at logon
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\Server\ServerManager' -Name 'DoNotOpenAtLogon' -Type DWord -Value 1

    # Disable Explorer SmartScreen
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\System' -Name 'EnableSmartScreen' -Type DWord -Value 0

    # Disable Shutdown Event Tracker
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows NT\Reliability' -Name 'ShutdownReasonOn' -Type DWord -Value 0
}

Function Optimize-WindowsSettingsUser {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green '[Windows] Applying user settings ...'

    # Remove volume control icon
    $AudioSrv = Get-Service -Name AudioSrv -ErrorAction SilentlyContinue
    if ($AudioSrv.StartType -eq 'Disabled') {
        Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'HideSCAVolume' -Type DWord -Value 1
    }

    # Remove Recycle Bin desktop icon
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu' -Name '{645FF040-5081-101B-9F08-00AA002F954E}' -Type DWord -Value 1
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' -Name '{645FF040-5081-101B-9F08-00AA002F954E}' -Type DWord -Value 1

    # Disable startup programs launch delay
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Name 'StartupDelayInMSec' -Type DWord -Value 0
}

Function Optimize-WindowsUpdate {
    [CmdletBinding()]
    Param()

    Write-Host -ForegroundColor Green '[Windows Update] Disabling automatic updates ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoUpdate' -Type DWord -Value 1

    Write-Host -ForegroundColor Green '[Windows Update] Enabling recommended updates ...'
    Set-RegistryValue -Path 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'IncludeRecommendedUpdates' -Type DWord -Value 1

    Write-Host -ForegroundColor Green '[Windows Update] Registering Microsoft Update ...'
    $ServiceManager = New-Object -ComObject Microsoft.Update.ServiceManager
    $ServiceRegistration = $ServiceManager.AddService2('7971f918-a847-4430-9279-4a52d1efe18d', 7, '')
    $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($ServiceRegistration)
    $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($ServiceManager)

    Write-Host -ForegroundColor Green '[Windows Update] Suppressing MSRT updates ...'
    Set-RegistryValue -Path 'HKCU:\Software\Policies\Microsoft\MRT' -Name 'DontOfferThroughWUAU' -Type DWord -Value 1
}

Function Set-RegistryValue {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter(Mandatory)]
        [String]$Type,

        [Parameter(Mandatory)]
        [String]$Value
    )

    try {
        if (!(Test-Path -Path $Path -PathType Container)) {
            $null = New-Item -Path $Path -Force -ErrorAction Stop
        }
    } catch {
        throw ('Failure creating registry key: {0}' -f $Path)
    }

    try {
        Set-ItemProperty @PSBoundParameters -ErrorAction Stop
    } catch {
        throw ('Failure creating registry value "{0}" ({1}) under key: {2}' -f $Name, $Type, $Path)
    }
}

Function Test-DotNetPresent {
    [CmdletBinding()]
    Param()

    $ClrVersions = '2.0', '4.0'
    foreach ($ClrVersion in $ClrVersions) {
        $VarName = 'DotNet{0}Present' -f $ClrVersion.Replace('.', '')
        switch ($ClrVersion) {
            '2.0' { $RegPath = 'HKLM:\Software\Microsoft\NET Framework Setup\NDP\v2.0.50727' }
            '4.0' { $RegPath = 'HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Full' }
        }

        $RegKey = Get-Item -Path $RegPath -ErrorAction Ignore
        if ($RegKey -and $RegKey.GetValue('Version')) {
            Set-Variable -Name $VarName -Scope Script -Value $true
        } else {
            Set-Variable -Name $VarName -Scope Script -Value $false
        }
    }
}

Function Test-Wow64Present {
    [CmdletBinding()]
    Param()

    if (Test-Path -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows NT\CurrentVersion' -PathType Container) {
        $Script:Wow64Present = $true
    } else {
        $Script:Wow64Present = $false
    }
}

$Tasks = @(
    'WindowsUpdate',
    'WindowsDefender',
    'WindowsSecurity',
    'WindowsSettingsComputer',
    'WindowsSettingsUser',
    'WindowsFeatures',
    'WindowsComponents',
    'DotNet',
    'PowerShell',
    'Office365'
)

foreach ($Task in $Tasks) {
    $Function = 'Optimize-{0}' -f $Task
    if ($PSCmdlet.ParameterSetName -eq 'OptOut') {
        if ($ExcludeTasks -notcontains $Task) {
            & $Function
        }
    } else {
        if ($IncludeTasks -contains $Task) {
            & $Function
        }
    }
}
