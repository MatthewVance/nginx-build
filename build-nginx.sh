#!/usr/bin/env bash

# make script exit if a simple command fails and
# make script print commands being executed
set -e -x

# names of latest versions of each package
export VERSION_PCRE=pcre-8.38
export VERSION_OPENSSL=openssl-1.0.2f
export VERSION_NGINX=nginx-1.9.10

# checksums of latest versions of each package
export SHA256_PCRE=9883e419c336c63b0cb5202b09537c140966d585e4d0da66147dc513da13e629
export SHA256_OPENSSL=932b4ee4def2b434f85435d9e3e19ca8ba99ce9a065a61524b429a9d5e9b2e9c
export SHA256_NGINX=6a5c72f4afaf57a6db064bba0965d72335f127481c5d4e64ee8714e7b368a51f

# URLs to the source directories
export SOURCE_OPENSSL=https://www.openssl.org/source/
export SOURCE_PCRE=ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/
export SOURCE_NGINX=http://nginx.org/download/

# make a 'today' variable for use in back-up filenames later
today=$(date +"%Y-%m-%d")

# clean out any files from previous runs of this script
rm -rf build
rm -rf /etc/nginx-default
mkdir build

# ensure that we have the required software to compile our own nginx
apt-get update && apt-get -y install \
  build-essential \
  curl \
  libssl-dev

# grab the source files
curl -L $SOURCE_PCRE$VERSION_PCRE.tar.gz -o ./build/PCRE.tar.gz && \
  echo "${SHA256_PCRE} ./build/PCRE.tar.gz" | sha256sum -c -
curl -L $SOURCE_OPENSSL$VERSION_OPENSSL.tar.gz -o ./build/OPENSSL.tar.gz && \
  echo "${SHA256_OPENSSL} ./build/OPENSSL.tar.gz" | sha256sum -c -
curl -L $SOURCE_NGINX$VERSION_NGINX.tar.gz -o ./build/NGINX.tar.gz && \
  echo "${SHA256_NGINX} ./build/NGINX.tar.gz" | sha256sum -c -

# expand the source files
cd build
tar xzf PCRE.tar.gz
tar xzf OPENSSL.tar.gz
tar xzf NGINX.tar.gz
cd ../

# set where OpenSSL and nginx will be built
export BPATH=$(pwd)/build
export STATICLIBSSL="$BPATH/staticlibssl"

# build static openssl
cd $BPATH/$VERSION_OPENSSL
rm -rf "$STATICLIBSSL"
mkdir "$STATICLIBSSL"
make clean
./config --prefix=$STATICLIBSSL no-shared no-ssl2 no-ssl3 no-idea \
&& make depend \
&& make \
&& make install_sw

# rename the existing /etc/nginx directory so it's saved as a back-up
mv /etc/nginx /etc/nginx-$today

# build nginx, with various modules included/excluded
cd $BPATH/$VERSION_NGINX
mkdir -p $BPATH/nginx
./configure --with-cc-opt="-I $STATICLIBSSL/include -I/usr/include" \
--with-ld-opt="-L $STATICLIBSSL/lib -Wl,-rpath -lssl -lcrypto -ldl -lz" \
--with-pcre=$BPATH/$VERSION_PCRE \
--sbin-path=/usr/sbin/nginx \
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

# rename the compiled 'default' /etc/nginx directory so its accessible as a reference to the new nginx defaults
mv /etc/nginx /etc/nginx-default

# now restore the previous version of /etc/nginx to /etc/nginx so the old settings are kept
mv /etc/nginx-$today /etc/nginx

echo "All done.";
echo "This build has not edited your existing /etc/nginx directory.";
echo "If things aren't working now you may need to refer to the";
echo "configuration files the new nginx ships with as defaults,";
echo "which are available at /etc/nginx-default";

