# dotfiles

| 目录/文件 | 用途 |
|-----------|------|
| `config/` | 应用配置，由 **rcm** 安装到 `~/.config` |
| `myscripts/` | 自定义 bash 函数库 → `~/.local/myscripts`（目录链接） |
| `tmux.conf` / `tmux-3.6.conf` | tmux |
| `vimrc` / `vimrc_min` / `ideavimrc` | Vim / IdeaVim |
| `xinitrc` / `Xresources` / `dwm/` | X11 / dwm |

---

## 配置安装（rcm）

- 安装：[thoughtbot/rcm](https://github.com/thoughtbot/rcm)
- `DOTFILES_DIRS` 指向 `~/dotfiles/config`（见 `config/tag-rcm/rcrc`）
- 常用：`rcup` 安装 / 更新，`lsrc` 查看链接

---

## myscripts

源码：`~/dotfiles/myscripts/` → `~/.local/myscripts`（目录符号链接）→ `.bashrc` source。  
只定义函数（`myscript_*`）；可执行命令另放 `~/.local/bin`。

**安装**

```bash
ln -sfn ~/dotfiles/myscripts ~/.local/myscripts
```

**`.bashrc`**（包进函数，`dir` / `f` / `skip` 均为 local，无残留）

```bash
myscript_load_all() {
  local dir f base skip skip_list
  # 跳过加载（空格或冒号分隔，.sh 可省略），例如：skip="path_cleanup git_info"
  skip=""
  dir="${HOME}/.local/myscripts"
  [ -d "$dir" ] || return 0
  skip_list=" ${skip//:/ } "
  for f in "$dir"/*.sh; do
    [ -f "$f" ] || continue
    base="${f##*/}"
    base="${base%.sh}"
    case "$skip_list" in
      *" $base "*|*" $base.sh "*) continue ;;
    esac
    . "$f"
  done
}
myscript_load_all
unset -f myscript_load_all
```

| 文件 | 命令 |
|------|------|
| `proxy_tool.sh` | `myscript_proxy_on` / `off` / `show` / `gen_config` / `help` |
| `git_info.sh` | `myscript_git_prompt`（PS1）、`myscript_git_check_repo` |
| `path_cleanup.sh` | `myscript_path_cleanup`（source 时自动跑一次） |

代理配置：`~/.config/my_proxy_config.conf`（或 `MYSCRIPT_PROXY_CONFIG`）

---

## 常用软件

| 软件 | 类型 | 简介 | 显示协议 |
|------|------|------|----------|
| noto-cjk | 字体 | Noto 中日韩字体 | — |
| X11 | 显示服务 | X Window 显示服务器 | X11 |
| dwm | GUI | 极简动态平铺窗口管理器 | X11 |
| picom | GUI | X11 合成器（透明/阴影等） | X11 |
| rofi | GUI | 应用启动器 / 窗口切换 | X11 |
| alacritty | GUI | GPU 加速终端模拟器 | 两者 |
| fcitx5 | GUI | 输入法框架 | 两者 |
| lm_sensors | CLI | 读取硬件温度/电压等传感器 | — |
| s-tui | TUI | 终端里看 CPU 温度与压力测试 | — |
| dmidecode | CLI | 读取 DMI/SMBIOS 硬件信息 | — |
| CPU-X | GUI | 类似 CPU-Z 的硬件信息查看 | 两者 |
| fzf | TUI | 通用模糊查找 | — |
| LazyGit | TUI | Git 终端 UI | — |
| tmux | TUI | 终端复用器 | — |
| remmina | GUI | 远程桌面客户端（RDP/VNC 等） | 两者 |
| freerdp | CLI | RDP 客户端（`xfreerdp` / `wlfreerdp`） | 两者 |

补充：

- **alacritty**：用 `alacritty.toml`；主题 → `~/.config/alacritty/themes`（[alacritty-theme](https://github.com/alacritty/alacritty-theme)）
- **tmux**：`tmux.conf` → `~/.tmux.conf`；`tmux-3.6.conf` → `~/.tmux-3.6.conf`（3.6+）

---

## 备忘

- 传感器芯片：ITE IT8712F
