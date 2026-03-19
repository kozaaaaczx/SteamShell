Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Steam functions (embedded so the EXE is self-contained)
$script:AppVersion = '0.4.1'
$script:SteamExeOverride = $null

function Get-SteamExePath {
    if ($script:SteamExeOverride -and (Test-Path $script:SteamExeOverride)) {
        return $script:SteamExeOverride
    }
    try {
        $regPaths = @(
            'HKCU:\Software\Valve\Steam',
            'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
            'HKLM:\SOFTWARE\Valve\Steam'
        )
        foreach ($rp in $regPaths) {
            if (Test-Path $rp) {
                $k = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
                foreach ($name in @('SteamExe', 'SteamPath', 'InstallPath')) {
                    if ($null -ne $k.$name -and [string]::IsNullOrWhiteSpace($k.$name) -eq $false) {
                        $candidate = $k.$name
                        if ($candidate -like '*.exe') {
                            if (Test-Path $candidate) { return $candidate }
                        }
                        else {
                            $exe = Join-Path $candidate 'steam.exe'
                            if (Test-Path $exe) { return $exe }
                        }
                    }
                }
            }
        }
    }
    catch { }

    $defaults = @(
        "$env:ProgramFiles (x86)\Steam\steam.exe",
        "$env:ProgramFiles\Steam\steam.exe",
        "$env:LOCALAPPDATA\Programs\Steam\steam.exe"
    )
    foreach ($p in $defaults) { if (Test-Path $p) { return $p } }
    throw "steam.exe not found. Install Steam or provide the path manually."
}

function Get-SteamInstallDir {
    try {
        $steamExe = Get-SteamExePath
        return Split-Path -Path $steamExe -Parent
    } catch { return $null }
}

function Stop-SteamGracefully {
    param(
        [int]$WaitSeconds = 12,
        [bool]$ForceClose = $true
    )
    $steamExe = Get-SteamExePath
    try { & $steamExe -shutdown | Out-Null } catch { }
    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    do {
        Start-Sleep -Milliseconds 300
        $procs = Get-Process -Name steam, steamwebhelper, SteamService, SteamBootstrapper -ErrorAction SilentlyContinue
    } while ($procs -and (Get-Date) -lt $deadline)
    
    if ($ForceClose) {
        $procs = Get-Process -Name steam, steamwebhelper, SteamService, SteamBootstrapper -ErrorAction SilentlyContinue
        if ($procs) {
            foreach ($p in $procs) { try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch { } }
        }
    }
}

function Start-Steam {
    $steamExe = Get-SteamExePath
    Start-Process -FilePath $steamExe -ErrorAction Stop | Out-Null
}

function Restart-Steam {
    Stop-SteamGracefully -WaitSeconds 12 -ForceClose $true
    Start-Steam
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Add-Log {
    param(
        [System.Windows.Forms.TextBoxBase]$TextBox,
        [string]$Message
    )
    $timestamp = (Get-Date).ToString('HH:mm:ss')
    $TextBox.AppendText("[$timestamp] $Message`r`n")
}

# UI
${form} = New-Object System.Windows.Forms.Form
${form}.Text = "SteamShell v$script:AppVersion"
${form}.Size = New-Object System.Drawing.Size(1020, 640)
${form}.StartPosition = 'CenterScreen'
${form}.MaximizeBox = $true
${form}.FormBorderStyle = 'Sizable'
${form}.MinimumSize = New-Object System.Drawing.Size(900, 580)
${form}.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 28)
${form}.ForeColor = [System.Drawing.Color]::White
${form}.Font = New-Object System.Drawing.Font('Segoe UI', 9)
${form}.AllowDrop = $true

$colorSurface = [System.Drawing.Color]::FromArgb(28, 28, 32)
$colorSurfaceAlt = [System.Drawing.Color]::FromArgb(20, 20, 24)
$colorAccent = [System.Drawing.Color]::FromArgb(88, 153, 255)
$colorBorder = [System.Drawing.Color]::FromArgb(62, 62, 66)
$colorSuccess = [System.Drawing.Color]::FromArgb(80, 200, 120)
$colorError = [System.Drawing.Color]::FromArgb(255, 100, 100)

function New-DarkButton([string]$text) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Dock = 'Fill'
    $b.Margin = New-Object System.Windows.Forms.Padding(6, 0, 6, 0)
    $b.FlatStyle = 'Flat'
    $b.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $b.ForeColor = [System.Drawing.Color]::White
    $b.FlatAppearance.BorderColor = $colorBorder
    $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(63, 63, 70)
    $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(51, 51, 55)
    return $b
}

