#!/bin/bash

# init2.sh

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

# 从 tty 读取输入是为了兼容 curl | bash 的运行方式

# ===> 基础设置与检查
# 遇到错误立即停止
set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' 

# ===> 逻辑开始
echo -e "\n${RED} ===> 继续执行初始化... <=== ${NC}"

# ===> 检查是否以 root 运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED} 请使用 root 权限运行此脚本：sudo $0${NC}"
   exit 1
fi

# ===> 检查服务器地区信息
if curl -s --connect-timeout 3 https://www.google.com > /dev/null; then
    SERVER_LOCATION=GLOBAL
else
    SERVER_LOCATION=CNMainLand
fi

# ===> 输出基本内容
echo -e "\n${RED} ===> init2.sh 执行内容：${NC}"
echo -e "\n${GREEN} 1. 配置服务器 SSH 密钥登录 "
echo -e " 2. 清理旧版本系统内核 "
echo -e " 3. 执行最终清理 ${NC}"
echo -e "\n ${RED} 执行时建议时刻保持状态监控 ${NC}"
echo -e "\n 等待 3 秒... "
sleep 3s
clear

# ===> 定义全局步骤数量
TOTAL_STEPS=3

# ===> 1. 配置服务器 SSH 密钥登录
echo -e "${GREEN} ===> [1/$TOTAL_STEPS] 开始配置 SSH 密钥登录... ${NC}"
sleep 1s

# ===> 1-1. 获取公钥
while true; do
    echo -e "\n${GREEN} ===> 请粘贴您的 SSH 公钥 (ssh-rsa / ssh-ed25519 AAAA...):  ${NC}"
    read -r PUB_KEY < /dev/tty
    sleep 1s

    # 非空验证
    if [[ -z "$PUB_KEY" ]]; then
        echo -e "\n${RED} 错误: 公钥不能为空，请重新输入 ${NC}"
        continue
    fi

    # 格式验证
    if [[ "$PUB_KEY" != ssh-* ]]; then
        echo -e "\n${RED} 输入的内容似乎非标准 SSH 公钥 ${NC}"
        echo -en "\n${GREEN} 是否继续? [y/N]: ${NC}"
        read -r CONFIRM < /dev/tty

        if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
            echo -e "\n${RED} 请重新输入 SSH 公钥： ${NC}"
            continue
        fi
    fi

    break
done

echo -e "\n${GREEN} 已获取公钥，准备配置... ${NC}"
sleep 1s

# ===> 1-2. SSH：清理 SSH Drop-in 干扰
# 这一步是为了防止 /etc/ssh/sshd_config.d/ 下的配置覆盖默认 SSH 配置
# OpenSSH 的配置文件 (/etc/ssh/sshd_config) 开头部分通常有一行：
# 'Include /etc/ssh/sshd_config.d/*.conf'
# 根据 OpenSSH 的 “First Match Wins” 原则
# 系统会先读取 sshd_config.d/50-cloud-init.conf 配置项
# 其中可能写着：'PasswordAuthentication yes'
# 那么这时候系统就会直接执行这一政策
# 随机忽略在主配置文件文件下面写的 'PasswordAuthentication no'
# 要在自动化脚本里彻底解决这个问题，最暴力且有效的方法是：
# 直接清空该目录下的干扰文件，或者直接注释掉 Include 指令
if [ -d "/etc/ssh/sshd_config.d" ]; then
    # 创建备份以防万一
    cp -r /etc/ssh/sshd_config.d /etc/ssh/sshd_config.d.bak
    # 删除目录下的所有 .conf 文件
    rm -f /etc/ssh/sshd_config.d/*.conf
fi

# ===> 1-3. 变量定义
# 填入需要创建的用户名
while true; do
    echo -e "\n${RED} 用户名仅允许只允许字母、数字、下划线、短横线，且以字母开头 ${NC}"
    echo -ne "\n${GREEN} ===> 请输入需要创建的用户名： ${NC}"
    read -r USERNAME < /dev/tty
    sleep 1s

# 简单合法性检查 
# 只允许字母、数字、下划线、短横线，且以字母开头
    if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo -ne "${RED} 错误: 用户名不合法 (只能包含小写字母、数字、_ -，且以字母开头) ${NC}"
        continue
    fi
    break
done
# ===> 1-4. 创建用户
if id "$USERNAME" &>/dev/null; then
    echo -e "\n${GREEN} 用户 $USERNAME 已存在，跳过创建 ${NC}"
else
    echo -e "\n${GREEN} 正在创建用户 $USERNAME ... ${NC}"
    useradd -m -s /bin/bash "$USERNAME"
fi
sleep 1s

# ===> 1-5. 配置 SSH 密钥
USER_HOME="/home/$USERNAME"
mkdir -p "$USER_HOME/.ssh"

# 写入获取到的公钥
echo "$PUB_KEY" > "$USER_HOME/.ssh/authorized_keys"

# 为了避免发生错误如重复添加，这里只添加一个密钥。
# 如果需要追加密钥，请手动执行。
chmod 700 "$USER_HOME/.ssh"
chmod 600 "$USER_HOME/.ssh/authorized_keys"
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.ssh"

echo -e "\n${GREEN} SSH 公钥已配置 "
echo -e " 如果需要为同一用户添加多个密钥，请手动在当前用户环境下手动执行 ${NC}"

# ===> 1-6. 配置 Sudo
# 写入 sudoers.d 避免修改 visudo
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME"
chmod 440 "/etc/sudoers.d/$USERNAME"
echo -e "\n${GREEN} Sudo 权限已配置 ${NC}"

# ===> 1-7. 加固 ssh/sshd 主配置
SSHD_CONFIG="/etc/ssh/sshd_config"

# 再次确保 Include 指令不会引入麻烦
# 之前已经删除了文件，为了双重保险，也可以把 Include 注释掉
# 如果需要删除配置文件中的 Include 行，请取消注释下一行
# sed -i 's/^Include/#Include/' $SSHD_CONFIG 

echo -e "${GREEN} 配置 SSH 服务... ${NC}"
cp $SSHD_CONFIG "$SSHD_CONFIG.bak.$(date +%F)"

# 使用 sed 强行替换或追加配置
# 逻辑：查找配置项，如果找到就替换，找不到就在文件末尾追加
function ensure_config() {
    local key=$1
    local value=$2
    if grep -q "^#\?${key}" "$SSHD_CONFIG"; then
        sed -i "s/^#\?${key}.*/${key} ${value}/" "$SSHD_CONFIG"
    else
        echo "${key} ${value}" >> "$SSHD_CONFIG"
    fi
}

