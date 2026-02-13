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
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-blue" alt="Platform">
  <img src="https://img.shields.io/badge/shell-zsh%20%7C%20bash%20%7C%20fish%20%7C%20PowerShell%207-green" alt="Shell">
  <img src="https://img.shields.io/badge/license-MIT-yellow" alt="License">
</p>

---

## 😫 痛点

- 跑 `cmake`、`gradlew`、AI 模型训练，输出刷了几百行，想找报错得往上翻半天
- 在 tmux 里跑命令，输出超出屏幕就看不到了，想复制完整输出巨麻烦
- 想把报错丢给 AI，还得手动选中、复制，滑动半天

**现在，`md` 一下就搞定。**

## ✨ 特性

- 🚀 **完全无感** - 自动捕获所有命令输出，无需改变任何习惯
- 📋 **一键复制** - 命令 + 完整输出，直接粘贴给 AI
- 🔧 **一键安装 / 卸载** - 一条命令搞定
- 🌍 **多平台** - macOS / 所有 Linux 发行版
- 🖥️ **SSH 友好** - 服务器上 `md`，直接复制到本地剪贴板

## 🔮 未来工作

- [ ] 支持 tmux 3.2 以下版本
- [ ] 终端进度条裁剪（去除多余的 `\r` 回车覆盖内容）
- [ ] 与 fzf 联动实现历史输出搜索功能

## 📦 安装

### Bash / Zsh / Fish (macOS / Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/Cishoon/md/main/install-online.sh | bash
```

<details>
<summary>💡 习惯用 md 当 mkdir？可以改用 mdd 命令</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/Cishoon/md/main/install-online.sh | MD_CMD_NAME=mdd bash
```

这样安装后使用 `mdd` 代替 `md`，不会影响你的 `md` 习惯。

</details>

### PowerShell 7 (Windows)

```powershell
irm https://raw.githubusercontent.com/Cishoon/md/main/install-online.ps1 | iex
```

> ⚠️ 需要 PowerShell 7 或更高版本。默认会覆盖内置的 `md` 别名（mkdir 的简写）

<details>
<summary>💡 想保留 md 作为 mkdir？可以改用 mdd 命令</summary>

```powershell
$env:MD_CMD_NAME = "mdd"; irm https://raw.githubusercontent.com/Cishoon/md/main/install-online.ps1 | iex
```

</details>

<details>
<summary>没有 PowerShell 7？</summary>

```powershell
winget install --id Microsoft.PowerShell -e

$PSVersionTable # 查看版本
```

</details>

安装完成后重启终端。


## 🔧 使用

```bash
cmake ..         # 输出了 500 行，报错在中间某处
md               # copied
```

Ctrl+V 粘贴，剪贴板内容：

```
$ cmake ..
-- The C compiler identification is GNU 9.4.0
-- The CXX compiler identification is GNU 9.4.0
...
CMake Error at CMakeLists.txt:42:
  Could not find package XXX
...
```

### 排除特定命令

安装 `md` 后，某些命令会检测输出环境是否为 TTY，显示不同的样式（如带颜色的输出），或者是可交互的（如 `nload`、`htop`），可能会无法正常显示或使用。

可以手动使用 `md exclude add <cmd>` 排除这些命令：

```bash
md exclude add nload
md exclude add htop
```

## 📖 命令

| 命令 | 说明 |
|:----:|:-----|
| `md` | 复制上一条命令到剪贴板 |
| `md on` | 启用 md |
| `md off` | 禁用 md（忽略所有捕获和复制） |
| `md status` | 查看当前启用/禁用状态 |
| `md exclude list` | 查看排除的命令列表 |
| `md exclude add <cmd>` | 添加命令到排除列表 |
| `md exclude rm <cmd>` | 从排除列表移除命令 |
| `md update` | 更新到最新版本 |
| `md uninstall` | 卸载 |
| `md version` | 显示版本 |
| `md help` | 帮助 |

> 排除列表中的命令不会被捕获输出，保持原有显示效果。用户自定义配置保存在 `~/.md/exclude`

## 🖥️ 支持平台

| 平台 | Shell | 
|:----:|:-----:|
| macOS | zsh / bash / fish |
| Linux (所有发行版) | zsh / bash / fish |
| Windows | PowerShell 7 |
| SSH 远程服务器 | zsh / bash / fish |

> 使用 OSC 52 协议复制到剪贴板，需要终端支持（iTerm2、Windows Terminal、Alacritty、kitty 等现代终端均支持）

> ⚠️ **tmux 用户注意**: 目前仅支持 tmux 3.2 及以上版本（需要 `set-buffer -w` 功能）

## ⚙️ 原理

利用 shell hook 机制在命令执行前后劫持 stdout/stderr，通过 `tee` 分流保存，对用户完全透明。

- **zsh**: `preexec` / `precmd` hooks
- **bash**: `DEBUG` trap + `PROMPT_COMMAND`
- **fish**: `script(1)` 全局捕获 + `fish_preexec` / `fish_postexec` 偏移切片
- **PowerShell 7**: `Start-Transcript` + PSReadLine `CommandValidationHandler` + `prompt` 函数重写

## 📄 License

MIT
