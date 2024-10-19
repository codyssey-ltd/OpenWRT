#/bin/ash

#/usr/bin/03-set-wireguard.asm - Wireguard setup script

source /root/.config/asm/asm.env

mkdir -p "/root/.config/asm/wg0"
touch "/root/.config/asm/wg0/wg0.env"
# Setup Wireguard tunnels
for i in $(seq 0 10); do
    if [ -f "/root/.config/asm/wg$i/wg$i.env" ] ; then
        case ${i} in
            #Configuring Wireguard Server interface
            0)
                if [ ! -f "/root/.config/asm/wg${i}/privatekey" ]; then
                    WG0_PORT="$(($VLAN + 49000))"
                    cd /root/.config/asm/wg${i} && umask 077
                    wg genkey | tee privatekey | wg pubkey > publickey
                    uci set network.wg${i}="interface"
                    uci set network.wg${i}.proto="wireguard"
                    uci set network.wg${i}.private_key="$(cat /root/.config/asm/wg${i}/privatekey)"
                    uci add_list network.wg${i}.addresses="10.150.$VLAN.254/24"
                    uci set network.wg${i}.listen_port="$WG0_PORT"
                    uci set network.wg${i}.defaultroute="0"
                    # Firewall rule to allow WG0 port:
                    uci set firewall.rule49=rule
                    uci set firewall.rule49.dest_port="$WG0_PORT"
                    uci set firewall.rule49.family="ipv4"
                    uci set firewall.rule49.name="Wireguard-Server"
                    uci set firewall.rule49.proto="udp"
                    uci set firewall.rule49.src="wan"
                    uci set firewall.rule49.target="ACCEPT"
                fi
           ;;
            # Configuring peer WG interfaces
            *)
                source  /root/.config/asm/wg$i/wg$i.env
                WG_PREFIX=$(echo $WG_NET | cut -d/ -f1 | cut -d. -f1-3)
                WG_IP=$(ip addr show wg${i} |grep -w inet |awk '{ print $2}'| cut -d "/" -f 1)

                if [ "$WG_IP" != "$WG_PREFIX.$VLAN" ]; then
                    echo "Setting Wireguard wg${i} interface"
                    uci -q delete network.wg${i}
                    if [ ! -f "/root/.config/asm/wg${i}/privatekey" ]; then
                        cd /root/.config/asm/wg${i} && umask 077
                        wg genkey | tee privatekey | wg pubkey > publickey
                        wg genpsk > presharedkey
                    fi

                    # Configure Wireguard interface wg${i}
                    uci set network.wg${i}="interface"
                    uci set network.wg${i}.proto="wireguard"
                    uci set network.wg${i}.private_key="$(cat /root/.config/asm/wg${i}/privatekey)"
                    uci add_list network.wg${i}.addresses="${WG_PREFIX}.$VLAN/32"

                    # Add VPN peers
                    uci -q delete network.wireguard_wg${i}
                    uci set network.wireguard_wg${i}="wireguard_wg${i}"
                    uci set network.@wireguard_wg${i}[0].public_key="$PUB_KEY"
                    uci set network.@wireguard_wg${i}[0].preshared_key="$(cat /root/.config/asm/wg${i}/presharedkey)"
                    uci set network.@wireguard_wg${i}[0].endpoint_host="$HOST"
                    uci set network.@wireguard_wg${i}[0].description="$HOST"
                    uci set network.@wireguard_wg${i}[0].endpoint_port="$PORT"
                    uci set network.@wireguard_wg${i}[0].route_allowed_ips="1"
                    uci set network.@wireguard_wg${i}[0].persistent_keepalive="25"
                    uci add_list network.@wireguard_wg${i}[0].allowed_ips="$WG_NET"

                    # Prepare server config
                    echo  >/root/.config/asm/wg${i}/server.conf
                    echo "# $ORG_SLUG OpenWRT client for $HOST" >/root/.config/asm/wg${i}/server.conf
                    echo "[Peer]" >>/root/.config/asm/wg${i}/server.conf
                    echo "PublicKey = $(cat /root/.config/asm/wg${i}/publickey)" >>/root/.config/asm/wg${i}/server.conf
                    echo "PresharedKey = $(cat /root/.config/asm/wg${i}/presharedkey)" >>/root/.config/asm/wg${i}/server.conf
                    allowed_ips=$(echo $WG_NET | grep "," | cut -d, -f2-9)
        #            if [ ! -z $allowed_ips ]; then
        #                allowed_ips="${WG_PREFIX}.$VLAN/32,10.149.$VLAN.0/24,"$allowed_ips
        #            else
                        allowed_ips="${WG_PREFIX}.$VLAN/32,10.149.$VLAN.0/24"
        #            fi
                    echo "AllowedIPs = $allowed_ips" >>/root/.config/asm/wg${i}/server.conf
                    echo -e "" >>/root/.config/asm/wg${i}/server.conf

                    # Encrypting and sending wg${i} conf to Wireguard server
                    CERT_SLUG=$(echo $ORG_SLUG | sed 's/[-_#$%*@]//g')
                    export $(uci get acme.$CERT_SLUG.credentials)
                    openssl enc -aes-256-cbc -pbkdf2 -salt -a -in /root/.config/asm/wg${i}/server.conf -out /tmp/${HOSTNAME}_wg${i}.enc -pass pass:${CF_Zone_ID}
                    max_retry=3
                    counter=1
                    until curl --max-time 5 -q -X POST -H "Content-Type: multipart/form-data" -H 'Authorization-Token: eyJhbGciOiJIUzI1NiIsInR5cCI6ImFjY2Vzcy' -F "HOST=$HOSTNAME" -F "wgconf=@/tmp/${HOSTNAME}_wg${i}.enc" https://${HOST}:${PORT}/wg-trap.php
                    do
                        echo "Trying to send conf file to WG server again. Attempt #$counter out of $max_retry"
                        if [[ $counter -eq $max_retry ]]; then
                            echo "Failed to send WG config to https://${HOST}:${PORT}!"
                            break
                        fi
                        sleep 10
                        counter=$((counter+1))
                    done
                    rm -f "/tmp/${HOSTNAME}_wg${i}.enc"
                    net_restart=true
                else
                    echo "wg$i configuration is actual. No action needed."
                fi
            ;;
        esac

        # Adding wg${i} interface to the LAN network zone
        case "$(uci get firewall.@zone[0].network)" in
            *\ *) uci set firewall.@zone[0].network="$(uci get firewall.@zone[0].network) wg${i}" ;;
            *) uci add_list firewall.@zone[0].network="wg${i}" ;;
        esac
        uci commit firewall
        uci commit network
    else
        echo "wg$i configuration is not defined. Skipping..."
    fi
done

MD5="$(md5sum "/etc/config/network")"
if [ ! -f "/root/.config/asm/network.md5" ]; then
    echo "$MD5" >"/root/.config/asm/network.md5"
    echo "network" >>"/tmp/restart-services"
    echo "firewall" >>"/tmp/restart-services"
else
    MD5_LAST=$(cat "/root/.config/asm/network.md5")
    if [ "$MD5" != "$MD5_LAST" ] || $net_restart; then
        echo "$MD5" >"/root/.config/asm/network.md5"
        echo "network" >>"/tmp/restart-services"
        echo "firewall" >>"/tmp/restart-services"
    fi
fi
