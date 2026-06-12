#!/usr/bin/env python3
"""
analyze_peas.py — 从 linPEAS 输出中提取提权关键信息
用法: python3 analyze_peas.py /tmp/peas-output.txt
"""
import re
import sys

def strip_ansi(s):
    return re.sub(r'\x1b\[[0-9;]*[mK]', '', s)

def load(path):
    with open(path, encoding='utf-8', errors='replace') as f:
        return f.read()

def extract(text):
    lines = text.splitlines()
    info = {
        'os': [],
        'kernel': '',
        'cves': [],
        'suid': [],
        'sudo': [],
        'cron': [],
        'writable': [],
        'interesting': [],
    }

    for line in lines:
        raw = line
        line = strip_ansi(line)

        # OS / kernel
        if 'Linux version' in line:
            info['kernel'] = line
        if re.search(r'(Ubuntu|Debian|CentOS|kernel).*\d', line, re.I):
            info['os'].append(line)

        # CVE matches
        if re.search(r'CVE-\d{4}-\d{4,}', line):
            info['cves'].append(line)

        # SUID
        if re.search(r'(SUID|SGID|capabilities)', line, re.I) and '╔' not in line:
            info['suid'].append(line)

        # Sudo
        if re.search(r'sudo', line, re.I) and '╔' not in line:
            info['sudo'].append(line)

        # Cron / jobs
        if re.search(r'(cron|job|timer|schedule)', line, re.I) and '╔' not in line:
            info['cron'].append(line)

        # Writable paths
        if re.search(r'(writable|write.*perm)', line, re.I):
            info['writable'].append(line)

        # Interesting (passwords, keys, mysql, etc.)
        if re.search(r'(password|passwd|key|secret|credential|mysql)', line, re.I) and '╔' not in line:
            info['interesting'].append(line)

    return info

def print_section(title, items, max_items=20):
    if not items:
        print(f"  ❌ 未发现")
        return
    print(f"  ✅ 发现 {len(items)} 项 (显示前 {max_items}):")
    for item in items[:max_items]:
        print(f"     • {item[:120]}")

if __name__ == '__main__':
    path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/target_peas.txt'
    text = load(path)
    info = extract(text)

    print("=" * 60)
    print("  linPEAS 分析报告")
    print("=" * 60)

    print("\n[1] 内核 / OS")
    if info['kernel']:
        print(f"  • {info['kernel']}")
    print_section("OS 信息", info['os'], 5)

    print("\n[2] CVE 漏洞匹配")
    print_section("CVE", info['cves'], 30)

    print("\n[3] SUID / SGID / 能力")
    print_section("SUID", info['suid'])

    print("\n[4] Sudo 配置")
    print_section("Sudo", info['sudo'])

    print("\n[5] Cron / 定时任务")
    print_section("Cron", info['cron'])

    print("\n[6] 可写路径")
    print_section("Writable", info['writable'])

    print("\n[7] 敏感信息（密码/密钥/MySQL）")
    print_section("Interesting", info['interesting'])
