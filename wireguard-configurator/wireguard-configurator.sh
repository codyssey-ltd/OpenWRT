#!/bin/bash
#source ./.env
inotifywait -m $ENC_DIR -e create -e moved_to -e close_write -e delete |
  while read directory action file; do
    CONF="${DEC_DIR}/${file%.*}.conf"
    case "$action" in
      DELETE)  echo "$file deleted. Removing corresponding config."
          rm -f "${CONF}"
        ;;
      *)  if [[ "$file" =~ .*enc$ ]]; then
            openssl enc -aes-256-cbc -a -pbkdf2 -salt -d -in "${ENC_DIR}/$file" -out "/tmp/$file" -pass pass:${ZONE_ID} 2> /dev/null
            if [ $? -eq 0 ]; then
              mv "/tmp/$file" "${CONF}"
              echo "Successfully decrypted file."
            else
              echo "Could not decrypt file" >&2
            fi
          fi
        ;;
      esac

      echo "Reassembling ${wg_iface} config..."
      cat "${DEC_DIR}/.base" > /etc/wireguard/${wg_iface}.conf
      for conf in "${DEC_DIR}/*.conf"; do
        cat $conf >> /etc/wireguard/${wg_iface}.conf
      done
      wg syncconf ${wg_iface} <(wg-quick strip ${wg_iface})
      /usr/bin/systemctl restart wg-quick@${wg_iface}
      if [ $? -eq 0 ]; then
        echo "Wireguard configuration applied successfully"
      else
        echo "Wireguard reconfiguration FAILED!!!" >&2
      fi

  done
 
# systemd unit to use with this file:
# /etc/systemd/wireguard-configurator.service
#
# [Service]
# EnvironmentFile=/opt/wg-configs/.env
# ExecStart=/opt/wg-configs/wireguard-configurator.sh
# Restart=always
# RestartSec=1
# StandardOutput=syslog
# StandardError=syslog
# SyslogIdentifier=wireguard-configurator
# User=root
# Group=root

# [Install]
# WantedBy=multi-user.target
