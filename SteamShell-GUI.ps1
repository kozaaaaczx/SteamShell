Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# SteamShell v0.7.0 "The Professional Update"
$script:AppVersion = '0.7.0'
$script:SteamExeOverride = $null

function Get-SteamExePath {
    if ($script:SteamExeOverride -and (Test-Path $script:SteamExeOverride)) { return $script:SteamExeOverride }
    try {
        foreach ($rp in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
            if (Test-Path $rp) {
                $k = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
                foreach ($n in @('SteamExe','SteamPath','InstallPath')) {
                    if ($k.$n -and -not [string]::IsNullOrWhiteSpace($k.$n)) {
                        if ($k.$n -like '*.exe') { if (Test-Path $k.$n) { return $k.$n } }
                        else { $exe = Join-Path $k.$n 'steam.exe'; if (Test-Path $exe) { return $exe } }
                    }
                }
            }
        }
    } catch {}
    foreach ($p in @("$env:ProgramFiles (x86)\Steam\steam.exe","$env:ProgramFiles\Steam\steam.exe")) { if (Test-Path $p) { return $p } }
    throw "steam.exe not found."
}
function Get-SteamInstallDir { try { Split-Path (Get-SteamExePath) -Parent } catch { $null } }
function Stop-SteamGracefully([int]$Wait=12) {
    try { & (Get-SteamExePath) -shutdown | Out-Null } catch {}
    $end = (Get-Date).AddSeconds($Wait)
    do { Start-Sleep -Milliseconds 400; $pr = Get-Process steam,steamwebhelper,SteamService -ErrorAction SilentlyContinue } while ($pr -and (Get-Date) -lt $end)
    Get-Process steam,steamwebhelper,SteamService -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
function Start-Steam { Start-Process (Get-SteamExePath) }
function Restart-Steam { Stop-SteamGracefully; Start-Steam }
function Get-SteamAccounts {
    $accs = @(); $dir = Get-SteamInstallDir; if (!$dir) { return $accs }
    $vdf = Join-Path $dir "config\loginusers.vdf"; if (!(Test-Path $vdf)) { return $accs }
    $cur = $null
    foreach ($l in (Get-Content $vdf)) {
        if ($l -match '^\s*"(\d{5,})"') { $cur = [PSCustomObject]@{id=$matches[1];name="";persona=""} }
        elseif ($cur -and $l -match '"AccountName"\s+"([^"]+)"') { $cur.name = $matches[1] }
        elseif ($cur -and $l -match '"PersonaName"\s+"([^"]+)"') { $cur.persona = $matches[1] }
        elseif ($cur -and $l -match '^\s*}') { if ($cur.name) { $accs += $cur }; $cur = $null }
    }
    $accs
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SteamShell" Height="740" Width="1120"
        WindowStartupLocation="CenterScreen" AllowDrop="True"
        WindowStyle="None" ResizeMode="CanResizeWithGrip"
        Background="Transparent" AllowsTransparency="True">
  <Window.Resources>

    <!-- Professional Shadow -->
    <DropShadowEffect x:Key="PanelShadow" BlurRadius="12" ShadowDepth="0" Opacity="0.25"/>

    <Style x:Key="TopBtn" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontFamily" Value="Segoe UI Semibold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="8" Padding="20,11" BorderThickness="0">
              <Border.RenderTransform>
                <TranslateTransform Y="0"/>
              </Border.RenderTransform>
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Opacity" Value="0.9"/>
                <Trigger.EnterActions>
                  <BeginStoryboard>
                    <Storyboard>
                      <DoubleAnimation Storyboard.TargetName="bd" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.Y)" To="-2" Duration="0:0:0.15"/>
                    </Storyboard>
                  </BeginStoryboard>
                </Trigger.EnterActions>
                <Trigger.ExitActions>
                  <BeginStoryboard>
                    <Storyboard>
                      <DoubleAnimation Storyboard.TargetName="bd" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.Y)" To="0" Duration="0:0:0.15"/>
                    </Storyboard>
                  </BeginStoryboard>
                </Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="bd" Property="Opacity" Value="0.75"/>
                <Setter TargetName="bd" Property="RenderTransform">
                  <Setter.Value><TranslateTransform Y="0"/></Setter.Value>
                </Setter>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="SideBtn" TargetType="Button">
      <Setter Property="Foreground" Value="#b0bec5"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="FontFamily" Value="Segoe UI"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Margin" Value="0,0,0,3"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="6" Padding="14,10">
              <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#1e2a3a"/>
                <Setter Property="Foreground" Value="White"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="WinBtn" TargetType="Button">
      <Setter Property="Foreground" Value="#6e7681"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Width" Value="48"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" Padding="0,8">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#21262d"/>
                <Setter Property="Foreground" Value="#c9d1d9"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="CloseBtn" TargetType="Button" BasedOn="{StaticResource WinBtn}">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="Transparent" Padding="0,8">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#da3633"/>
                <Setter Property="Foreground" Value="White"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#8b949e"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Margin" Value="0,0,0,8"/>
    </Style>

    <Style x:Key="SectionHeader" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#58a6ff"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Margin" Value="0,0,0,12"/>
    </Style>

  </Window.Resources>

  <Border CornerRadius="8" BorderBrush="#21262d" BorderThickness="1">
    <Border.Background>
      <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
        <GradientStop Color="#0d1117" Offset="0"/>
        <GradientStop Color="#0a0f14" Offset="1"/>
      </LinearGradientBrush>
    </Border.Background>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="46"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="1"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="38"/>
      </Grid.RowDefinitions>

      <!-- Custom Title Bar -->
      <Border Grid.Row="0" Background="#010409" CornerRadius="8,8,0,0" x:Name="titleBar">
        <Grid Margin="18,0">
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <Ellipse Width="10" Height="10" Fill="#58a6ff" Margin="0,0,10,0"/>
            <TextBlock x:Name="lblTitle" Text="SteamShell" FontSize="13" FontWeight="SemiBold" Foreground="#c9d1d9" VerticalAlignment="Center"/>
            <TextBlock x:Name="lblVer" Text="" FontSize="11" Foreground="#484f58" VerticalAlignment="Center" Margin="10,2,0,0"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
            <Button x:Name="btnMin" Content="&#x2500;" Style="{StaticResource WinBtn}" FontSize="10"/>
            <Button x:Name="btnMax" Content="&#x25A1;" Style="{StaticResource WinBtn}"/>
            <Button x:Name="btnClose" Content="&#x2715;" Style="{StaticResource CloseBtn}"/>
          </StackPanel>
        </Grid>
      </Border>

      <!-- Action Bar (Revised Focus) -->
      <Border Grid.Row="1" Background="Transparent" Padding="18,14">
        <StackPanel Orientation="Horizontal">
          <Button x:Name="btnStart" Content="Start" Background="#238636" Style="{StaticResource TopBtn}" Width="125"/>
          <Button x:Name="btnStop" Content="Stop" Background="#21262d" Style="{StaticResource TopBtn}" Width="100"/>
          <Button x:Name="btnRestart" Content="Restart" Background="#21262d" Style="{StaticResource TopBtn}" Width="110"/>
          <Button x:Name="btnKill" Content="Kill All" Background="#21262d" Style="{StaticResource TopBtn}" Width="110"/>
          <Button x:Name="btnImport" Content="Import Files" Background="#1f6feb" Style="{StaticResource TopBtn}" Width="145" Margin="0"/>
        </StackPanel>
      </Border>

      <!-- Content Separator -->
      <Border Grid.Row="2" Background="#21262d" Margin="18,0"/>

      <!-- Main Content -->
      <Grid Grid.Row="3" Margin="18,16,18,12">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="290"/>
        </Grid.ColumnDefinitions>

        <!-- Log Panel -->
        <Border Grid.Column="0" Background="#010409" CornerRadius="10" BorderBrush="#161b22" BorderThickness="1" Margin="0,0,16,0" Effect="{StaticResource PanelShadow}">
          <Grid>
            <Grid.RowDefinitions>
              <RowDefinition Height="40"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <Border Background="#0d1117" CornerRadius="10,10,0,0" Padding="16,0" BorderBrush="#161b22" BorderThickness="0,0,0,1">
              <Grid>
                <TextBlock Text="Console" Foreground="#58a6ff" FontSize="11" FontWeight="SemiBold" VerticalAlignment="Center" LetterSpacing="1"/>
                <Button x:Name="btnClear" Content="Clear" Style="{StaticResource SideBtn}" HorizontalAlignment="Right" Foreground="#484f58" Margin="0" FontSize="11"/>
              </Grid>
            </Border>
            <ScrollViewer Grid.Row="1" x:Name="svLog" VerticalScrollBarVisibility="Auto" Margin="0">
              <TextBox x:Name="txtLog" Foreground="#3fb950" FontFamily="Cascadia Code, Consolas" FontSize="12"
                       TextWrapping="Wrap" Padding="16,12" Background="Transparent" IsReadOnly="True" BorderThickness="0"/>
            </ScrollViewer>
          </Grid>
        </Border>

        <!-- Sidebar -->
        <ScrollViewer Grid.Column="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
          <StackPanel>

            <!-- Accounts Card -->
            <Border Background="#161b22" CornerRadius="10" Padding="18" Margin="0,0,0,14" BorderBrush="#21262d" BorderThickness="1" Effect="{StaticResource PanelShadow}">
              <StackPanel>
                <TextBlock Text="Accounts" Style="{StaticResource SectionHeader}"/>
                <ComboBox x:Name="cmbAccounts" Background="#0d1117" Foreground="White" Padding="10,8" Margin="0,0,0,12" FontSize="12">
                  <ComboBox.Resources>
                    <SolidColorBrush x:Key="{x:Static SystemColors.WindowBrushKey}" Color="#161b22"/>
                    <SolidColorBrush x:Key="{x:Static SystemColors.HighlightBrushKey}" Color="#1f6feb"/>
                  </ComboBox.Resources>
                </ComboBox>
                <Button x:Name="btnSwitch" Content="Switch Account" Background="#1f6feb" Style="{StaticResource TopBtn}" Margin="0" FontSize="12"/>
              </StackPanel>
            </Border>

            <!-- Settings Card -->
            <Border Background="#161b22" CornerRadius="10" Padding="18" Margin="0,0,0,14" BorderBrush="#21262d" BorderThickness="1" Effect="{StaticResource PanelShadow}">
              <StackPanel>
                <TextBlock Text="Settings" Style="{StaticResource SectionHeader}"/>
                <CheckBox x:Name="chkBackup" Content="Backup before overwrite" IsChecked="True"/>
                <CheckBox x:Name="chkOnTop" Content="Always on top"/>
                <StackPanel Orientation="Horizontal" Margin="0,8,0,0">
                  <TextBlock Text="Wait:" Foreground="#8b949e" VerticalAlignment="Center" FontSize="12" Margin="0,0,10,0"/>
                  <TextBox x:Name="txtWait" Text="12" Width="50" Background="#0d1117" Foreground="White" BorderBrush="#30363d" Padding="8,6" FontSize="12"/>
                  <TextBlock Text="sec" Foreground="#484f58" VerticalAlignment="Center" FontSize="11" Margin="8,0,0,0"/>
                </StackPanel>
              </StackPanel>
            </Border>

            <!-- Tools Card -->
            <Border Background="#161b22" CornerRadius="10" Padding="10" Margin="0,0,0,8" BorderBrush="#21262d" BorderThickness="1" Effect="{StaticResource PanelShadow}">
              <StackPanel>
                <TextBlock Text="Tools" Style="{StaticResource SectionHeader}" Margin="12,12,12,8"/>
                <Button x:Name="btnDepot"  Content="Depot Cache Folder"   Style="{StaticResource SideBtn}"/>
                <Button x:Name="btnLua"    Content="Lua Scripts Folder"    Style="{StaticResource SideBtn}"/>
                <Button x:Name="btnConfig" Content="Steam Config Folder"   Style="{StaticResource SideBtn}"/>
                <Button x:Name="btnBrowse" Content="Set Steam Path"        Style="{StaticResource SideBtn}"/>
                <Button x:Name="btnAbout"  Content="About"                  Style="{StaticResource SideBtn}" Margin="0,0,0,8"/>
              </StackPanel>
            </Border>

          </StackPanel>
        </ScrollViewer>
      </Grid>

      <!-- Status Bar -->
      <Border Grid.Row="4" Background="#010409" CornerRadius="0,0,8,8" Padding="18,0">
        <Grid VerticalAlignment="Center">
          <TextBlock x:Name="statusLabel" Text="Ready" Foreground="#484f58" FontSize="11" VerticalAlignment="Center"/>
          <TextBlock x:Name="statusSteam" Text="" HorizontalAlignment="Right" FontSize="11" FontWeight="SemiBold" VerticalAlignment="Center"/>
        </Grid>
      </Border>

    </Grid>
  </Border>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$w = [System.Windows.Markup.XamlReader]::Load($reader)

