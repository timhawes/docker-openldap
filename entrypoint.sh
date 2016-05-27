#!/bin/bash

if [ "$1" = "bash" ]; then
  exec bash
fi

if [ -z "$LDAP_ROOT_PASSWORD" ]; then
  LDAP_ROOT_PASSWORD=password
fi

mkdir -p /etc/ldap/slapd.d /var/lib/ldap /var/run/slapd

if [ ! -d "/etc/ldap/slapd.d/cn=config" ]; then
  echo "Setting up configuration database"
  if [ -n "$LDAP_DOMAIN" ]; then
    LDAP_SUFFIX="dc=$(echo $LDAP_DOMAIN | sed 's/\./,dc=/g')"
    LDAP_DOMAIN_FIRSTPART="$(echo $LDAP_DOMAIN | cut -d. -f1)"
    mkdir -p "/var/lib/ldap/$LDAP_SUFFIX"
    (cat /etc/ldap/config.ldif.template; echo; cat /etc/ldap/config-database.ldif.template) \
      | sed "s/@@LDAP_ROOT_PASSWORD@@/$LDAP_ROOT_PASSWORD/g" \
      | sed "s/@@LDAP_DOMAIN@@/$LDAP_DOMAIN/g" \
      | sed "s/@@LDAP_DOMAIN_FIRSTPART@@/$LDAP_DOMAIN_FIRSTPART/g" \
      | sed "s/@@LDAP_SUFFIX@@/$LDAP_SUFFIX/g" \
      | slapadd -F /etc/ldap/slapd.d -b "cn=config"
    cat /etc/ldap/database.ldif.template \
      | sed "s/@@LDAP_ROOT_PASSWORD@@/$LDAP_ROOT_PASSWORD/g" \
      | sed "s/@@LDAP_DOMAIN@@/$LDAP_DOMAIN/g" \
      | sed "s/@@LDAP_DOMAIN_FIRSTPART@@/$LDAP_DOMAIN_FIRSTPART/g" \
      | sed "s/@@LDAP_SUFFIX@@/$LDAP_SUFFIX/g" \
      | slapadd -F /etc/ldap/slapd.d -b "$LDAP_SUFFIX"
  else
    cat /etc/ldap/config.ldif.template \
      | sed "s/@@LDAP_ROOT_PASSWORD@@/$LDAP_ROOT_PASSWORD/g" \
      | slapadd -F /etc/ldap/slapd.d -b "cn=config"
  fi
fi

echo "Fixing permissions"
chown -R ldap:ldap /etc/ldap/slapd.d /var/lib/ldap /var/run/slapd

echo "Starting slapd"
/usr/local/libexec/slapd -d 0 -F /etc/ldap/slapd.d -u ldap -g ldap -h "ldap:/// ldapi:///"
