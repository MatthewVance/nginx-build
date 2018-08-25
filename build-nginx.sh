#!/usr/bin/env bash
# Run as root or with sudo
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root or with sudo."
  exit 1
fi

# Make script exit if a simple command fails and
# Make script print commands being executed
set -e -x

# Set names of latest versions of each package
VERSION_PCRE=pcre-8.42
VERSION_ZLIB=zlib-1.2.11
VERSION_OPENSSL=openssl-1.1.0i
VERSION_NGINX=nginx-1.15.2

# Set checksums of latest versions
SHA256_PCRE=69acbc2fbdefb955d42a4c606dfde800c2885711d2979e356c0636efde9ec3b5
SHA256_ZLIB=c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1
SHA256_OPENSSL=ebbfc844a8c8cc0ea5dc10b86c9ce97f401837f3fa08c17b2cdadc118253cf99
SHA256_NGINX=eeba09aecfbe8277ac33a5a2486ec2d6731739f3c1c701b42a0c3784af67ad90

# Set OpenPGP keys used to sign downloads
OPGP_PCRE=45F68D54BBE23FB3039B46E59766E084FB0F43D8
OPGP_ZLIB=5ED46A6721D365587791E2AA783FCD8E58BCAFBA
OPGP_OPENSSL=8657ABB260F056B1E5190839D9C4D26D0E604491
OPGP_NGINX=B0F4253373F8F6F510D42178520A9993A1C052F8

# Set URLs to the source directories
SOURCE_PCRE=https://ftp.pcre.org/pub/pcre/
SOURCE_ZLIB=https://zlib.net/
SOURCE_OPENSSL=https://www.openssl.org/source/
SOURCE_NGINX=https://nginx.org/download/

# Set where OpenSSL and nginx will be built
BPATH=$(pwd)/build

# Make a 'today' variable for use in back-up filenames later
today=$(date +"%Y-%m-%d")

# Clean out any files from previous runs of this script
rm -rf \
  "$BPATH" \
  /etc/nginx-default
mkdir $BPATH

# Ensure the required software to compile nginx is installed
apt-get update && apt-get -y install \
  binutils \
  build-essential \
  curl \
  dirmngr \
  libssl-dev

# Download the source files
curl -L $SOURCE_PCRE$VERSION_PCRE.tar.gz -o $BPATH/PCRE.tar.gz && \
  echo "${SHA256_PCRE} ${BPATH}/PCRE.tar.gz" | sha256sum -c -
curl -L $SOURCE_ZLIB$VERSION_ZLIB.tar.gz -o $BPATH/ZLIB.tar.gz && \
  echo "${SHA256_ZLIB} ${BPATH}/ZLIB.tar.gz" | sha256sum -c -
curl -L $SOURCE_OPENSSL$VERSION_OPENSSL.tar.gz -o $BPATH/OPENSSL.tar.gz && \
  echo "${SHA256_OPENSSL} ${BPATH}/OPENSSL.tar.gz" | sha256sum -c -
curl -L $SOURCE_NGINX$VERSION_NGINX.tar.gz -o $BPATH/NGINX.tar.gz && \
  echo "${SHA256_NGINX} ${BPATH}/NGINX.tar.gz" | sha256sum -c -

# Download the signature files
curl -L $SOURCE_PCRE$VERSION_PCRE.tar.gz.sig -o $BPATH/PCRE.tar.gz.sig
curl -L $SOURCE_ZLIB$VERSION_ZLIB.tar.gz.asc -o $BPATH/ZLIB.tar.gz.asc
curl -L $SOURCE_OPENSSL$VERSION_OPENSSL.tar.gz.asc -o $BPATH/OPENSSL.tar.gz.asc
curl -L $SOURCE_NGINX$VERSION_NGINX.tar.gz.asc -o $BPATH/NGINX.tar.gz.asc

# Verify OpenPGP signature of downloads
cd $BPATH
export GNUPGHOME="$(mktemp -d)"
gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$OPGP_PCRE" "$OPGP_ZLIB" "$OPGP_OPENSSL" "$OPGP_NGINX"
gpg --batch --verify PCRE.tar.gz.sig PCRE.tar.gz
gpg --batch --verify ZLIB.tar.gz.asc ZLIB.tar.gz
gpg --batch --verify OPENSSL.tar.gz.asc OPENSSL.tar.gz
gpg --batch --verify NGINX.tar.gz.asc NGINX.tar.gz