# Find controls
$titleBar = $w.FindName("titleBar"); $lblVer = $w.FindName("lblVer")
$btnMin = $w.FindName("btnMin"); $btnMax = $w.FindName("btnMax"); $btnClose = $w.FindName("btnClose")
$btnStart = $w.FindName("btnStart"); $btnStop = $w.FindName("btnStop"); $btnRestart = $w.FindName("btnRestart")
$btnKill = $w.FindName("btnKill"); $btnImport = $w.FindName("btnImport"); $btnSwitch = $w.FindName("btnSwitch")
$btnClear = $w.FindName("btnClear"); $btnDepot = $w.FindName("btnDepot"); $btnLua = $w.FindName("btnLua")
$btnConfig = $w.FindName("btnConfig"); $btnBrowse = $w.FindName("btnBrowse"); $btnAbout = $w.FindName("btnAbout")
$cmbAccounts = $w.FindName("cmbAccounts"); $chkBackup = $w.FindName("chkBackup"); $chkOnTop = $w.FindName("chkOnTop")
$txtWait = $w.FindName("txtWait"); $txtLog = $w.FindName("txtLog"); $svLog = $w.FindName("svLog")
$statusLabel = $w.FindName("statusLabel"); $statusSteam = $w.FindName("statusSteam")

$lblVer.Text = "v$script:AppVersion"