ensure_config "PermitRootLogin" "prohibit-password"
ensure_config "PasswordAuthentication" "no"
ensure_config "PubkeyAuthentication" "yes"
ensure_config "KbdInteractiveAuthentication" "no"
ensure_config "ChallengeResponseAuthentication" "no"

# 给 Root 也配上一份密钥，作为 SSH 备用通道
echo -e "${GREEN} 正在同步公钥给 Root 用户... ${NC}"
mkdir -p /root/.ssh
echo "$PUB_KEY" > /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

# 在重启 SSH 前，强制设置用户密码
# 这是为了 sudo 验证，以及 VNC 救急
echo -e "\n${GREEN} ===> 请为用户 $USERNAME 设置密码: ${NC}"
# 使用 until 循环：只要 passwd 命令失败，循环就会继续
until passwd "$USERNAME"; do
    echo -e "\n${RED} 请重试... ${NC}"
    sleep 1s
    echo -e "${GREEN} ===> 请重新为 $USERNAME 设置密码: ${NC}"
done

# ===> 1-8. 收尾
sshd -t # 检查语法
systemctl restart ssh || systemctl restart sshd
sleep 1s

echo -e "\n${GREEN} ===> 用户配置完成 ${NC}"
echo -e " 用户: ${GREEN} $USERNAME ${NC}"
echo -e " 公钥: ${GREEN} $PUB_KEY ${NC}"
echo -e "\n${RED} 请新建一个终端用于测试登录： ${NC}"
echo -e "${RED} 1. 能否使用密钥登录对应用户? ${NC}"
echo -e "    - 正常情况：可正常以 $USERNAME 身份登录而不是被拒绝 (publickey) "
echo -e "${RED} 2. 登录后使用 'sudo -i' 时是否还需要输入密码? ${NC}"
echo -e "    - 正常情况：可以直接切换至 root 身份 "
sleep 1s
echo -ne "\n${RED} ===> 如果测试结果没有问题，请输入 'ok': ${NC}"
# 只有在输入 ok 后才继续执行
while true; do
    read -r SSH_TEST_RESULT < /dev/tty
    if [[ "$SSH_TEST_RESULT" == "ok" ]] || [[ "$SSH_TEST_RESULT" == "OK" ]]; then
        echo -e "\n${GREEN} 确认成功 ${NC}"
        break
    else
        echo -ne "${RED} ===> 请输入 'ok' 以确认： ${NC}"
        continue
    fi
done

echo -e "\n${GREEN} ===> Done. ${NC}"
sleep 2s
clear

# ===> 2. 清理旧版本系统旧内核
echo -e "${GREEN} [1/$TOTAL_STEPS] 配置 SSH 密钥登录... DONE √ "
echo -e " ===> [2/$TOTAL_STEPS] 正在清理旧内核与无用依赖 ... ${NC}"

apt --fix-broken install -y || true
sleep 1s

echo -e "\n${GREEN} 正在确认当前内核... ${NC}"
CURRENT_KERNEL=$(uname -r)
echo -e "${GREEN} 当前运行内核${NC}: $CURRENT_KERNEL "
sleep 1s

