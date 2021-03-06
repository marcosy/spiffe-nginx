#!/bin/bash

declare -r NGINX_VERSION="1.13.9"
declare -r NGINX_URL="http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"

set -e
[[ $DEBUG ]] && set -x

ngx_tar=.cache/$(basename ${NGINX_URL})
ngx_dir=nginx-${NGINX_VERSION}
ngx_modules=objs/ngx_modules.c

setup_nginx() {
	mkdir -p /usr/local/nginx/html
	cp spiffe-support/index.html /usr/local/nginx/html

	mkdir -p .cache
	if [[ ! -r ${ngx_tar} ]]; then
		curl --progress-bar --location --output ${ngx_tar} ${NGINX_URL}
	fi
	if [[ ! -d ${ngx_dir} ]]; then
		tar -xzf ${ngx_tar}
	fi
	cp -rvp spiffe-support/* ${ngx_dir}

	cd ngx_http_fetch_spiffe_certs_module
	protoc --grpc_out=. --plugin=protoc-gen-grpc=`which grpc_cpp_plugin` workload.proto
	protoc --cpp_out=. workload.proto
	cd ..
}

update_nginx_modules() {
	pwd
	sed -i '/ngx_http_fetch_spiffe_certs_module/d' ${ngx_modules}
	sed -i '/extern ngx_module_t  ngx_http_ssl_module;/i \extern ngx_module_t  ngx_http_fetch_spiffe_certs_module; \' ${ngx_modules}
	sed -i '/&ngx_http_ssl_module,/i \    &ngx_http_fetch_spiffe_certs_module, \' ${ngx_modules}
	sed -i '/"ngx_http_ssl_module",/i \    "ngx_http_fetch_spiffe_certs_module", \' ${ngx_modules}
}

case $1 in
	configure)
		setup_nginx
		cd ${ngx_dir}
		set -x
		./configure $_config \
			--with-cc-opt="-fPIE" --with-ld-opt="-fpie -static" \
			--with-debug \
			--with-http_ssl_module \
			--add-module=/opt/nginx-dev/ngx_http_fetch_spiffe_certs_module
		set +x
		update_nginx_modules
		;;
	make)
		set -x
		setup_nginx
		cd ${ngx_dir}
		make
		cp objs/nginx ..
		set +x
		;;
	clean)
		rm -rf ${ngx_dir}
		setup_nginx
		;;
esac
