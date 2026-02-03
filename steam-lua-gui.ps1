Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Steam functions (embedded so the EXE is self-contained)
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
                foreach ($name in @('SteamExe','SteamPath','InstallPath')) {
                    if ($null -ne $k.$name -and [string]::IsNullOrWhiteSpace($k.$name) -eq $false) {
                        $candidate = $k.$name
                        if ($candidate -like '*.exe') {
                            if (Test-Path $candidate) { return $candidate }
                        } else {
                            $exe = Join-Path $candidate 'steam.exe'
                            if (Test-Path $exe) { return $exe }
                        }
                    }
                }
            }
        }
    } catch { }

    $defaults = @(
        "$env:ProgramFiles (x86)\Steam\steam.exe",
        "$env:ProgramFiles\Steam\steam.exe",
        "$env:LOCALAPPDATA\Programs\Steam\steam.exe"
    )
    foreach ($p in $defaults) { if (Test-Path $p) { return $p } }
    throw "steam.exe not found. Install Steam or provide the path manually."
}

function Get-SteamInstallDir {
    $steamExe = Get-SteamExePath
    return Split-Path -Path $steamExe -Parent
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
    Stop-SteamGracefully -WaitSeconds 12
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
${form}            = New-Object System.Windows.Forms.Form
${form}.Text       = 'Steam lua'
${form}.Size       = New-Object System.Drawing.Size(980, 560)
${form}.StartPosition= 'CenterScreen'
${form}.MaximizeBox= $true
${form}.FormBorderStyle = 'Sizable'
${form}.MinimumSize = New-Object System.Drawing.Size(860, 520)
${form}.BackColor   = [System.Drawing.Color]::FromArgb(24,24,28)
${form}.ForeColor   = [System.Drawing.Color]::White
${form}.Font        = New-Object System.Drawing.Font('Segoe UI', 9)

$colorSurface = [System.Drawing.Color]::FromArgb(28, 28, 32)
$colorSurfaceAlt = [System.Drawing.Color]::FromArgb(20, 20, 24)
$colorAccent = [System.Drawing.Color]::FromArgb(88, 153, 255)
$colorBorder = [System.Drawing.Color]::FromArgb(62, 62, 66)

function New-SectionLabel([string]$text) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $text
    $label.Dock = 'Top'
    $label.AutoSize = $false
    $label.Height = 22
    $label.Margin = New-Object System.Windows.Forms.Padding(8,10,8,0)
    $label.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
    $label.ForeColor = [System.Drawing.Color]::Gainsboro
    return $label
}

## Top bar: TableLayoutPanel with buttons
$topPanel = New-Object System.Windows.Forms.TableLayoutPanel
$topPanel.ColumnCount = 4
$topPanel.RowCount = 1
$topPanel.Dock = 'Top'
$topPanel.Height = 56
$topPanel.Padding = New-Object System.Windows.Forms.Padding(12,12,12,6)
$topPanel.BackColor = $colorSurface
for ($i=0; $i -lt 4; $i++) { $null = $topPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25))) }

function New-DarkButton([string]$text){
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Dock = 'Fill'
    $b.Margin = New-Object System.Windows.Forms.Padding(6,0,6,0)
    $b.FlatStyle = 'Flat'
    $b.BackColor = [System.Drawing.Color]::FromArgb(45,45,48)
    $b.ForeColor = [System.Drawing.Color]::White
    $b.FlatAppearance.BorderColor = $colorBorder
    $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(63,63,70)
    $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(51,51,55)
    return $b
}

function New-AccentButton([string]$text){
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Dock = 'Fill'
    $b.Margin = New-Object System.Windows.Forms.Padding(6,0,6,0)
    $b.FlatStyle = 'Flat'
    $b.BackColor = $colorAccent
    $b.ForeColor = [System.Drawing.Color]::Black
    $b.FlatAppearance.BorderColor = $colorAccent
    $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(109, 170, 255)
    $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(72, 137, 240)
    return $b
}

$btnStart   = New-DarkButton 'Start'
$btnStop    = New-DarkButton 'Stop'
$btnRestart = New-DarkButton 'Restart'
$btnImport  = New-AccentButton 'Import'

$topPanel.Controls.Add($btnStart,0,0)
$topPanel.Controls.Add($btnStop,1,0)
$topPanel.Controls.Add($btnRestart,2,0)
$topPanel.Controls.Add($btnImport,3,0)

