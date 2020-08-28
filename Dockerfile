FROM debian:buster

ENV OPENLDAP_VERSION 2.4.52
ENV OPENLDAP_SHA1 c65ebaf9f3f874295b72f19a5de9b74ff0ade4ec

RUN installDeps='libhdb9-heimdal libicu63 libkadm5srv8-heimdal libkrb5-26-heimdal libltdl7 libsasl2-2 libssl1.1 ca-certificates' \
    && buildDeps='build-essential file groff-base heimdal-dev libdb-dev libicu-dev libltdl-dev libsasl2-dev libssl-dev wget' \
    && apt-get update \
    && apt-get install -y --no-install-recommends $buildDeps $installDeps \
    && cd /usr/src \
    && wget http://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-$OPENLDAP_VERSION.tgz \
    && echo "$OPENLDAP_SHA1 openldap-$OPENLDAP_VERSION.tgz" | sha1sum -c \
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
        --enable-lmpasswd \
        --enable-spasswd \
        --enable-modules \
        --enable-rewrite \
        --enable-rlookups \
        --enable-slapi \
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
    && make install HEIMDAL_INC=-I/usr/include/heimdal HEIMDAL_LIB="-L/usr/lib/x86_64-linux-gnu/heimdal -lkrb5 -lkadm5srv" \
    && cd /usr/src \
    && rm -rf openldap-$OPENLDAP_VERSION \
    && apt-get purge -y --auto-remove $buildDeps \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -s /sbin/nologin -d /nonexistant ldap \
    && ln -s /usr/local/libexec/openldap /usr/lib/ldap \
    && ln -s /usr/local/etc/openldap/schema /etc/ldap/schema \
    && ls -sf /etc/ldap/ldap.conf /usr/local/etc/openldap/ldap.conf
COPY schema/*.ldif /usr/local/etc/openldap/schema/
COPY ldap.conf /etc/ldap/ldap.conf
COPY cn=config.ldif /docker-entrypoint-initdb.d/ldif/cn=config.ldif
COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
VOLUME ["/etc/ldap/slapd.d", "/var/lib/ldap"]
EXPOSE 389 636
