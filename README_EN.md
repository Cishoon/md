# md

> **M**essage **D**ump - Copy last command and output to clipboard with one keystroke

[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-blue)]()
[![Shell](https://img.shields.io/badge/shell-zsh%20%7C%20bash-green)]()
[![License](https://img.shields.io/badge/license-MIT-yellow)]()

Got an error? Just type `md` and paste it to your AI assistant.

## ✨ Features

- 🚀 **Seamless** - Auto-capture, no workflow changes needed
- 📋 **One keystroke** - Command + output, clean format
- 🌍 **Cross-platform** - macOS / Linux / WSL
- 🐚 **Multi-shell** - zsh / bash

## 📦 Installation

```bash
git clone https://github.com/yourname/md.git
cd md && ./install.sh
source ~/.zshrc  # or ~/.bashrc
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

| Platform | Shell | Clipboard Tool |
|:--------:|:-----:|:--------------:|
| macOS | zsh / bash | pbcopy (built-in) |
| Linux | zsh / bash | xclip / xsel |
| WSL | bash | clip.exe (built-in) |

> Linux users need to install clipboard tool: `sudo apt install xclip`

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
