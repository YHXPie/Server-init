#!/bin/bash

# init.sh

# Copyright (C) 2026 StreamingHX/yhxpie
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# ===> 基础设置与检查
# 遇到错误立即停止
set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' 

# ===> 逻辑开始
echo -e "\n${RED} ===> 开始执行服务器初始化... <=== ${NC}"
sleep 1s

# ===> 检查是否以 root 运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED} 请使用 root 权限运行此脚本：sudo $0${NC}"
   exit 1
fi

# ===> 定义全局步骤数量
TOTAL_STEPS=10

# ===> 输出基本内容
echo -e "\n${RED} ===> 执行内容：${NC}"
echo -e "\n${GREEN} 1. 设置主机名称 "
echo -e " 2. 设置 Asia/Shanghai 时区 "
echo -e " 3. 启用系统 BBR 算法 "
echo -e " 4. 配置 Swap 交换空间 "
echo -e " 5. 调整 apt 源并配置软件、系统更新 "
echo -e " 6. 启用 ufw 防火墙 "
echo -e " 7. 配置防爆破组件 "
echo -e " 8. 系统内核更新 "
echo -e " 9. 系统磁盘空间优化 "
echo -e " 10. 可选：安装增强性组件 "
echo -e "     - 面板 / Docker ... ${NC}"
echo -e "\n ${RED} 执行时建议时刻保持连接以监控状态 ${NC}"
echo -e "\n 等待 3 秒... "
sleep 3s
clear

# ===> 1. 交互式修改主机名
echo -e "${GREEN} [1/$TOTAL_STEPS] ===> 主机名配置 ${NC}"
sleep 1s
echo -e " 当前主机名: ${GREEN} $(hostname) ${NC}"
echo -ne "\n${GREEN} 是否需要修改主机名? [y/N]: ${NC}"
read -r CHANGE_HOSTNAME < /dev/tty

if [[ "$CHANGE_HOSTNAME" =~ ^[Yy]$ ]]; then
    while true; do
        echo -e "\n${RED} 主机名仅允许区分大小写的字母、数字、连字符，不能以连字符开头或结尾 ${NC}"
        echo -ne "${GREEN} ===> 请输入新的主机名: ${NC}"
        read -r NEW_HOSTNAME < /dev/tty
        sleep 1s
        
        # 验证是否为空
        if [[ -z "$NEW_HOSTNAME" ]]; then
            echo -e "\n${GREEN} 已跳过修改 ${NC}"
            break
        fi

        # 核心验证逻辑 正则含义：
        # ^[a-zA-Z0-9]    : 必须以字母或数字开头
        # [-a-zA-Z0-9]*   : 中间可以包含字母、数字或连字符
        # [a-zA-Z0-9]$    : 必须以字母或数字结尾 (防止以 - 结尾)
        # {1,63}          : 长度限制 (可选，通常不超过 63 字符)
        if [[ ! "$NEW_HOSTNAME" =~ ^[a-zA-Z0-9][-a-zA-Z0-9]*[a-zA-Z0-9]$ ]] && [[ ! "$NEW_HOSTNAME" =~ ^[a-zA-Z0-9]$ ]]; then
            echo -e "\n${RED} 主机名格式有误，请重新设置 ${NC}"
            continue
        fi

        if hostnamectl set-hostname "$NEW_HOSTNAME"; then
            # 修正 /etc/hosts 里的记录，防止 sudo 解析慢
            if grep -q "^127.0.1.1" /etc/hosts; then
                sed -i "s/^127.0.1.1.*/127.0.1.1 $NEW_HOSTNAME/" /etc/hosts
            else
                echo "127.0.1.1 $NEW_HOSTNAME" >> /etc/hosts
            fi

            echo -e "\n${GREEN} 主机名修改完成 ${NC}"
            echo -e "${GREEN} ===> Done. ${NC}"
            break
        else
            echo -e "\n${RED} 设置失败，请重试 ${NC}"
            continue
        fi
    done
    sleep 2s
else
    echo -e "\n${GREEN} 已跳过修改 ${NC}"
    sleep 1s
fi
clear

# ===> 2. 设置时区
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置主机名称... OK √ "
echo -e " ===> [2/$TOTAL_STEPS] 正在设置时区为 Asia/Shanghai... ${NC}"
sleep 1s
timedatectl set-timezone Asia/Shanghai

# 部分 Debian 可能默认没有安装 ntp 服务
timedatectl set-ntp true || true

# 重启时间同步服务，确保立即生效
systemctl restart systemd-timesyncd.service 2>/dev/null || TIME_SYNC_AGAIN=yes

timedatectl set-local-rtc 0 || true

# 显示时间
echo -e "\n 当前时间: $(date)"
echo -e "${GREEN} ===> Done. ${NC}"
sleep 2s
clear

# ===> 3. 启用系统 TCP BBR
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置主机名称... OK √ "
echo -e " [2/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... OK √ "
echo -e " ===> [3/$TOTAL_STEPS] 配置 TCP BBR... ${NC}"
sleep 1s

if [[ $(sysctl -n net.ipv4.tcp_congestion_control) != "bbr" ]]; then
    BBR_CONF="/etc/sysctl.d/90-bbr.conf"
    echo "net.core.default_qdisc=fq" > "$BBR_CONF"
    echo "net.ipv4.tcp_congestion_control=bbr" >> "$BBR_CONF"
    sysctl --system    
    echo -e "\n${GREEN} 已成功启用 ${NC}"
    sleep 2s
