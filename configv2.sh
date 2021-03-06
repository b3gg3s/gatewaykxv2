#!/bin/bash

. ./functionsv2.sh

if [ "$(/usr/bin/id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

conffile="/etc/hoods/$1.conf"
if [ ! -s "$conffile" ]; then
    echo "Usage: $0 Hoodname ";
    exit 1;
fi

. "$conffile"

#fe80 IPv6 holen:
fe80=$(ip -6 addr show $ethernetinterface | grep "inet6 fe80" | grep -v "inet6 fe80::1" | tail -n 1 | cut -d " " -f6)
echo "Wir nutzen folgende fe80 IPv6: $fe80"

if [ -z "$fastdport" ]; then
    fastdport=$fastdportbase
    while grep $fastdport /etc/fastd/fff.bat*/fff.bat*.conf* &>/dev/null ; do ((fastdport+=1)); done
    echo "Wir nutzen $fastdport Port für fastd"
    ## $fastdport = port für fastdport
fi

if [ -z "$bat" ]; then
    bat=$batbase
    while grep bat$bat /etc/systemd/system/fastd*bat*.service &>/dev/null ; do ((bat+=1)); done
    echo "Wir nutzen $bat Nummer für Batman Interface"
    ## $bat = bat interface
fi

if [ -z "$httpport" ]; then
    httpport=$httpportbase
    while grep $httpport /etc/apache2/sites-available/* &>/dev/null ; do ((httpport+=1)); done
    echo "Wir nutzen $httpport Port für http Server"
    ## $httpport = port für httpserver
fi


#### Configuration ####

batif="bat$bat"
iflabel="fff.$batif"

# Fastd config - /etc/fastd/fff.bat"$bat"
fastdsecret="90e9418a189e18f6a126a554081b445690a63752baa763ac26339c8742308144"
setupFastdConfig "$iflabel" "$batif" "$fastdinterfacename" "$fastdport" "$httpport" "$fastdsecret"

# Network interfaces - /etc/network/interfaces.d/bat"$bat"
setupInterface "$iflabel" "$batif" "$fastdinterfacename" "$Hoodname" "$ipv4" "$ipv6" "$fe80" "$ipv4net" "$ipv6net"

# Fastd service - /etc/systemd/system/fastdbat"$bat".service
setupFastdService "$iflabel"

systemctl enable "fastd-$iflabel"
systemctl start "fastd-$iflabel"
echo "fastd Service gestartet und enabled"

# Apache config - /etc/apache2/sites-available/bat"$bat".conf
setupApache "$iflabel" "$httpport"

a2ensite "$iflabel"
systemctl reload apache2
echo "Config für Apache neu geladen und Apache neu gestartet"

# Cronjob für Hoodfile anlegen
setupCronHoodfile "$iflabel" "$lat" "$lon"

# Dnsmasq service - /etc/systemd/system/dnsmasqbat"$bat".service
setupDnsmasq "$iflabel" "$batif" "$dhcpstart" "$dhcpende" "$ipv4netmask"

systemctl enable "dnsmasq-$iflabel.service"
systemctl start "dnsmasq-$iflabel.service"
echo "dnsmasq enabled und gestartet"

echo "<html><header></header><body><img src="https://i.pinimg.com/originals/c8/af/e6/c8afe6457997851b504458a30b6d223d.jpg"></img></body></html>" > /var/www/html/index.html

# Radvd config - /etc/radvd.conf
setupRadvd "$batif" "$fe80" "$ipv6net"

/etc/init.d/radvd restart
echo "radvd neu gestartet"

# Alfred service - /etc/systemd/system/alfredbat"$bat".service
setupAlfred "$iflabel" "$batif"

systemctl enable "alfred-$iflabel"
systemctl start "alfred-$iflabel"
echo "Alfred Service gestartet und enabled"

# MRTG Config neu machen - /etc/mrtg/dhcp.cfg
setupMrtg "$iflabel" "$batif" "$Hoodname" "$mengeaddr"

echo "Script fertig"