# Title bar behavior
$titleBar.Add_MouseLeftButtonDown({ $w.DragMove() })
$btnMin.Add_Click({ $w.WindowState = 'Minimized' })
$btnMax.Add_Click({ if ($w.WindowState -eq 'Maximized') { $w.WindowState = 'Normal' } else { $w.WindowState = 'Maximized' } })
$btnClose.Add_Click({ $w.Close() })

# Log (OPTIMIZED for WPF performance)
function Write-Log([string]$msg) {
    $ts = (Get-Date).ToString('HH:mm:ss')
    $txtLog.AppendText("[$ts] $msg`n")
    if ($svLog) { $svLog.ScrollToEnd() }
}

function Import-Files($paths) {
    $dM = 'C:\Program Files (x86)\Steam\depotcache'; $dL = 'C:\Program Files (x86)\Steam\config\stplug-in'
    if (!(Test-Path $dM)) { New-Item $dM -ItemType Directory -Force | Out-Null }
    if (!(Test-Path $dL)) { New-Item $dL -ItemType Directory -Force | Out-Null }
    foreach ($p in $paths) {
        $ext = [System.IO.Path]::GetExtension($p).ToLower()
        $dst = if ($ext -eq '.manifest') { $dM } elseif ($ext -eq '.lua') { $dL } else { $null }
        if ($dst) {
            $target = Join-Path $dst ([System.IO.Path]::GetFileName($p))
            if ($chkBackup.IsChecked -and (Test-Path $target)) { Copy-Item $target "$target.bak" -Force }
            Copy-Item -LiteralPath $p -Destination $target -Force
            Write-Log "Imported: $([System.IO.Path]::GetFileName($p))"
        }
    }
}