function New-AccentButton([string]$text) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Dock = 'Fill'
    $b.Margin = New-Object System.Windows.Forms.Padding(6, 0, 6, 0)
    $b.FlatStyle = 'Flat'
    $b.BackColor = $colorAccent
    $b.ForeColor = [System.Drawing.Color]::Black
    $b.FlatAppearance.BorderColor = $colorAccent
    $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(109, 170, 255)
    $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(72, 137, 240)
    return $b
}

## Top bar
$topPanel = New-Object System.Windows.Forms.TableLayoutPanel
$topPanel.ColumnCount = 5
$topPanel.RowCount = 1
$topPanel.Dock = 'Top'
$topPanel.Height = 56
$topPanel.Padding = New-Object System.Windows.Forms.Padding(12, 12, 12, 6)
$topPanel.BackColor = $colorSurface
for ($i = 0; $i -lt 5; $i++) { $null = $topPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 20))) }

$btnStart = New-DarkButton 'Start'
$btnStop = New-DarkButton 'Stop'
$btnRestart = New-DarkButton 'Restart'
$btnKill = New-DarkButton 'Kill All'
$btnKill.ForeColor = $colorError
$btnImport = New-AccentButton 'Import'

$topPanel.Controls.AddRange(@($btnStart, $btnStop, $btnRestart, $btnKill, $btnImport))

## Main layout
$mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
$mainLayout.ColumnCount = 2
$mainLayout.RowCount = 2
$mainLayout.Dock = 'Fill'
[void]$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 62)))
[void]$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$mainLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 70)))
[void]$mainLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 30)))

## Log
$rtbLog = New-Object System.Windows.Forms.RichTextBox
$rtbLog.Dock = 'Fill'
$rtbLog.Margin = New-Object System.Windows.Forms.Padding(12, 6, 12, 0)
$rtbLog.ReadOnly = $true
$rtbLog.Font = New-Object System.Drawing.Font('Consolas', 10)
$rtbLog.BackColor = $colorSurfaceAlt
$rtbLog.ForeColor = [System.Drawing.Color]::Gainsboro
$rtbLog.BorderStyle = 'None'
$rtbLog.DetectUrls = $false

## Right panel
$sidePanel = New-Object System.Windows.Forms.Panel
$sidePanel.Dock = 'Fill'
$sidePanel.BackColor = $colorSurface
$sidePanel.Padding = New-Object System.Windows.Forms.Padding(0, 8, 12, 8)

$sideLayout = New-Object System.Windows.Forms.TableLayoutPanel
$sideLayout.Dock = 'Fill'
$sideLayout.ColumnCount = 1
$sideLayout.RowCount = 4
[void]$sideLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 130))) # Config
[void]$sideLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 120))) # Accounts
[void]$sideLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 220))) # Import Options
[void]$sideLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) # Quick Actions

# Group Config
$groupSteam = New-Object System.Windows.Forms.GroupBox
$groupSteam.Text = 'Steam Configuration'
$groupSteam.Dock = 'Fill'
$groupSteam.ForeColor = [System.Drawing.Color]::Gainsboro

$steamLayout = New-Object System.Windows.Forms.TableLayoutPanel
$steamLayout.Dock = 'Fill'
$steamLayout.ColumnCount = 2
$steamLayout.RowCount = 2
$labelSteamPath = New-Object System.Windows.Forms.Label
$labelSteamPath.Text = 'Auto-detecting...'; $labelSteamPath.Dock = 'Top'; $labelSteamPath.AutoEllipsis = $true; $labelSteamPath.ForeColor = [System.Drawing.Color]::Silver
$btnBrowseSteam = New-DarkButton 'Browse'; $btnOpenSteamFolder = New-DarkButton 'Folder'
$steamLayout.Controls.Add($labelSteamPath, 0, 0); $steamLayout.SetColumnSpan($labelSteamPath, 2)
$steamLayout.Controls.Add($btnBrowseSteam, 0, 1); $steamLayout.Controls.Add($btnOpenSteamFolder, 1, 1)
$groupSteam.Controls.Add($steamLayout)

# Group Accounts
$groupAcc = New-Object System.Windows.Forms.GroupBox
$groupAcc.Text = 'Steam Accounts'
$groupAcc.Dock = 'Fill'
$groupAcc.ForeColor = [System.Drawing.Color]::Gainsboro