else
    echo -e "\n${GREEN} BBR 配置已存在 ${NC}"
    sleep 1s
fi
clear

# ===> 4. 配置 Swap
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置主机名称... OK √ "
echo -e " [2/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... OK √ "
echo -e " [3/$TOTAL_STEPS] 配置 TCP BBR... OK √ "
echo -e " ===> [4/$TOTAL_STEPS] 检查并配置 Swap... ${NC}"
sleep 1s

# 检查是否已经存在 Swap
if [ $(awk '/^SwapTotal:/ {print $2}' /proc/meminfo) -gt 0 ]; then
    echo -e "\n${GREEN} Swap 已存在 ${NC}"
    sleep 1s
else
    # 获取物理内存大小 (MB)
    MEM_Total=$(free -m | awk '/Mem:/ { print $2 }')
    echo -e "\n${GREEN} 检测到系统内存: ${MEM_Total} MB ${NC}"
    echo -e "\n${RED} 请选择要创建的 Swap 大小： ${NC}"
    echo -e "${GREEN} A) 2GB${NC} "
    echo -e "${GREEN} B) 1GB${NC} - 默认推荐配置 "
    echo -e "${GREEN} C) 512MB${NC} "
    echo -e "${GREEN} D) 256MB${NC} "
    echo -e "${GREEN} E) 128MB${NC} "
    echo -e "${GREEN} F) 32MB${NC} - 为了创建而创建 "
    echo -e "${GREEN} G)${NC} 跳过 "
    echo -ne "\n${RED} ===> 请输入选项 [A-G]: ${NC}"
    read -r SWAP_CHOICE < /dev/tty
    sleep 1s

    case "$SWAP_CHOICE" in
        [aA])
            SWAP_SIZE=2G
            ;;
        [bB])
            SWAP_SIZE=1G
            ;;
        [cC])
            SWAP_SIZE=512M
            ;;
        [dD])
            SWAP_SIZE=256M
            ;;
        [eE])
            SWAP_SIZE=128M
            ;;
        [fF])
            SWAP_SIZE=32M
            ;;
        *)
            echo -e "\n${GREEN} 已跳过 Swap 配置 ${NC}"
            SWAP_SIZE=""
            ;;
    esac

    if [ -n "$SWAP_SIZE" ]; then
        echo -e "\n${GREEN} ===> 正在创建 ${SWAP_SIZE} Swap... ${NC}"
        fallocate -l $SWAP_SIZE /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=$(echo $SWAP_SIZE | sed 's/G/*1024/;s/M//' | bc)
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        echo -e "\n${GREEN} Swap 创建完成. ${NC}"
        echo -e "${GREEN} ===> Done. ${NC}"
        sleep 2s
    fi
fi
clear

# ===> 5. 配置 apt 源与基础软件
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置主机名称... OK √ "
echo -e " [2/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... OK √ "
echo -e " [3/$TOTAL_STEPS] 配置 TCP BBR... OK √ "
echo -e " [4/$TOTAL_STEPS] 检查并配置 Swap... OK √ "
echo -e " ===> [5/$TOTAL_STEPS] 正在更新 apt 源... "
sleep 1s

# ===> 获取 apt 资源文件位置
# Ubuntu 24.04+ 和 Debian 13+ 使用 deb822 格式
# 旧版 Ubuntu/Debian 使用 /etc/apt/sources.list
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    APT_SOURCE_FILE="/etc/apt/sources.list.d/ubuntu.sources"
elif [ -f /etc/apt/sources.list.d/debian.sources ]; then
    APT_SOURCE_FILE="/etc/apt/sources.list.d/debian.sources"
else
    APT_SOURCE_FILE="/etc/apt/sources.list"
fi

# 预定义修复 apt 包管理器的逻辑
function check_and_fix_apt() {
echo -e "\n${GREEN} 正在检查 apt 包管理器状态... ${NC}"
apt --fix-broken install -y || true
sleep 1s
}

# ===> 预定义获取服务器地区的逻辑
function check_network_region() {
    # 返回: "GLOBAL" 或 "CNMainLand" 或 "UNKNOWN"
    if command -v curl &> /dev/null; then
        if curl -s --connect-timeout 3 https://www.google.com > /dev/null; then
            echo "GLOBAL"
        else
            echo "CNMainLand"
        fi
    elif command -v wget &> /dev/null; then
        if wget -q --spider --timeout=3 https://www.google.com; then
            echo "GLOBAL"
        else
            echo "CNMainLand"
        fi
    else
        echo "UNKNOWN"
    fi
}