# 构造当前运行内核的完整包名
CURRENT_KERNEL_PKG="linux-image-$(uname -r)"

# 找出旧内核镜像
# 这里使用了 dpkg-query 避免 truncate 截断问题)
# dpkg-query -W -f='${db:Status-Status} ${Package}\n': 仅输出"安装状态"和"包名"
# grep '^installed': 确保只筛选当前已安装的包
# awk '{print $2}': 提取包名
# grep -E "^linux-image-[0-9]": 筛选以数字开头的镜像包以自动排除 linux-image-generic 元包
# grep -v "$CURRENT_KERNEL_PKG": 精准排除当前正在运行的内核包
OLD_IMAGES=$(dpkg-query -W -f='${db:Status-Status} ${Package}\n' | grep '^installed' | awk '{print $2}' | grep -E "^linux-image-[0-9]" | grep -v "$CURRENT_KERNEL_PKG" || true)

if [ -n "$OLD_IMAGES" ]; then
    echo -e "\n${GREEN} 正在清理旧版本 Linux 内核： ${NC}"
    echo -e "${RED} $OLD_IMAGES ${NC}\n"
    
    # 清除旧内核
    echo "$OLD_IMAGES" | xargs -r apt purge -y
    echo -e "\n${GREEN} Partly Done. (1/3) ${NC}"
    
    echo -e "\n${GREEN} 正在清理残留依赖... ${NC}"
    # 这一步会解决 rmdir not empty 的问题
    apt autoremove -y --purge
    echo -e "\n${GREEN} Partly Done. (2/3) ${NC}"
    sleep 1s
    update-grub

    echo -e "\n${GREEN} ===> 内核清理完成 ${NC}"
    echo -e "${GREEN} Done. (3/3) ${NC}"
    sleep 2s
else
    echo -e "\n${GREEN} 未发现旧内核镜像 ${NC}"
    sleep 1s
fi
clear

# ===> 3. 最终清理
echo -e "${GREEN} [1/$TOTAL_STEPS] 配置 SSH 密钥登录... DONE √ "
echo -e " [2/$TOTAL_STEPS] 清理旧内核与无用依赖 ... DONE √ "
echo -e " ===> [3/$TOTAL_STEPS] 正在执行最终清理 ... ${NC}"

# 使用 sed 移除 .bashrc 里提示标记
sed -i '/# \[Server-init\] Stage 2 Reminder/,/fi/d' /root/.bashrc

# 删除多余脚本
rm init-clean.sh SSH_GUIDE.md init.sh || true

# apt 清理
apt update
apt autoremove --purge -y
apt clean
echo -e "\n${GREEN} ===> Done. ${NC}"
sleep 2s
clear

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
# 内核版本
KERNEL_VER=$(uname -r)
# 公网 IPv4
PUBLIC_IPV4=$(curl -4 -s --max-time 3 https://api.ip.sb/ip -A Mozilla || echo " 没有公网 IPv4 ")
# 公网 IPv6
PUBLIC_IPV6=$(curl -6 -s --max-time 3 https://api.ip.sb/ip -A Mozilla || echo " 没有公网 IPv6 ")
sleep 1s

# ===> 完成总结
echo -e "\n${GREEN} ============================================= ${NC}"
echo -e "${GREEN}               系统状态信息检查 ${NC}"
echo -e "${GREEN} ============================================= ${NC}"
sleep 1s
echo -e "${GREEN} CPU 信息 ${NC}     : ${CPU_MODEL} "
echo -e "${GREEN} 内存占用 ${NC}     : ${MEM_USAGE} "
echo -e "${GREEN} Swap 占用 ${NC}    : ${SWAP_USAGE} "
echo -e "${GREEN} 磁盘空间占用 ${NC} : ${DISK_USAGE} "
echo -e "${GREEN} 系统信息 ${NC}     : ${SYSTEM_INFO} "
echo -e "${GREEN} 内核版本 ${NC}     : ${KERNEL_VER} "
echo -e "${GREEN} 公网 IP 信息 ${NC} : ${PUBLIC_IPV4} + ${PUBLIC_IPV6} "
echo -e "\n${GREEN} 用户登录配置信息   ：${NC}"
echo -e " - 用户: ${GREEN} $USERNAME ${NC}"
echo -e " - 公钥: ${GREEN} $PUB_KEY ${NC}"
sleep 1s
echo -e "\n${GREEN} 系统初始化全部完成 ${NC}"
sleep 2s

# 自行清理
if [ -f "$0" ]; then
    rm -f "$0"
    echo " init2.sh 脚本清理已完成 "
fi
sleep 1s
echo -e "\n  ____________________________ "
echo -e " | GitHub: yhxpie/server-init | \n"

# Done.

# GitHub: @yhxpie
# https://github.com/yhxpie/server-init
# Version 1.2.1
# Last Update: 2026-8-22
