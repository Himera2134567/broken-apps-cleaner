Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    try {
        $launcher = $env:BROKEN_APP_CLEANER_EXE
        if ([string]::IsNullOrWhiteSpace($launcher) -or -not (Test-Path -LiteralPath $launcher -PathType Leaf)) {
            [System.Windows.MessageBox]::Show(
                "Не удалось определить путь к программе для повторного запуска от имени администратора.",
                "Broken Apps Cleaner",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error
            ) | Out-Null
            exit 1
        }

        Start-Process -FilePath $launcher -Verb RunAs | Out-Null
        exit 0
    }
    catch {
        # Пользователь мог отменить UAC. В этом случае просто завершаемся.
        exit 0
    }
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Очистка пустых записей приложений"
        Width="1180"
        Height="760"
        MinWidth="900"
        MinHeight="620"
        WindowStartupLocation="CenterScreen"
        Background="#F3F4F6">
    <Grid Margin="18">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="190"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="White" CornerRadius="10" Padding="16" Margin="0,0,0,12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                    <TextBlock Text="Очистка пустых записей установленных приложений"
                               FontSize="24"
                               FontWeight="SemiBold"
                               Foreground="#111827"/>
                    <TextBlock Margin="0,7,0,0"
                               TextWrapping="Wrap"
                               Foreground="#4B5563"
                               Text="Программа находит записи, у которых отсутствует файл деинсталлятора. Перед удалением каждой записи создаётся резервная копия реестра. Файлы программ на диске не удаляются."/>
                </StackPanel>
                <Border Grid.Column="1" Margin="18,0,0,0" Padding="10,6" CornerRadius="6" Background="#DCFCE7" VerticalAlignment="Top">
                    <TextBlock Text="Запущено от администратора" Foreground="#166534" FontWeight="SemiBold"/>
                </Border>
            </Grid>
        </Border>

        <Border Grid.Row="1" Background="White" CornerRadius="10" Padding="12" Margin="0,0,0,12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <Button x:Name="ScanButton" Grid.Column="0" Content="Сканировать заново" Padding="16,8" Margin="0,0,8,0"/>
                <Button x:Name="SelectAllButton" Grid.Column="1" Content="Выбрать всё" Padding="16,8" Margin="0,0,8,0"/>
                <Button x:Name="ClearSelectionButton" Grid.Column="2" Content="Снять выбор" Padding="16,8" Margin="0,0,8,0"/>
                <Button x:Name="DeleteButton" Grid.Column="3" Content="Удалить выбранные записи" Padding="16,8" Margin="0,0,8,0" Background="#DC2626" Foreground="White" FontWeight="SemiBold"/>
                <Button x:Name="OpenBackupButton" Grid.Column="5" Content="Открыть резервные копии" Padding="16,8" IsEnabled="False"/>
            </Grid>
        </Border>

        <Border Grid.Row="2" Background="White" CornerRadius="10" Padding="8" Margin="0,0,0,12">
            <DataGrid x:Name="AppsGrid"
                      AutoGenerateColumns="False"
                      CanUserAddRows="False"
                      CanUserDeleteRows="False"
                      CanUserResizeRows="False"
                      HeadersVisibility="Column"
                      GridLinesVisibility="Horizontal"
                      AlternatingRowBackground="#F9FAFB"
                      RowHeaderWidth="0"
                      SelectionMode="Extended"
                      SelectionUnit="FullRow"
                      IsReadOnly="False">
                <DataGrid.Columns>
                    <DataGridCheckBoxColumn Header="Выбрать"
                                            Width="75"
                                            Binding="{Binding Selected, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}"/>
                    <DataGridTextColumn Header="Приложение" Width="220" IsReadOnly="True" Binding="{Binding DisplayName}"/>
                    <DataGridTextColumn Header="Версия" Width="100" IsReadOnly="True" Binding="{Binding DisplayVersion}"/>
                    <DataGridTextColumn Header="Размер" Width="90" IsReadOnly="True" Binding="{Binding SizeText}"/>
                    <DataGridTextColumn Header="Раздел" Width="145" IsReadOnly="True" Binding="{Binding Scope}"/>
                    <DataGridTextColumn Header="Отсутствующий деинсталлятор" Width="*" MinWidth="280" IsReadOnly="True" Binding="{Binding MissingExecutable}"/>
                </DataGrid.Columns>
            </DataGrid>
        </Border>

        <Border Grid.Row="3" Background="White" CornerRadius="10" Padding="12" Margin="0,0,0,12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="250"/>
                </Grid.ColumnDefinitions>
                <TextBlock x:Name="StatusText" Grid.Column="0" Text="Подготовка..." VerticalAlignment="Center" Foreground="#374151" FontWeight="SemiBold"/>
                <ProgressBar x:Name="ProgressBar" Grid.Column="1" Height="18" Minimum="0" Maximum="100" Value="0"/>
            </Grid>
        </Border>

        <Border Grid.Row="4" Background="#111827" CornerRadius="10" Padding="10">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Text="Ход выполнения и результат" Foreground="White" FontWeight="SemiBold" Margin="2,0,0,7"/>
                <TextBox x:Name="LogBox"
                         Grid.Row="1"
                         Background="#111827"
                         Foreground="#E5E7EB"
                         BorderThickness="0"
                         FontFamily="Consolas"
                         FontSize="13"
                         IsReadOnly="True"
                         AcceptsReturn="True"
                         TextWrapping="Wrap"
                         VerticalScrollBarVisibility="Auto"
                         HorizontalScrollBarVisibility="Disabled"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$scanButton = $window.FindName("ScanButton")