function Update-Accounts {
    $cmbAccounts.Items.Clear(); $script:AccList = @(Get-SteamAccounts)
    foreach ($a in $script:AccList) { $cmbAccounts.Items.Add("$($a.persona) ($($a.name))") | Out-Null }
    if ($cmbAccounts.Items.Count -gt 0) {
        $cmbAccounts.SelectedIndex = 0
        try {
            $cur = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).AutoLoginUser
            if ($cur) { for($i=0;$i -lt $script:AccList.Count;$i++) { if ($script:AccList[$i].name -eq $cur) { $cmbAccounts.SelectedIndex=$i; break } } }
        } catch {}
    }
}

function Update-Status {
    $pr = Get-Process steam -ErrorAction SilentlyContinue
    if ($pr) { $statusSteam.Text = "● RUNNING"; $statusSteam.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#3fb950") }
    else { $statusSteam.Text = "● STOPPED"; $statusSteam.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#f85149") }
}

# Events
$btnStart.Add_Click({ try { Start-Steam; Write-Log "Steam started." } catch { Write-Log "Error: $($_.Exception.Message)" } })
$btnStop.Add_Click({ try { Stop-SteamGracefully ([int]$txtWait.Text); Write-Log "Steam stopped." } catch { Write-Log "Error: $($_.Exception.Message)" } })
$btnRestart.Add_Click({ try { Restart-Steam; Write-Log "Steam restarted." } catch { Write-Log "Error: $($_.Exception.Message)" } })
$btnKill.Add_Click({ Get-Process steam,steamwebhelper,SteamService -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Write-Log "All killed." })
$btnImport.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog; $dlg.Multiselect=$true; $dlg.Filter="Steam Files|*.manifest;*.lua"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Import-Files $dlg.FileNames; Write-Log "Import done." }
})
$btnSwitch.Add_Click({
    if ($cmbAccounts.SelectedIndex -ge 0 -and $script:AccList.Count -gt 0) {
        $a = $script:AccList[$cmbAccounts.SelectedIndex]
        Set-ItemProperty "HKCU:\Software\Valve\Steam" -Name "AutoLoginUser" -Value $a.name
        Set-ItemProperty "HKCU:\Software\Valve\Steam" -Name "RememberPassword" -Value 1
        Write-Log "Switched: $($a.name). Restarting..."; Restart-Steam
    }
})
$btnClear.Add_Click({ $txtLog.Text = "" })
$btnDepot.Add_Click({ try { Start-Process 'C:\Program Files (x86)\Steam\depotcache' } catch {} })
$btnLua.Add_Click({ try { Start-Process 'C:\Program Files (x86)\Steam\config\stplug-in' } catch {} })
$btnConfig.Add_Click({ try { Start-Process 'C:\Program Files (x86)\Steam\config' } catch {} })
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog; $dlg.Filter="steam.exe|steam.exe"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $script:SteamExeOverride=$dlg.FileName; Write-Log "Path: $($dlg.FileName)" }
})
$btnAbout.Add_Click({ [System.Windows.MessageBox]::Show("SteamShell v$script:AppVersion`nProfessional Steam Management`n`ngithub.com/kozaaaaczx/steam-lua","About",0,64) })
$chkOnTop.Add_Checked({ $w.Topmost=$true }); $chkOnTop.Add_Unchecked({ $w.Topmost=$false })