# ===> 预定义修改 apt 资源文件的逻辑
function change_apt_source() {
    local REGION=$1

    # 备份原文件
    if [ ! -f "${APT_SOURCE_FILE}.bak" ]; then
        cp "$APT_SOURCE_FILE" "${APT_SOURCE_FILE}.bak"
    fi
    
    # ===> 对于国内服务器，切换至 NJU 源
    if [ "$SERVER_LOCATION" = "CNMainLand" ]; then
        echo -e "\n${GREEN} 正在切换至南京大学 NJU 镜像源... ${NC}"

        if grep -q "Ubuntu" /etc/issue; then
            # Ubuntu 逻辑：替换 archive.ubuntu.com, security.ubuntu.com 等主流域名
            # deb822 格式虽然结构变了，但 URL 依然存在，sed 替换依然有效
            sed -i 's@http://.*archive.ubuntu.com@http://mirrors.nju.edu.cn@g' "$APT_SOURCE_FILE"
            sed -i 's@http://.*security.ubuntu.com@http://mirrors.nju.edu.cn@g' "$APT_SOURCE_FILE"
            sed -i 's@http://ports.ubuntu.com@http://mirrors.nju.edu.cn@g' "$APT_SOURCE_FILE"
        elif grep -q "Debian" /etc/issue; then
            # Debian 逻辑：替换 deb.debian.org, security.debian.org
            sed -i 's@http://deb.debian.org@http://mirrors.nju.edu.cn@g' "$APT_SOURCE_FILE"
            sed -i 's@http://security.debian.org@http://mirrors.nju.edu.cn@g' "$APT_SOURCE_FILE"
        fi
    else
        # ===> 恢复/保持 默认源 (GLOBAL)
        # 如果当前文件已经被改过，即含有 nju.edu.cn，则恢复备份
        if grep -q "nju.edu.cn" "$APT_SOURCE_FILE"; then
            echo -e "${GREEN} 正在重新恢复至官方源... ${NC}"
            cp "${APT_SOURCE_FILE}.bak" "$APT_SOURCE_FILE"
        fi
    fi
}

# ===> 逻辑开始
check_and_fix_apt

# ===> 第一次确定地区
SERVER_LOCATION=$(check_network_region)

if [ "$SERVER_LOCATION" = "UNKNOWN" ]; then
    # 1. 强制切到 NJU HTTP 源
    change_apt_source "CNMainLand"
    apt update -y
    # 2. 更新并安装必备检测工具
    apt install -y curl wget
    # 3. 第二次确定地区，现在可以正常使用 wget 或者 curl 工具
    SERVER_LOCATION=$(check_network_region)
    # 4. 根据真实结果修正源
    if [ "$SERVER_LOCATION" = "GLOBAL" ]; then
        # 如果发现是海外机器，恢复默认源
        change_apt_source "GLOBAL"
    fi
else
    # 如果可以直接根据检测结果进行配置
    if [ "$SERVER_LOCATION" = "CNMainLand" ]; then
        # 国内服务器切换至 NJU 源
        change_apt_source "CNMainLand"
        # 海外服务器则无需换源
    fi
fi
echo -e "\n${GREEN} ===> Partly Done. (1/6) ${NC}"
sleep 1s
clear

# ===> 换源逻辑完成，开始切换至 HTTPS
echo -e "\n${GREEN} apt 源将切换至 https 模式 (2/6) ${NC}"

apt install -y apt-transport-https ca-certificates

# ===> 执行替换
if [ -n "$APT_SOURCE_FILE" ]; then
    # 替换 http:// 为 https://
    sed -i 's@http://@https://@g' "$APT_SOURCE_FILE"
    # 如果源链接原本是 http: 即不带 // 的罕见情况，进行一次保险
    sed -i 's@http:@https:@g' "$APT_SOURCE_FILE"
else
    echo -e "${GREEN} 未找到标准的 apt 源文件，跳过 https 切换 ${NC}"
fi
echo -e "\n${GREEN} ===> Partly Done. (2/6) ${NC}"
sleep 1s
clear

echo -e "\n${GREEN} 正在更新软件包列表... (3/6) ${NC}"
apt update

# 直接卸载 needrestart，避免干扰运行
if dpkg -l | grep -q needrestart; then
    apt purge -y needrestart
fi

echo -e "\n${GREEN} ===> Partly Done. (3/6) ${NC}"
sleep 1s
clear

echo -e "\n${GREEN} 正在移除 Ubuntu Snap... (4/6) ${NC}"
if grep -q "Ubuntu" /etc/issue; then
    if command -v snap &> /dev/null; then
        echo -e "\n${GREEN} 检测到 Snap，正在移除... ${NC}"
        systemctl stop snapd.service || true
        systemctl stop snapd.socket || true
        apt purge snapd -y
        rm -rf /root/snap /snap /var/snap /var/lib/snapd
        apt-mark hold snap
        echo -e "\n${GREEN} ===> Partly Done. (4/6) ${NC}"
    else
        echo -e "\n${GREEN} Snap 未安装，跳过当前步骤 ${NC}"
    fi
else
    echo -e "${GREEN} ===> 非 Ubuntu 系统，跳过当前步骤 ${NC}"
fi
sleep 1s
clear

echo -e "\n${GREEN} 正在安装基础软件... (5/6) ${NC}"
PACKAGES="sudo vim nano ufw bash curl wget htop qemu-guest-agent locales systemd-timesyncd unattended-upgrades"
echo -e "\n${GREEN} ===> 即将安装：$PACKAGES ${NC}"

apt install -y $PACKAGES

# 配置语言环境：尝试生成 en_US.UTF-8
if command -v locale-gen &> /dev/null; then
    locale-gen en_US.UTF-8
    update-locale LANG=en_US.UTF-8
else
    # 对于部分没有 locale-gen 命令的极简系统，尝试重新配置
    dpkg-reconfigure -f noninteractive locales || true
fi
sleep 1s

# 有必要则使用 systemd-timesyncd 再次同步时间
if [ "$TIME_SYNC_AGAIN" = "yes" ]; then
    systemctl enable --now systemd-timesyncd
    sleep 1s
    timedatectl set-ntp on
    sleep 1s
    timedatectl set-local-rtc 0 || true
    timedatectl
    echo -e "\n 当前时间: $(date) "
