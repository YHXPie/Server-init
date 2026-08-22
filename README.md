# server-init for Debian / Ubuntu

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Bash](https://img.shields.io/badge/Language-Bash-blue.svg)]()
[![OS](https://img.shields.io/badge/OS-Debian%20%7C%20Ubuntu-orange)]()

一个适用于 Debian / Ubuntu 服务器的自动化初始化脚本套件，
包含系统基础配置、安全加固、内核升级、面板安装以及 Docker 环境部署等功能。

最低系统要求：
**Debian 11** & **Ubuntu 22.04 LTS**

> [!CAUTION]
> 项目名称为 `server-init` ，即只主动适配服务器系统，一些功能；理论上支持桌面端系统，但仍然不建议桌面端系统使用
>
> 例如脚本会清除 Snap，这会导致桌面端的 Ubuntu Software 出现问题
---

## 如何使用

> [!CAUTION]
> 仅建议在全新安装完成的系统环境下使用

### 第一步：`init.sh` 基础配置

非常建议提前安装 `curl`，一些 Debian 镜像中可能默认不含有此包。

如果没有，请使用命令：
```
apt install curl
```

**使用 root 用户运行以下命令：**

国外服务器：

```bash
curl -O https://raw.githubusercontent.com/yhxpie/server-init/main/init.sh || wget -O ${_##*/} $_ && bash init.sh
```
国内服务器：

```bash
curl -O https://yhxpie-server-init.netlify.app/init.sh || wget -O ${_##*/} $_ && bash init.sh
```

> [!WARNING]
> 脚本 Stage 1 执行完毕后，系统将强制重启。

对于完全测试环境，可以使用：
```bash
curl -O https://yhxpie-server-init.netlify.app/init-test.sh && bash init.sh
```

### 第二步：配置用户与清理

> [!WARNING]
> `init2.sh` 或 `init-clean.sh` 请务必在系统重启后执行

此时会看到终端中有相应提示：

- 方案 A：完成配置（推荐）输入以下命令，进行 SSH 密钥配置和整体环境清理：
```bash
sudo bash init2.sh
```

- 方案 B：跳过配置。如果测试环境下不需要配置用户密钥，则输入以下命令清理残留文件：
```bash
sudo bash init-clean.sh
```

`init-clean.sh` 仅删除控制台消息并删除所有残留文件，如果是仅测试环境，也可以不执行

- - -

## 功能特性

分为 Stage 1 & Stage 2，旨在实现“开箱即用”的最佳实践配置

### Stage 1: `init.sh`：服务器基础配置

- **基础设置**：
  - 修改主机名称
  - 设置时区为 `Asia/Shanghai` 并同步时间
- **网络优化**：
  - 开启 TCP BBR 拥塞控制算法
- **智能源配置**：
  - 自动检测服务器地区，大陆地区自动切换至南京大学 NJU 镜像源
  - 将更新源从 HTTP 切换为 HTTPS
- **安全防护**：
  - 配置 UFW 防火墙
  - 提供 Fail2ban 或 SSHGuard 防暴力安全组件
- **内核升级**：
  - 自动更新系统内核
  - Ubuntu 支持更新至 HWE 硬件增强堆栈内核
- **系统清理和优化**：
  - 创建 Swap
  - Ubuntu 卸载 Snap
  - 释放 ext4 预留磁盘空间至 1%
- **环境部署 (可选)**：
  - 安装 Docker CE & Docker Compose，自动匹配国内/官方源
  - 安装服务器面板：
    - 宝塔面板：最新版/稳定版
    - aaPanel (宝塔国际版) (English Only)
    - 1Panel
   
> [!IMPORTANT]
> 在国际环境中安装 **中文版宝塔面板** 的速度较慢，安装过程中请耐心等待
> 
> 同样地，在国内环境中安装 **aaPanel** 的速度也会较慢

### Stage 2: `init2.sh`：进阶配置

- **SSH 安全加固**：
  - 强制清理 SSH Drop-in 干扰配置
  - 配置 SSH 密钥登录，**禁用密码登录**
  - 禁用 Root 密码登录，仅允许密钥登录
- **用户管理**：
  - 创建 sudo 免密用户并同步公钥
- **深度清理**：
  - 精准识别并移除旧版本内核
  - 移除无用依赖与残留配置文件

此步骤中涉及的用户可以通过 VNC 进行密码登录

### `init-test.sh`：测试环境快速配置

单阶段快速配置，适用于快速简单部署测试环境不含任何 `sleep` 等待时间或多余提示。

- **基础设置**：
  - 设置时区为 `Asia/Shanghai` 并同步时间
- **网络优化**：
  - 开启 TCP BBR 拥塞控制算法
- **apt 源配置**：
  - 自动检测服务器地区，大陆地区自动切换至 NJU 镜像源
- **环境部署**：
  - 直接安装 Docker
  - 安装最新版宝塔面板 (可选)

---

## 兼容性：

- ✅ = 支持所有功能
- ⚠️ = 需要注意
- ❌ = 无法提供支持

### Ubuntu <img width="16" height="16" src="https://documentation.ubuntu.com/server/_static/favicon.png" /> 

| OS Version | Status | init.sh | init2.sh |
| :----- | :-----: | :-----: | :-----: |
| 26.04 LTS (Resolute Raccoon) | Verifed | ✅ | ✅ |
| 25.10 (Questing Quokka) | Verifed | ✅ | ✅ |
| 25.04 (Plucky Puffin) | Verifed | ✅ | ✅ |
| 24.04 LTS (Noble Numbat) | Verifed | ✅ | ✅ |
| 22.04 LTS (Jammy Jellyfish) | Verifed | ✅ | ✅ |
| 20.04 LTS (Focal Fossa) | ⚠️ | Docker 来自 apt 仓库 |  |
| 18.04 LTS (Bionic Beaver) | ⚠️ | Docker 来自 apt 仓库 |  |

### Debian <img width="16" height="16" src="https://www.debian.org/favicon.ico" />

| OS Version | Status | init.sh | init2.sh |
| :----- | :-----: | :-----: | :-----: |
| 13 (Trixie) | Verifed | ✅ | ✅ |
| 12 (Bookworm) | Verifed | ✅ | ✅ |
| 11 (Bullseye) | Verifed | ✅ | ✅ |
| 10 (Buster) | ⚠️ | Docker 来自 apt 仓库 |  | Docker 来自 apt 仓库 |

❌ 旧版本系统的 Docker 安装自系统对应的 apt 仓库，其中无 Docker Compose

## 免责声明

1. 建议在新安装完成的**官方原版纯净系统**上运行
2. 请务必在执行 Stage 2 前自行保存好您的 SSH 公私钥

不建议在生产环境运行。作者不对因脚本执行导致的任何数据丢失或系统故障负责。

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
