//go:build windows

package main

import (
	_ "embed"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"unsafe"
)

//go:embed cleaner.ps1
var cleanerScript []byte

const createNoWindow = 0x08000000

var (
	user32          = syscall.NewLazyDLL("user32.dll")
	procMessageBoxW = user32.NewProc("MessageBoxW")
)

func utf16Ptr(text string) *uint16 {
	ptr, err := syscall.UTF16PtrFromString(text)
	if err != nil {
		return nil
	}
	return ptr
}

func showError(title, message string) {
	procMessageBoxW.Call(
		0,
		uintptr(unsafe.Pointer(utf16Ptr(message))),
		uintptr(unsafe.Pointer(utf16Ptr(title))),
		0x00000010, // MB_ICONERROR
	)
}

func main() {
	tempDir, err := os.MkdirTemp("", "BrokenAppsCleaner-")
	if err != nil {
		showError("Broken Apps Cleaner", fmt.Sprintf("Не удалось создать временную папку:\n%v", err))
		return
	}
	defer os.RemoveAll(tempDir)

	scriptPath := filepath.Join(tempDir, "cleaner.ps1")
	if err := os.WriteFile(scriptPath, cleanerScript, 0o600); err != nil {
		showError("Broken Apps Cleaner", fmt.Sprintf("Не удалось подготовить интерфейс программы:\n%v", err))
		return
	}

	exePath, err := os.Executable()
	if err != nil {
		showError("Broken Apps Cleaner", fmt.Sprintf("Не удалось определить путь к EXE:\n%v", err))
		return
	}
	exePath, _ = filepath.Abs(exePath)

	cmd := exec.Command(
		"powershell.exe",
		"-NoLogo",
		"-NoProfile",
		"-NonInteractive",
		"-ExecutionPolicy", "Bypass",
		"-WindowStyle", "Hidden",
		"-File", scriptPath,
	)
	cmd.Env = append(os.Environ(), "BROKEN_APP_CLEANER_EXE="+exePath)
	cmd.SysProcAttr = &syscall.SysProcAttr{
		HideWindow:    true,
		CreationFlags: createNoWindow,
	}

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			// Код 1223 обычно означает, что пользователь отменил запрос UAC.
			if exitErr.ExitCode() == 1223 {
				return
			}
		}
		showError("Broken Apps Cleaner", fmt.Sprintf("Программа завершилась с ошибкой:\n%v", err))
	}
}
