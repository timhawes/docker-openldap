FROM debian:bullseye

ENV OPENLDAP_VERSION 2.6.3

COPY gpg-pubkey.txt /usr/src/

RUN installDeps='ca-certificates libargon2-1 libevent-2.1-7 libevent-core-2.1-7 libevent-extra-2.1-7 libevent-openssl-2.1-7 libevent-pthreads-2.1-7 libhdb9-heimdal libicu67 libkadm5srv8-heimdal libkrb5-26-heimdal libltdl7 libsasl2-2 libssl1.1 libwrap0' \
    && buildDeps='build-essential file gnupg groff-base heimdal-dev libargon2-dev libdb-dev libevent-dev libicu-dev libltdl-dev libsasl2-dev libssl-dev libwrap0-dev pkg-config wget' \
    && apt-get update \
    && apt-get install -y --no-install-recommends $buildDeps $installDeps \
    && cd /usr/src \
    && wget http://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-$OPENLDAP_VERSION.tgz \
    && wget http://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-$OPENLDAP_VERSION.tgz.asc \
    && gpg --no-tty --import gpg-pubkey.txt \
    && gpg --verify openldap-$OPENLDAP_VERSION.tgz.asc openldap-$OPENLDAP_VERSION.tgz \
    && tar xfz openldap-$OPENLDAP_VERSION.tgz \
    && rm -f openldap-$OPENLDAP_VERSION.tgz \
    && cd openldap-$OPENLDAP_VERSION \
    && ./configure \
        --prefix=/usr/local \
        --enable-slapd \
        --enable-dynacl \
        --enable-aci \
        --enable-cleartext \
        --enable-crypt \
        --enable-spasswd \
        --enable-modules \
        --enable-rlookups \
        --enable-slapi \
        --enable-wrappers \
        --enable-backends=yes \
        --enable-perl=no \
        --enable-sql=no \
        --enable-wt=no \
        --enable-overlays=yes \
        --enable-argon2=yes \
        --enable-balancer=yes \
    && make -j$(nproc) \
    && make install \
    && cd contrib/slapd-modules/smbk5pwd \
    && make install HEIMDAL_INC="-I/usr/include/heimdal $(krb5-config.heimdal --cflags kadm-server)" HEIMDAL_LIB="-L/usr/heimdal/lib -lkrb5 -lkadm5srv $(krb5-config.heimdal --libs kadm-server)" \
    && cd /usr/src \
    && rm -rf openldap-$OPENLDAP_VERSION \
    && apt-get purge -y --auto-remove $buildDeps \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -s /sbin/nologin -d /nonexistant ldap \
    && rm -rf /etc/ldap \
    && ln -s /usr/local/etc/openldap /etc/ldap \
    && ln -s /usr/local/libexec/openldap /usr/lib/ldap \
    && ldconfig
COPY schema/*.ldif /usr/local/etc/openldap/schema/
COPY ldap.conf /usr/local/etc/openldap/ldap.conf
COPY cn=config.ldif /docker-entrypoint-initdb.d/ldif/cn=config.ldif
COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
VOLUME ["/etc/ldap/slapd.d", "/var/lib/ldap"]
EXPOSE 389 636