fi

echo -e "\n${GREEN} ===> Partly Done. (5/6) ${NC}"
sleep 1s
clear

echo -e "\n${GREEN} ===> 正在更新系统及软件... (6/6) ${NC}"
apt upgrade -y
echo -e "\n${GREEN} 系统更新完毕 ${NC}"
echo -e "${GREEN} ===> Done. ${NC}"
sleep 2s
clear

# ===> 6. 配置 ufw 防火墙
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置主机名称... OK √ "
echo -e " [2/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... OK √ "
echo -e " [3/$TOTAL_STEPS] 配置 TCP BBR... OK √ "
echo -e " [4/$TOTAL_STEPS] 检查并配置 Swap... OK √ "
echo -e " [5/$TOTAL_STEPS] 配置 apt 源与基础软件... OK √ "
echo -e " ===> [6/$TOTAL_STEPS] 配置 ufw 防火墙... ${NC}"

# 设置默认策略：拒绝入站，允许出站
ufw default deny incoming
ufw default allow outgoing

# 放行 SSH 端口
ufw allow OpenSSH || ufw allow ssh || ufw allow 22/tcp
# 一些情况下写数字更明确，但是为了避免更换端口导致无法放行，这里改为 ssh

# 放行常用 Web 端口
ufw allow 80/tcp
ufw allow 443/tcp

# 启用防火墙
ufw --force enable

# 显示状态
ufw status verbose
echo -e "\n${GREEN} ufw 已配置并启动 ${NC}"
echo -e "${GREEN} ===> Done. ${NC}"
sleep 2s
clear

# ===> 7. 选择安全组件
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置主机名称... OK √ "
echo -e " [2/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... OK √ "
echo -e " [3/$TOTAL_STEPS] 配置 TCP BBR... OK √ "
echo -e " [4/$TOTAL_STEPS] 检查并配置 Swap... OK √ "
echo -e " [5/$TOTAL_STEPS] 配置 apt 源与基础软件... OK √ "
echo -e " [6/$TOTAL_STEPS] 配置 ufw 防火墙... OK √ "
echo -e " ===> [7/$TOTAL_STEPS] 配置安全组件... ${NC}"
sleep 1s
echo -e "\n${RED} 选择要安装的安全防护工具： \n${NC}"
echo -e "${GREEN} 1) ${NC} Fail2ban (${GREEN} 默认 ${NC}- 功能强大但负载占用稍高) "
echo -e "${GREEN} 2) ${NC} SSHGuard (更加轻量，资源占用更低) "
echo -ne "\n${RED} 请输入选项 [1/2] : ${NC}"
read -r SECURITY_CHOICE < /dev/tty

check_and_fix_apt
if [[ "$SECURITY_CHOICE" == "2" ]]; then
    echo -e "\n${GREEN} ===> 已选择: SSHGuard ${NC}"
    INSTALLED_SECURITY_TOOL="SSHGuard"

    if ! command -v sshguard &> /dev/null; then
        apt install -y sshguard
    fi

    # SSHGuard 默认配置较少，主要靠白名单防止误封
    mkdir -p /etc/sshguard
    WHITELIST_FILE="/etc/sshguard/whitelist"
    
    # 如果文件不存在则创建它
    if [ ! -f "$WHITELIST_FILE" ]; then
        touch "$WHITELIST_FILE"
    fi
    
    # 追加写入白名单，防止覆盖
    if ! grep -q "127.0.0.1" "$WHITELIST_FILE"; then
        echo "127.0.0.1" >> "$WHITELIST_FILE"
        echo "::1" >> "$WHITELIST_FILE"
    fi

    systemctl restart sshguard
    systemctl enable sshguard
    echo -e "\n${GREEN} ===> SSHGuard 已启动 ${NC}"

else
    echo -e "\n${GREEN} ===> 已选择: Fail2ban (默认方案) ${NC}"
    INSTALLED_SECURITY_TOOL="Fail2ban"

    if ! command -v fail2ban-client &> /dev/null; then
        apt install -y fail2ban
    fi

    # 配置 jail.local ，覆盖默认配置
    cat > /etc/fail2ban/jail.local << EOF
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
    # Debian/Ubuntu 现代版通常不需要指定 logpath，会自动监测 systemd journal
    # 但显式指定 backend 为 systemd 更稳妥
    systemctl restart fail2ban
    systemctl enable fail2ban
    echo -e "\n${GREEN} Fail2ban 已启动 "
    echo -e "${GREEN} 防护策略: 1 小时错误 5 次 → 封禁 24 小时；惯犯封禁 4 周 ${NC}"
fi
echo -e "\n${GREEN} ===> Done. ${NC}"
sleep 2s
clear

# ===> 8. 系统内核更新
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置主机名称... OK √ "
echo -e " [2/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... OK √ "
echo -e " [3/$TOTAL_STEPS] 配置 TCP BBR... OK √ "
echo -e " [4/$TOTAL_STEPS] 检查并配置 Swap... OK √ "
echo -e " [5/$TOTAL_STEPS] 配置 apt 源与基础软件... OK √ "
echo -e " [6/$TOTAL_STEPS] 配置 ufw 防火墙... OK √ "
echo -e " [7/$TOTAL_STEPS] 配置安全组件... OK √ "
echo -e " ===> [8/$TOTAL_STEPS] 检查内核更新... ${NC}"
sleep 1s