$selectAllButton = $window.FindName("SelectAllButton")
$clearSelectionButton = $window.FindName("ClearSelectionButton")
$deleteButton = $window.FindName("DeleteButton")
$openBackupButton = $window.FindName("OpenBackupButton")
$appsGrid = $window.FindName("AppsGrid")
$statusText = $window.FindName("StatusText")
$progressBar = $window.FindName("ProgressBar")
$logBox = $window.FindName("LogBox")

$table = New-Object System.Data.DataTable
[void]$table.Columns.Add("Selected", [bool])
[void]$table.Columns.Add("DisplayName", [string])
[void]$table.Columns.Add("DisplayVersion", [string])
[void]$table.Columns.Add("SizeText", [string])
[void]$table.Columns.Add("Scope", [string])
[void]$table.Columns.Add("MissingExecutable", [string])
[void]$table.Columns.Add("InstallLocation", [string])
[void]$table.Columns.Add("UninstallString", [string])
[void]$table.Columns.Add("PSPath", [string])
[void]$table.Columns.Add("NativePath", [string])

$appsGrid.ItemsSource = $table.DefaultView
$script:lastBackupDirectory = $null
$script:isBusy = $false

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO", "OK", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    $time = Get-Date -Format "HH:mm:ss"
    $logBox.AppendText("[$time] [$Level] $Message`r`n")
    $logBox.ScrollToEnd()
}

function Pump-Ui {
    $window.Dispatcher.Invoke(
        [action]{},
        [Windows.Threading.DispatcherPriority]::Background
    )
}

function Set-BusyState {
    param([bool]$Busy)

    $script:isBusy = $Busy
    $scanButton.IsEnabled = -not $Busy
    $selectAllButton.IsEnabled = -not $Busy
    $clearSelectionButton.IsEnabled = -not $Busy
    $deleteButton.IsEnabled = -not $Busy
    $appsGrid.IsEnabled = -not $Busy
}

function Get-ValueSafely {
    param(
        [Parameter(Mandatory)]
        [object]$Object,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-UninstallerExecutable {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Command
    )

    if ([string]::IsNullOrWhiteSpace($Command)) {
        return $null
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Command.Trim())

    if ($expanded -match '^\s*"([^"]+?\.exe)"') {
        return $Matches[1]
    }

    if ($expanded -match '^\s*([A-Za-z]:\\.*?\.exe)(?:\s|$)') {
        return $Matches[1].Trim()
    }

    if ($expanded -match '^\s*([^\s"]+?\.exe)(?:\s|$)') {
        return $Matches[1].Trim()
    }

    return $null
}

function Test-UninstallCommandBroken {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Command
    )

    if ([string]::IsNullOrWhiteSpace($Command)) {
        return $false
    }

    $executable = Get-UninstallerExecutable -Command $Command
    if ([string]::IsNullOrWhiteSpace($executable)) {
        return $false
    }

    if ([IO.Path]::IsPathRooted($executable)) {
        return -not (Test-Path -LiteralPath $executable -PathType Leaf)
    }

    $resolved = Get-Command -Name $executable -CommandType Application -ErrorAction SilentlyContinue
    return $null -eq $resolved
}

