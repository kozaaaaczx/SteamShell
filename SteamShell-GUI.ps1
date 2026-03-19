Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# SteamShell v0.9.0 "The Launcher Experience"
$script:AppVersion = '0.9.0'
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
        Title="SteamShell" Height="800" Width="1200"
        WindowStartupLocation="CenterScreen" AllowDrop="True"
        WindowStyle="None" ResizeMode="CanResizeWithGrip"
        Background="Transparent" AllowsTransparency="True">
  <Window.Resources>
    
    <!-- Modern Color Palette -->
    <SolidColorBrush x:Key="BgBrush" Color="#0B0F14"/>
    <SolidColorBrush x:Key="PanelBrush" Color="#121821"/>
    <SolidColorBrush x:Key="HoverBrush" Color="#1A2330"/>
    <SolidColorBrush x:Key="AccentBrush" Color="#4CC2FF"/>
    <SolidColorBrush x:Key="BorderBrush" Color="#1F2937"/>
    <SolidColorBrush x:Key="TextMain" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="TextDim" Color="#8B949E"/>

    <!-- Nav Button -->
    <Style x:Key="NavBtn" TargetType="RadioButton">
      <Setter Property="Foreground" Value="{StaticResource TextDim}"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Height" Value="52"/>
      <Setter Property="Margin" Value="0,2,0,2"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Border x:Name="bd" Background="Transparent" CornerRadius="8" Padding="14,0">
              <StackPanel Orientation="Horizontal">
                <Border x:Name="indicator" Width="3" Height="20" Background="{StaticResource AccentBrush}" CornerRadius="2" HorizontalAlignment="Left" Visibility="Collapsed" Margin="-14,0,11,0"/>
                <TextBlock x:Name="icon" Text="{TemplateBinding Content}" FontFamily="Segoe MDL2 Assets" FontSize="18" VerticalAlignment="Center" Margin="0,0,14,0"/>
                <TextBlock x:Name="txt" Text="{TemplateBinding Tag}" VerticalAlignment="Center" FontFamily="Segoe UI Semibold"/>
              </StackPanel>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="{StaticResource HoverBrush}"/>
                <Setter Property="Foreground" Value="White"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="indicator" Property="Visibility" Value="Visible"/>
                <Setter Property="Foreground" Value="{StaticResource AccentBrush}"/>
                <Setter TargetName="icon" Property="Foreground" Value="{StaticResource AccentBrush}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Dash Card -->
    <Style x:Key="DashCard" TargetType="Border">
      <Setter Property="Background" Value="{StaticResource PanelBrush}"/>
      <Setter Property="CornerRadius" Value="14"/>
      <Setter Property="Padding" Value="24"/>
      <Setter Property="BorderBrush" Value="{StaticResource BorderBrush}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Margin" Value="0,0,16,16"/>
      <Setter Property="RenderTransformOrigin" Value="0.5,0.5"/>
      <Setter Property="RenderTransform">
        <Setter.Value><ScaleTransform ScaleX="1" ScaleY="1"/></Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="ActionBtn" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontFamily" Value="Segoe UI Semibold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Padding" Value="24,14"/>
      <Setter Property="Background" Value="{StaticResource PanelBrush}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="BorderBrush" Value="{StaticResource BorderBrush}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="10" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
               <Border.RenderTransform><ScaleTransform ScaleX="1" ScaleY="1"/></Border.RenderTransform>
               <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="{StaticResource HoverBrush}"/>
                <Trigger.EnterActions>
                  <BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="bd" Storyboard.TargetProperty="(UIElement.RenderTransform).(ScaleTransform.ScaleX)" To="1.04" Duration="0:0:0.15"/></Storyboard></BeginStoryboard>
                  <BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="bd" Storyboard.TargetProperty="(UIElement.RenderTransform).(ScaleTransform.ScaleY)" To="1.04" Duration="0:0:0.15"/></Storyboard></BeginStoryboard>
                </Trigger.EnterActions>
                <Trigger.ExitActions>
                  <BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="bd" Storyboard.TargetProperty="(UIElement.RenderTransform).(ScaleTransform.ScaleX)" To="1" Duration="0:0:0.15"/></Storyboard></BeginStoryboard>
                  <BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="bd" Storyboard.TargetProperty="(UIElement.RenderTransform).(ScaleTransform.ScaleY)" To="1" Duration="0:0:0.15"/></Storyboard></BeginStoryboard>
                </Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

  </Window.Resources>

  <Border x:Name="mainBorder" Background="{StaticResource BgBrush}" CornerRadius="16" BorderBrush="{StaticResource BorderBrush}" BorderThickness="1">
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="260"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <!-- Sidebar -->
      <Border Grid.Column="0" Background="{StaticResource PanelBrush}" CornerRadius="16,0,0,16" BorderBrush="{StaticResource BorderBrush}" BorderThickness="0,0,1,0">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <!-- App Logo -->
          <StackPanel Grid.Row="0" Margin="28,48,28,40">
            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
              <Border Width="38" Height="38" Background="{StaticResource AccentBrush}" CornerRadius="10">
                <TextBlock Text="&#xE961;" FontFamily="Segoe MDL2 Assets" Foreground="#000" VerticalAlignment="Center" HorizontalAlignment="Center" FontSize="20"/>
              </Border>
              <TextBlock Text="SteamShell" FontSize="22" FontWeight="Bold" Foreground="White" Margin="14,0,0,0" VerticalAlignment="Center"/>
            </StackPanel>
            <TextBlock x:Name="lblVer" Text="v0.9.0" FontSize="11" Foreground="{StaticResource TextDim}" Margin="52,2,0,0"/>
          </StackPanel>

          <!-- Nav Menu -->
          <StackPanel Grid.Row="1" Margin="18,0">
            <RadioButton x:Name="navDashboard" Content="&#xE80F;" Tag="Dashboard" Style="{StaticResource NavBtn}" IsChecked="True"/>
            <RadioButton x:Name="navAccounts"  Content="&#xE77B;" Tag="Profiles" Style="{StaticResource NavBtn}"/>
            <RadioButton x:Name="navFiles"     Content="&#xE8B7;" Tag="Assets" Style="{StaticResource NavBtn}"/>
            <RadioButton x:Name="navSettings"  Content="&#xE713;" Tag="Settings" Style="{StaticResource NavBtn}"/>
          </StackPanel>

          <StackPanel Grid.Row="2" Margin="18,0,18,32">
            <Button x:Name="btnAbout" Content="&#xE946;" Tag="Help &amp; Social" Style="{StaticResource NavBtn}"/>
          </StackPanel>
        </Grid>
      </Border>

      <!-- Content -->
      <Grid Grid.Column="1">
        <Grid.RowDefinitions>
          <RowDefinition Height="56"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <!-- ToolBar -->
        <Grid Grid.Row="0" x:Name="titleBar">
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,4,8,0">
            <Button x:Name="btnMin" Content="&#xE921;" FontFamily="Segoe MDL2 Assets" Style="{StaticResource NavBtn}" Height="32" Width="44" Padding="0" Margin="0"/>
            <Button x:Name="btnClose" Content="&#xE8BB;" FontFamily="Segoe MDL2 Assets" Style="{StaticResource NavBtn}" Height="32" Width="44" Padding="0" Foreground="#F85149" Margin="0"/>
          </StackPanel>
        </Grid>

        <!-- Pages -->
        <Grid Grid.Row="1" Margin="44,12,44,36">

          <!-- Dashboard -->
          <Grid x:Name="pageDashboard">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <TextBlock Grid.Row="0" Text="Overview" FontSize="26" FontWeight="Bold" Foreground="White" Margin="0,0,0,28"/>

            <WrapPanel Grid.Row="1">
              <!-- Steam Status Card -->
              <Border Style="{StaticResource DashCard}" Width="240">
                <StackPanel>
                  <TextBlock Text="STEAM STATUS" Foreground="{StaticResource TextDim}" FontSize="10" FontWeight="Bold" Margin="0,0,0,14" LetterSpacing="1"/>
                  <StackPanel Orientation="Horizontal">
                    <TextBlock x:Name="statusSteam" Text="CHECKING..." Foreground="{StaticResource AccentBrush}" FontSize="18" FontWeight="SemiBold"/>
                  </StackPanel>
                </StackPanel>
              </Border>

              <!-- Active Profile Card -->
              <Border Style="{StaticResource DashCard}" Width="320">
                <StackPanel>
                  <TextBlock Text="ACTIVE PROFILE" Foreground="{StaticResource TextDim}" FontSize="10" FontWeight="Bold" Margin="0,0,0,14" LetterSpacing="1"/>
                  <TextBlock x:Name="lblActiveAcc" Text="Unknown" Foreground="White" FontSize="18" FontWeight="SemiBold"/>
                </StackPanel>
              </Border>
            </WrapPanel>

            <!-- Console -->
            <Grid Grid.Row="2" Margin="0,12,0,0">
              <Border Background="{StaticResource PanelBrush}" CornerRadius="14" BorderBrush="{StaticResource BorderBrush}" BorderThickness="1">
                <Grid>
                  <Grid.RowDefinitions><RowDefinition Height="46"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                  <Border Background="{StaticResource HoverBrush}" CornerRadius="14,14,0,0" Padding="18,0">
                    <Grid>
                      <TextBlock Text="Command Output" VerticalAlignment="Center" Foreground="{StaticResource TextDim}" FontSize="12" FontWeight="SemiBold"/>
                      <Button x:Name="btnClear" Content="&#xE894; Clear" FontFamily="Segoe MDL2 Assets" Style="{StaticResource NavBtn}" Height="30" HorizontalAlignment="Right" FontSize="11" Padding="8,0" Margin="0"/>
                    </Grid>
                  </Border>
                  <ScrollViewer Grid.Row="1" x:Name="svLog" VerticalScrollBarVisibility="Auto">
                    <TextBox x:Name="txtLog" Background="Transparent" Foreground="#4CC2FF" IsReadOnly="True" BorderThickness="0" Padding="20" FontFamily="Consolas" FontSize="14" TextWrapping="Wrap"/>
                  </ScrollViewer>
                </Grid>
              </Border>
              
              <!-- Action Tray -->
              <StackPanel VerticalAlignment="Bottom" HorizontalAlignment="Right" Margin="24" Orientation="Horizontal">
                <Button x:Name="btnStart" Content="START" Background="{StaticResource AccentBrush}" Foreground="#000" Style="{StaticResource ActionBtn}" Width="120" Margin="0,0,12,0" FontWeight="Bold"/>
                <Button x:Name="btnStop" Content="STOP" Style="{StaticResource ActionBtn}" Width="100"/>
              </StackPanel>
            </Grid>
          </Grid>

          <!-- Profiles -->
          <Grid x:Name="pageAccounts" Visibility="Collapsed">
            <StackPanel MaxWidth="600" HorizontalAlignment="Left">
              <TextBlock Text="Profiles" FontSize="26" FontWeight="Bold" Foreground="White" Margin="0,0,0,8"/>
              <TextBlock Text="Switch between local Steam accounts with one click." Foreground="{StaticResource TextDim}" Margin="0,0,0,40"/>
              
              <Border Background="{StaticResource PanelBrush}" CornerRadius="14" Padding="24" BorderBrush="{StaticResource BorderBrush}" BorderThickness="1">
                <StackPanel>
                  <TextBlock Text="Select Account" Foreground="White" Margin="0,0,0,12"/>
                  <ComboBox x:Name="cmbAccounts" Background="{StaticResource BgBrush}" Foreground="White" Height="48" Padding="12" FontSize="14"/>
                  <Button x:Name="btnSwitch" Content="Switch &amp; Restart Steam" Background="{StaticResource AccentBrush}" Foreground="#000" Style="{StaticResource ActionBtn}" Margin="0,24,0,0" FontWeight="Bold"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </Grid>

          <!-- Files -->
          <Grid x:Name="pageFiles" Visibility="Collapsed">
            <StackPanel MaxWidth="700" HorizontalAlignment="Left">
              <TextBlock Text="Assets" FontSize="26" FontWeight="Bold" Foreground="White" Margin="0,0,0,8"/>
              <TextBlock Text="Import .manifest and .lua files directly into Steam folders." Foreground="{StaticResource TextDim}" Margin="0,0,0,40"/>
              
              <Button x:Name="btnImport" Content="&#xE8B5; Open File Picker" Style="{StaticResource ActionBtn}" Height="60" Width="300" HorizontalAlignment="Left" FontSize="16" Margin="0,0,0,40"/>
              
              <TextBlock Text="Quick Access Folders" Foreground="White" FontWeight="Bold" Margin="0,0,0,16"/>
              <WrapPanel>
                 <Button x:Name="btnDepot"  Content="&#xE8B7; Depot Cache" Style="{StaticResource ActionBtn}" Margin="0,0,12,12"/>
                 <Button x:Name="btnLua"    Content="&#xE8B7; LUA Scripts" Style="{StaticResource ActionBtn}" Margin="0,0,12,12"/>
                 <Button x:Name="btnConfig" Content="&#xE8B7; Steam config" Style="{StaticResource ActionBtn}" Margin="0,0,12,12"/>
              </WrapPanel>
            </StackPanel>
          </Grid>

          <!-- Settings -->
          <Grid x:Name="pageSettings" Visibility="Collapsed">
            <StackPanel MaxWidth="600" HorizontalAlignment="Left">
              <TextBlock Text="Configuration" FontSize="26" FontWeight="Bold" Foreground="White" Margin="0,0,0,40"/>
              
              <Border Background="{StaticResource PanelBrush}" CornerRadius="14" Padding="24" BorderBrush="{StaticResource BorderBrush}" BorderThickness="1" Margin="0,0,0,24">
                <StackPanel>
                  <CheckBox x:Name="chkBackup" Content="Enable file backups" IsChecked="True" Foreground="White" Margin="0,0,0,12"/>
                  <CheckBox x:Name="chkOnTop" Content="Always on top" Foreground="White"/>
                </StackPanel>
              </Border>
              
              <Border Background="{StaticResource PanelBrush}" CornerRadius="14" Padding="24" BorderBrush="{StaticResource BorderBrush}" BorderThickness="1">
                <StackPanel Orientation="Horizontal">
                  <TextBlock Text="Steam EXE Location" Foreground="White" VerticalAlignment="Center" Margin="0,0,24,0"/>
                  <Button x:Name="btnBrowse" Content="Locate..." Style="{StaticResource ActionBtn}" Padding="16,8"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </Grid>

        </Grid>
      </Grid>
    </Grid>
  </Border>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$w = [System.Windows.Markup.XamlReader]::Load($reader)