KERNEL_VERSION=$(uname -r)
echo -e "\n${GREEN} 当前内核: $KERNEL_VERSION ${NC}" 

# 判断是否为云厂商专用内核 (Azure, GCP, AWS, Oracle)
if [[ "$KERNEL_VERSION" == *"azure"* ]] || \
   [[ "$KERNEL_VERSION" == *"gcp"* ]] || \
   [[ "$KERNEL_VERSION" == *"aws"* ]] || \
   [[ "$KERNEL_VERSION" == *"uek"* ]] || \
   [[ "$KERNEL_VERSION" == *"oracle"* ]]; then
    echo -e "\n${GREEN} 检测到专用内核 ${NC}"
else
    # 仅在 Ubuntu 下尝试安装 HWE
    if grep -q "Ubuntu" /etc/issue; then
        echo -ne "\n${GREEN} 是否需要安装 Ubuntu HWE 硬件增强堆栈内核? [y/N]: ${NC}"
        read -r INSTALL_HWE_KERNEL < /dev/tty
        if [[ "$INSTALL_HWE_KERNEL" =~ ^[Yy]$ ]]; then
            echo -e "\n${GREEN} 正在准备 HWE 内核更新... ${NC}"
            check_and_fix_apt
            apt install -y --no-install-recommends linux-generic-hwe-$(lsb_release -rs) || apt install linux-modules-extra-$(uname -r)
        else
            apt install linux-modules-extra-$(uname -r) || true
        fi
    fi
    update-grub
    echo -e "\n${GREEN} ===> Done. ${NC}"
fi
sleep 2s
clear

# ===> 9. 磁盘空间优化
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置主机名称... OK √ "
echo -e " [2/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... OK √ "
echo -e " [3/$TOTAL_STEPS] 配置 TCP BBR... OK √ "
echo -e " [4/$TOTAL_STEPS] 检查并配置 Swap... OK √ "
echo -e " [5/$TOTAL_STEPS] 配置 apt 源与基础软件... OK √ "
echo -e " [6/$TOTAL_STEPS] 配置 ufw 防火墙... OK √ "
echo -e " [7/$TOTAL_STEPS] 配置安全组件... OK √ "
echo -e " [8/$TOTAL_STEPS] 检查内核更新... OK √ "
echo -e " ===> [9/$TOTAL_STEPS] 磁盘空间优化... ${NC}"
# 只有 ext4 文件系统支持 tune2fs，执行前需要判断。
ROOT_FS=$(df -T / | awk 'NR==2 {print $2}')
if [ "$ROOT_FS" == "ext4" ]; then
    ROOT_DEV=$(findmnt / -o SOURCE -n)
    # 留 1%
    tune2fs -m 1 "$ROOT_DEV" 
    echo -e "\n${GREEN} 已将 $ROOT_DEV 的保留空间调整为 1% ${NC}"
    echo -e "${GREEN} ===> Done. ${NC}"
    sleep 2s
else
    echo -e "\n${GREEN} 根文件系统为 $ROOT_FS，跳过优化 ${NC}"
    sleep 1s
fi
clear

# ===> 10. 安装增强性组件
echo -e "${GREEN} [1/$TOTAL_STEPS] 设置主机名称... OK √ "
echo -e " [2/$TOTAL_STEPS] 设置时区为 Asia/Shanghai... OK √ "
echo -e " [3/$TOTAL_STEPS] 配置 TCP BBR... OK √ "
echo -e " [4/$TOTAL_STEPS] 检查并配置 Swap... OK √ "
echo -e " [5/$TOTAL_STEPS] 配置 apt 源与基础软件... OK √ "
echo -e " [6/$TOTAL_STEPS] 配置 ufw 防火墙... OK √ "
echo -e " [7/$TOTAL_STEPS] 配置安全组件... OK √ "
echo -e " [8/$TOTAL_STEPS] 检查内核更新... OK √ "
echo -e " [9/$TOTAL_STEPS] 磁盘空间优化... OK √ "
echo -e " ===> [10/$TOTAL_STEPS] 安装增强性组件... ${NC}"
echo -e "${GREEN} 服务器面板/ Docker 环境安装 ${NC}"
sleep 1s

