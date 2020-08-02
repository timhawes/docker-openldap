#!/bin/bash

set -e

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
  if [ -f /docker-entrypoint-initdb.d/ldif/cn=config.ldif ]; then
    echo "Restoring /docker-entrypoint-initdb.d/ldif/cn=config.ldif"
    dirs=$(grep ^olcDbDirectory: </docker-entrypoint-initdb.d/ldif/cn=config.ldif | cut -d" " -f2-)
    if [ -n "$dirs" ]; then
      mkdir -p $dirs
      chown ldap:ldap $dirs
    fi
    slapadd -F /etc/ldap/slapd.d -b cn=config </docker-entrypoint-initdb.d/ldif/cn=config.ldif
  fi
  for f in /docker-entrypoint-initdb.d/ldif/*; do
    case "$f" in
      /docker-entrypoint-initdb.d/ldif/cn=config.ldif)
        true
        ;;
      *.ldif)
        echo "Restoring $f"
        slapadd -F /etc/ldap/slapd.d -b $(basename $f .ldif) <"$f"
        ;;
    esac
  done
fi

echo "Fixing permissions"
chown -R ldap:ldap /etc/ldap/slapd.d /var/lib/ldap /var/run/slapd

echo "Starting slapd"
/usr/local/libexec/slapd -d $LDAP_DEBUG -F /etc/ldap/slapd.d -u ldap -g ldap -h "ldap:/// ldaps:/// ldapi:///" &

sleep 2

echo "Running post scripts..."
for f in /docker-entrypoint-initdb.d/post/*; do
  if [ -f "$f" ]; then
    case "$f" in
      *.ldif)
        echo "Loading $f"
        ldapadd -H ldapi:/// <"$f"
        ;;
      *.sh)
        echo "Running $f"
        . "$f"
        ;;
    esac
  fi
done

echo "Waiting for slapd to exit..."
trap 'kill %1' TERM INT
wait
