# Broken Apps Cleaner

A Windows desktop utility for finding stale entries in **Installed apps** when the referenced uninstaller executable is missing. It lets the user review candidates and export a registry backup before removing selected entries.

[Описание на русском](README.ru.md)

## Use case

Manually removing an application's directory can leave its uninstall entry behind. Windows may keep showing that application and its previously recorded size. This tool helps review and remove those stale entries through a WPF interface.

The displayed size comes from registry metadata. Removing an entry does **not** reclaim that amount of disk space, remove application files, or uninstall an application.

## Features

- Scans the machine-wide 64-bit and 32-bit uninstall registry branches, plus the current user's branch.
- Expands environment variables in uninstall commands and checks whether their `.exe` exists or resolves through `PATH`.
- Lists candidates with name, version, recorded size, registry scope and missing executable.
- Supports individual selection, select all, selection reset and an explicit removal confirmation.
- Exports each selected registry key to a separate `.reg` file before deleting it; a failed export prevents deletion of that entry.
- Shows progress and an operation log, and provides a shortcut to the backup directory.

## Download and run

1. Download `BrokenAppsCleaner.exe` and `SHA256.txt` from [Releases](https://github.com/Himera2134567/broken-apps-cleaner/releases).
2. Optionally verify the download in PowerShell with `Get-FileHash .\BrokenAppsCleaner.exe -Algorithm SHA256` and compare it with `SHA256.txt`.
3. Run the executable and approve the Windows administrator prompt.
4. Review the scan results and select only entries you have independently confirmed are obsolete.
5. Choose **Удалить выбранные записи** and review the confirmation.

**Runtime:** Windows 10/11 x64 with the built-in Windows PowerShell and WPF components available. The executable embeds the script and starts it locally; Python, a virtual environment and third-party libraries are not required. This Windows executable does not run natively on Linux or macOS.

The release executable is the original build supplied with the project. It is unsigned. See the release notes for the checks performed.

## Backups and recovery

Before removing entries, the tool creates `BrokenAppsCleaner_Backup_<timestamp>` on the desktop. It contains one `.reg` export per entry and a `result.log` file. Review and import the corresponding `.reg` file to restore an entry. Keep the backup until the result has been checked.

## Architecture and files

| File | Responsibility |
| --- | --- |
| `main.go` | Native Go launcher: embeds `cleaner.ps1`, writes it to a temporary directory, starts Windows PowerShell with the launcher path in an environment variable, and cleans up after the child process exits. |
| `cleaner.ps1` | WPF interface, administrator check and relaunch, uninstall-command parsing, registry scan, selection, backup and deletion logic. |
| `go.mod` | Go module and minimum language version. There are no third-party Go dependencies. |
| `build.bat` | Builds an x64 Windows GUI executable without requiring CGO. |
| `tests/smoke.ps1` | Runs isolated command-parsing, executable-detection and utility checks without opening the application or editing the registry. |
| `SHA256.txt` | Checksum of the original release executable. Rebuilding produces a different checksum; calculate a new one for your build. |
| `README_RU.txt` | Original Russian instructions distributed with the project. |

## Build from source

Install Go **1.23 or newer**, then run on Windows:

```bat
build.bat
```

Equivalent commands:

```bat
set GOOS=windows
set GOARCH=amd64
set CGO_ENABLED=0
go build -trimpath -ldflags="-s -w -H=windowsgui" -o BrokenAppsCleaner.exe .
```

The resulting executable includes `cleaner.ps1`; distribute the executable without a Python installation or a virtual environment. Changes to the script require rebuilding the executable.

## Validation

Run the checks in Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\smoke.ps1
```

For this publication, the PowerShell syntax and isolated function checks passed. The original executable's SHA-256 matched the supplied checksum, its PE header identified a Windows x64 GUI application, and its embedded script matched the published source byte for byte. The administrator GUI and destructive registry operations were not run during preparation. A new Go build was not performed locally because the Go SDK was unavailable.

## Limitations

Detection is a heuristic based on missing executable paths. A moved uninstaller or disconnected drive can also make a valid entry appear broken. Commands without a recognizable `.exe` are skipped; this is not an inventory of every Windows installation format. The current-user branch belongs to the account running the elevated process.

Review candidates before removal. The tool edits uninstall registry entries and does not provide application repair, malware scanning, file cleanup or recovery of deleted application files.
