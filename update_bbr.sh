#!/bin/bash
set -e

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