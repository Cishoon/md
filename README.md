<p align="center">
  <img src="logo.png" alt="md logo" width="120">
</p>

<h1 align="center">md</h1>

<p align="center">
  <b>M</b>essage <b>D</b>ump - 一键复制上一条命令到剪贴板
</p>

<p align="center">
  <a href="README_EN.md">English</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL-blue" alt="Platform">
  <img src="https://img.shields.io/badge/shell-zsh%20%7C%20bash-green" alt="Shell">
  <img src="https://img.shields.io/badge/license-MIT-yellow" alt="License">
</p>

---

报错了？`md` 一下，直接丢给 AI。

## ✨ 特性

- 🚀 **无感使用** - 自动捕获，无需改变任何习惯
- 📋 **一键复制** - 命令 + 输出，格式清晰
- 🌍 **跨平台** - macOS / Linux / WSL / SSH 远程
- 🐚 **多 Shell** - zsh / bash

## 📦 安装

```bash
curl -fsSL https://raw.githubusercontent.com/Cishoon/md/main/install-online.sh | bash
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

## 📖 命令

| 命令 | 说明 |
|:----:|:-----|
| `md` | 复制上一条命令到剪贴板 |
| `md update` | 更新到最新版本 |
| `md uninstall` | 卸载 |
| `md version` | 显示版本 |
| `md help` | 帮助 |

## 🖥️ 支持平台

| 平台 | Shell | 
|:----:|:-----:|
| macOS | zsh / bash |
| Linux | zsh / bash |
| WSL | bash |
| SSH 远程 | zsh / bash |

> 使用 OSC 52 协议复制到剪贴板，需要终端支持（iTerm2、Windows Terminal、Alacritty、kitty 等现代终端均支持）

## ⚙️ 原理

利用 shell hook 机制在命令执行前后劫持 stdout/stderr，通过 `tee` 分流保存，对用户完全透明。

- **zsh**: `preexec` / `precmd` hooks
- **bash**: `DEBUG` trap + `PROMPT_COMMAND`

## 📄 License

MIT