# ===> 获取最新面板版本号
PANEL_CURL_RETRY="--retry 5 --retry-delay 5 --retry-all-errors --connect-timeout 15"
# 宝塔面板：正式版
BT_LATEST_VERSION=$(curl -sSL $PANEL_CURL_RETRY "https://www.bt.cn/new/download.html" | grep -oE '正式版[^0-9]*[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u | sort -V | tail -n 1)
# 宝塔面板：稳定版
BT_STABLE_VERSION=$(curl -sSL $PANEL_CURL_RETRY "https://www.bt.cn/new/download.html" | grep -oE '稳定版[^0-9]*[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u | sort -V | tail -n 1)
# aaPanel
AAPANEL_VERSION=$(curl -sSL $PANEL_CURL_RETRY "https://www.aapanel.com/new/download.html" | grep -ioE 'Install aaPanel[^0-9]*[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u | sort -V | tail -n 1)

echo -e "\n${RED} 请选择要安装的面板： \n${NC}"
echo -e "${GREEN} A) 宝塔面板${NC} - 最新正式版 - ${BT_LATEST_VERSION} "
echo -e "${GREEN} B) 宝塔面板${NC} - 稳定版 - ${BT_STABLE_VERSION} "
echo -e "${GREEN} C) aaPanel${NC} - 宝塔国际版 - ${AAPANEL_VERSION} (English Only) "
echo -e "${GREEN} D) 1Panel v2${NC} - 自带 Docker 的容器化面板 "
echo -e "${GREEN} E)${NC} 跳过面板安装 "
echo -ne "\n${RED} 请输入选项 [A-E]: ${NC}"
read -r PANEL_CHOICE < /dev/tty

# ===> 要求用户保存面板登录信息
function wait_for_ok() {
    echo -e "\n${RED} ===> 关键信息确认： ${NC}"
    echo -e "${RED} 请务必保存上方的面板登录信息 ${NC}"
    while true; do
        echo -ne "\n${RED} ===> 输入 'ok' 以继续... (Type 'ok' to continue): ${NC}"
        read -r CONFIRM < /dev/tty
        if [[ "$CONFIRM" == "ok" ]] || [[ "$CONFIRM" == "OK" ]]; then
            echo -e "${GREEN} 确认成功，继续执行... ${NC}"
            break
        else
            echo -e "\n${RED} ===> 输入 'ok' 以继续... (Type 'ok' to continue): ${NC}"
        fi
    done
}

function check_installed_bt_version() {
    if [ -f "/www/server/panel/class/common.py" ]; then
        INSTALLED_BT_VERSION=$(grep -E 'g\.version[[:space:]]*=' /www/server/panel/class/common.py | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    fi
    NEED_ASK_DOCKER_INSTALL=true
}

# ===> 开始面板安装逻辑
check_and_fix_apt
case $PANEL_CHOICE in
    [aA])
        echo -e "\n${GREEN} ===> 安装宝塔最新版... "
        BT_INSTALL_URL=$(curl -sSL $PANEL_CURL_RETRY "https://www.bt.cn/new/download.html" | grep -oE 'https://[^"'\'' <>]+/install[^"'\'' <>]*\.sh' | head -n 1)
        echo -e " 请根据安装脚本提示就行操作... ${NC}"
        wget --tries=5 --timeout=25 -O install_panel.sh $BT_INSTALL_URL
        bash install_panel.sh
        check_installed_bt_version
        INSTALLED_PANEL=" 宝塔面板 v${INSTALLED_BT_VERSION} "
        ;;
    [bB])
        echo -e "\n${GREEN} ===> 安装宝塔稳定版... "
        BT_INSTALL_URL=$(curl -sSL $PANEL_CURL_RETRY "https://www.bt.cn/new/download.html" | grep -oE 'https://[^"'\'' <>]+/installStable[^"'\'' <>]*\.sh' | head -n 1)
        echo -e " 请根据安装脚本提示进行操作... ${NC}"
        wget --tries=5 --timeout=25 -O install_panel.sh $BT_INSTALL_URL
        bash install_panel.sh
        check_installed_bt_version
        INSTALLED_PANEL=" 宝塔面板稳定版 v${INSTALLED_BT_VERSION} "
        ;;
    [cC])
        echo -e "\n${GREEN} ===> 安装宝塔国际版 aaPanel ... "
        BT_INSTALL_URL=$(curl -sSL $PANEL_CURL_RETRY "https://www.aapanel.com/new/download.html" | grep -oE 'https://[^"'\'' <>]+/script/[^"'\'' <>]*\.sh' | head -n 1)
        echo -e " 请根据安装脚本提示进行操作... ${NC}"
        wget --tries=5 --timeout=25 --no-check-certificate -O install_panel.sh https://www.aapanel.com/script/install_panel_en.sh
        bash install_panel.sh
        check_installed_bt_version
        INSTALLED_PANEL=" aaPanel v${INSTALLED_BT_VERSION} "
        ;;
    [dD])
    # https://1panel.cn/#quickstart
        echo -e "\n${GREEN} ===> 安装 1Panel ... "
        echo -e " 请先根据安装脚本提示进行操作，并直接安装 Docker... ${NC}"
        echo -e " 后续步骤中将不再单独安装 Docker ${NC}"
        wget --tries=5 --timeout=25 -O install_panel.sh https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh
        bash install_panel.sh
        INSTALLED_PANEL=" 1Panel "
        NEED_ASK_DOCKER_INSTALL=false
        ;;
    *)
        echo -e "\n${GREEN} 已跳过面板安装 ${NC}"
        NEED_SAVE_PANEL_INFO=false
        NEED_ASK_DOCKER_INSTALL=true
        ;;
esac

# ===> 宝塔/aaPanel 后续逻辑
if [ "$NEED_SAVE_PANEL_INFO" != false ]; then
    # 确认保存登录信息
    echo -e "\n${GREEN} ===> Partly Done. (1/2) ${NC}"
    wait_for_ok
    sleep 1s
fi

# 用 ufw 强制关掉不安全的端口
ufw delete allow 20/tcp >/dev/null 2>&1 || true
ufw delete allow 21/tcp >/dev/null 2>&1 || true
ufw delete allow 888/tcp >/dev/null 2>&1 || true
ufw delete allow 8888/tcp >/dev/null 2>&1 || true
ufw delete allow 39000:40000/tcp >/dev/null 2>&1 || true
ufw reload
sleep 1s

if [ "$NEED_ASK_DOCKER_INSTALL" = true ]; then
    echo -ne "\n${RED} ===> 是否安装 Docker 环境? [Y/n]： ${NC}"
    read -r DOCKER_CONFIRM < /dev/tty
    sleep 1s

    if [[ "$DOCKER_CONFIRM" =~ ^[Yy]$ ]] || [[ -z "$DOCKER_CONFIRM" ]]; then
        echo -e "\n${GREEN} 正在检查 Docker 安装条件... ${NC}"
        check_and_fix_apt
        if [ -f /etc/os-release ]; then
            . /etc/os-release
        else
            ID=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
            VERSION_ID=$(lsb_release -rs)
        fi

        # 版本号检查
        # Ubuntu 22.04 +
        if [[ "$ID" == "ubuntu" ]]; then
            if [[ "$VERSION_ID" < "22.00" ]]; then
                echo -e "\n 当前系统为 Ubuntu $VERSION_ID，将安装来自 apt 仓库的 Docker 版本 "
                INSTALL_APT_DOCKER=true
            fi
        # Debian 11 +
        elif [[ "$ID" == "debian" ]]; then
            DEB_MAIN=$(echo "$VERSION_ID" | cut -d. -f1)
            if [[ "$DEB_MAIN" -lt 11 ]]; then
                echo -e "\n 当前系统为 Debian $VERSION_ID，将安装来自 apt 仓库的 Docker 版本 "
                INSTALL_APT_DOCKER=true 
            fi
        else
            echo -e "${GREEN} 由于系统信息未知，请自行安装 Docker ${NC}"
            DOCKER_CONFIRM=No
        fi

        if [ "$INSTALL_APT_DOCKER" = true ]; then
            echo -e "\n${GREEN} ===> 正在从 apt 源执行 Docker 安装... ${NC}"
            apt install -y docker docker.io
        else
            echo -e "\n${GREEN} ===> 正在执行 Docker 安装... ${NC}"
            curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors --connect-timeout 20 https://get.docker.com -o get-docker.sh
            case "$SERVER_LOCATION" in
            "GLOBAL")
                bash get-docker.sh
                ;;
            "CNMainLand")
                bash get-docker.sh --mirror Aliyun
                ;;
            *)
                bash get-docker.sh
                ;;
            esac
        fi
        echo -e "\n${GREEN} ===> Done. ${NC}"
    fi
    sleep 2s
