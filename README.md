# Linux 运维脚本合集

> 适用于 Debian / Ubuntu / CentOS 系统初始化、重装、网络优化、SSH 配置、软件源更换、Grub 修复、LOTServer 管理

---

<!-- 目录 -->
## 目录

- [前提组件](#前提组件)
- [一键 DD CentOS7 国际版](#一键-dd-centos7-国际版)
- [Linux-NetSpeed 网络优化](#linux-netspeed-网络优化)
- [修改 SSH 端口](#修改-ssh-端口)
- [CentOS7 阿里云仓库](#centos7-阿里云仓库)
- [CentOS7 更换仓库](#centos7-更换仓库)
- [Debian9 更换仓库](#debian9-更换仓库)
- [Grub 配置修复](#grub-配置修复)
- [BBR 安装](#bbr-安装)
- [LotServer 加速使用方法](#lotserver-加速使用方法)
- [CentOS7 开机自启](#centos7-开机自启)
- [合集默认密码](#合集默认密码)

---

<!-- 前提组件 -->
## 前提组件

> 执行任何脚本前，请先安装所需依赖组件

### Debian / Ubuntu 系统

```bash
apt-get install -y xz-utils openssl gawk file wget screen && screen -S os
```

### RedHat / CentOS 系统

```bash
yum install -y xz openssl gawk file glibc-common wget screen && screen -S os
```

---

<!-- 一键 DD -->
## 一键 DD CentOS7 国际版

> 默认密码：`Pwd@CentOS`
>
> 此脚本用于全自动重装系统为 CentOS7 国际版

```bash
wget --no-check-certificate -O NewReinstall.sh https://raw.githubusercontent.com/fcurrk/reinstall/master/NewReinstall.sh && chmod a+x NewReinstall.sh && bash NewReinstall.sh
```

---

<!-- 网络优化 -->
## Linux-NetSpeed 网络优化

> 用于优化 Linux 服务器网络性能，支持 BBR/BBRplus/LotServer 等加速方案

```bash
wget -N --no-check-certificate "https://raw.githubusercontent.com/semao168/Linux-NetSpeed/main/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
```

<!-- centos7内核锁定不更新 -->
## 内核锁定不更新

> 内核锁定

```bash
yum versionlock delete kernel*
yum versionlock delete kernel-headers*
yum versionlock delete kernel-tools*

```

> 内核解锁

```bash
yum install -y yum-plugin-versionlock

# 2. 查看已装内核
rpm -q kernel
# 示例：kernel-3.10.0-1160.el7.x86_64

# 3. 锁定所有 kernel 相关包
yum versionlock add kernel*
yum versionlock add kernel-headers*
yum versionlock add kernel-tools*

# 查看锁定列表
yum versionlock list

# 以后正常更新
yum update -y

```



---



## 安装Xray VLESS-Reality

> 脚本

```bash
yum install wget -y && wget -O sshd.sh "https://raw.githubusercontent.com/semao168/Linux-NetSpeed/main/xray/xray-reality.sh" && chmod +x xray-reality..sh && ./xray-reality..sh
```

---




## 修改 SSH 端口

> 通过脚本快速修改 SSH 默认端口，增强服务器安全性

```bash
yum install wget -y && wget -O sshd.sh "https://raw.githubusercontent.com/semao168/lotServer/main/sshd.sh" && chmod +x sshd.sh && ./sshd.sh
```
> debian换端口重启ssh
```bash
bash -c 'NEW_PORT=13348;SSH_CFG=/etc/ssh/sshd_config;cp $SSH_CFG ${SSH_CFG}.bak.$(date +%Y%m%d%H%M%S);sed -i -E "s/^[# ]*Port [0-9]+/Port $NEW_PORT/" $SSH_CFG;grep -q "^Port $NEW_PORT" $SSH_CFG || echo "Port $NEW_PORT" >> $SSH_CFG;command -v ufw && (ufw allow $NEW_PORT/tcp;ufw reload);systemctl restart ssh;systemctl is-active --quiet ssh && echo "✅ 已成功修改SSH端口为 $NEW_PORT" || (echo "❌ 失败，已回滚";cp ${SSH_CFG}.bak.$(date +%Y%m%d%H%M%S) $SSH_CFG;systemctl restart ssh)'
```
---

<!-- CentOS7 阿里云仓库 -->
## CentOS7 阿里云仓库

> 将 CentOS7 系统源更换为阿里云镜像源，提升软件包下载速度

```bash
curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
```

---

<!-- CentOS7 更换仓库 -->
## CentOS7 更换仓库

> 将 CentOS7 系统源更换为中科大镜像源，并安装 EPEL 扩展源

```bash
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup && curl -o /etc/yum.repos.d/CentOS-Base.repo -L https://raw.githubusercontent.com/semao168/Linux-NetSpeed/main/CentOS-ustc.repo && yum install epel-release -y
```

---

<!-- Debian9 更换仓库 -->
## Debian9 更换仓库

> 将 Debian9 系统源更换为国内镜像源

```bash
wget -O /etc/apt/sources.list https://raw.githubusercontent.com/semao168/Linux-NetSpeed/main/sources.list --no-check-certificate
```

---

<!-- Grub 配置修复 -->
## Grub 配置修复

> 当系统引导文件丢失时，使用此脚本修复 Grub

### 情况一：/boot/grub/grub.conf 缺失

```bash
yum install -y grub && grub-mkconfig -o /boot/grub/grub.conf
```

### 情况二：/boot/grub2/grub.cfg 缺失

```bash
yum install -y grub2 && grub2-mkconfig -o /boot/grub2/grub.cfg
```

---

<!-- BBR 安装 -->
## BBR 安装

> 安装并启用 BBR 拥塞控制算法，提升网络吞吐量

```bash
wget -N --no-check-certificate "https://raw.githubusercontent.com/semao168/Linux-NetSpeed/main/bbr.sh" && chmod +x bbr.sh && ./bbr.sh
```

### 验证 BBR 是否启用成功

```bash
sysctl net.ipv4.tcp_congestion_control
```

> 预期返回值：`net.ipv4.tcp_congestion_control = bbr`

---

<!-- LotServer 加速 -->
## LotServer 加速使用方法

> LotServer（锐速）是一款 TCP 加速软件，可显著提升服务器网络性能

| 操作 | 命令 |
|------|------|
| 启动 | `/appex/bin/lotServer.sh start` |
| 停止 | `/appex/bin/lotServer.sh stop` |
| 查看状态 | `/appex/bin/lotServer.sh status` |
| 重启 | `/appex/bin/lotServer.sh restart` |

---

<!-- CentOS7 开机自启 -->
## CentOS7 开机自启

> 设置 LotServer 开机自动启动

```bash
echo "/appex/bin/lotServer.sh restart" >> /etc/rc.d/rc.local && chmod +x /etc/rc.d/rc.local
```

---

<!-- 合集默认密码 -->
## 合集默认密码

> 以下为各系统镜像的默认登录密码，请及时修改

### Linux 系统

| 系统版本 | 默认密码 |
|----------|----------|
| CentOS 7.7（已关闭防火墙及 SELinux） | `Pwd@CentOS` |
| CentOS 7 | `cxthhhhh.com` |
| CentOS 7 (ARM64 / UEFI) | `cxthhhhh.com` |
| CentOS 8 | `cxthhhhh.com` |
| Rocky 8 | `cxthhhhh.com` |
| Rocky 8 (UEFI) | `cxthhhhh.com` |
| Rocky 8 (ARM64 / UEFI) | `cxthhhhh.com` |
| CentOS 9 | `cxthhhhh.com` |
| CentOS 6 | `Minijer.com` |
| Debian 11 | `Minijer.com` |
| Debian 10 | `Minijer.com` |
| Debian 9 | `Minijer.com` |
| Debian 8 | `Minijer.com` |
| Ubuntu 20.04 | `Minijer.com` |
| Ubuntu 18.04 | `Minijer.com` |
| Ubuntu 16.04 | `Minijer.com` |

### Windows 系统

| 系统版本 | 默认密码 |
|----------|----------|
| Windows Server 2022 | `cxthhhhh.com` |
| Windows Server 2022 (UEFI) | `cxthhhhh.com` |
| Windows Server 2019 | `cxthhhhh.com` |
| Windows Server 2016 | `cxthhhhh.com` |
| Windows Server 2012 | `cxthhhhh.com` |
| Windows Server 2008 | `cxthhhhh.com` |
| Windows Server 2003 | `cxthhhhh.com` |
| Windows 10 LTSC | `Teddysun.com` |
| Windows 10 LTSC (UEFI) | `Teddysun.com` |
| Windows 7 x86 Lite | `nat.ee` |
| Windows 7 x86 Lite（阿里云专用） | `nat.ee` |
| Windows 7 x64 Lite | `nat.ee` |
| Windows 7 x64 Lite (UEFI) | `nat.ee` |
| Windows 10 LTSC Lite | `nat.ee` |
| Windows 10 LTSC Lite（阿里云专用） | `nat.ee` |
| Windows 10 LTSC Lite (UEFI) | `nat.ee` |
| Windows Server 2003 Lite | `WinSrv2003x86-Chinese`（C 盘默认 10G） |
| Windows Server 2008 Lite | `nat.ee` |
| Windows Server 2008 Lite (UEFI) | `nat.ee` |
| Windows Server 2012 Lite | `nat.ee` |
| Windows Server 2012 Lite (UEFI) | `nat.ee` |
| Windows Server 2016 Lite | `nat.ee` |
| Windows Server 2016 Lite (UEFI) | `nat.ee` |
| Windows Server 2022 Lite | `nat.ee` |
| Windows Server 2022 Lite (UEFI) | `nat.ee` |

---

<!-- 自定义镜像 -->
## 自定义镜像

> 更多自定义镜像需求可自行扩展
