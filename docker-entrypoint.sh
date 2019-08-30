#!/bin/bash

set -x

if [ "$1" = "bash" ]; then
  exec bash
fi

ulimit -n 1024

if [ -z "$LDAP_DEBUG" ]; then
  LDAP_DEBUG=0
fi

mkdir -p /etc/ldap/slapd.d /var/lib/ldap /var/run/slapd

if [ -d "/etc/ldap/slapd.d/cn=config" ]; then
  ldap_configured=yes
else
  ldap_configured=no
fi

if [ "$ldap_configured" = "no" ]; then
  echo "Restoring LDIF files..."
  if [ -f /docker-entrypoint-initdb.d/ldif/cn=config.ldif ]; then
    dirs=$(grep ^olcDbDirectory: </docker-entrypoint-initdb.d/ldif/cn=config.ldif | cut -d" " -f2-)
    if [ -n "$dirs" ]; then
      mkdir -p $dirs
      chown ldap:ldap $dirs
    fi
    slapadd -F /etc/ldap/slapd.d -b cn=config </docker-entrypoint-initdb.d/ldif/cn=config.ldif
  fi
  for f in /docker-entrypoint-initdb.d/ldif/*; do
    case "$f" in
      /docker-entrypoint-initdb.d/ldif/cn=config.ldif) true;;
      *.ldif) slapadd -F /etc/ldap/slapd.d -b $(basename $f .ldif) <"$f";;
    esac
  done
fi

echo "Fixing permissions"
chown -R ldap:ldap /etc/ldap/slapd.d /var/lib/ldap /var/run/slapd

echo "Starting slapd"
/usr/local/libexec/slapd -d $LDAP_DEBUG -F /etc/ldap/slapd.d -u ldap -g ldap -h "ldap:/// ldaps:/// ldapi:///" &

if [ "$ldap_configured" = "no" ]; then
  echo "Running post scripts..."
  sleep 2
  for f in /docker-entrypoint-initdb.d/post/*; do
    case "$f" in
      *.ldif) ldapadd -H ldapi:/// <"$f";;
      *.sh) . "$f";;
    esac
  done
fi

trap 'kill %1' TERM INT
wait
