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
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-blue" alt="Platform">
  <img src="https://img.shields.io/badge/shell-zsh%20%7C%20bash-green" alt="Shell">
  <img src="https://img.shields.io/badge/license-MIT-yellow" alt="License">
</p>

---

Got an error? Just type `md` and paste it to your AI assistant.

## ✨ Features

- 🚀 **Seamless** - Auto-capture, no workflow changes needed
- 📋 **One keystroke** - Command + output, clean format
- 🌍 **Cross-platform** - macOS / Linux / WSL
- 🐚 **Multi-shell** - zsh / bash

## 📦 Installation

**One-line install (macOS/Linux):**

```bash
curl -fsSL https://raw.githubusercontent.com/Cishoon/md/main/install-online.sh | bash
source ~/.zshrc  # or ~/.bashrc
```

**One-line install (Windows PowerShell):**

```powershell
irm https://raw.githubusercontent.com/Cishoon/md/main/install-online.ps1 | iex
```

**Or manual install:**

```bash
git clone https://github.com/Cishoon/md.git
cd md && ./install.sh        # macOS/Linux
cd md && .\install.ps1       # Windows PowerShell
```

## 🔧 Usage

```bash
npm run build    # got an error
md               # copied
```

Ctrl+V to paste, clipboard content:

```
$ npm run build
Error: Cannot find module 'xxx'
    at Function.Module._resolveFilename (node:internal/modules/cjs/loader:933:15)
    at Function.Module._load (node:internal/modules/cjs/loader:778:27)
    ...
```

## 🖥️ Supported Platforms

| Platform | Shell | 
|:--------:|:-----:|
| macOS | zsh / bash |
| Linux | zsh / bash |
| WSL | bash |
| Windows | PowerShell |
| SSH Remote | zsh / bash |

> Uses OSC 52 protocol for clipboard access. Requires terminal support (iTerm2, Windows Terminal, Alacritty, kitty, etc.)

## 🗑️ Uninstall

```bash
./install.sh uninstall
```

## ⚙️ How It Works

Uses shell hooks to intercept stdout/stderr before and after command execution, piping through `tee` to save output transparently.

- **zsh**: `preexec` / `precmd` hooks
- **bash**: `DEBUG` trap + `PROMPT_COMMAND`

## 📄 License

MIT
