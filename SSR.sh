PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

clear
echo
echo 
echo "#############################################################"
echo "一键安装shadowsocksr服务器"
echo "系统要求:  CentOS 6,7, Debian, Ubuntu"
echo "#############################################################"

#获取当前路径
cur_dir=`pwd`

#确保ROOT权限
rootness(){
    if [[ $EUID -ne 0 ]]; then
       echo "Error: 此脚本必须以root身份运行！" 1>&2
       exit 1
    fi
}

#禁用SElinux
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

#判定操作系统
check_sys(){
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    elif cat /proc/version | grep -q -E -i "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ ${checkType} == "sysRelease" ]]; then
        if [ "$value" == "$release" ]; then
            return 0
        else
            return 1
        fi
    elif [[ ${checkType} == "packageManager" ]]; then
        if [ "$value" == "$systemPackage" ]; then
            return 0
        else
            return 1
        fi
    fi
}

#获取版本
getversion(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

#CentOS 版本
centosversion(){
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

#获取IP地址
get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

#预安装设置
pre_install(){
    if check_sys packageManager yum || check_sys packageManager apt; then
        #不支持CentOS 5
        if centosversion 5; then
            echo "Error:不支持CentOS 5,请在CentOS 6+/Debian 7+/Ubuntu 12+系统中再次尝试安装。"
            exit 1
        fi
    else
        echo "Error:暂不支持您的操作系统。请在CentOS 6+/Debian 7+/Ubuntu 12+系统中再次尝试安装。"
        exit 1
    fi
    #设置ShadowsocksR密码
    echo "请输入要设置SSR的密码:"
    read -p "(密码默认: q123123):" shadowsockspwd
    [ -z "${shadowsockspwd}" ] && shadowsockspwd="q123123"
    echo
    echo "---------------------------"
    echo "password = ${shadowsockspwd}"
    echo "---------------------------"
    echo
    #设置ShadowsocksR端口
    while true
    do
    echo -e "请输入ssr端口 [1-65535]:"
    read -p "(默认端口: 1024):" shadowsocksport
    [ -z "${shadowsocksport}" ] && shadowsocksport="1024"
    expr ${shadowsocksport} + 0 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ ${shadowsocksport} -ge 1 ] && [ ${shadowsocksport} -le 65535 ]; then
            echo
            echo "---------------------------"
            echo "port = ${shadowsocksport}"
            echo "---------------------------"
            echo
            break
        else
            echo "输入错误，请输入正确的数字"
        fi
    else
        echo "输入错误，请输入正确的数字"
    fi
    done
    get_char(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
    }
    echo
    echo "按任意键开始安装…或按Ctrl + C取消安装"
    char=`get_char`
    #安装必要的依赖项
    if check_sys packageManager yum; then
        yum install -y unzip openssl-devel gcc swig python python-devel python-setuptools autoconf libtool libevent automake make curl curl-devel zlib-devel perl perl-devel cpio expat-devel gettext-devel
    elif check_sys packageManager apt; then
        apt-get -y update
        apt-get -y install python python-dev python-pip python-m2crypto curl wget unzip gcc swig automake make perl cpio build-essential
    fi
    cd ${cur_dir}
}

#下载文件
download_files(){
    #下载libsodium
    if ! wget --no-check-certificate -O libsodium-1.0.11.tar.gz https://github.com/emperorxu/SSR/libsodium-1.0.11.tar.gz; then
        echo "libsodium-1.0.11.tar.gz下载失败!"
        exit 1
    fi
    #下载ShadowsocksR
    if ! wget --no-check-certificate -O manyuser.zip https://github.com/emperorxu/SSR/shadowsocks-manyuser.zip; then
        echo "ShadowsocksR下载失败!"
        exit 1
    fi
    #下载ShadowsocksR init脚本
    if check_sys packageManager yum; then
        if ! wget --no-check-certificate https://github.com/emperorxu/SSR/shadowsocksr -O /etc/init.d/shadowsocks; then
            echo "ShadowsocksR chkconfig下载失败!"
            exit 1
        fi
    elif check_sys packageManager apt; then
        if ! wget --no-check-certificate https://github.com/emperorxu/SSR/shadowsocksr/debian -O /etc/init.d/shadowsocks; then
            echo "ShadowsocksR chkconfig下载失败!"
            exit 1
        fi
    fi
}

#防火墙配置
firewall_set(){
    echo "开始配置防火墙..."
    if centosversion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep -i ${shadowsocksport} > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${shadowsocksport} -j ACCEPT
                iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${shadowsocksport} -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo "端口 ${shadowsocksport} 已配置."
            fi
        else
            echo "WARNING: iptables 已关闭或未安装, 如需请手动配置."
        fi
    elif centosversion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/tcp
            firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/udp
            firewall-cmd --reload
        else
            echo "Firewalld 似乎未在运行, 尝试启动..."
            systemctl start firewalld
            if [ $? -eq 0 ]; then
                firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/tcp
                firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/udp
                firewall-cmd --reload
            else
                echo "WARNING: firewalld 启动失败. 如果需要，请手动启用端口 ${shadowsocksport} ."
            fi
        fi
    fi
    echo "防火墙配置完成..."
}

#配置ShadowsocksR
config_shadowsocks(){
    cat > /etc/shadowsocks.json<<-EOF
{
    "server":"0.0.0.0",
    "server_ipv6":"::",
    "server_port":${shadowsocksport},
    "local_address":"127.0.0.1",
    "local_port":1080,
    "udp_timeout": 60,
    "password":"${shadowsockspwd}",
    "timeout":120,
    "method":"chacha20",
    "protocol":"origin",
    "protocol_param":"",
    "obfs":"http_simple",
    "obfs_param":"",
    "redirect":"",
    "connect_verbose_info": 1,
    "dns_ipv6":false,
    "fast_open":false,
    "workers":1
}
EOF
}

#安装ShadowsocksR
install(){
    #安装libsodium
    tar zxf libsodium-1.0.11.tar.gz
    cd libsodium-1.0.11
    ./configure && make && make install
    if [ $? -ne 0 ]; then
        echo "libsodium安装失败"
        install_cleanup
        exit 1
    fi
    echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf
    ldconfig
    #安装ShadowsocksR
    cd ${cur_dir}
    unzip -q manyuser.zip
    mv shadowsocks-manyuser/shadowsocks /usr/local/
    if [ -f /usr/local/shadowsocks/server.py ]; then
        chmod +x /etc/init.d/shadowsocks
        if check_sys packageManager yum; then
            chkconfig --add shadowsocks
            chkconfig shadowsocks on
        elif check_sys packageManager apt; then
            update-rc.d -f shadowsocks defaults
        fi
        /etc/init.d/shadowsocks start

        clear
        echo
        echo "Congratulations, ShadowsocksR install completed!"
        echo -e "Server IP: \033[41;37m $(get_ip) \033[0m"
        echo -e "Server Port: \033[41;37m ${shadowsocksport} \033[0m"
        echo -e "Password: \033[41;37m ${shadowsockspwd} \033[0m"
        echo -e "Local IP: \033[41;37m 127.0.0.1 \033[0m"
        echo -e "Local Port: \033[41;37m 1080 \033[0m"
        echo -e "Protocol: \033[41;37m origin \033[0m"
        echo -e "obfs: \033[41;37m http_simple \033[0m"
        echo -e "Encryption Method: \033[41;37m chacha20 \033[0m"
        echo
        echo "SSR安装成功!"
        echo
    else
        echo "SSR安装失败!"
        install_cleanup
        exit 1
    fi
}

#清理安装
install_cleanup(){
    cd ${cur_dir}
    rm -rf manyuser.zip shadowsocks-manyuser libsodium-1.0.11.tar.gz libsodium-1.0.11
}


#卸载ShadowsocksR
uninstall_shadowsocks(){
    printf "确定卸载 ShadowsocksR? (y/n)"
    printf "\n"
    read -p "(Default: n):" answer
    [ -z ${answer} ] && answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        /etc/init.d/shadowsocks status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            /etc/init.d/shadowsocks stop
        fi
        if check_sys packageManager yum; then
            chkconfig --del shadowsocks
        elif check_sys packageManager apt; then
            update-rc.d -f shadowsocks remove
        fi
        rm -f /etc/shadowsocks.json
        rm -f /etc/init.d/shadowsocks
        rm -f /var/log/shadowsocks.log
        rm -rf /usr/local/shadowsocks
        echo "ShadowsocksR卸载成功!"
    else
        echo
        echo "卸载取消..."
        echo
    fi
}

#安装ShadowsocksR
install_shadowsocks(){
    rootness
    disable_selinux
    pre_install
    download_files
    config_shadowsocks
    install
    if check_sys packageManager yum; then
        firewall_set
    fi
    install_cleanup
}

#初始化
action=$1
[ -z $1 ] && action=install
case "$action" in
    install|uninstall)
    ${action}_shadowsocks
    ;;
    *)
    echo "变量错误! [${action}]"
    echo "Usage: `basename $0` {install|uninstall}"
    ;;
esac
