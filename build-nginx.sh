#!/usr/bin/env bash
# Run as root or with sudo

# Make script exit if a simple command fails and
# Make script print commands being executed
set -e -x

# Set names of latest versions of each package
export VERSION_PCRE=pcre-8.39
export VERSION_OPENSSL=openssl-1.0.2h
export VERSION_NGINX=nginx-1.11.3

# Set checksums of latest versions
export SHA256_PCRE=ccdf7e788769838f8285b3ee672ed573358202305ee361cfec7a4a4fb005bbc7
export SHA256_OPENSSL=1d4007e53aad94a5b2002fe045ee7bb0b3d98f1a47f8b2bc851dcd1c74332919
export SHA256_NGINX=4a667f40f9f3917069db1dea1f2d5baa612f1fa19378aadf71502e846a424610

# Set GPG keys used to sign downloads
export GPG_OPENSSL=8657ABB260F056B1E5190839D9C4D26D0E604491
export GPG_NGINX=B0F4253373F8F6F510D42178520A9993A1C052F8

# Set URLs to the source directories
export SOURCE_OPENSSL=https://www.openssl.org/source/
export SOURCE_PCRE=ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/
export SOURCE_NGINX=http://nginx.org/download/

# Make a 'today' variable for use in back-up filenames later
today=$(date +"%Y-%m-%d")

# Clean out any files from previous runs of this script
rm -rf build
rm -rf /etc/nginx-default
mkdir build

# Ensure the required software to compile nginx is installed
apt-get update && apt-get -y install \
  build-essential \
  curl \
  libssl-dev

# Download the source files
curl -L $SOURCE_PCRE$VERSION_PCRE.tar.gz -o ./build/PCRE.tar.gz && \
  echo "${SHA256_PCRE} ./build/PCRE.tar.gz" | sha256sum -c -
curl -L $SOURCE_OPENSSL$VERSION_OPENSSL.tar.gz -o ./build/OPENSSL.tar.gz && \
  echo "${SHA256_OPENSSL} ./build/OPENSSL.tar.gz" | sha256sum -c -
curl -L $SOURCE_NGINX$VERSION_NGINX.tar.gz -o ./build/NGINX.tar.gz && \
  echo "${SHA256_NGINX} ./build/NGINX.tar.gz" | sha256sum -c -

# Download the signature files
curl -L $SOURCE_OPENSSL$VERSION_OPENSSL.tar.gz.asc -o ./build/OPENSSL.tar.gz.asc
curl -L $SOURCE_NGINX$VERSION_NGINX.tar.gz.asc -o ./build/NGINX.tar.gz.asc

# Verify GPG signature of downloads
cd build
export GNUPGHOME="$(mktemp -d)"
gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_OPENSSL"
gpg --batch --verify OPENSSL.tar.gz.asc OPENSSL.tar.gz
gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_NGINX"
gpg --batch --verify NGINX.tar.gz.asc NGINX.tar.gz
rm -r "$GNUPGHOME" OPENSSL.tar.gz.asc NGINX.tar.gz.asc

# Expand the source files
tar xzf PCRE.tar.gz
tar xzf OPENSSL.tar.gz
tar xzf NGINX.tar.gz
cd ../

# Set where OpenSSL and nginx will be built
export BPATH=$(pwd)/build
export STATICLIBSSL="$BPATH/staticlibssl"

# Build static OpenSSL
cd $BPATH/$VERSION_OPENSSL
rm -rf "$STATICLIBSSL"
mkdir "$STATICLIBSSL"
make clean
./config --prefix=$STATICLIBSSL no-shared no-ssl2 no-ssl3 no-idea \
&& make depend \
&& make \
&& make install_sw

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

# Add nginx user and group if nginx user does not already exist
id -u nginx &>/dev/null || adduser --system --no-create-home --disabled-login --disabled-password --group nginx

# Build nginx, with various modules included/excluded
cd $BPATH/$VERSION_NGINX
mkdir -p $BPATH/nginx
./configure \
--prefix=/etc/nginx \
--with-cc-opt="-I $STATICLIBSSL/include -I/usr/include -O3 -fPIE -fstack-protector-strong -Wformat -Werror=format-security" \
--with-ld-opt="-L $STATICLIBSSL/lib -Wl,-Bsymbolic-functions -Wl,-z,relro,-rpath -lssl -lcrypto -ldl -lz" \
--with-openssl=$BPATH/$VERSION_OPENSSL \
--with-pcre=$BPATH/$VERSION_PCRE \
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
--with-http_ssl_module \
--with-http_realip_module \
--with-http_sub_module \
--with-http_mp4_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_secure_link_module \
--with-http_stub_status_module \
--with-http_auth_request_module \
--with-file-aio \
--without-mail_imap_module \
--without-mail_pop3_module \
--without-mail_smtp_module \
--with-http_v2_module \
--with-ipv6 \
--with-threads \
--with-stream \
--with-stream_ssl_module \
--with-http_slice_module \
&& make && make install

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
PIDFile=/run/nginx.pid
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
