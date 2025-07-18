#!/bin/ash

#/usr/bin/04-set-firewall.asm

source /root/.config/asm/asm.env
# Capture the 3rd octet of eth1 (WAN) IP address
PVE_NODE_OCTET=$(ifconfig eth1 | grep 'inet addr:' | cut -d: -f2 | cut -d' ' -f1 | cut -d. -f3)
# Configure and reorder custom Firewall rules
sed -i "s/VLAN/${VLAN}/g" /etc/config/firewall
sed -i "s/PVE_NODE/${PVE_NODE_OCTET}/g" /etc/config/firewall
for r in $(seq 0 99); do
    uci reorder firewall.rule${r}=${r} > /dev/null 2>&1
done
uci commit firewall
MD5="$(md5sum "/etc/config/firewall")"
if [ ! -f "/root/.config/asm/firewall.md5" ]; then
    echo "$MD5" >"/root/.config/asm/firewall.md5"
    echo "firewall" >>"/tmp/restart-services"
else
    MD5_LAST=$(cat "/root/.config/asm/firewall.md5")
    if [ "$MD5" != "$MD5_LAST" ]; then
        echo "$MD5" >"/root/.config/asm/firewall.md5"
        echo "firewall" >>"/tmp/restart-services"
    fi
fi