else
    echo -e "\n${RED} 已跳过 Docker 安装 ${NC}"
    INSTALLED_DOCKER=" 未安装 "
    sleep 1s
fi

# ===> 读取 Docker 版本信息
if command -v docker &> /dev/null; then
    # 提取 Docker 版本
    D_VER=$(docker --version | awk '{print $3}' | tr -d ',')
    
    # 提取 Compose 版本
    C_VER=$(docker compose version 2>/dev/null | awk '{print $4}')
    
    # 如果没取到 Compose 版本比如旧版，则标记一下
    if [[ -z "$C_VER" ]]; then C_VER="Unknown"; fi
    
    INSTALLED_DOCKER="${GREEN} 运行中 ：Docker $D_VER + Compose $C_VER ${NC}"
fi
clear

# ===> 清理缓存
echo -e "\n${GREEN} ===> 开始清理... ${NC}"
# 清理 apt 缓存
apt update
apt autoremove --purge -y
apt clean
# 清理增强组件缓存
rm -f install_panel.sh|| true
rm -f get-docker.sh || true
# 清理 1Panel 安装残留的目录和压缩包
rm -rf 1panel-v* 1panel-v*.tar.gz || true
# 清理 VPS 初始化的遗留日志
rm -f virt-sysprep-firstboot.log || true

# ===> 采集基本系统信息，为总结做准备
# CPU 型号 (提取第一行 model name)
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | awk -F: '{print $2}' | sed 's/^[ \t]*//')
# 内存使用 (已用/总计)
MEM_USAGE=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
# Swap 使用 (已用/总计)
SWAP_USAGE=$(free -h | awk '/Swap:/ {print $3 "/" $2}')
# 磁盘使用 (根目录 / 的占用)
DISK_USAGE=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')
# 系统信息
if [ -f /etc/os-release ]; then
    . /etc/os-release
    SYSTEM_INFO="$PRETTY_NAME"
else
    SYSTEM_INFO="Unknown Linux"