# Controls
$titleBar = $w.FindName("titleBar"); $lblVer = $w.FindName("lblVer")
$btnMin = $w.FindName("btnMin"); $btnClose = $w.FindName("btnClose")
$btnStart = $w.FindName("btnStart"); $btnStop = $w.FindName("btnStop")
$btnImport = $w.FindName("btnImport"); $btnSwitch = $w.FindName("btnSwitch")
$btnClear = $w.FindName("btnClear"); $btnDepot = $w.FindName("btnDepot")
$btnLua = $w.FindName("btnLua"); $btnConfig = $w.FindName("btnConfig")
$btnBrowse = $w.FindName("btnBrowse"); $btnAbout = $w.FindName("btnAbout")
$cmbAccounts = $w.FindName("cmbAccounts"); $chkBackup = $w.FindName("chkBackup"); $chkOnTop = $w.FindName("chkOnTop")
$txtLog = $w.FindName("txtLog"); $svLog = $w.FindName("svLog")
$statusSteam = $w.FindName("statusSteam"); $lblActiveAcc = $w.FindName("lblActiveAcc")

# Nav
$navDashboard = $w.FindName("navDashboard"); $navAccounts = $w.FindName("navAccounts")
$navFiles = $w.FindName("navFiles"); $navSettings = $w.FindName("navSettings")
$pDashboard = $w.FindName("pageDashboard"); $pAccounts = $w.FindName("pageAccounts")
$pFiles = $w.FindName("pageFiles"); $pSettings = $w.FindName("pageSettings")

