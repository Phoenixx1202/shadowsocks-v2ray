#!/bin/sh

# Verifique o sistema
if [ ! -f /etc/lsb-release ];then
    if ! grep -Eqi "ubuntu|debian" /etc/issue;then
        echo "\033[1;31mApenas Ubuntu ou Debian podem executar este shell.\033[0m"
        exit 1
    fi
fi

# Certifique-se de que apenas o root pode executar nosso script
[ `whoami` != "root" ] && echo "\033[1;31mEste script deve ser executado como root.\033[0m" && exit 1

# Versão
LIBSODIUM_VER=stable
MBEDTLS_VER=2.16.5
ss_file=0
v2_file=0
get_latest_ver(){
    ss_file=$(wget -qO- https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest | grep name | grep tar | cut -f4 -d\")
    v2_file=$(wget -qO- https://api.github.com/repos/shadowsocks/v2ray-plugin/releases/latest | grep linux-amd64 | grep name | cut -f4 -d\")
}

# Definir senha de configuração shadowocks-libev
set_password(){
    echo "\033[1;34mPor favor, digite a senha para shadowsocks-libev:\033[0m"
    read -p "(Senha padrão: Phoenix1203):" shadowsockspwd
    [ -z "${shadowsockspwd}" ] && shadowsockspwd="Phoenix1203"
    echo "\033[1;35mpassword = ${shadowsockspwd}\033[0m"
}

# Definir domínio
set_domain(){
    echo "\033[1;34mPor favor, insira o seu domínio:\033[0m"
    echo "Se você não tiver um, pode registrar um gratuitamente em:"
    echo "https://my.freenom.com/clientarea.php"
    read domain
    str=`echo $domain | grep '^\([a-zA-Z0-9_\-]\{1,\}\.\)\{1,\}[a-zA-Z]\{2,5\}'`
    while [ ! -n "${str}" ]
    do
        echo "\033[1;31mDomínio inválido.\033[0m"
        echo "\033[1;31mPor favor, tente novamente:\033[0m"
        read domain
        str=`echo $domain | grep '^\([a-zA-Z0-9_\-]\{1,\}\.\)\{1,\}[a-zA-Z]\{2,5\}'`
    done
    echo "\033[1;35mdomain = ${domain}\033[0m"
}

# Pré-instalação
pre_install(){
    read -p "Pressione qualquer tecla para iniciar a instalação." a
    echo "\033[1;34mComeçando a instalar. Isso pode demorar um pouco.\033[0m"
    apt-get update
    apt-get install -y --no-install-recommends gettext build-essential autoconf libtool libpcre3-dev asciidoc xmlto libev-dev libc-ares-dev automake
}


# Instalação do Libsodium
install_libsodium(){
    if [ -f /usr/lib/libsodium.a ] || [ -f /usr/lib64/libsodium.a ];then
        echo "\033[1;32mLibsodium já instalado, pule.\033[0m"
    else
        if [ ! -f libsodium-$LIBSODIUM_VER.tar.gz ];then
            wget https://download.libsodium.org/libsodium/releases/LATEST.tar.gz -O libsodium-$LIBSODIUM_VER.tar.gz
        fi
        tar xf libsodium-$LIBSODIUM_VER.tar.gz
        cd libsodium-$LIBSODIUM_VER
        ./configure --prefix=/usr && make
        make install
        cd ..
        ldconfig
        if [ ! -f /usr/lib/libsodium.a ] && [ ! -f /usr/lib64/libsodium.a ];then
            echo "\033[1;31mFalha ao instalar libsodium.\033[0m"
            exit 1
        fi
    fi
}


# Instalação de MbedTLS
install_mbedtls(){
    if [ -f /usr/lib/libmbedtls.a ];then
        echo "\033[1;32mMbedTLS já instalado, pule.\033[0m"
    else
        if [ ! -f mbedtls-$MBEDTLS_VER-gpl.tgz ];then
            wget https://tls.mbed.org/download/mbedtls-$MBEDTLS_VER-gpl.tgz
        fi
        tar xf mbedtls-$MBEDTLS_VER-gpl.tgz
        cd mbedtls-$MBEDTLS_VER
        make SHARED=1 CFLAGS=-fPIC
        make DESTDIR=/usr install
        cd ..
        ldconfig
        if [ ! -f /usr/lib/libmbedtls.a ];then
            echo "\033[1;31mFalha ao instalar MbedTLS.\033[0m"
            exit 1
        fi
    fi
}


# Instalação de shadowocks-libev
install_ss(){
    if [ -f /usr/local/bin/ss-server ];then
        echo "\033[1;32mShadowsocks-libev já instalado, pule.\033[0m"
    else
        if [ ! -f $ss_file ];then
            ss_url=$(wget -qO- https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest | grep browser_download_url | cut -f4 -d\")
            wget $ss_url
        fi
        tar xf $ss_file
        cd $(echo ${ss_file} | cut -f1-3 -d\.)
        ./configure && make
        make install
        cd ..
        if [ ! -f /usr/local/bin/ss-server ];then
            echo "\033[1;31mFalha ao instalar shadowocks-libev.\033[0m"
            exit 1
        fi
    fi
}


# Instalação do plugin v2ray
install_v2(){
    if [ -f /usr/local/bin/v2ray-plugin ];then
        echo "\033[1;32mplugin v2ray já instalado, pular.\033[0m"
    else
        if [ ! -f $v2_file ];then
            v2_url=$(wget -qO- https://api.github.com/repos/shadowsocks/v2ray-plugin/releases/latest | grep linux-amd64 | grep browser_download_url | cut -f4 -d\")
            wget $v2_url
        fi
        tar xf $v2_file
        mv v2ray-plugin_linux_amd64 /usr/local/bin/v2ray-plugin
        if [ ! -f /usr/local/bin/v2ray-plugin ];then
            echo "\033[1;31mFalha ao instalar o plugin v2ray.\033[0m"
            exit 1
        fi
    fi
}

# Configurar
ss_conf(){
    mkdir /etc/shadowsocks-libev
    cat >/etc/shadowsocks-libev/config.json << EOF
{
    "server":"0.0.0.0",
    "server_port":443,
    "password":"$shadowsockspwd",
    "timeout":300,
    "method":"aes-256-gcm",
    "plugin":"v2ray-plugin",
    "plugin_opts":"server;tls;cert=/etc/letsencrypt/live/$domain/fullchain.pem;key=/etc/letsencrypt/live/$domain/privkey.pem;host=$domain;loglevel=none"
}
EOF
    cat >/lib/systemd/system/shadowsocks.service << EOF
[Unit]
Description=Shadowsocks-libev Server Service
After=network.target
[Service]
ExecStart=/usr/local/bin/ss-server -c /etc/shadowsocks-libev/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
}

get_cert(){
    if [ -f /etc/letsencrypt/live/$domain/fullchain.pem ];then
        echo "\033[1;32mcertificado já obtido, pule.\033[0m"
    else
        apt-get update
        if grep -Eqi "ubuntu" /etc/issue;then
            apt-get install -y software-properties-common
            add-apt-repository -y universe
            add-apt-repository -y ppa:certbot/certbot
            apt-get update
        fi
        apt-get install -y certbot 
        certbot certonly --cert-name $domain -d $domain --standalone --agree-tos --register-unsafely-without-email
        systemctl enable certbot.timer
        systemctl start certbot.timer
        if [ ! -f /etc/letsencrypt/live/$domain/fullchain.pem ];then
            echo "\033[1;31mFalha ao obter certificado.\033[0m"
            exit 1
        fi
    fi
}

start_ss(){
    systemctl status shadowsocks > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        systemctl stop shadowsocks
    fi
    systemctl enable shadowsocks
    systemctl start shadowsocks
}

remove_files(){
    rm -f libsodium-$LIBSODIUM_VER.tar.gz mbedtls-$MBEDTLS_VER-gpl.tgz $ss_file $v2_file
    rm -rf libsodium-$LIBSODIUM_VER mbedtls-$MBEDTLS_VER $(echo ${ss_file} | cut -f1-3 -d\.)
}

print_ss_info(){
    clear
    echo "\033[1;32mParabéns, instalação do servidor Shadowsocks-libev concluída\033[0m"
    echo "IP do seu servidor         :  ${domain} "
    echo "Porta do seu servidor      :  443 "
    echo "Sua senha                  :  ${shadowsockspwd} "
    echo "Seu método de criptografia :  aes-256-gcm "
    echo "Seu Plugin                 :  v2ray-plugin"
    echo "Suas opções de plug-in     :  tls;host=${domain}"
    echo "aproveite!"
}

install_all(){
    set_password
    set_domain
    pre_install
    install_libsodium
    install_mbedtls
    get_latest_ver
    install_ss
    install_v2
    ss_conf
    get_cert
    start_ss
    remove_files
    print_ss_info
}

remove_all(){
    systemctl disable shadowsocks
    systemctl stop shadowsocks
    rm -fr /etc/shadowsocks-libev
    rm -f /usr/local/bin/ss-local
    rm -f /usr/local/bin/ss-tunnel
    rm -f /usr/local/bin/ss-server
    rm -f /usr/local/bin/ss-manager
    rm -f /usr/local/bin/ss-redir
    rm -f /usr/local/bin/ss-nat
    rm -f /usr/local/bin/v2ray-plugin
    rm -f /usr/local/lib/libshadowsocks-libev.a
    rm -f /usr/local/lib/libshadowsocks-libev.la
    rm -f /usr/local/include/shadowsocks.h
    rm -f /usr/local/lib/pkgconfig/shadowsocks-libev.pc
    rm -f /usr/local/share/man/man1/ss-local.1
    rm -f /usr/local/share/man/man1/ss-tunnel.1
    rm -f /usr/local/share/man/man1/ss-server.1
    rm -f /usr/local/share/man/man1/ss-manager.1
    rm -f /usr/local/share/man/man1/ss-redir.1
    rm -f /usr/local/share/man/man1/ss-nat.1
    rm -f /usr/local/share/man/man8/shadowsocks-libev.8
    rm -fr /usr/local/share/doc/shadowsocks-libev
    rm -f /usr/lib/systemd/system/shadowsocks.service
    echo "\033[1;32mRemovido com Sucesso!\033[0m"
}

clear
echo "O que você quer fazer?"
echo "[1] Instalar"
echo "[2] Remover"
read -p "(Opção padrão: Instalar):" option
option=${option:-1}
if [ $option -eq 2 ];then
    remove_all
else
    install_all
fi
