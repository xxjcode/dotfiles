#!/usr/bin/env bash
# 代理环境变量工具（bash；兼容 Arch / Fedora / Debian）
# 用法: source myscripts/proxy_tool.sh
# 配置: $MYSCRIPT_PROXY_CONFIG 或默认 ~/.config/my_proxy_config.conf

MYSCRIPT_PROXY_CONFIG_FILE="${MYSCRIPT_PROXY_CONFIG:-$HOME/.config/my_proxy_config.conf}"

# 当前配置路径（优先环境变量，便于 source 后仍可覆盖）
myscript_proxy_config_path() {
    printf '%s' "${MYSCRIPT_PROXY_CONFIG:-$MYSCRIPT_PROXY_CONFIG_FILE}"
}

# URL userinfo 编码（纯 bash，不依赖 python/perl）
# 保留 RFC 3986 unreserved: ALPHA DIGIT - . _ ~
myscript_proxy_urlencode() {
    local LC_ALL=C
    local s="${1-}" c hex out="" i
    local -i len=${#s}
    for ((i = 0; i < len; i++)); do
        c="${s:i:1}"
        case "$c" in
            [A-Za-z0-9.~_-]) out+="$c" ;;
            *)
                printf -v hex '%%%02X' "'$c"
                out+="$hex"
                ;;
        esac
    done
    printf '%s' "$out"
}

# 从配置文件读取指定 section，输出代理 URL；失败返回 1（错误只走 stderr）
# 依赖：bash、awk、tr、printf、cat、mkdir、dirname（发行版默认均有）
myscript_proxy_load_config() {
    local section="${1:-}"
    local conf protocol host port username password
    local parsed

    conf=$(myscript_proxy_config_path)

    if [ -z "$section" ]; then
        printf '%s\n' "myscript_proxy_load_config: 缺少 section 参数" >&2
        return 1
    fi
    if [ ! -f "$conf" ]; then
        printf '%s\n' "未找到配置文件：$conf" >&2
        return 1
    fi

    # 一次 awk 解析（awk 为 POSIX 必备）；仅支持整行 # 注释，不支持行尾注释
    parsed=$(awk -v sec="$section" '
        function trim(s) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
            gsub(/^["'\'']|["'\'']$/, "", s)
            return s
        }
        /^[[:space:]]*#/ { next }
        $0 ~ "^[[:space:]]*\\[" sec "\\][[:space:]]*$" { insec=1; next }
        /^[[:space:]]*\[/ { insec=0; next }
        !insec { next }
        {
            eq = index($0, "=")
            if (eq < 1) next
            key = trim(substr($0, 1, eq - 1))
            val = trim(substr($0, eq + 1))
            if (key == "PROTOCOL") p = val
            else if (key == "HOST") h = val
            else if (key == "PORT") o = val
            else if (key == "USERNAME") u = val
            else if (key == "PASSWORD") w = val
        }
        END { printf "%s\n%s\n%s\n%s\n%s", p, h, o, u, w }
    ' "$conf") || {
        printf '%s\n' "解析配置失败：$conf" >&2
        return 1
    }

    {
        IFS= read -r protocol
        IFS= read -r host
        IFS= read -r port
        IFS= read -r username
        IFS= read -r password
    } < <(printf '%s\n' "$parsed")

    if [ -z "$protocol" ] || [ -z "$host" ] || [ -z "$port" ]; then
        printf '%s\n' "配置不完整：[$section] 需要 PROTOCOL/HOST/PORT（$conf）" >&2
        printf '%s\n' "提示：只支持整行 # 注释；不要写在 HOST=... 行尾。" >&2
        return 1
    fi

    protocol=$(printf '%s' "$protocol" | tr '[:upper:]' '[:lower:]')

    if [ -n "$username" ] && [ -n "$password" ]; then
        username=$(myscript_proxy_urlencode "$username")
        password=$(myscript_proxy_urlencode "$password")
        printf '%s://%s:%s@%s:%s\n' "$protocol" "$username" "$password" "$host" "$port"
    else
        if [ -n "$username" ] || [ -n "$password" ]; then
            printf '%s\n' "提示：[$section] 需同时填写 USERNAME 与 PASSWORD 才会带认证，已忽略不完整认证。" >&2
        fi
        printf '%s://%s:%s\n' "$protocol" "$host" "$port"
    fi
}

# 同时设置常见大小写变量，兼容 curl/wget/python 等
myscript_proxy_export() {
    local name="$1"
    local value="$2"
    case "$name" in
        all_proxy)
            export all_proxy="$value" ALL_PROXY="$value" ;;
        http_proxy)
            export http_proxy="$value" HTTP_PROXY="$value" ;;
        https_proxy)
            export https_proxy="$value" HTTPS_PROXY="$value" ;;
        *)
            return 1 ;;
    esac
}

myscript_proxy_unset_one() {
    case "$1" in
        all_proxy)
            unset all_proxy ALL_PROXY ;;
        http_proxy)
            unset http_proxy HTTP_PROXY ;;
        https_proxy)
            unset https_proxy HTTPS_PROXY ;;
        *)
            return 1 ;;
    esac
}

