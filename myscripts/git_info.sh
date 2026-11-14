#!/usr/bin/env bash
# Git 仓库状态提示（bash；兼容 Arch / Fedora / Debian 等常见发行版）
# 用法: source myscripts/git_info.sh
# 在 PS1 中调用: $(myscript_git_prompt)

# \001 / \002 等价于 \[ \]，在命令替换输出中也能让 bash 正确计算提示符宽度
MYSCRIPT_GIT_C_RESET=$'\001\033[0m\002'
MYSCRIPT_GIT_C_RED=$'\001\033[0;31m\002'
MYSCRIPT_GIT_C_GREEN=$'\001\033[0;32m\002'
MYSCRIPT_GIT_C_YELLOW=$'\001\033[0;33m\002'
MYSCRIPT_GIT_C_PURPLE=$'\001\033[0;35m\002'
MYSCRIPT_GIT_C_CYAN=$'\001\033[0;36m\002'

# 是否在 git 工作树内（且 git 可用）
myscript_git_in_repo() {
    command -v git >/dev/null 2>&1 || return 1
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# 当前目录是否为 git 仓库（人工检查；直接打到终端，不用提示符宽度标记）
myscript_git_check_repo() {
    if myscript_git_in_repo; then
        printf '\033[0;32m当前目录是Git仓库\033[0m\n'
    else
        printf '\033[0;31m当前目录不是Git仓库\033[0m\n'
    fi
}

# 分支名，或 detached HEAD 时的短 SHA
myscript_git_branch() {
    myscript_git_in_repo || return 0
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null \
        || git rev-parse --short HEAD 2>/dev/null) || return 0
    [ -n "$branch" ] || return 0
    printf '%s' "${MYSCRIPT_GIT_C_CYAN}[${branch}]${MYSCRIPT_GIT_C_RESET}"
}

# 工作区 / 暂存 / 未跟踪 / 冲突 / 上下游 / 特殊状态
myscript_git_status() {
    myscript_git_in_repo || return 0

    local output="" status git_dir ahead behind

    status=$(git status --porcelain 2>/dev/null) || status=""
    git_dir=$(git rev-parse --git-dir 2>/dev/null) || return 0

    # 未暂存修改
    if ! git diff --quiet 2>/dev/null; then
        output="${output}${MYSCRIPT_GIT_C_RED}*${MYSCRIPT_GIT_C_RESET}"
    fi

    # 已暂存修改
    if ! git diff --cached --quiet 2>/dev/null; then
        output="${output}${MYSCRIPT_GIT_C_GREEN}+${MYSCRIPT_GIT_C_RESET}"
    fi

    # 未跟踪
    if printf '%s\n' "$status" | grep -q '^??'; then
        output="${output}${MYSCRIPT_GIT_C_YELLOW}?${MYSCRIPT_GIT_C_RESET}"
    fi

    # 冲突：UU/AA/DD/AU/UA/DU/UD 等
    if printf '%s\n' "$status" | grep -qE '^(U.|.U|AA|DD)'; then
        output="${output}${MYSCRIPT_GIT_C_RED}!${MYSCRIPT_GIT_C_RESET}"
    fi

    # 与上游差异（无上游时静默跳过）
    if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
        ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null) || ahead=0
        behind=$(git rev-list --count 'HEAD..@{u}' 2>/dev/null) || behind=0
        ahead=${ahead:-0}
        behind=${behind:-0}
        if [ "$ahead" -gt 0 ] 2>/dev/null; then
            output="${output}${MYSCRIPT_GIT_C_GREEN}↑${ahead}${MYSCRIPT_GIT_C_RESET}"
        fi
        if [ "$behind" -gt 0 ] 2>/dev/null; then
            output="${output}${MYSCRIPT_GIT_C_RED}↓${behind}${MYSCRIPT_GIT_C_RESET}"
        fi
    fi

    # rebase / merge 等
    if [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; then
        output="${output}${MYSCRIPT_GIT_C_PURPLE}|REBASE${MYSCRIPT_GIT_C_RESET}"
    elif [ -f "$git_dir/MERGE_HEAD" ]; then
        output="${output}${MYSCRIPT_GIT_C_PURPLE}|MERGE${MYSCRIPT_GIT_C_RESET}"
    elif [ -f "$git_dir/CHERRY_PICK_HEAD" ]; then
        output="${output}${MYSCRIPT_GIT_C_PURPLE}|CHERRY-PICK${MYSCRIPT_GIT_C_RESET}"
    elif [ -f "$git_dir/REVERT_HEAD" ]; then
        output="${output}${MYSCRIPT_GIT_C_PURPLE}|REVERT${MYSCRIPT_GIT_C_RESET}"
    elif [ -f "$git_dir/BISECT_LOG" ]; then
        output="${output}${MYSCRIPT_GIT_C_PURPLE}|BISECT${MYSCRIPT_GIT_C_RESET}"
    fi

    [ -n "$output" ] || return 0
    printf ' %s' "$output"
}

# 分支 + 状态（供 PS1 或手动调用）
myscript_git_prompt() {
    myscript_git_in_repo || return 0
    local branch status
    branch=$(myscript_git_branch) || return 0
    [ -n "$branch" ] || return 0
    status=$(myscript_git_status)
    printf '%s%s' "$branch" "$status"
}

# 仅 bash 交互壳设置 PS1；被 sh/dash 或非交互 source 时不改提示符
if [ -n "${BASH_VERSION:-}" ] && [[ $- == *i* ]]; then
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$(myscript_git_prompt)\n╰─╼\$ '
fi