## Main layout
$mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
$mainLayout.ColumnCount = 2
$mainLayout.RowCount = 2
$mainLayout.Dock = 'Fill'
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 62)))
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$mainLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 72)))
$mainLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 28)))

## Log as RichTextBox filling the client area
$rtbLog = New-Object System.Windows.Forms.RichTextBox
$rtbLog.Dock = 'Fill'
$rtbLog.Margin = New-Object System.Windows.Forms.Padding(12,6,12,0)
$rtbLog.ReadOnly = $true
$rtbLog.Font = New-Object System.Drawing.Font('Consolas', 10)
$rtbLog.BackColor = $colorSurfaceAlt
$rtbLog.ForeColor = [System.Drawing.Color]::Gainsboro
$rtbLog.BorderStyle = 'None'
$rtbLog.DetectUrls = $false

## Right panel: options + quick actions
$sidePanel = New-Object System.Windows.Forms.Panel
$sidePanel.Dock = 'Fill'
$sidePanel.BackColor = $colorSurface
$sidePanel.Padding = New-Object System.Windows.Forms.Padding(0,8,12,8)

$sideLayout = New-Object System.Windows.Forms.TableLayoutPanel
$sideLayout.Dock = 'Fill'
$sideLayout.ColumnCount = 1
$sideLayout.RowCount = 3
$sideLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 170)))
$sideLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 210)))
$sideLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))

$groupSteam = New-Object System.Windows.Forms.GroupBox
$groupSteam.Text = 'Steam'
$groupSteam.Dock = 'Fill'
$groupSteam.BackColor = $colorSurface
$groupSteam.ForeColor = [System.Drawing.Color]::Gainsboro
$groupSteam.Padding = New-Object System.Windows.Forms.Padding(10,20,10,10)

$steamLayout = New-Object System.Windows.Forms.TableLayoutPanel
$steamLayout.Dock = 'Fill'
$steamLayout.ColumnCount = 2
$steamLayout.RowCount = 4
$steamLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 65)))
$steamLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 35)))
$steamLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))
$steamLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
$steamLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
$steamLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))

$labelSteamPathTitle = New-Object System.Windows.Forms.Label
$labelSteamPathTitle.Text = 'Steam.exe:'
$labelSteamPathTitle.Dock = 'Fill'
$labelSteamPathTitle.ForeColor = [System.Drawing.Color]::Silver

$labelSteamPath = New-Object System.Windows.Forms.Label
$labelSteamPath.Text = 'Auto-detect'
$labelSteamPath.Dock = 'Fill'
$labelSteamPath.AutoEllipsis = $true
$labelSteamPath.ForeColor = [System.Drawing.Color]::Gainsboro

$btnBrowseSteam = New-DarkButton 'Browse...'
$btnBrowseSteam.Margin = New-Object System.Windows.Forms.Padding(0,0,0,0)
$btnOpenSteamFolder = New-DarkButton 'Open folder'
$btnOpenSteamFolder.Margin = New-Object System.Windows.Forms.Padding(0,0,0,0)

$steamLayout.Controls.Add($labelSteamPathTitle, 0, 0)
$steamLayout.Controls.Add($labelSteamPath, 0, 1)
$steamLayout.SetColumnSpan($labelSteamPath, 2)
$steamLayout.Controls.Add($btnBrowseSteam, 1, 2)
$steamLayout.Controls.Add($btnOpenSteamFolder, 1, 3)

$groupSteam.Controls.Add($steamLayout)

$groupImport = New-Object System.Windows.Forms.GroupBox
$groupImport.Text = 'Import options'
$groupImport.Dock = 'Fill'
$groupImport.BackColor = $colorSurface
$groupImport.ForeColor = [System.Drawing.Color]::Gainsboro
$groupImport.Padding = New-Object System.Windows.Forms.Padding(10,20,10,10)

$importLayout = New-Object System.Windows.Forms.TableLayoutPanel
$importLayout.Dock = 'Fill'
$importLayout.ColumnCount = 2
$importLayout.RowCount = 5
$importLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 60)))
$importLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 40)))
$importLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))
$importLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
$importLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
$importLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 32)))
$importLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 32)))