# 启用代理：myscript_proxy_on [socks5|http|https|all]
myscript_proxy_on() {
    local proxy_type="${1:-all}"
    local url conf

    conf=$(myscript_proxy_config_path)
    if [ ! -f "$conf" ]; then
        printf '%s\n' "未找到配置文件：$conf" >&2
        printf '%s\n' "可先执行: myscript_proxy_gen_config" >&2
        return 1
    fi

    case "$proxy_type" in
        socks5|SOCKS5)
            url=$(myscript_proxy_load_config "SOCKS5") || return 1
            myscript_proxy_export all_proxy "$url"
            printf 'SOCKS5 代理已启用: %s\n' "$url" ;;
        http|HTTP)
            url=$(myscript_proxy_load_config "HTTP") || return 1
            myscript_proxy_export http_proxy "$url"
            printf 'HTTP 代理已启用: %s\n' "$url" ;;
        https|HTTPS)
            url=$(myscript_proxy_load_config "HTTPS") || return 1
            myscript_proxy_export https_proxy "$url"
            printf 'HTTPS 代理已启用: %s\n' "$url" ;;
        all|ALL)
            url=$(myscript_proxy_load_config "SOCKS5") || return 1
            myscript_proxy_export all_proxy "$url"
            url=$(myscript_proxy_load_config "HTTP") || return 1
            myscript_proxy_export http_proxy "$url"
            url=$(myscript_proxy_load_config "HTTPS") || return 1
            myscript_proxy_export https_proxy "$url"
            printf '全协议代理已启用\n' ;;
        *)
            printf '%s\n' "无效代理类型！支持：socks5/http/https/all" >&2
            return 1 ;;
    esac
}

# 关闭代理：myscript_proxy_off [socks5|http|https|all]
myscript_proxy_off() {
    local target="${1:-all}"

    case "$target" in
        http|HTTP)
            myscript_proxy_unset_one http_proxy
            printf 'HTTP 代理已关闭\n' ;;
        https|HTTPS)
            myscript_proxy_unset_one https_proxy
            printf 'HTTPS 代理已关闭\n' ;;
        socks5|SOCKS5)
            myscript_proxy_unset_one all_proxy
            printf 'SOCKS5 代理已关闭\n' ;;
        all|ALL)
            myscript_proxy_unset_one http_proxy
            myscript_proxy_unset_one https_proxy
            myscript_proxy_unset_one all_proxy
            printf '所有代理已关闭\n' ;;
        *)
            printf '%s\n' "无效参数！支持：http/https/socks5/all" >&2
            return 1 ;;
    esac
}

myscript_proxy_show() {
    local conf
    conf=$(myscript_proxy_config_path)
    printf 'all_proxy / ALL_PROXY:   %s\n' "${all_proxy:-${ALL_PROXY:-}}"
    printf 'http_proxy / HTTP_PROXY: %s\n' "${http_proxy:-${HTTP_PROXY:-}}"
    printf 'https_proxy / HTTPS_PROXY: %s\n' "${https_proxy:-${HTTPS_PROXY:-}}"
    printf '配置文件: %s\n' "$conf"
    if [ -f "$conf" ]; then
        printf '%s\n' '---- 配置内容 ----'
        cat "$conf"
    else
        printf '配置文件未找到\n'
    fi
}

# 生成配置模板（不覆盖已有文件）
myscript_proxy_gen_config() {
    local conf dir
    conf=$(myscript_proxy_config_path)

    if [ -f "$conf" ]; then
        printf '%s\n' "配置文件已存在：$conf" >&2
        return 1
    fi

    dir=$(dirname "$conf")
    mkdir -p "$dir" || {
        printf '%s\n' "无法创建目录：$dir" >&2
        return 1
    }

    cat > "$conf" <<'EOF'
# 代理配置模板
# 提示：只支持整行 # 注释，不要把注释写在键值同一行末尾。
# USERNAME/PASSWORD 需同时填写；密码中的 @ : / 等会自动 URL 编码。

[SOCKS5]
PROTOCOL="socks5"
HOST="127.0.0.1"
PORT="1080"
USERNAME=""
PASSWORD=""

[HTTP]
PROTOCOL="http"
HOST="127.0.0.1"
PORT="8080"
USERNAME=""
PASSWORD=""

[HTTPS]
PROTOCOL="https"
HOST="127.0.0.1"
PORT="8443"
USERNAME=""
PASSWORD=""
EOF
    printf '配置文件已生成: %s\n' "$conf"
    printf '%s\n' "提示：只支持整行 # 注释；USERNAME 与 PASSWORD 需成对填写。"
}

myscript_proxy_help() {
    local conf
    conf=$(myscript_proxy_config_path)
    cat <<EOF
Usage:
  myscript_proxy_on [类型]     启用代理（socks5/http/https/all，默认 all）
  myscript_proxy_off [类型]    关闭代理（socks5/http/https/all，默认 all）
  myscript_proxy_gen_config    生成配置文件模板
  myscript_proxy_show          显示当前代理与配置
  myscript_proxy_help          显示本帮助

配置文件: $conf
可用环境变量 MYSCRIPT_PROXY_CONFIG 覆盖路径。

配置提示:
  - 只支持整行 # 注释（行尾注释不支持，会导致值被污染）
  - USERNAME 与 PASSWORD 需同时填写；特殊字符会自动 URL 编码
  - 解析仅用 bash/awk/tr 等系统自带工具
EOF
}