$accLayout = New-Object System.Windows.Forms.TableLayoutPanel
$accLayout.Dock = 'Fill'
$accLayout.ColumnCount = 2
$accLayout.RowCount = 2
$comboAccounts = New-Object System.Windows.Forms.ComboBox
$comboAccounts.Dock = 'Fill'; $comboAccounts.DropDownStyle = 'DropDownList'; $comboAccounts.BackColor = $colorSurfaceAlt; $comboAccounts.ForeColor = [System.Drawing.Color]::White; $comboAccounts.FlatStyle = 'Flat'
$btnSwitchAcc = New-DarkButton 'Switch'
$btnRefreshAcc = New-DarkButton 'Ref.'
$accLayout.Controls.Add($comboAccounts, 0, 0); $accLayout.SetColumnSpan($comboAccounts, 2)
$accLayout.Controls.Add($btnSwitchAcc, 0, 1); $accLayout.Controls.Add($btnRefreshAcc, 1, 1)
$groupAcc.Controls.Add($accLayout)

# Group Import Options
$groupImport = New-Object System.Windows.Forms.GroupBox
$groupImport.Text = 'Import Options'
$groupImport.Dock = 'Fill'
$groupImport.ForeColor = [System.Drawing.Color]::Gainsboro

$importLayout = New-Object System.Windows.Forms.TableLayoutPanel
$importLayout.Dock = 'Fill'
$importLayout.ColumnCount = 2
$importLayout.RowCount = 5
$chkManifest = New-Object System.Windows.Forms.CheckBox; $chkManifest.Text = 'Manifests'; $chkManifest.Checked = $true
$chkLua = New-Object System.Windows.Forms.CheckBox; $chkLua.Text = 'Lua Scripts'; $chkLua.Checked = $true
$chkBackup = New-Object System.Windows.Forms.CheckBox; $chkBackup.Text = 'Backup before overwrite'; $chkBackup.Checked = $true; $chkBackup.ForeColor = $colorAccent
$labelWait = New-Object System.Windows.Forms.Label; $labelWait.Text = 'Shutdown wait (s)'
$numWait = New-Object System.Windows.Forms.NumericUpDown; $numWait.Minimum = 4; $numWait.Maximum = 60; $numWait.Value = 12; $numWait.BackColor = $colorSurfaceAlt; $numWait.ForeColor = [System.Drawing.Color]::White
$chkAlwaysOnTop = New-Object System.Windows.Forms.CheckBox; $chkAlwaysOnTop.Text = 'Always on top'
$importLayout.Controls.Add($chkManifest, 0, 0); $importLayout.Controls.Add($chkLua, 1, 0)
$importLayout.Controls.Add($chkBackup, 0, 1); $importLayout.SetColumnSpan($chkBackup, 2)
$importLayout.Controls.Add($labelWait, 0, 2); $importLayout.Controls.Add($numWait, 1, 2)
$importLayout.Controls.Add($chkAlwaysOnTop, 0, 3)
$groupImport.Controls.Add($importLayout)

# Group Quick Actions
$groupQuick = New-Object System.Windows.Forms.GroupBox
$groupQuick.Text = 'Quick Actions'
$groupQuick.Dock = 'Fill'
$groupQuick.ForeColor = [System.Drawing.Color]::Gainsboro

$quickLayout = New-Object System.Windows.Forms.TableLayoutPanel
$quickLayout.Dock = 'Fill'
$quickLayout.ColumnCount = 2
$btnOpenDepot = New-DarkButton 'Depot cache'; $btnOpenLua = New-DarkButton 'ST Plug-in'
$btnClearLog = New-DarkButton 'Clear log'; $btnSaveLog = New-DarkButton 'Save log'
$btnRevealConfig = New-DarkButton 'Config'; $btnAbout = New-DarkButton 'About'
$quickLayout.Controls.Add($btnOpenDepot, 0, 0); $quickLayout.Controls.Add($btnOpenLua, 1, 0)
$quickLayout.Controls.Add($btnClearLog, 0, 1); $quickLayout.Controls.Add($btnSaveLog, 1, 1)
$quickLayout.Controls.Add($btnRevealConfig, 0, 2); $quickLayout.Controls.Add($btnAbout, 1, 2)
$groupQuick.Controls.Add($quickLayout)

$sideLayout.Controls.AddRange(@($groupSteam, $groupAcc, $groupImport, $groupQuick))
$sidePanel.Controls.Add($sideLayout)

