# md

> **M**essage **D**ump - 一键复制上一条命令到剪贴板

[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-blue)]()
[![Shell](https://img.shields.io/badge/shell-zsh%20%7C%20bash-green)]()
[![License](https://img.shields.io/badge/license-MIT-yellow)]()

报错了？`md` 一下，直接丢给 AI。

## ✨ 特性

- 🚀 **无感使用** - 自动捕获，无需改变任何习惯
- 📋 **一键复制** - 命令 + 输出，格式清晰
- 🌍 **跨平台** - macOS / Linux / WSL
- 🐚 **多 Shell** - zsh / bash

## 📦 安装

```bash
git clone https://github.com/yourname/md.git
cd md && ./install.sh
source ~/.zshrc  # 或 ~/.bashrc
```

## 🔧 使用

```bash
npm run build    # 报错了
md               # copied
```

Ctrl+V 粘贴，剪贴板内容：

```
$ npm run build
Error: Cannot find module 'xxx'
    at Function.Module._resolveFilename (node:internal/modules/cjs/loader:933:15)
    at Function.Module._load (node:internal/modules/cjs/loader:778:27)
    ...
```

## 🖥️ 支持平台

| 平台 | Shell | 剪贴板工具 |
|:----:|:-----:|:----------:|
| macOS | zsh / bash | pbcopy (内置) |
| Linux | zsh / bash | xclip / xsel |
| WSL | bash | clip.exe (内置) |

> Linux 用户需安装剪贴板工具：`sudo apt install xclip`

## 🗑️ 卸载

```bash
./install.sh uninstall
```

## ⚙️ 原理

利用 shell hook 机制在命令执行前后劫持 stdout/stderr，通过 `tee` 分流保存，对用户完全透明。

- **zsh**: `preexec` / `precmd` hooks
- **bash**: `DEBUG` trap + `PROMPT_COMMAND`

## 📄 License

MIT
