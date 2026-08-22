#!/usr/bin/env bash

# 开启严格模式：遇到错误、未定义变量或管道错误立即退出
set -euo pipefail

CONFIG_FILE="/etc/fail2ban/jail.local"
BACKUP_FILE="${CONFIG_FILE}.bak.$(date +%Y%m%d_%H%M%S)"

echo " ===> [1/4] 正在检查并备份原有配置... "
if [ -f "$CONFIG_FILE" ]; then
    sudo cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo " 原配置已备份至: $BACKUP_FILE "
else
    echo " 未发现原配置，将直接创建新文件 "
fi

echo " ===> [2/4] 正在写入新版 jail.local..."
# 注意：如果要加静态 IP），请加在 ignoreip 后面，用空格隔开
cat << 'EOF' | sudo tee "$CONFIG_FILE" > /dev/null
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
bantime  = 86400
findtime = 3600
maxretry = 5
bantime.increment = true
bantime.factor    = 2
bantime.maxtime   = 4w
backend  = systemd

[sshd]
enabled = true
port    = ssh
mode    = aggressive
EOF

echo " ===> [3/4] 正在校验新配置语法..."
if sudo fail2ban-client --test > /dev/null 2>&1; then
    echo " ===> [4/4] 语法校验通过,正在重启 Fail2ban 并重新加载规则..."
    sudo systemctl restart fail2ban
    sudo rm -f "$BACKUP_FILE"
else
    echo " 语法校验失败,正在回滚... "
    if [ -f "$BACKUP_FILE" ]; then
        sudo cp "$BACKUP_FILE" "$CONFIG_FILE"
        sudo rm -f "$BACKUP_FILE"
        echo " 已成功回滚至上一版本配置 "
    else
        sudo rm -f "$CONFIG_FILE"
        echo " 已清理错误的配置文件 "
    fi
    exit 1
fi