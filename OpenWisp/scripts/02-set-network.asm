#!/bin/ash

#/usr/bin/02-set-network.asm

source /root/.config/asm/asm.env

# Setup LAN, DHCP and DNS
if [ "$ip" != "10.149.${VLAN}.254" ];then
    echo "Setting LAN interface IP address"
    uci set network.lan.ipaddr="10.149.${VLAN}.254"
    uci set dhcp.dnsmasq1.domain="${ORG_SLUG}.asm"
    uci set dhcp.dnsmasq1.local="/${ORG_SLUG}.asm/"
    uci add_list dhcp.@dnsmasq[0].server='/altec.asm.co.il/10.87.131.250'

    # Setup SecureNAT on Softether VPN server
    MAC=$(hexdump -n3 -e'/3 "AE-9B-9E" 3/1 "-%02X"' /dev/random)
    /usr/libexec/softethervpn/vpncmd  /server localhost:5555 /password:dTb8afnEAAI30r /adminhub:VPN /cmd SecureNatHostSet /IP:192.168.217.254 /MAC:${MAC} /MASK:none
    /bin/sleep 2
    /usr/libexec/softethervpn/vpncmd  /server localhost:5555 /password:dTb8afnEAAI30r /adminhub:VPN /cmd DhcpSet /START:192.168.217.10 /END:192.168.217.199 /MASK:255.255.255.0 /GW:none /DNS:10.149.${VLAN}.254 /DNS2:none /EXPIRE:7200 /PUSHROUTE:10.149.${VLAN}.0/255.255.255.0/192.168.217.254 /LOG:yes /DOMAIN:${ORG_SLUG}.asm
    /bin/sleep 2
    /usr/libexec/softethervpn/vpncmd  /server localhost:5555 /password:dTb8afnEAAI30r /adminhub:VPN /cmd SecureNatEnable

    # Prepare RDAIUS NAT config
    export $(uci get acme.${ORG_SLUG}.credentials)
    SECRET=$(echo ${ORG_SLUG} | md5sum | openssl base64)
    /usr/libexec/softethervpn/vpncmd  /server localhost:5555 /password:dTb8afnEAAI30r /adminhub:VPN /cmd RadiusServerSet radius.asm.co.il /RETRY_INTERVAL:500 /SECRET:$SECRET

    WAN_IP=$(ifstatus wan |  jsonfilter -e '@["ipv4-address"][0].address')
    echo "#RADIUS NAS configuration data" >/root/.config/asm/radius-nas.cfg
    echo "NAS IP: $WAN_IP" >>/root/.config/asm/radius-nas.cfg
    echo "NAS Name: $HOSTNAME" >>/root/.config/asm/radius-nas.cfg
    echo "NAS SECRET: $SECRET" >>/root/.config/asm/radius-nas.cfg

    uci commit network
    uci commit dhcp
fi

MD5="$(md5sum "/etc/config/network")"
if [ ! -f "/root/.config/asm/network.md5" ]; then
    echo "$MD5" >"/root/.config/asm/network.md5"
    echo "network" >>"/tmp/restart-services"
    echo "dnsmasq" >>"/tmp/restart-services"
else
    MD5_LAST=$(cat "/root/.config/asm/network.md5")
    if [ "$MD5" != "$MD5_LAST" ] || $net_restart; then
        echo "$MD5" >"/root/.config/asm/network.md5"
        echo "network" >>"/tmp/restart-services"
        echo "dnsmasq" >>"/tmp/restart-services"
    fi
fi
