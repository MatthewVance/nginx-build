# NGINX Build Script

This is an NGINX build script which compiles NGINX with a custom version of OpenSSL. It should work on other Debian-based Linux distros. 

The benefit of building from source is you can customize the modules to your needs and always use the latest versions of NGINX and OpenSSL. 

Compiling will take time, especially on a Raspberry Pi, so be patient.

## Usage

### Installation

1. `sudo mkdir /usr/local/src/nginx/`
2. `cd /usr/local/src/nginx/`
3. `sudo curl -L https://raw.githubusercontent.com/MatthewVance/nginx-build/master/build-nginx.sh -o build_nginx.sh`
4. `cat build_nginx.sh` (review downloaded code before executing)
5. `sudo chmod +x build_nginx.sh`
6. `sudo ./build_nginx.sh`
7. `sudo nginx`

### Upgrading

1. `cd /usr/local/src/nginx/`
2. `sudo rm /usr/local/src/nginx/build_nginx.sh`
3. `sudo curl -L https://raw.githubusercontent.com/MatthewVance/nginx-build/master/build-nginx.sh -o build_nginx.sh`
4. `cat build_nginx.sh` (review downloaded code before executing)
5. `sudo chmod +x build_nginx.sh`
6. `sudo kill -QUIT $( cat /var/run/nginx.pid )`
7. `sudo ./build_nginx.sh`
8. `sudo nginx`

## Issues

If you have any problems with or questions about this image, please contact me
through a [GitHub issue](https://github.com/MatthewVance/nginx-build/issues).

## Contributing

You are invited to contribute fixes and/or updates.

## Acknowledgments

The script was originally based on the [build_nginx.sh](https://gist.github.com/MattWilcox/402e2e8aa2e1c132ee24) script from [@MattWilcox](https://github.com/MattWilcox), but revised overtime to better fit my needs. You can find more details about the other Matt's version in his [blog post](https://mattwilcox.net/web-development/setting-up-a-secure-website-with-https-and-spdy-support-under-nginx-on-a-raspberry-pi).

## License

Unless otherwise specified, all code is released under the MIT License (MIT). See the [repository's `LICENSE` file](https://github.com/MatthewVance/nginx-build/blob/master/LICENSE) for details.