$chkImportManifest = New-Object System.Windows.Forms.CheckBox
$chkImportManifest.Text = 'Manifests (.manifest)'
$chkImportManifest.Checked = $true
$chkImportManifest.Dock = 'Fill'

$chkImportLua = New-Object System.Windows.Forms.CheckBox
$chkImportLua.Text = 'Lua scripts (.lua)'
$chkImportLua.Checked = $true
$chkImportLua.Dock = 'Fill'

$labelWait = New-Object System.Windows.Forms.Label
$labelWait.Text = 'Shutdown wait (s)'
$labelWait.Dock = 'Fill'
$labelWait.ForeColor = [System.Drawing.Color]::Silver

$numWait = New-Object System.Windows.Forms.NumericUpDown
$numWait.Minimum = 4
$numWait.Maximum = 60
$numWait.Value = 12
$numWait.Dock = 'Fill'
$numWait.BackColor = $colorSurfaceAlt
$numWait.ForeColor = [System.Drawing.Color]::White
$numWait.BorderStyle = 'FixedSingle'

$chkForceClose = New-Object System.Windows.Forms.CheckBox
$chkForceClose.Text = 'Force close if still running'
$chkForceClose.Checked = $true
$chkForceClose.Dock = 'Fill'
$chkForceClose.Margin = New-Object System.Windows.Forms.Padding(0,6,0,0)

$chkAlwaysOnTop = New-Object System.Windows.Forms.CheckBox
$chkAlwaysOnTop.Text = 'Always on top'
$chkAlwaysOnTop.Checked = $false
$chkAlwaysOnTop.Dock = 'Fill'
$chkAlwaysOnTop.Margin = New-Object System.Windows.Forms.Padding(0,6,0,0)

$importLayout.Controls.Add($chkImportManifest, 0, 0)
$importLayout.SetColumnSpan($chkImportManifest, 2)
$importLayout.Controls.Add($chkImportLua, 0, 1)
$importLayout.SetColumnSpan($chkImportLua, 2)
$importLayout.Controls.Add($labelWait, 0, 2)
$importLayout.Controls.Add($numWait, 1, 2)
$importLayout.Controls.Add($chkForceClose, 0, 3)
$importLayout.SetColumnSpan($chkForceClose, 2)
$importLayout.Controls.Add($chkAlwaysOnTop, 0, 4)
$importLayout.SetColumnSpan($chkAlwaysOnTop, 2)

$groupImport.Controls.Add($importLayout)

$groupQuick = New-Object System.Windows.Forms.GroupBox
$groupQuick.Text = 'Quick actions'
$groupQuick.Dock = 'Fill'
$groupQuick.BackColor = $colorSurface
$groupQuick.ForeColor = [System.Drawing.Color]::Gainsboro
$groupQuick.Padding = New-Object System.Windows.Forms.Padding(10,20,10,10)

$quickLayout = New-Object System.Windows.Forms.TableLayoutPanel
$quickLayout.Dock = 'Fill'
$quickLayout.ColumnCount = 2
$quickLayout.RowCount = 3
$quickLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$quickLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$quickLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 36)))
$quickLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 36)))
$quickLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 36)))

$btnOpenDepot = New-DarkButton 'Open depotcache'
$btnOpenLua = New-DarkButton 'Open stplug-in'
$btnClearLog = New-DarkButton 'Clear log'
$btnSaveLog = New-DarkButton 'Save log'
$btnCopyPath = New-DarkButton 'Copy Steam path'
$btnRevealConfig = New-DarkButton 'Open config'

$btnOpenDepot.Margin = New-Object System.Windows.Forms.Padding(3,0,3,0)
$btnOpenLua.Margin = New-Object System.Windows.Forms.Padding(3,0,3,0)
$btnClearLog.Margin = New-Object System.Windows.Forms.Padding(3,0,3,0)
$btnSaveLog.Margin = New-Object System.Windows.Forms.Padding(3,0,3,0)
$btnCopyPath.Margin = New-Object System.Windows.Forms.Padding(3,0,3,0)
$btnRevealConfig.Margin = New-Object System.Windows.Forms.Padding(3,0,3,0)

$quickLayout.Controls.Add($btnOpenDepot, 0, 0)
$quickLayout.Controls.Add($btnOpenLua, 1, 0)
$quickLayout.Controls.Add($btnClearLog, 0, 1)
$quickLayout.Controls.Add($btnSaveLog, 1, 1)
$quickLayout.Controls.Add($btnCopyPath, 0, 2)
$quickLayout.Controls.Add($btnRevealConfig, 1, 2)

