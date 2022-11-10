#!/bin/bash

apt-get update; apt-get upgrade; apt-get install gnupg
echo 'deb [arch=amd64] https://repo.symas.com/repo/deb/main/release26 bullseye main' > /etc/apt/sources.list.d/symas.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys DA26A148887DCBEB

systemctl stop slapd
apt-get remove symas-openldap-gold symas-openldap-lib symas-openldap-server; apt autoremove

apt-get update
apt-get install symas-openldap-server symas-openldap-clients
ln -s /etc/openldap/slapd.d /opt/symas/etc/openldap/
ln -s /opt/symas/lib /opt/symas/lib64

mkdir /secrets/var/lib/openldap//run
mv /var/symas/run/ldapi /secrets/var/lib/openldap/run/
ln -s /secrets/var/lib/openldap/ /var/symas
chown ldap:ldap /var/symas/run/
chmod 755 /srv/secrets/var/lib/openldap/

# sasl:
mkdir /secrets/etc/openldap/sasl2

cat >/secrets/etc/openldap/sasl2/slapd.conf <<EOL
pwcheck_method: saslauthd
saslauthd_path: /secrets/run/saslauthd/mux
EOL

ln -s /secrets/etc/openldap/sasl2/slapd.conf /opt/symas/lib64/sasl2/

cat > /lib/systemd/system/symas-openldap-server.service
[Unit]
Description=Symas OpenLDAP (Default Instance)
After=syslog.service network-online.target containers.service
Wants=syslog.service network-online.target containers.service

[Service]
Type=forking
ExecStartPre=/bin/bash -c 'fqdn=`hostname -f`; systemctl set-environment URLs="ldapi:/// ldap://$fqdn ldaps://$fqdn"'
ExecStart=/opt/symas/lib64/slapd -F /etc/openldap/slapd.d -u ldap -g ldap -h "${URLs}"
LimitNOFILE=16384

[Install]
WantedBy=default.target
EOT 

# sasl passthrough works? ./
# gssapi works? ./
# replication works?
# ulimits?