# Expand the source files
for archive in *.tar.gz; do
  tar xzf "$archive"
done

# Clean up
rm -r \
  "$GNUPGHOME" \
  PCRE.tar.* \
  ZLIB.tar.* \
  OPENSSL.tar.* \
  NGINX.tar.*
cd ../

# Rename the existing /etc/nginx directory so it's saved as a back-up
if [ -d "/etc/nginx" ]; then
  mv /etc/nginx /etc/nginx-$today
fi

# Create NGINX cache directories if they do not already exist
if [ ! -d "/var/cache/nginx/" ]; then
  mkdir -p \
    /var/cache/nginx/client_temp \
    /var/cache/nginx/proxy_temp \
    /var/cache/nginx/fastcgi_temp \
    /var/cache/nginx/uwsgi_temp \
    /var/cache/nginx/scgi_temp
fi

# Add nginx group and user if they do not already exist
id -g nginx &>/dev/null || addgroup --system nginx
id -u nginx &>/dev/null || adduser --disabled-password --system --home /var/cache/nginx --shell /sbin/nologin --group nginx

# Test to see if our version of gcc supports __SIZEOF_INT128__
if gcc -dM -E - </dev/null | grep -q __SIZEOF_INT128__
then
  ECFLAG="enable-ec_nistp_64_gcc_128"
else
  ECFLAG=""
fi

# Build nginx, with various modules included/excluded
cd $BPATH/$VERSION_NGINX
./configure \
--prefix=/etc/nginx \
--with-cc-opt='-O3 -fPIE -fstack-protector-strong -Wformat -Werror=format-security' \
--with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro' \
--with-pcre=$BPATH/$VERSION_PCRE \
--with-zlib=$BPATH/$VERSION_ZLIB \
--with-openssl-opt="no-weak-ssl-ciphers no-ssl3 no-shared $ECFLAG -DOPENSSL_NO_HEARTBEATS -fstack-protector-strong" \
--with-openssl=$BPATH/$VERSION_OPENSSL \
--sbin-path=/usr/sbin/nginx \
--modules-path=/usr/lib/nginx/modules \
--conf-path=/etc/nginx/nginx.conf \
--error-log-path=/var/log/nginx/error.log \
--http-log-path=/var/log/nginx/access.log \
--pid-path=/var/run/nginx.pid \
--lock-path=/var/run/nginx.lock \
--http-client-body-temp-path=/var/cache/nginx/client_temp \
--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
--user=nginx \
--group=nginx \
--with-file-aio \
--with-http_auth_request_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_mp4_module \
--with-http_realip_module \
--with-http_secure_link_module \
--with-http_slice_module \
--with-http_ssl_module \
--with-http_stub_status_module \
--with-http_sub_module \
--with-http_v2_module \
--with-pcre-jit \
--with-stream \
--with-stream_ssl_module \
--with-threads \
--without-http_empty_gif_module \
--without-http_geo_module \
--without-http_split_clients_module \
--without-http_ssi_module \
--without-mail_imap_module \
--without-mail_pop3_module \
--without-mail_smtp_module
make
make install
make clean
strip -s /usr/sbin/nginx*

if [ -d "/etc/nginx-$today" ]; then
  # Rename the compiled 'default' /etc/nginx directory so its accessible as a reference to the new nginx defaults
  mv /etc/nginx /etc/nginx-default

  # Restore the previous version of /etc/nginx to /etc/nginx so the old settings are kept
  mv /etc/nginx-$today /etc/nginx
fi

# Create NGINX systemd service file if it does not already exist
if [ ! -e "/lib/systemd/system/nginx.service" ]; then
  # Control will enter here if $DIRECTORY doesn't exist.
  FILE="/lib/systemd/system/nginx.service"

  /bin/cat >$FILE <<'EOF'
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
fi

echo "All done.";
echo "Start with sudo systemctl start nginx"
echo "or with sudo nginx"