## Status strip
$statusStrip = New-Object System.Windows.Forms.StatusStrip; $statusStrip.BackColor = $colorSurface; $statusStrip.ForeColor = [System.Drawing.Color]::White
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel; $statusLabel.Text = "SteamShell v$script:AppVersion • Ready"; $statusStrip.Items.Add($statusLabel) | Out-Null
$statusSteam = New-Object System.Windows.Forms.ToolStripStatusLabel; $statusSteam.Alignment = [System.Windows.Forms.ToolStripItemAlignment]::Right; $statusSteam.Text = "STEAM: CHECKING..."; $statusStrip.Items.Add($statusSteam) | Out-Null

$mainLayout.Controls.Add($rtbLog, 0, 1); $mainLayout.Controls.Add($sidePanel, 1, 1)
${form}.Controls.AddRange(@($mainLayout, $topPanel, $statusStrip))

# Timer
$timerStatus = New-Object System.Windows.Forms.Timer; $timerStatus.Interval = 3000
function Update-SteamStatus {
    $procs = Get-Process -Name steam -ErrorAction SilentlyContinue
    if ($procs) { $statusSteam.Text = "STEAM: RUNNING"; $statusSteam.ForeColor = $colorSuccess } 
    else { $statusSteam.Text = "STEAM: STOPPED"; $statusSteam.ForeColor = $colorError }
}
$timerStatus.Add_Tick({ Update-SteamStatus })

# Steam Account Logic
function Get-SteamAccounts {
    $accounts = @()
    $steamDir = Get-SteamInstallDir
    if ($null -eq $steamDir) { return $accounts }
    $vdfPath = Join-Path $steamDir "config\loginusers.vdf"
    if (Test-Path $vdfPath) {
        $content = Get-Content $vdfPath
        $currentAccount = $null
        foreach ($line in $content) {
            if ($line -match '^\s*"(\d{5,})"') { $currentAccount = @{ id = $matches[1] } }
            elseif ($line -match '"AccountName"\s+"([^"]+)"' -and $null -ne $currentAccount) { $currentAccount.name = $matches[1] }
            elseif ($line -match '"PersonaName"\s+"([^"]+)"' -and $null -ne $currentAccount) { $currentAccount.persona = $matches[1] }
            elseif ($line -match '^\s*}' -and $null -ne $currentAccount) { 
                if ($currentAccount.name) { $accounts += $currentAccount }
                $currentAccount = $null 
            }
        }
    }
    return $accounts
}

function Refresh-Accounts {
    $comboAccounts.Items.Clear()
    $script:SteamAccountsList = Get-SteamAccounts
    foreach ($acc in $script:SteamAccountsList) {
        $null = $comboAccounts.Items.Add("$($acc.persona) ($($acc.name))")
    }
    if ($comboAccounts.Items.Count -gt 0) { $comboAccounts.SelectedIndex = 0 }
    
    # Try selection current user
    $current = (Get-ItemProperty "HKCU:\Software\Valve\Steam").AutoLoginUser
    if ($current) {
        for ($i=0; $i -lt $script:SteamAccountsList.Count; $i++) {
            if ($script:SteamAccountsList[$i].name -eq $current) { $comboAccounts.SelectedIndex = $i; break }
        }
    }
}

# Functions
function Set-UiBusy($busy) {
    foreach ($ctrl in @($btnStart, $btnStop, $btnRestart, $btnKill, $btnImport, $btnSwitchAcc, $btnRefreshAcc)) { $ctrl.Enabled = -not $busy }
    $statusLabel.Text = if ($busy) { "Working..." } else { "Ready • v$script:AppVersion" }
}

function Check-ForUpdates {
    try {
        $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/kozaaaaczx/steam-lua/releases/latest" -ErrorAction SilentlyContinue
        if ($null -ne $latest.tag_name) {
            $latestVerStr = $latest.tag_name -replace 'v', ''
            if ([version]$latestVerStr -gt [version]$script:AppVersion) {
                $title = "SteamShell - Update Available"
                $msg = "A new version (v$latestVerStr) is available!`n`nWould you like to install the update now?"
                if ([System.Windows.Forms.MessageBox]::Show($msg, $title, 4, 32) -eq 6) { Start-Process "https://github.com/kozaaaaczx/steam-lua/releases/latest" }
            }
        }
    } catch { }
}

