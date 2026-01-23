<p align="center">
  <img src="logo.png" alt="md logo" width="120">
</p>

<h1 align="center">md</h1>

<p align="center">
  <b>M</b>essage <b>D</b>ump - Copy last command and output to clipboard with one keystroke
</p>

<p align="center">
  <a href="README.md">中文</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-blue" alt="Platform">
  <img src="https://img.shields.io/badge/shell-zsh%20%7C%20bash%20%7C%20PowerShell%207-green" alt="Shell">
  <img src="https://img.shields.io/badge/license-MIT-yellow" alt="License">
</p>

---

## 😫 The Pain

- Running `cmake`, `gradlew`, or AI model training - output floods the screen, scrolling forever to find the error
- Commands in tmux - output goes beyond the buffer, nearly impossible to copy everything
- Want to paste the error to AI? Manual selection is tedious and error-prone

**Now, just type `md`.**

## ✨ Features

- 🚀 **Seamless** - Auto-captures all command output, zero workflow changes
- 📋 **One keystroke** - Command + full output, ready to paste to AI
- 🔧 **One-line install / uninstall** - Simple as it gets
- 🌍 **Cross-platform** - macOS / all Linux distros
- 🖥️ **SSH friendly** - Run `md` on server, copies to your local clipboard

## 🔮 Roadmap

- [ ] Support tmux versions below 3.2

## 📦 Installation

### Bash / Zsh (macOS / Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/Cishoon/md/main/install-online.sh | bash
```

### PowerShell 7 (Windows)

```powershell
irm https://raw.githubusercontent.com/Cishoon/md/main/install-online.ps1 | iex
```

> ⚠️ Requires PowerShell 7 or later. Overrides the built-in `md` alias (shortcut for mkdir). Use `mkdir` or `New-Item` to create directories.

<details>
<summary>Don't have PowerShell 7? Click to install</summary>

```powershell
winget install Microsoft.PowerShell
```

</details>

Restart your terminal after installation.

## 🔧 Usage

```bash
cmake ..         # 500 lines of output, error somewhere in the middle
md               # copied
```

Ctrl+V to paste, clipboard content:

```
$ cmake ..
-- The C compiler identification is GNU 9.4.0
-- The CXX compiler identification is GNU 9.4.0
...
CMake Error at CMakeLists.txt:42:
  Could not find package XXX
...
```

## 📖 Commands

| Command | Description |
|:-------:|:------------|
| `md` | Copy last command to clipboard |
| `md exclude list` | Show excluded commands |
| `md exclude add <cmd>` | Add command to exclude list |
| `md exclude rm <cmd>` | Remove command from exclude list |
| `md update` | Update to latest version |
| `md uninstall` | Uninstall |
| `md version` | Show version |
| `md help` | Help |

> Excluded commands won't have their output captured, preserving original display. User config saved in `~/.md/exclude`

## 🖥️ Supported Platforms

| Platform | Shell | 
|:--------:|:-----:|
| macOS | zsh / bash |
| Linux (all distros) | zsh / bash |
| Windows | PowerShell 7 |
| SSH Remote | zsh / bash |

> Uses OSC 52 protocol for clipboard access. Requires terminal support (iTerm2, Windows Terminal, Alacritty, kitty, etc.)

> ⚠️ **tmux users**: Currently only supports tmux 3.2+ (requires `set-buffer -w` feature)

## ⚙️ How It Works

Uses shell hooks to intercept stdout/stderr before and after command execution, piping through `tee` to save output transparently.

- **zsh**: `preexec` / `precmd` hooks
- **bash**: `DEBUG` trap + `PROMPT_COMMAND`
- **PowerShell 7**: `Start-Transcript` + PSReadLine `CommandValidationHandler` + `prompt` function override

## 📄 License

MIT
