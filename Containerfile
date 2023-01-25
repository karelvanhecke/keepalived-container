FROM docker.io/alpine:3.17 as BUILDER
RUN apk add autoconf \
automake \
libnftnl-dev \
nftables-dev \
ipset-dev \
libnfnetlink-dev \
libnl3-dev \
musl-dev \
libressl-dev \
gcc \
make \
pcre2-dev \
kmod-dev \
file-dev \
curl \
git \
libcap-utils
RUN git clone -b v2.2.7 --depth=1 https://github.com/acassen/keepalived.git
WORKDIR /keepalived
RUN curl -o libressl-1.patch https://github.com/acassen/keepalived/commit/bbec15d4781670ac1be5e543cb04543f79200e69.patch && \
curl -o libressl-2.patch https://github.com/acassen/keepalived/commit/5cb40301f5cd8fbedbb756cd3d838def7293e0bd.patch && \
git apply libressl-1.patch && \
git apply libressl-2.patch
RUN ./build_setup
RUN ./configure --prefix=/usr \
--sysconfdir=/etc \
--enable-bfd \
--disable-systemd \
--disable-dynamic-linking \
--enable-regex
RUN make
RUN make install
RUN addgroup -g 301 -S keepalived && adduser -u 301 -S keepalived -G keepalived
RUN setcap "cap_net_admin+ep cap_net_raw+ep cap_net_broadcast+ep" /usr/sbin/keepalived
RUN mkdir /run/keepalived && chown -R keepalived:keepalived /run/keepalived
FROM scratch
COPY --from=BUILDER /usr/lib/libcrypto.so.50 /usr/lib/libcrypto.so.50
COPY --from=BUILDER /usr/lib/libssl.so.53 /usr/lib/libssl.so.53
COPY --from=BUILDER /lib/libkmod.so.2 /lib/libkmod.so.2
COPY --from=BUILDER /usr/lib/libnl-3.so.200 /usr/lib/libnl-3.so.200
COPY --from=BUILDER /usr/lib/libnl-genl-3.so.200 /usr/lib/libnl-genl-3.so.200
COPY --from=BUILDER /usr/lib/libmagic.so.1 /usr/lib/libmagic.so.1
COPY --from=BUILDER /usr/lib/libnftnl.so.11 /usr/lib/libnftnl.so.11
COPY --from=BUILDER /usr/lib/libmnl.so.0 /usr/lib/libmnl.so.0
COPY --from=BUILDER /usr/lib/libpcre2-8.so.0 /usr/lib/libpcre2-8.so.0
COPY --from=BUILDER /lib/ld-musl-x86_64.so.1 /lib/ld-musl-x86_64.so.1
COPY --from=BUILDER /usr/lib/libzstd.so.1 /usr/lib/libzstd.so.1
COPY --from=BUILDER /usr/lib/liblzma.so.5 /usr/lib/liblzma.so.5
COPY --from=BUILDER /lib/libz.so.1 /lib/libz.so.1
COPY --from=BUILDER /lib/libcrypto.so.3 /lib/libcrypto.so.3
COPY --from=BUILDER /usr/sbin/keepalived /usr/sbin/keepalived
COPY --from=BUILDER /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=BUILDER /etc/passwd /etc/passwd
COPY --from=BUILDER /etc/group /etc/group
COPY --from=BUILDER /usr/share/misc/magic.mgc /usr/share/misc/magic.mgc
COPY --from=BUILDER --chown=301:301 /run/keepalived /run
USER 301:301
ENTRYPOINT ["/usr/sbin/keepalived","-n","-l","-D"]
