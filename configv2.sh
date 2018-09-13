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
[ -z "$iflabel" ] && iflabel="fff.$batif"

# Fastd config - /etc/fastd/fff.bat"$bat"
fastdsecret="50d86e0c1e9bea9a717fc568f9126764d9165bb7f0c0911f6c21ed901f15e46c"
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