$groupQuick.Controls.Add($quickLayout)

$sideLayout.Controls.Add($groupSteam, 0, 0)
$sideLayout.Controls.Add($groupImport, 0, 1)
$sideLayout.Controls.Add($groupQuick, 0, 2)
$sidePanel.Controls.Add($sideLayout)

## Status strip at bottom
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.SizingGrip = $true
$statusStrip.BackColor = $colorSurface
$statusStrip.ForeColor = [System.Drawing.Color]::White
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = 'Ready'
$statusStrip.Items.Add($statusLabel) | Out-Null

$mainLayout.Controls.Add($topPanel, 0, 0)
$mainLayout.SetColumnSpan($topPanel, 2)
$mainLayout.Controls.Add($rtbLog, 0, 1)
$mainLayout.Controls.Add($sidePanel, 1, 1)

${form}.Controls.AddRange(@($mainLayout, $statusStrip))

function Set-UiBusy($busy) {
    $btnStart.Enabled   = -not $busy
    $btnStop.Enabled    = -not $busy
    $btnRestart.Enabled = -not $busy
    $btnImport.Enabled  = -not $busy
    if ($busy) { $statusLabel.Text = 'Working...' } else { $statusLabel.Text = 'Ready' }
}

function Update-SteamPathLabel {
    try {
        $path = Get-SteamExePath
        $labelSteamPath.Text = $path
    } catch {
        $labelSteamPath.Text = 'Not found'
    }
}

function Open-Folder([string]$path, [string]$label) {
    if (-not (Test-Path $path)) {
        Add-Log -TextBox $rtbLog -Message ("Missing folder: " + $path)
        return
    }
    Add-Log -TextBox $rtbLog -Message ("Opening " + $label + "...")
    Start-Process -FilePath $path | Out-Null
}

# Handlery
$btnStart.Add_Click({
    try {
        Set-UiBusy $true
        Add-Log -TextBox $rtbLog -Message 'Starting Steam...'
        Start-Steam
        Add-Log -TextBox $rtbLog -Message 'Steam started.'
    } catch {
        Add-Log -TextBox $rtbLog -Message ("Error: " + $_.Exception.Message)
    } finally {
        Set-UiBusy $false
    }
})

$btnStop.Add_Click({
    try {
        Set-UiBusy $true
        Add-Log -TextBox $rtbLog -Message 'Closing Steam...'
        Stop-SteamGracefully -WaitSeconds ([int]$numWait.Value) -ForceClose $chkForceClose.Checked
        Add-Log -TextBox $rtbLog -Message 'Steam closed.'
    } catch {
        Add-Log -TextBox $rtbLog -Message ("Error: " + $_.Exception.Message)
    } finally {
        Set-UiBusy $false
    }
})

$btnRestart.Add_Click({
    try {
        Set-UiBusy $true
        Add-Log -TextBox $rtbLog -Message 'Restarting Steam...'
        Stop-SteamGracefully -WaitSeconds ([int]$numWait.Value) -ForceClose $chkForceClose.Checked
        Start-Steam
        Add-Log -TextBox $rtbLog -Message 'Restart completed.'
    } catch {
        Add-Log -TextBox $rtbLog -Message ("Error: " + $_.Exception.Message)
    } finally {
        Set-UiBusy $false
    }
})

