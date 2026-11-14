#!/usr/bin/env bash
# PATH 去重（保守）：只去掉重复的非空路径，保留首次出现顺序
# - 空段（::、末尾 :，表示当前目录）全部保留，不去重、不删除
# - 不展开 ~、不规范化尾斜杠、不排序
# 用法: source 后自动执行一次；也可手动 myscript_path_cleanup

myscript_path_cleanup() {
    local -a parts unique
    local -A seen
    local rest p new_path first

    [[ -n "${PATH+x}" ]] || return 0

    # 不用 read/<<<：IFS 拆分会丢掉尾部空段；手工按 : 切开以保留 :: 与末尾 :
    parts=()
    rest="${PATH}"
    while true; do
        case "$rest" in
            *:*)
                parts+=("${rest%%:*}")
                rest="${rest#*:}"
                ;;
            *)
                parts+=("$rest")
                break
                ;;
        esac
    done

    unique=()
    for p in "${parts[@]}"; do
        if [[ -z "$p" ]]; then
            unique+=("")
            continue
        fi
        [[ -n "${seen[$p]+x}" ]] && continue
        seen[$p]=1
        unique+=("$p")
    done

    # 不用 "${a[*]}"：同样会丢掉末尾空元素
    new_path=""
    first=1
    for p in "${unique[@]}"; do
        if ((first)); then
            new_path="$p"
            first=0
        else
            new_path+=":$p"
        fi
    done

    [[ "$new_path" == "$PATH" ]] || export PATH="$new_path"
}

myscript_path_cleanup