# Drag & Drop
$w.Add_DragEnter({ param($s,$e) if($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)){$e.Effects='Copy'} })
$w.Add_Drop({ param($s,$e) Import-Files ($e.Data.GetData([System.Windows.DataFormats]::FileDrop)); Write-Log "Drop import done." })

# Timers
$timer = New-Object System.Windows.Threading.DispatcherTimer; $timer.Interval=[TimeSpan]::FromSeconds(3)
$timer.Add_Tick({ Update-Status }); $timer.Start()

$timerUpd = New-Object System.Windows.Threading.DispatcherTimer; $timerUpd.Interval=[TimeSpan]::FromSeconds(5)
$timerUpd.Add_Tick({ param($s,$e); $s.Stop()
    try { $rel = Invoke-RestMethod "https://api.github.com/repos/kozaaaaczx/steam-lua/releases/latest" -ErrorAction SilentlyContinue
        if ($rel.tag_name -match '(\d+\.\d+\.\d+)' -and [version]$matches[1] -gt [version]$script:AppVersion) {
            if ([System.Windows.MessageBox]::Show("New version v$($matches[1]) available!`nOpen download?","Update",4,32) -eq 6) { Start-Process "https://github.com/kozaaaaczx/steam-lua/releases/latest" }
        }
    } catch {}
}); $timerUpd.Start()

# Init
Update-Accounts; Update-Status; Write-Log "SteamShell v$script:AppVersion initialized. Ready for operations."
$w.ShowDialog() | Out-Null