function Switch-Page($page) {
    @($pDashboard, $pAccounts, $pFiles, $pSettings) | ForEach-Object { $_.Visibility = 'Collapsed' }
    $page.Visibility = 'Visible'
}

$navDashboard.Add_Checked({ Switch-Page $pDashboard })
$navAccounts.Add_Checked({ Switch-Page $pAccounts })
$navFiles.Add_Checked({ Switch-Page $pFiles })
$navSettings.Add_Checked({ Switch-Page $pSettings })

# Logic
function Write-Log([string]$msg) {
    if (!$txtLog) { return }
    $ts = (Get-Date).ToString('HH:mm:ss')
    $txtLog.AppendText("[$ts] $msg`n")
    if ($svLog) { $svLog.ScrollToEnd() }
}

function Update-Status {
    $pr = Get-Process steam -ErrorAction SilentlyContinue
    if ($pr) { 
        $statusSteam.Text = "ACTIVE"; $statusSteam.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#3fb950") 
    } else { 
        $statusSteam.Text = "INACTIVE"; $statusSteam.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#F85149") 
    }
    try {
        $cur = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).AutoLoginUser
        $lblActiveAcc.Text = if ($cur) { $cur } else { "None" }
    } catch { $lblActiveAcc.Text = "Error" }
}