$btnImport.Add_Click({
    try {
        Set-UiBusy $true
        if (-not $chkImportManifest.Checked -and -not $chkImportLua.Checked) {
            Add-Log -TextBox $rtbLog -Message 'Select at least one import type.'
            return
        }

        $manifestSrcs = @()
        $luaSrcs = @()

        if ($chkImportManifest.Checked) {
            $manifestDialog = New-Object System.Windows.Forms.OpenFileDialog
            $manifestDialog.Title = 'Select .manifest files'
            $manifestDialog.Filter = 'Manifest (*.manifest)|*.manifest'
            $manifestDialog.CheckFileExists = $true
            $manifestDialog.Multiselect = $true
            if ($manifestDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
                Add-Log -TextBox $rtbLog -Message 'Import cancelled (manifest).'
                return
            }
            $manifestSrcs = @($manifestDialog.FileNames)
        }

        if ($chkImportLua.Checked) {
            $luaDialog = New-Object System.Windows.Forms.OpenFileDialog
            $luaDialog.Title = 'Select .lua files'
            $luaDialog.Filter = 'Lua (*.lua)|*.lua'
            $luaDialog.CheckFileExists = $true
            $luaDialog.Multiselect = $true
            if ($luaDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
                Add-Log -TextBox $rtbLog -Message 'Import cancelled (lua).'
                return
            }
            $luaSrcs = @($luaDialog.FileNames)
        }

        $manifestDstDir = 'C:\Program Files (x86)\Steam\depotcache'
        $luaDstDir      = 'C:\Program Files (x86)\Steam\config\stplug-in'

        if (-not (Test-Path $manifestDstDir)) { New-Item -ItemType Directory -Path $manifestDstDir -Force | Out-Null }
        if (-not (Test-Path $luaDstDir)) { New-Item -ItemType Directory -Path $luaDstDir -Force | Out-Null }

        if ($manifestSrcs.Count -gt 0) {
            Add-Log -TextBox $rtbLog -Message ("Copying manifests (" + $manifestSrcs.Count + ")...")
            foreach ($m in $manifestSrcs) {
                $manifestDst = Join-Path $manifestDstDir ([System.IO.Path]::GetFileName($m))
                Copy-Item -LiteralPath $m -Destination $manifestDst -Force
            }
        }
        if ($luaSrcs.Count -gt 0) {
            Add-Log -TextBox $rtbLog -Message ("Copying lua files (" + $luaSrcs.Count + ")...")
            foreach ($l in $luaSrcs) {
                $luaDst = Join-Path $luaDstDir ([System.IO.Path]::GetFileName($l))
                Copy-Item -LiteralPath $l -Destination $luaDst -Force
            }
        }
        Add-Log -TextBox $rtbLog -Message 'Import completed.'
    } catch {
        Add-Log -TextBox $rtbLog -Message ("Error: " + $_.Exception.Message)
    } finally {
        Set-UiBusy $false
    }
})

$btnBrowseSteam.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = 'Select steam.exe'
    $dialog.Filter = 'Steam (steam.exe)|steam.exe'
    $dialog.CheckFileExists = $true
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $script:SteamExeOverride = $dialog.FileName
    Update-SteamPathLabel
    Add-Log -TextBox $rtbLog -Message ("Steam path set to: " + $dialog.FileName)
})

$btnOpenSteamFolder.Add_Click({
    try {
        $dir = Get-SteamInstallDir
        Open-Folder -path $dir -label 'Steam folder'
    } catch {
        Add-Log -TextBox $rtbLog -Message ("Error: " + $_.Exception.Message)
    }
})

$btnOpenDepot.Add_Click({ Open-Folder -path 'C:\Program Files (x86)\Steam\depotcache' -label 'depotcache' })
$btnOpenLua.Add_Click({ Open-Folder -path 'C:\Program Files (x86)\Steam\config\stplug-in' -label 'stplug-in' })
$btnRevealConfig.Add_Click({ Open-Folder -path 'C:\Program Files (x86)\Steam\config' -label 'config' })

$btnClearLog.Add_Click({ $rtbLog.Clear() })

$btnSaveLog.Add_Click({
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Title = 'Save log'
    $dialog.Filter = 'Text (*.txt)|*.txt'
    $dialog.FileName = 'steam-lua-log.txt'
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $rtbLog.SaveFile($dialog.FileName, [System.Windows.Forms.RichTextBoxStreamType]::PlainText)
    Add-Log -TextBox $rtbLog -Message ("Log saved: " + $dialog.FileName)
})

$btnCopyPath.Add_Click({
    try {
        $path = Get-SteamExePath
        [System.Windows.Forms.Clipboard]::SetText($path)
        Add-Log -TextBox $rtbLog -Message 'Steam path copied.'
    } catch {
        Add-Log -TextBox $rtbLog -Message ("Error: " + $_.Exception.Message)
    }
})

$chkAlwaysOnTop.Add_CheckedChanged({
    ${form}.TopMost = $chkAlwaysOnTop.Checked
})

# Init
Update-SteamPathLabel

# Show
[void]${form}.ShowDialog()