function Import-SteamFiles($filePaths) {
    $manifestDstDir = 'C:\Program Files (x86)\Steam\depotcache'
    $luaDstDir = 'C:\Program Files (x86)\Steam\config\stplug-in'
    if (-not (Test-Path $manifestDstDir)) { New-Item -ItemType Directory -Path $manifestDstDir -Force | Out-Null }
    if (-not (Test-Path $luaDstDir)) { New-Item -ItemType Directory -Path $luaDstDir -Force | Out-Null }
    
    foreach ($src in $filePaths) {
        $ext = [System.IO.Path]::GetExtension($src).ToLower()
        $dstDir = $null
        if ($ext -eq ".manifest") { $dstDir = $manifestDstDir }
        elseif ($ext -eq ".lua") { $dstDir = $luaDstDir }
        
        if ($dstDir) {
            $dst = Join-Path $dstDir ([System.IO.Path]::GetFileName($src))
            if ($chkBackup.Checked -and (Test-Path $dst)) { Copy-Item $dst ($dst + ".bak") -Force }
            Copy-Item -LiteralPath $src -Destination $dst -Force
            Add-Log -TextBox $rtbLog -Message "Imported: $([System.IO.Path]::GetFileName($src))"
        }
    }
}

# Handlers
$btnStart.Add_Click({ Set-UiBusy $true; Start-Steam; Set-UiBusy $false })
$btnStop.Add_Click({ Set-UiBusy $true; Stop-SteamGracefully -WaitSeconds ([int]$numWait.Value); Set-UiBusy $false })
$btnKill.Add_Click({ 
    $procs = Get-Process -Name steam, steamwebhelper, SteamService -ErrorAction SilentlyContinue
    if ($procs) { foreach ($p in $procs) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } }
    Add-Log -TextBox $rtbLog -Message "Force killed Steam processes."
})
$btnRestart.Add_Click({ Set-UiBusy $true; Restart-Steam; Set-UiBusy $false })

$btnImport.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Multiselect = $true; $d.Filter = "Steam Files (*.manifest, *.lua)|*.manifest;*.lua"
    if ($d.ShowDialog() -eq 1) { Import-SteamFiles $d.FileNames; Add-Log -TextBox $rtbLog -Message "Import complete." }
})

$btnRefreshAcc.Add_Click({ Refresh-Accounts })
$btnSwitchAcc.Add_Click({
    if ($comboAccounts.SelectedIndex -ge 0) {
        $acc = $script:SteamAccountsList[$comboAccounts.SelectedIndex]
        Set-ItemProperty "HKCU:\Software\Valve\Steam" -Name "AutoLoginUser" -Value $acc.name
        Set-ItemProperty "HKCU:\Software\Valve\Steam" -Name "RememberPassword" -Value 1
        Add-Log -TextBox $rtbLog -Message "Account switched to: $($acc.name). Restarting Steam..."
        Restart-Steam
    }
})

# Drag & Drop Handlers
${form}.Add_DragEnter({ if ($_.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { $_.Effect = [System.Windows.Forms.DragDropEffects]::Copy } })
${form}.Add_DragDrop({
    $files = @($_.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop))
    if ($files.Count -gt 0) {
        Import-SteamFiles $files
        $res = [System.Windows.Forms.MessageBox]::Show("Files imported via Drag & Drop. Restart Steam now?", "Restart?", 4, 32)
        if ($res -eq 6) { Restart-Steam }
    }
})

$rtbLog.Add_DragEnter({ if ($_.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { $_.Effect = [System.Windows.Forms.DragDropEffects]::Copy } })
$rtbLog.Add_DragDrop({
    $files = @($_.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop))
    if ($files.Count -gt 0) { Import-SteamFiles $files }
})

$btnOpenDepot.Add_Click({ Start-Process 'C:\Program Files (x86)\Steam\depotcache' })
$btnOpenLua.Add_Click({ Start-Process 'C:\Program Files (x86)\Steam\config\stplug-in' })
$btnRevealConfig.Add_Click({ Start-Process 'C:\Program Files (x86)\Steam\config' })
$btnClearLog.Add_Click({ $rtbLog.Clear() })
$chkAlwaysOnTop.Add_CheckedChanged({ ${form}.TopMost = $chkAlwaysOnTop.Checked })
$btnAbout.Add_Click({ [System.Windows.Forms.MessageBox]::Show("SteamShell v$script:AppVersion`n`nNew: Account Switcher & Drag & Drop!`n`nGitHub: https://github.com/kozaaaaczx/steam-lua", "About", 0, 64) })

# Init
Update-SteamStatus; Refresh-Accounts; $timerStatus.Start()
[void](New-Object System.Windows.Forms.Timer -Property @{Interval=2000;Enabled=$true}).Add_Tick({ $_.Stop(); Check-ForUpdates })

[void]${form}.ShowDialog()