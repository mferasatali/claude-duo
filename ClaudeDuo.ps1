#Requires -Version 5.1
<#
.SYNOPSIS
  Claude Duo — run two Claude Code sessions in one Windows Terminal window.
#>
[CmdletBinding()]
param(
    [string]$Left,
    [string]$Right,
    [ValidateSet('vertical', 'horizontal')]
    [string]$Split = 'vertical',
    [switch]$Maximized,
    [switch]$NoGui
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$AppName = 'Claude Duo'
$ConfigDir = Join-Path $env:APPDATA 'ClaudeDuo'
$ConfigPath = Join-Path $ConfigDir 'config.json'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Find-ClaudeCmd {
    $candidates = @(
        (Get-Command claude.cmd -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
        'C:\nodejs\claude.cmd',
        (Join-Path $env:APPDATA 'npm\claude.cmd')
    ) | Where-Object { $_ }

    foreach ($path in $candidates) {
        if ((Test-Path -LiteralPath $path) -and ($path -match '\.(cmd|exe)$')) { return $path }
    }
    return $null
}

function Find-WindowsTerminal {
    $cmd = Get-Command wt.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $store = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
    if (Test-Path -LiteralPath $store) { return $store }
    return $null
}

function Get-AccountEmail {
    param([string]$AccountDir)
    $candidates = New-Object System.Collections.Generic.List[string]
    if ($AccountDir -eq 'default' -or [string]::IsNullOrWhiteSpace($AccountDir)) {
        $candidates.Add((Join-Path $env:USERPROFILE '.claude.json'))
        $candidates.Add((Join-Path $env:USERPROFILE '.claude\.claude.json'))
    } else {
        $candidates.Add((Join-Path $AccountDir '.claude.json'))
        $candidates.Add((Join-Path $AccountDir '.claude\.claude.json'))
        $candidates.Add((Join-Path $env:USERPROFILE '.claude.json'))
    }
    foreach ($path in $candidates) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        try {
            $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop
            $match = [regex]::Match($raw, '"emailAddress"\s*:\s*"([^"]+)"')
            if ($match.Success) { return $match.Groups[1].Value }
        } catch { }
    }
    return $null
}

function Get-AccountCatalog {
    $dir2 = Join-Path $env:USERPROFILE '.claude-account-2'
    $dir3 = Join-Path $env:USERPROFILE '.claude-account-3'
    $emailDefault = Get-AccountEmail 'default'
    $email2 = Get-AccountEmail $dir2
    $email3 = Get-AccountEmail $dir3
    $labelDefault = if ($emailDefault) { "Personal ($emailDefault)" } else { 'Personal (default ~/.claude)' }
    $label2 = if ($email2) { "Work ($email2)" } else { 'Work (account 2)' }
    $label3 = if ($email3) { "Other ($email3)" } else { 'Other (account 3)' }
    return [ordered]@{
        default  = @{ Label = $labelDefault; Dir = 'default'; Email = $emailDefault }
        account2 = @{ Label = $label2; Dir = $dir2; Email = $email2 }
        account3 = @{ Label = $label3; Dir = $dir3; Email = $email3 }
    }
}

function Resolve-AccountDir {
    param([string]$AccountId)
    $catalog = Get-AccountCatalog
    if (-not $catalog.Contains($AccountId)) { return 'default' }
    return [string]$catalog[$AccountId].Dir
}

function Resolve-AccountLabel {
    param([string]$AccountId)
    $catalog = Get-AccountCatalog
    if (-not $catalog.Contains($AccountId)) { return 'Personal' }
    $label = [string]$catalog[$AccountId].Label
    if ($label -match '^([^(]+)') { return $matches[1].Trim() }
    return $label
}

function Resolve-AccountTitle {
    param([string]$AccountId)
    $catalog = Get-AccountCatalog
    if (-not $catalog.Contains($AccountId)) { return 'Claude-Personal' }
    $email = [string]$catalog[$AccountId].Email
    if (-not [string]::IsNullOrWhiteSpace($email)) { return $email }
    $label = Resolve-AccountLabel $AccountId
    return ("Claude-" + ($label -replace '\s+', '-'))
}

function Read-Config {
    $defaults = [ordered]@{
        LeftFolder   = [Environment]::GetFolderPath('MyDocuments')
        RightFolder  = [Environment]::GetFolderPath('MyDocuments')
        SameFolder   = $true
        Split        = 'vertical'
        Maximized    = $true
        LeftAccount  = 'default'
        RightAccount = 'account2'
        SecondAccount = $true
    }
    if (-not (Test-Path -LiteralPath $ConfigPath)) { return $defaults }
    try {
        $raw = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($key in @($defaults.Keys)) {
            if ($null -ne $raw.$key) { $defaults[$key] = $raw.$key }
        }
        if ($null -eq $raw.LeftAccount -and $null -ne $raw.SecondAccount) {
            $defaults.LeftAccount = 'default'
            $defaults.RightAccount = if ([bool]$raw.SecondAccount) { 'account2' } else { 'default' }
        }
    } catch { }
    return $defaults
}

function Save-Config {
    param([hashtable]$Config)
    if (-not (Test-Path -LiteralPath $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }
    ($Config | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
}

function Get-GuiConfigSnapshot {
    param($Ui)
    $leftAccount = if ($Ui.LeftAccount.SelectedItem) { [string]$Ui.LeftAccount.SelectedItem.Tag } else { 'default' }
    $rightAccount = if ($Ui.RightAccount.SelectedItem) { [string]$Ui.RightAccount.SelectedItem.Tag } else { 'account2' }
    return @{
        LeftFolder    = $Ui.Left.Text.Trim()
        RightFolder   = $Ui.Right.Text.Trim()
        SameFolder    = [bool]$Ui.Same.Checked
        Split         = if ($Ui.Stack.Checked) { 'horizontal' } else { 'vertical' }
        Maximized     = [bool]$Ui.Max.Checked
        LeftAccount   = $leftAccount
        RightAccount  = $rightAccount
        SecondAccount = ($rightAccount -ne 'default')
    }
}

function Select-AccountComboItem {
    param($Combo, [string]$AccountId)
    foreach ($item in $Combo.Items) {
        if ([string]$item.Tag -eq $AccountId) {
            $Combo.SelectedItem = $item
            return
        }
    }
    if ($Combo.Items.Count -gt 0) { $Combo.SelectedIndex = 0 }
}

function Build-AccountLaunchCmd {
    param([string]$AccountId)
    $launcher = Join-Path $ScriptDir 'Run-Claude-Account.cmd'
    $accountDir = Resolve-AccountDir $AccountId
    $label = (Resolve-AccountLabel $AccountId) -replace '\s+', '-'
    $quotedLauncher = ConvertTo-WtQuoted $launcher
    if ($accountDir -eq 'default') {
        return "cmd.exe /k $quotedLauncher default $label"
    }
    $quotedDir = ConvertTo-WtQuoted $accountDir
    return "cmd.exe /k $quotedLauncher $quotedDir $label"
}

function Show-Alert {
    param([string]$Text, [string]$Title = $AppName)
    [System.Windows.Forms.MessageBox]::Show(
        $Text, $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
}

function ConvertTo-WtQuoted {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }
    return '"' + ($Value -replace '"', '\"') + '"'
}

function Start-ClaudeDuo {
    param(
        [string]$LeftFolder,
        [string]$RightFolder,
        [string]$SplitMode,
        [bool]$MaximizeWindow,
        [string]$LeftAccount = 'default',
        [string]$RightAccount = 'account2'
    )

    $wt = Find-WindowsTerminal
    $claude = Find-ClaudeCmd

    if (-not $wt) {
        throw "Windows Terminal was not found. Install it from the Microsoft Store (search 'Windows Terminal'), then try again."
    }
    if (-not $claude) {
        throw "Claude Code was not found. Install it, or add claude.cmd to PATH."
    }
    if (-not (Test-Path -LiteralPath $LeftFolder)) {
        throw "Left folder does not exist:`n$LeftFolder"
    }
    if (-not (Test-Path -LiteralPath $RightFolder)) {
        throw "Right folder does not exist:`n$RightFolder"
    }

    if ($LeftAccount -eq $RightAccount) {
        throw "Left and right panes use the same account.`nPick different accounts in the dropdowns, or use 'Open one account' below."
    }

    $splitFlag = if ($SplitMode -eq 'horizontal') { '-H' } else { '-V' }
    $leftDir = ConvertTo-WtQuoted $LeftFolder
    $rightDir = ConvertTo-WtQuoted $RightFolder
    $leftCmd = Build-AccountLaunchCmd $LeftAccount
    $rightCmd = Build-AccountLaunchCmd $RightAccount
    $leftTitle = ConvertTo-WtQuoted (Resolve-AccountTitle $LeftAccount)
    $rightTitle = ConvertTo-WtQuoted (Resolve-AccountTitle $RightAccount)

    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add('--window new')
    if ($MaximizeWindow) { $parts.Add('--maximized') }
    $parts.Add("new-tab --title $leftTitle --suppressApplicationTitle -d $leftDir $leftCmd")
    $parts.Add(';')
    $parts.Add("split-pane $splitFlag -s 0.5 --title $rightTitle --suppressApplicationTitle -d $rightDir $rightCmd")
    $arguments = ($parts -join ' ')

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $wt
    $psi.Arguments = $arguments
    $psi.UseShellExecute = $true
    [void][System.Diagnostics.Process]::Start($psi)
}

function Start-SingleClaudeAccount {
    param(
        [string]$Folder,
        [string]$AccountId,
        [bool]$MaximizeWindow = $true
    )

    $wt = Find-WindowsTerminal
    $claude = Find-ClaudeCmd
    if (-not $wt) { throw "Windows Terminal was not found." }
    if (-not $claude) { throw "Claude Code was not found." }
    if (-not (Test-Path -LiteralPath $Folder)) { throw "Folder does not exist:`n$Folder" }

    $dir = ConvertTo-WtQuoted $Folder
    $cmd = Build-AccountLaunchCmd $AccountId
    $title = ConvertTo-WtQuoted (Resolve-AccountTitle $AccountId)
    $parts = @('--window new')
    if ($MaximizeWindow) { $parts += '--maximized' }
    $parts += "new-tab --title $title --suppressApplicationTitle -d $dir $cmd"
    $arguments = ($parts -join ' ')

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $wt
    $psi.Arguments = $arguments
    $psi.UseShellExecute = $true
    [void][System.Diagnostics.Process]::Start($psi)
}

function New-DesktopShortcut {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnkPath = Join-Path $desktop 'Claude Duo.lnk'
    $target = Join-Path $ScriptDir 'Launch-ClaudeDuo.vbs'
    $wt = Find-WindowsTerminal

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($lnkPath)
    $shortcut.TargetPath = $target
    $shortcut.WorkingDirectory = $ScriptDir
    $shortcut.Description = 'Open two Claude Code sessions in one window'
    if ($wt) { $shortcut.IconLocation = "$wt,0" }
    $shortcut.Save()
    return $lnkPath
}

function New-Label {
    param($Text, $X, $Y, $Width = 460, $Height = 22, $Color = '#E8E4DF', $Size = 9, $Bold = $false)
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    $label.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Color)
    $label.BackColor = [System.Drawing.Color]::Transparent
    $fontStyle = if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $label.Font = New-Object System.Drawing.Font('Segoe UI', $Size, $fontStyle)
    return $label
}

function New-TextBox {
    param($X, $Y, $Width = 372)
    $box = New-Object System.Windows.Forms.TextBox
    $box.Location = New-Object System.Drawing.Point($X, $Y)
    $box.Size = New-Object System.Drawing.Size($Width, 28)
    $box.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $box.BorderStyle = 'FixedSingle'
    $box.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#2A2622')
    $box.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#F4EFE8')
    return $box
}

function New-Button {
    param($Text, $X, $Y, $Width, $Height, $Back, $Fore)
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Location = New-Object System.Drawing.Point($X, $Y)
    $btn.Size = New-Object System.Drawing.Size($Width, $Height)
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = [System.Drawing.ColorTranslator]::FromHtml($Back)
    $btn.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($Fore)
    $btn.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $btn
}

function New-ComboBox {
    param($X, $Y, $Width = 420)
    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.Location = New-Object System.Drawing.Point($X, $Y)
    $combo.Size = New-Object System.Drawing.Size($Width, 28)
    $combo.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $combo.DropDownStyle = 'DropDownList'
    $combo.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#2A2622')
    $combo.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#F4EFE8')
    $combo.FlatStyle = 'Flat'
    return $combo
}

function Populate-AccountCombo {
    param($Combo)
    $Combo.Items.Clear()
    foreach ($entry in (Get-AccountCatalog).GetEnumerator()) {
        [void]$Combo.Items.Add([PSCustomObject]@{ Tag = $entry.Key; Text = $entry.Value.Label })
    }
    $Combo.DisplayMember = 'Text'
}

function Show-Gui {
    $config = Read-Config
    $bg = [System.Drawing.ColorTranslator]::FromHtml('#161412')
    $panel = [System.Drawing.ColorTranslator]::FromHtml('#1F1C19')

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $AppName
    $form.Size = New-Object System.Drawing.Size(520, 640)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.BackColor = $bg
    $form.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#F4EFE8')
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

    $form.Controls.Add((New-Label $AppName 24 18 460 32 '#F4EFE8' 18 $true))
    $form.Controls.Add((New-Label 'Two Claude Code sessions — pick a different account per pane.' 24 52 460 22 '#B7A99A' 9))

    $folderPanel = New-Object System.Windows.Forms.Panel
    $folderPanel.Location = New-Object System.Drawing.Point(20, 88)
    $folderPanel.Size = New-Object System.Drawing.Size(464, 168)
    $folderPanel.BackColor = $panel
    $form.Controls.Add($folderPanel)

    $folderPanel.Controls.Add((New-Label 'Folder A  (left / top)' 16 12 300 20 '#B7A99A' 8))
    $txtLeft = New-TextBox 16 34 348
    $txtLeft.Text = [string]$config.LeftFolder
    $folderPanel.Controls.Add($txtLeft)
    $btnBrowseA = New-Button 'Browse' 372 32 76 28 '#3A342E' '#F4EFE8'
    $folderPanel.Controls.Add($btnBrowseA)

    $folderPanel.Controls.Add((New-Label 'Folder B  (right / bottom)' 16 72 300 20 '#B7A99A' 8))
    $txtRight = New-TextBox 16 94 348
    $txtRight.Text = [string]$config.RightFolder
    $folderPanel.Controls.Add($txtRight)
    $btnBrowseB = New-Button 'Browse' 372 92 76 28 '#3A342E' '#F4EFE8'
    $folderPanel.Controls.Add($btnBrowseB)

    $chkSame = New-Object System.Windows.Forms.CheckBox
    $chkSame.Text = 'Use the same folder for both'
    $chkSame.Location = New-Object System.Drawing.Point(16, 132)
    $chkSame.Size = New-Object System.Drawing.Size(420, 22)
    $chkSame.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#E8E4DF')
    $chkSame.Checked = [bool]$config.SameFolder
    $folderPanel.Controls.Add($chkSame)

    $accountPanel = New-Object System.Windows.Forms.Panel
    $accountPanel.Location = New-Object System.Drawing.Point(20, 268)
    $accountPanel.Size = New-Object System.Drawing.Size(464, 108)
    $accountPanel.BackColor = $panel
    $form.Controls.Add($accountPanel)

    $accountPanel.Controls.Add((New-Label 'Left pane account' 16 12 300 20 '#B7A99A' 8))
    $cmbLeftAccount = New-ComboBox 16 32 420
    Populate-AccountCombo $cmbLeftAccount
    Select-AccountComboItem $cmbLeftAccount ([string]$config.LeftAccount)
    $accountPanel.Controls.Add($cmbLeftAccount)

    $accountPanel.Controls.Add((New-Label 'Right pane account' 16 58 300 20 '#B7A99A' 8))
    $cmbRightAccount = New-ComboBox 16 78 420
    Populate-AccountCombo $cmbRightAccount
    $rightAccountId = if ($config.RightAccount) { [string]$config.RightAccount } elseif ([bool]$config.SecondAccount) { 'account2' } else { 'default' }
    Select-AccountComboItem $cmbRightAccount $rightAccountId
    $accountPanel.Controls.Add($cmbRightAccount)

    $optPanel = New-Object System.Windows.Forms.Panel
    $optPanel.Location = New-Object System.Drawing.Point(20, 388)
    $optPanel.Size = New-Object System.Drawing.Size(464, 72)
    $optPanel.BackColor = $panel
    $form.Controls.Add($optPanel)

    $radioSide = New-Object System.Windows.Forms.RadioButton
    $radioSide.Text = 'Side by side'
    $radioSide.Location = New-Object System.Drawing.Point(16, 18)
    $radioSide.Size = New-Object System.Drawing.Size(140, 24)
    $radioSide.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#F4EFE8')
    $radioSide.Checked = ([string]$config.Split -ne 'horizontal')
    $optPanel.Controls.Add($radioSide)

    $radioStack = New-Object System.Windows.Forms.RadioButton
    $radioStack.Text = 'One above the other'
    $radioStack.Location = New-Object System.Drawing.Point(170, 18)
    $radioStack.Size = New-Object System.Drawing.Size(170, 24)
    $radioStack.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#F4EFE8')
    $radioStack.Checked = ([string]$config.Split -eq 'horizontal')
    $optPanel.Controls.Add($radioStack)

    $chkMax = New-Object System.Windows.Forms.CheckBox
    $chkMax.Text = 'Maximize'
    $chkMax.Location = New-Object System.Drawing.Point(350, 18)
    $chkMax.Size = New-Object System.Drawing.Size(100, 24)
    $chkMax.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#F4EFE8')
    $chkMax.Checked = [bool]$config.Maximized
    $optPanel.Controls.Add($chkMax)

    $optPanel.Controls.Add((New-Label 'Pane titles show account email. After /exit, press R or type claude (same login stays).' 16 44 430 22 '#B7A99A' 8))

    $btnLaunch = New-Button 'Open 2 Claude Code' 20 476 300 44 '#D97757' '#1A120E'
    $btnLaunch.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($btnLaunch)

    $btnShortcut = New-Button 'Pin to Desktop' 328 476 156 44 '#3A342E' '#F4EFE8'
    $form.Controls.Add($btnShortcut)

    $btnOpenLeft = New-Button 'Open left account only' 20 532 220 36 '#3A342E' '#F4EFE8'
    $form.Controls.Add($btnOpenLeft)

    $btnOpenRight = New-Button 'Open right account only' 264 532 220 36 '#3A342E' '#F4EFE8'
    $form.Controls.Add($btnOpenRight)

    $claudePath = Find-ClaudeCmd
    $wtPath = Find-WindowsTerminal
    $claudeOk = if ($claudePath) { 'Claude Code found' } else { 'Claude Code NOT found' }
    $wtOk = if ($wtPath) { 'Windows Terminal found' } else { 'Windows Terminal NOT found' }
    $statusColor = if ($claudePath -and $wtPath) { '#8FBF8A' } else { '#E08A6A' }
    $status = New-Label "$claudeOk  ·  $wtOk  ·  Settings auto-save" 24 580 460 22 $statusColor 8
    $form.Controls.Add($status)

    $ui = @{
        Left         = $txtLeft
        Right        = $txtRight
        BrowseB      = $btnBrowseB
        Same         = $chkSame
        Side         = $radioSide
        Stack        = $radioStack
        Max          = $chkMax
        LeftAccount  = $cmbLeftAccount
        RightAccount = $cmbRightAccount
    }

    $persistConfig = {
        try { Save-Config (Get-GuiConfigSnapshot $ui) } catch { }
    }.GetNewClosure()

    $syncRight = {
        if ($ui.Same.Checked) {
            $ui.Right.Text = $ui.Left.Text
            $ui.Right.Enabled = $false
            $ui.BrowseB.Enabled = $false
        } else {
            $ui.Right.Enabled = $true
            $ui.BrowseB.Enabled = $true
        }
    }.GetNewClosure()

    $pickFolder = {
        param($box)
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Choose a project folder for Claude Code'
        $dialog.ShowNewFolderButton = $true
        if ($box.Text -and (Test-Path -LiteralPath $box.Text)) { $dialog.SelectedPath = $box.Text }
        if ($dialog.ShowDialog() -eq 'OK') {
            $box.Text = $dialog.SelectedPath
            & $syncRight
            & $persistConfig
        }
    }

    $btnBrowseA.Add_Click({ & $pickFolder $ui.Left }.GetNewClosure())
    $btnBrowseB.Add_Click({ & $pickFolder $ui.Right }.GetNewClosure())
    $chkSame.Add_CheckedChanged({ & $syncRight; & $persistConfig }.GetNewClosure())
    $txtLeft.Add_TextChanged({ if ($ui.Same.Checked) { $ui.Right.Text = $ui.Left.Text }; & $persistConfig }.GetNewClosure())
    $txtRight.Add_TextChanged({ & $persistConfig }.GetNewClosure())
    $radioSide.Add_CheckedChanged({ if ($radioSide.Checked) { & $persistConfig } }.GetNewClosure())
    $radioStack.Add_CheckedChanged({ if ($radioStack.Checked) { & $persistConfig } }.GetNewClosure())
    $chkMax.Add_CheckedChanged({ & $persistConfig }.GetNewClosure())
    $cmbLeftAccount.Add_SelectedIndexChanged({ & $persistConfig }.GetNewClosure())
    $cmbRightAccount.Add_SelectedIndexChanged({ & $persistConfig }.GetNewClosure())
    $form.Add_FormClosing({ & $persistConfig }.GetNewClosure())
    & $syncRight
    & $persistConfig

    $btnLaunch.Add_Click({
        $cfg = Get-GuiConfigSnapshot $ui
        try {
            Start-ClaudeDuo -LeftFolder $cfg.LeftFolder -RightFolder $cfg.RightFolder -SplitMode $cfg.Split -MaximizeWindow $cfg.Maximized -LeftAccount $cfg.LeftAccount -RightAccount $cfg.RightAccount
            Save-Config $cfg
        } catch {
            Show-Alert $_.Exception.Message
        }
    }.GetNewClosure())

    $btnOpenLeft.Add_Click({
        $cfg = Get-GuiConfigSnapshot $ui
        try {
            Start-SingleClaudeAccount -Folder $cfg.LeftFolder -AccountId $cfg.LeftAccount -MaximizeWindow $cfg.Maximized
            Save-Config $cfg
        } catch {
            Show-Alert $_.Exception.Message
        }
    }.GetNewClosure())

    $btnOpenRight.Add_Click({
        $cfg = Get-GuiConfigSnapshot $ui
        try {
            $folder = if ($cfg.SameFolder) { $cfg.LeftFolder } else { $cfg.RightFolder }
            Start-SingleClaudeAccount -Folder $folder -AccountId $cfg.RightAccount -MaximizeWindow $cfg.Maximized
            Save-Config $cfg
        } catch {
            Show-Alert $_.Exception.Message
        }
    }.GetNewClosure())

    $btnShortcut.Add_Click({
        try {
            $path = New-DesktopShortcut
            Show-Alert "Shortcut created:`n$path"
        } catch {
            Show-Alert $_.Exception.Message
        }
    }.GetNewClosure())

    $form.ShowDialog() | Out-Null
}

# --- entry ---
if ($NoGui) {
    $cfg = Read-Config
    $leftFolder = if ($Left) { $Left } else { [string]$cfg.LeftFolder }
    $rightFolder = if ($Right) { $Right } else { if ([bool]$cfg.SameFolder) { $leftFolder } else { [string]$cfg.RightFolder } }
    $splitMode = if ($PSBoundParameters.ContainsKey('Split')) { $Split } else { [string]$cfg.Split }
    $max = if ($PSBoundParameters.ContainsKey('Maximized')) { [bool]$Maximized } else { [bool]$cfg.Maximized }
    $leftAccount = if ($cfg.LeftAccount) { [string]$cfg.LeftAccount } else { 'default' }
    $rightAccount = if ($cfg.RightAccount) { [string]$cfg.RightAccount } elseif ([bool]$cfg.SecondAccount) { 'account2' } else { 'default' }
    Start-ClaudeDuo -LeftFolder $leftFolder -RightFolder $rightFolder -SplitMode $splitMode -MaximizeWindow $max -LeftAccount $leftAccount -RightAccount $rightAccount
} else {
    Show-Gui
}