function Get-RegistryRoots {
    return @(
        [PSCustomObject]@{
            PSPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
            Scope = "Все пользователи, 64-bit"
        },
        [PSCustomObject]@{
            PSPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
            Scope = "Все пользователи, 32-bit"
        },
        [PSCustomObject]@{
            PSPath = "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
            Scope = "Текущий пользователь"
        }
    )
}

function Invoke-Scan {
    if ($script:isBusy) {
        return
    }

    Set-BusyState -Busy $true
    $table.Rows.Clear()
    $progressBar.IsIndeterminate = $true
    $progressBar.Value = 0
    $statusText.Text = "Сканирование реестра..."
    Write-Log -Message "Начато сканирование записей установленных приложений."

    try {
        $roots = @(Get-RegistryRoots)
        $rootNumber = 0
        $brokenCount = 0
        $checkedCount = 0

        foreach ($root in $roots) {
            $rootNumber++
            $statusText.Text = "Сканирование: $($root.Scope) ($rootNumber из $($roots.Count))"
            Write-Log -Message "Проверяется раздел: $($root.Scope)."
            Pump-Ui

            if (-not (Test-Path -LiteralPath $root.PSPath)) {
                Write-Log -Message "Раздел отсутствует и пропущен: $($root.PSPath)" -Level "WARN"
                continue
            }

            $subKeys = @(Get-ChildItem -LiteralPath $root.PSPath -ErrorAction SilentlyContinue)
            $index = 0

            foreach ($subKey in $subKeys) {
                $index++
                $checkedCount++

                if (($index % 25) -eq 0) {
                    $statusText.Text = "$($root.Scope): проверено $index из $($subKeys.Count)"
                    Pump-Ui
                }

                try {
                    $properties = Get-ItemProperty -LiteralPath $subKey.PSPath -ErrorAction Stop
                    $displayName = [string](Get-ValueSafely -Object $properties -Name "DisplayName")

                    if ([string]::IsNullOrWhiteSpace($displayName)) {
                        continue
                    }

                    $uninstallString = [string](Get-ValueSafely -Object $properties -Name "UninstallString")
                    $quietUninstallString = [string](Get-ValueSafely -Object $properties -Name "QuietUninstallString")
                    $command = $uninstallString

                    if ([string]::IsNullOrWhiteSpace($command)) {
                        $command = $quietUninstallString
                    }

                    if (-not (Test-UninstallCommandBroken -Command $command)) {
                        continue
                    }

                    $missingExecutable = Get-UninstallerExecutable -Command $command
                    $displayVersion = [string](Get-ValueSafely -Object $properties -Name "DisplayVersion")
                    $installLocation = [string](Get-ValueSafely -Object $properties -Name "InstallLocation")
                    $estimatedSize = Get-ValueSafely -Object $properties -Name "EstimatedSize"
                    $sizeText = ""

                    if ($null -ne $estimatedSize) {
                        try {
                            $sizeGb = [double]$estimatedSize / 1048576.0
                            if ($sizeGb -ge 0.01) {
                                $sizeText = ("{0:N2} ГБ" -f $sizeGb)
                            }
                            else {
                                $sizeMb = [double]$estimatedSize / 1024.0
                                $sizeText = ("{0:N0} МБ" -f $sizeMb)
                            }
                        }
                        catch {
                            $sizeText = ""
                        }
                    }

                    $row = $table.NewRow()
                    $row.Selected = $false
                    $row.DisplayName = $displayName
                    $row.DisplayVersion = $displayVersion
                    $row.SizeText = $sizeText
                    $row.Scope = $root.Scope
                    $row.MissingExecutable = $missingExecutable
                    $row.InstallLocation = $installLocation
                    $row.UninstallString = $command
                    $row.PSPath = $subKey.PSPath
                    $row.NativePath = $subKey.Name
                    [void]$table.Rows.Add($row)

                    $brokenCount++
                    Write-Log -Message "Найдена пустая запись: $displayName; отсутствует: $missingExecutable" -Level "WARN"
                }
                catch {
                    Write-Log -Message "Не удалось проверить ключ $($subKey.Name): $($_.Exception.Message)" -Level "WARN"
                }
            }
        }

        $appsGrid.Items.Refresh()
        $statusText.Text = "Проверено записей: $checkedCount. Найдено пустых: $brokenCount."
        Write-Log -Message "Сканирование завершено. Проверено: $checkedCount; найдено пустых записей: $brokenCount." -Level "OK"

        if ($brokenCount -eq 0) {
            [System.Windows.MessageBox]::Show(
                "Записей с отсутствующими деинсталляторами не найдено.",
                "Результат сканирования",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
        }
    }
    catch {
        $statusText.Text = "Сканирование завершилось с ошибкой."
        Write-Log -Message $_.Exception.Message -Level "ERROR"
        [System.Windows.MessageBox]::Show(
            "Во время сканирования возникла ошибка:`n`n$($_.Exception.Message)",
            "Ошибка",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
    finally {
        $progressBar.IsIndeterminate = $false
        $progressBar.Value = 100
        Set-BusyState -Busy $false
    }
}

function Convert-ToSafeFileName {
    param([Parameter(Mandatory)][string]$Name)

    $safe = $Name
    foreach ($character in [IO.Path]::GetInvalidFileNameChars()) {
        $safe = $safe.Replace([string]$character, "_")
    }

    $safe = $safe.Trim()
    if ([string]::IsNullOrWhiteSpace($safe)) {
        $safe = "RegistryEntry"
    }
    if ($safe.Length -gt 90) {
        $safe = $safe.Substring(0, 90)
    }
    return $safe
}

function Invoke-DeleteSelected {
    if ($script:isBusy) {
        return
    }

    # Завершаем редактирование текущего чекбокса, чтобы его значение попало в DataTable.
    [void]$appsGrid.CommitEdit([System.Windows.Controls.DataGridEditingUnit]::Cell, $true)
    [void]$appsGrid.CommitEdit([System.Windows.Controls.DataGridEditingUnit]::Row, $true)

    $selectedRows = @($table.Rows | Where-Object { $_.Selected -eq $true })

    if ($selectedRows.Count -eq 0) {
        [System.Windows.MessageBox]::Show(
            "Сначала отметьте хотя бы одну запись в столбце «Выбрать».",
            "Ничего не выбрано",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
        return
    }

    $previewNames = @($selectedRows | Select-Object -First 12 | ForEach-Object { "• $($_.DisplayName)" })
    $preview = $previewNames -join "`n"
    if ($selectedRows.Count -gt 12) {
        $preview += "`n• ...и ещё $($selectedRows.Count - 12)"
    }

    $confirmation = [System.Windows.MessageBox]::Show(
        "Будут удалены только записи из списка установленных приложений.`nФайлы на диске удаляться не будут.`n`n$preview`n`nПродолжить?",
        "Подтверждение удаления",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )

    if ($confirmation -ne [System.Windows.MessageBoxResult]::Yes) {
        Write-Log -Message "Удаление отменено пользователем."
        return
    }

    Set-BusyState -Busy $true
    $progressBar.IsIndeterminate = $false
    $progressBar.Minimum = 0
    $progressBar.Maximum = $selectedRows.Count
    $progressBar.Value = 0

    $desktop = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $backupDirectory = Join-Path $desktop "BrokenAppsCleaner_Backup_$timestamp"
    [void](New-Item -ItemType Directory -Path $backupDirectory -Force)
    $script:lastBackupDirectory = $backupDirectory
    $openBackupButton.IsEnabled = $true

    $logFile = Join-Path $backupDirectory "result.log"
    $succeededRows = New-Object System.Collections.Generic.List[object]
    $successCount = 0
    $failedCount = 0
    $current = 0

    Write-Log -Message "Начато удаление $($selectedRows.Count) записей. Резервные копии: $backupDirectory"
    "Broken Apps Cleaner result - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Set-Content -LiteralPath $logFile -Encoding UTF8

    try {
        foreach ($row in $selectedRows) {
            $current++
            $progressBar.Value = $current - 1
            $statusText.Text = "Обработка $current из $($selectedRows.Count): $($row.DisplayName)"
            Pump-Ui

            $safeName = Convert-ToSafeFileName -Name ([string]$row.DisplayName)
            $backupFile = Join-Path $backupDirectory ("{0:D3}_{1}.reg" -f $current, $safeName)

            try {
                Write-Log -Message "[$current/$($selectedRows.Count)] Резервная копия: $($row.DisplayName)"

                $regOutput = & reg.exe export ([string]$row.NativePath) $backupFile /y 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Не удалось экспортировать ключ реестра. reg.exe: $($regOutput -join ' ')"
                }

                Remove-Item -LiteralPath ([string]$row.PSPath) -Recurse -Force -ErrorAction Stop
                $successCount++
                [void]$succeededRows.Add($row)

                $message = "Удалено: $($row.DisplayName). Копия: $backupFile"
                Write-Log -Message $message -Level "OK"
                $message | Add-Content -LiteralPath $logFile -Encoding UTF8
            }
            catch {
                $failedCount++
                $message = "Ошибка: $($row.DisplayName): $($_.Exception.Message)"
                Write-Log -Message $message -Level "ERROR"
                $message | Add-Content -LiteralPath $logFile -Encoding UTF8
            }

            $progressBar.Value = $current
            Pump-Ui
        }

        foreach ($row in $succeededRows) {
            $table.Rows.Remove($row)
        }
        $appsGrid.Items.Refresh()

        $statusText.Text = "Готово. Удалено: $successCount; ошибок: $failedCount."
        Write-Log -Message "Операция завершена. Удалено: $successCount; ошибок: $failedCount." -Level "OK"

        $resultText = "Операция завершена.`n`nУспешно удалено: $successCount`nОшибок: $failedCount`n`nРезервные копии:`n$backupDirectory"
        [System.Windows.MessageBox]::Show(
            $resultText,
            "Результат",
            [System.Windows.MessageBoxButton]::OK,
            $(if ($failedCount -eq 0) { [System.Windows.MessageBoxImage]::Information } else { [System.Windows.MessageBoxImage]::Warning })
        ) | Out-Null
    }
    catch {
        $statusText.Text = "Удаление завершилось с ошибкой."
        Write-Log -Message $_.Exception.Message -Level "ERROR"
        [System.Windows.MessageBox]::Show(
            "Во время удаления произошла ошибка:`n`n$($_.Exception.Message)",
            "Ошибка",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
    finally {
        Set-BusyState -Busy $false
    }
}

$scanButton.Add_Click({ Invoke-Scan })

$selectAllButton.Add_Click({
    if ($script:isBusy) { return }
    foreach ($row in $table.Rows) {
        $row.Selected = $true
    }
    $appsGrid.Items.Refresh()
    Write-Log -Message "Выбраны все найденные записи."
})

$clearSelectionButton.Add_Click({
    if ($script:isBusy) { return }
    foreach ($row in $table.Rows) {
        $row.Selected = $false
    }
    $appsGrid.Items.Refresh()
    Write-Log -Message "Выбор снят со всех записей."
})

$deleteButton.Add_Click({ Invoke-DeleteSelected })

$openBackupButton.Add_Click({
    if (-not [string]::IsNullOrWhiteSpace($script:lastBackupDirectory) -and (Test-Path -LiteralPath $script:lastBackupDirectory)) {
        Start-Process explorer.exe -ArgumentList ('"' + $script:lastBackupDirectory + '"') | Out-Null
    }
})

$window.Add_ContentRendered({
    $window.Dispatcher.BeginInvoke(
        [action]{ Invoke-Scan },
        [Windows.Threading.DispatcherPriority]::ApplicationIdle
    ) | Out-Null
})

[void]$window.ShowDialog()