fi
# 公网 IPv4
PUBLIC_IPV4=$(curl -4 -s --max-time 3 https://api.ip.sb/ip -A Mozilla || echo " 未检测到 IPv4 ")
# 公网 IPv6
PUBLIC_IPV6=$(curl -6 -s --max-time 3 https://api.ip.sb/ip -A Mozilla || echo " 未检测到 IPv6 ")
# 下载后续文件
CURL_DOWNLOAD_RETRY="--retry 5 --retry-delay 5 --retry-all-errors --connect-timeout 20"
WGET_DOWNLOAD_RETRY="--tries=5 --timeout=25"
if [ "$SERVER_LOCATION" = "GLOBAL" ]; then
    DOWNLOAD_DOMAIN=https://raw.githubusercontent.com/yhxpie/server-init
    curl -fLO $CURL_DOWNLOAD_RETRY $DOWNLOAD_DOMAIN/main/init2.sh || wget $WGET_DOWNLOAD_RETRY -O init2.sh $DOWNLOAD_DOMAIN/main/init2.sh
    curl -fLO $CURL_DOWNLOAD_RETRY $DOWNLOAD_DOMAIN/main/init-clean.sh || wget $WGET_DOWNLOAD_RETRY -O init-clean.sh $DOWNLOAD_DOMAIN/main/init-clean.sh
    curl -fLO $CURL_DOWNLOAD_RETRY $DOWNLOAD_DOMAIN/main/SSH_GUIDE.md || wget $WGET_DOWNLOAD_RETRY -O SSH_GUIDE.md $DOWNLOAD_DOMAIN/main/SSH_GUIDE.md
else
    DOWNLOAD_DOMAIN=https://yhxpie-server-init.netlify.app
    curl -fLO $CURL_DOWNLOAD_RETRY $DOWNLOAD_DOMAIN/init2.sh || wget $WGET_DOWNLOAD_RETRY -O init2.sh $DOWNLOAD_DOMAIN/init2.sh
    curl -fLO $CURL_DOWNLOAD_RETRY $DOWNLOAD_DOMAIN/init-clean.sh || wget $WGET_DOWNLOAD_RETRY -O init-clean.sh $DOWNLOAD_DOMAIN/init-clean.sh
    curl -fLO $CURL_DOWNLOAD_RETRY $DOWNLOAD_DOMAIN/SSH_GUIDE.md|| wget $WGET_DOWNLOAD_RETRY -O SSH_GUIDE.md $DOWNLOAD_DOMAIN/SSH_GUIDE.md
fi

echo -e "${GREEN} ===> Done. ${NC}"
sleep 2s
clear

# ===> 完成总结
echo -e "\n${GREEN} ============================================= ${NC}"
echo -e "${GREEN}                系统初始化摘要 ${NC}"
echo -e "${GREEN} ============================================= ${NC}"
echo -e " - 时区设置      : ${GREEN} Asia/Shanghai √ ${NC}"
echo -e " - TCP BBR       : ${GREEN} 已启用 √ ${NC}"
echo -e " - Swap 交换分区 : ${GREEN} 已配置 √ ${NC}"
echo -e " - APT 源与更新  : ${GREEN} 完成 √ ${NC}"
echo -e " - ufw 防火墙    : ${GREEN} 就绪 √ ${NC}"
echo -e " - 安全防护组件  : ${GREEN} 已安装 $INSTALLED_SECURITY_TOOL √ ${NC}"
echo -e " - 内核检查      : ${GREEN} 完成 √ ${NC}"
echo -e " - 磁盘空间优化  : ${GREEN} 完成 √ ${NC}"
# 增强组件相关信息
echo -e "${GREEN} 增强组件信息： ${NC}"
echo -e " - 面板环境      : ${GREEN} $INSTALLED_PANEL ${NC}"
echo -e " - Docker 环境   : ${GREEN} $INSTALLED_DOCKER ${NC}"
sleep 1s

echo -e "\n${GREEN} ============================================= ${NC}"
echo -e "${GREEN}               系统状态信息检查 ${NC}"
echo -e "${GREEN} ============================================= ${NC}"
echo -e "${GREEN} CPU 信息 ${NC}     : ${CPU_MODEL} "
echo -e "${GREEN} 内存占用 ${NC}     : ${MEM_USAGE} "
echo -e "${GREEN} Swap 占用 ${NC}    : ${SWAP_USAGE} "
echo -e "${GREEN} 磁盘空间占用 ${NC} : ${DISK_USAGE} "
echo -e "${GREEN} 系统信息 ${NC}     : ${SYSTEM_INFO} "
echo -e "${GREEN} 公网 IP 信息 ${NC} : ${PUBLIC_IPV4} + ${PUBLIC_IPV6} "
sleep 2s

echo -e "\n${GREEN} 系统初始化 Stage 2 中，需要创建一个非 root 用户并强制启用 SSH 密钥登录 ${NC}"
echo -e " 有关如何创建 SSH 密钥的信息：${NC} "
cat SSH_GUIDE.md

# 添加控制台提示信息
cat >> /root/.bashrc << 'EOF'
# [server-init] Stage 2 Reminder
if [ -f /root/init2.sh ]; then
    echo -e "\033[0;31m========================================================\033[0m"
    echo -e "\033[1;33m 系统初始化 Stage 2 尚未执行 \033[0m"
    echo -e "\033[1;32m 请在 root 下输入: 'sudo bash init2.sh' \033[0m"
    echo -e "\033[1;32m 以继续进行 SSH 密钥登陆配置与最终环境清理\033[0m"
    echo
    echo -e "\033[1;32m 有关如何创建 SSH 密钥的信息 \033[0m"
    echo -e "\033[1;32m 请输入 'cat SSH_GUIDE.md' \033[0m"
    echo
    echo -e "\033[1;32m 如果无需进行后续操作 \033[0m"
    echo -e "\033[1;32m 请在 root 下输入: 'sudo bash init-clean.sh' 提前结束 \033[0m"
    echo -e "\033[0;31m========================================================\033[0m"
fi
EOF

# 自行清理
if [ -f "$0" ]; then
    rm -f "$0"
    echo -e "\n init.sh 脚本清理已完成 "
fi
sleep 1s
echo -e "\n${RED} 即将重启系统 "
echo -e "\n  ____________________________ "
echo -e " | GitHub: yhxpie/server-init | \n"
sleep 1s

reboot

# Done.

# GitHub: @yhxpie
# https://github.com/yhxpie/server-init
# Version 1.2.2
# Last Update: 2026-8-22
