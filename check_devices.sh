#!/bin/sh

# 检查参数是否正确
if [ "$#" -ne 2 ]; then
    logger "Usage: $0 <MASTER_DEVICE_MAC> <SLAVE_DEVICE_MAC>"
    exit 1
fi

# 将传入的设备 MAC 地址转换为小写
MASTER_DEVICE_MAC=$(echo "$1" | awk '{print tolower($0)}')
SLAVE_DEVICE_MAC=$(echo "$2" | awk '{print tolower($0)}')

# 检测设备是否在线
check_device_online() {
    local mac_address=$1
    local online=$(arp-scan --interface=br-lan --localnet | grep -i "$mac_address")
    if [ -n "$online" ]; then
        logger "$mac_address 在线"
        return 0  # 在线
    else
        logger "$mac_address 不在线"
        return 1  # 不在线
    fi
}

# 唤醒设备
wake_device() {
    local mac_address=$1
    logger "唤醒设备 $mac_address..."
    etherwake -b "$mac_address"
}

# 远程关机设备
shutdown_device() {
    local mac_address=$1
    local ip_address=$(arp-scan --interface=br-lan --localnet | grep -i "$mac_address" | awk '{print $1}')
    if [ -n "$ip_address" ]; then
        logger "远程关机设备 $mac_address ($ip_address)..."
        ssh -i ~/.ssh/id_rsa root@"$ip_address" 'shutdown -h +5'
    else
        logger "未找到设备 $mac_address 的IP地址，无法远程关机。"
    fi
}

# 主逻辑
logger "检测主设备 $MASTER_DEVICE_MAC 的在线状态..."
if check_device_online "$MASTER_DEVICE_MAC"; then
    ip_address=$(arp-scan --interface=br-lan --localnet | grep -i "$SLAVE_DEVICE_MAC" | awk '{print $1}')
    logger "检测从设备 $SLAVE_DEVICE_MAC 的在线状态..."
    if ! check_device_online "$SLAVE_DEVICE_MAC"; then
        wake_device "$SLAVE_DEVICE_MAC"
    else
        ssh -i ~/.ssh/id_rsa root@"$ip_address" 'shutdown -c'  # 取消关机任务
    fi
else
    logger "检测从设备 $SLAVE_DEVICE_MAC 的在线状态..."
    if check_device_online "$SLAVE_DEVICE_MAC"; then
        shutdown_device "$SLAVE_DEVICE_MAC"
    fi
fi