function Update-Accounts {
    $cmbAccounts.Items.Clear(); $script:AccList = @(Get-SteamAccounts)
    foreach ($a in $script:AccList) { $cmbAccounts.Items.Add("$($a.persona) ($($a.name))") | Out-Null }
}

function Import-Files($ps) {
    $dM = 'C:\Program Files (x86)\Steam\depotcache'; $dL = 'C:\Program Files (x86)\Steam\config\stplug-in'
    if (!(Test-Path $dM)) { New-Item $dM -ItemType Directory -Force | Out-Null }
    if (!(Test-Path $dL)) { New-Item $dL -ItemType Directory -Force | Out-Null }
    foreach ($p in $ps) {
        $ext = [System.IO.Path]::GetExtension($p).ToLower()
        $dst = if ($ext -eq '.manifest') { $dM } elseif ($ext -eq '.lua') { $dL } else { $null }
        if ($dst) {
            $dest = Join-Path $dst ([System.IO.Path]::GetFileName($p))
            if ($chkBackup.IsChecked -and (Test-Path $dest)) { Copy-Item $dest "$dest.bak" -Force }
            Copy-Item -LiteralPath $p -Destination $dest -Force
            Write-Log "Imported: $([System.IO.Path]::GetFileName($p))"
        }
    }
}

