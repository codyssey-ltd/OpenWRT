#!/bin/ash

#/usr/bin/01-set-acme.asm

source /root/.config/asm/asm.env
source /root/.config/asm/acme.env
CERT_SLUG=$(echo $ORG_SLUG | sed 's/[-_#$%*@]//g')

# Setup ACME
if [ -f "/root/.config/asm/acme.env" ]; then
echo "" >/etc/config/acme
tee -a /etc/config/acme << END
config acme
	option account_email '$ORG_SLUG@altec.co.il'
	option debug '0'
config cert '$CERT_SLUG'
	option use_staging '0'
	option enabled '1'
	option staging '1'
	option key_type 'rsa2048'
	list domains '$ORG_SLUG.asm.co.il'
	option update_uhttpd '1'
	option validation_method 'dns'
	option dns 'dns_cf'
	list credentials 'CF_Token=${CF_Token}'
	list credentials 'CF_Account_ID=${CF_Account_ID}'
	list credentials 'CF_Zone_ID=${CF_Zone_ID}'
	option days '60'
END
	md5sum "/root/.config/asm/acme.env" >"/root/.config/asm/acme.env.md5"
    uci commit acme
fi

MD5="$(md5sum "/etc/config/acme")"
if [ ! -f "/root/.config/asm/acme.md5" ]; then
    echo "$MD5" >"/root/.config/asm/acme.md5"
    echo "acme" >>"/tmp/restart-services"
else
    MD5_LAST=$(cat "/root/.config/asm/acme.md5")
    if [ "$MD5" != "$MD5_LAST" ] || $net_restart; then
        echo "$MD5" >"/root/.config/asm/acme.md5"
        echo "acme" >>"/tmp/restart-services"
    fi
fi
