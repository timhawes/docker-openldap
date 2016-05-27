FROM debian:jessie

ENV OPENLDAP_VERSION 2.4.44
ENV OPENLDAP_SHA1 016a738d050a68d388602a74b5e991035cdba149

COPY smbk5pwd.patch /usr/src/smbk5pwd.patch
RUN installDeps='libicu52 libkadm5srv8-heimdal libkrb5-26-heimdal libltdl7 libsasl2-2 libslp1 libssl1.0.0' \
    && buildDeps='build-essential file groff-base heimdal-dev libdb-dev libicu-dev libltdl-dev libsasl2-dev libslp-dev libssl-dev wget' \
    && apt-get update \
    && apt-get install -y --no-install-recommends $buildDeps $installDeps \
    && cd /usr/src \
    && wget http://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-$OPENLDAP_VERSION.tgz \
    && echo "$OPENLDAP_SHA1 openldap-$OPENLDAP_VERSION.tgz" | sha1sum -c \
    && tar xfz openldap-$OPENLDAP_VERSION.tgz \
    && rm -f openldap-$OPENLDAP_VERSION.tgz \
    && cd openldap-$OPENLDAP_VERSION \
    && patch -p1 <../smbk5pwd.patch \
    && ./configure \
        --prefix=/usr/local \
        --enable-slapd \
        --enable-dynacl \
        --enable-aci \
        --enable-cleartext \
        --enable-crypt \
        --enable-lmpasswd \
        --enable-spasswd \
        --enable-modules \
        --enable-rewrite \
        --enable-rlookups \
        --enable-slapi \
        --enable-slp \
        --enable-backends=no \
        --enable-bdb=mod \
        --enable-dnssrv=mod \
        --enable-hdb=mod \
        --enable-ldap=mod \
        --enable-mdb=mod \
        --enable-meta=mod \
        --enable-monitor=mod \
        --enable-null=mod \
        --enable-passwd=mod \
        --enable-relay=mod \
        --enable-sock=mod \
        --enable-overlays=mod \
        --with-threads \
        --with-tls \
    && make -j$(nproc) \
    && make install \
    && cd contrib/slapd-modules/smbk5pwd \
    && make install \
    && cd /usr/src \
    && rm -rf openldap-$OPENLDAP_VERSION \
    && apt-get purge -y --auto-remove $buildDeps \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -s /sbin/nologin -d /nonexistant ldap \
    && ln -s /usr/local/libexec/openldap /usr/lib/ldap \
    && ln -s /usr/local/etc/openldap/schema /etc/ldap/schema
COPY samba.ldif /usr/local/etc/openldap/schema/samba.ldif
COPY entrypoint.sh /entrypoint.sh
COPY *.ldif.template /etc/ldap/

ENTRYPOINT ["/entrypoint.sh"]
VOLUME ["/etc/ldap/slapd.d", "/var/lib/ldap"]
EXPOSE 389 636