# Handlers
$titleBar.Add_MouseLeftButtonDown({ $w.DragMove() })
$btnMin.Add_Click({ $w.WindowState = 'Minimized' })
$btnClose.Add_Click({ $w.Close() })
$btnStart.Add_Click({ try { Start-Steam; Write-Log "Starting Steam..." } catch { Write-Log "Error: $($_.Exception.Message)" } })
$btnStop.Add_Click({ try { Stop-SteamGracefully 12; Write-Log "Closing Steam..." } catch { Write-Log "Error: $($_.Exception.Message)" } })
$btnSwitch.Add_Click({
    if ($cmbAccounts.SelectedIndex -ge 0) {
        $a = $script:AccList[$cmbAccounts.SelectedIndex]
        Set-ItemProperty "HKCU:\Software\Valve\Steam" -Name "AutoLoginUser" -Value $a.name
        Write-Log "Profile: $($a.name). Restarting..."; Restart-Steam
    }
})
$btnClear.Add_Click({ $txtLog.Text = "" })
$btnImport.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog; $dlg.Multiselect=$true; $dlg.Filter="Steam Assets|*.manifest;*.lua"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Import-Files $dlg.FileNames; Write-Log "Done." }
})
$btnAbout.Add_Click({ [System.Windows.MessageBox]::Show("SteamShell Professional v$script:AppVersion","Info",0,64) })

# DragDrop
$w.Add_DragEnter({ param($s,$e) if($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)){$e.Effects='Copy'} })
$w.Add_Drop({ param($s,$e) Import-Files ($e.Data.GetData([System.Windows.DataFormats]::FileDrop)); Write-Log "Dropped files processed." })

# Timer
$t = New-Object System.Windows.Threading.DispatcherTimer; $t.Interval=[TimeSpan]::FromSeconds(2)
$t.Add_Tick({ Update-Status }); $t.Start()

# Init
Update-Accounts; Update-Status; Write-Log "System Ready."
$w.ShowDialog() | Out-Null