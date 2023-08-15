#!/bin/bash
All_Path=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export All_Path

#脚本版本
Shell_Version="1.1.0"
#定义输出
Font_Green="\033[32m"
Font_Red="\033[31m"
Font_Blue="\033[34m"
Font_Yellow="\033[33m"
Back_Green="\033[42;37m"
Back_Red="\033[41;37m"
Font_None="\033[0m"
Info="${Font_Blue}[信息]${Font_None}"
Tip="${Font_Yellow}[注意]${Font_None}"
Error="${Font_Red}[错误]${Font_None}"
Success="${Font_Green}[信息]${Font_None}"
if [ ! -d /usr/lib/systemd/system ]; then
    Path_Ctl="/etc/systemd/system/socks5.service"
else
    Path_Ctl="/usr/lib/systemd/system/socks5.service"
fi

#Root用户
Get_User=$(env | grep USER | cut -d "=" -f 2)
if [ $EUID -ne 0 ] || [ ${Get_User} != "root" ]; then
    echo -e "{$Error} 请使用Root账户运行该脚本"
    exit 1
fi

#
function Check_Status() {
    Get_Pid=$(ps -ef| grep "socks5"| grep -v grep| grep -v ".sh"| grep -v "init.d"| grep -v "service"| awk '{print $2}')
}

#检查系统
function Check_System() {
    if [[ -f /etc/redhat-release ]]; then
        Release="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        Release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        Release="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        Release="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        Release="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        Release="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        Release="centos"
    fi
    Bit=$(uname -m)
    if test "$Bit" = "armv8l"; then
        Bit="arm64"
    elif test "$Bit" = "aarch64"; then
        Bit="arm64"
    elif test "$Bit" = "x86_64"; then
        Bit="x86_64"
    else
        echo -e "${Error} 抱歉 目前Gosocks5脚本仅支持x86_64,armv8l和aarch64架构"
        #echo -e "${Error} 抱歉 目前Gosocks5脚本仅支持x86_64架构"
        exit 1
    fi
}

#安装依赖
function Install_Dependence() {
    if [[ ${Release} == "centos" ]]; then
        yum update
        yum install -y sudo gzip wget curl crontabs vixie-cron net-tools jq git
    else
        apt-get update
        apt-get install -y sudo gzip wget curl cron net-tools jq git
    fi
}

#安装Golang V1.8
function Install_Golang() {
    go version &> /dev/null
    if [ $? -ne 0 ]; then
        if [ ! -d /etc/golang ]; then
            mkdir /etc/golang
        fi
        cd /etc/golang
        if [ ! -d /etc/golang/Go ]; then
            wget https://storage.googleapis.com/golang/go1.8.linux-amd64.tar.gz
            tar -xvf go1.8.linux-amd64.tar.gz
            mv go /etc/golang/Go
            rm go1.8.linux-amd64.tar.gz
            echo "
export GOROOT=/etc/golang/Go
export GOPATH=/etc/golang/Projects
export PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH" >> ~/.bash_profile
            export GOROOT=/etc/golang/Go
            export GOPATH=/etc/golang/Projects
            export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
        fi
        go version &> /dev/null
        if [ ! $? -ne 0 ]; then
            echo -e "${Success} 安装Golang  V1.8成功"
        else
            echo -e "${Error} 安装Golang失败 请尝试手动安装"
            exit 1
        fi
    else
        echo -e "${Tip} 检测到已存在Golang 跳过安装"
    fi
}

#安装Gosocks5
function Install_Socks5() {
    Install_Dependence
    #Install_Golang
    sleep 2s
    if hash socks5 2>/dev/null; then
        echo -e "${Error} 检测到已存在Gosocks5或其他Socks5 已停止安装"
        exit 1
    else
        echo -e "${Info} 正在安装Socks5 请耐心等待一段时间"
        wget https://github.com/0990/socks5/releases/download/v1.0.0/socks5_1.0.0_Linux_${Bit}.tar.gz
        if [ $? -ne 0 ]; then
            echo -e "${Error} 安装失败 请手动执行\"wget https://github.com/0990/socks5/releases/download/v1.0.0/socks5_1.0.0_Linux_${Bit}.tar.gz\"并检查错误"
            exit 1
        else
            mkdir /etc/gosocks5
            tar -xzvf socks5_1.0.0_Linux_${Bit}.tar.gz
            mv ss5 /etc/gosocks5/socks5
            mv ss5.json /etc/gosocks5/socks5.json
            chmod +x /etc/gosocks5 -R
            rm -rf socks5_1.0.0_Linux_${Bit}.tar.gz
            /etc/gosocks5/socks5 &> /dev/null 2&
			killall socks5
            if [ ! $? -ne 0 ]; then
                echo -e "${Success} 安装成功"
                sleep 3s
                Init_Socks5
            else
                echo -e "${Error} 启动Socks5失败 请手动执行\"/etc/gosocks5/socks5\"并检查错误"
                exit 1
            fi
        fi
    fi
}

#配置Socks5
function Init_Socks5() {
    read -p "请输入需要侦听的端口（默认1080）: " Read_Port
    if [ ! -n "$Read_Port" ]; then
        Read_Port="1080"
    fi
    Check_Port $Read_Port
    read -p "请输入用户名（为空则无认证）: " Read_User
    if [ ! -z  "$Read_User" ]; then
        read -p "请输入该用户名的密码: " Read_Pwd
        sed -i "s/\"ListenPort\": 1080/\"ListenPort\": ${Read_Port}/g" /etc/gosocks5/socks5.json
        sed -i "s/\"UserName\": \"\"/\"UserName\": \"${Read_User}\"/g" /etc/gosocks5/socks5.json
        sed -i "s/\"Password\": \"\"/\"Password\": \"${Read_Pwd}\"/g" /etc/gosocks5/socks5.json
    else
        sed -i "s/\"ListenPort\": 1080/\"ListenPort\": ${Read_Port}/g" /etc/gosocks5/socks5.json
    fi
    echo "
[Unit]
Description=socks5

[Service]
Restart=always
RestartSec=5
ExecStart=/etc/gosocks5/socks5 -c /etc/gosocks5/socks5.json

[Install]
WantedBy=multi-user.target" > socks5.service
    mv socks5.service ${Path_Ctl}
    systemctl daemon-reload
    systemctl start socks5
    systemctl enable socks5
    echo -e "${Success} Socks5配置成功并已启动"
    exit 1
}

#卸载Socks5
function Uninstall_Socks5() {
    if test -o ${Path_Ctl} -o /etc/gosocks5/socks5;then
        systemctl stop socks5.service
        systemctl disable socks5.service
        rm -rf /etc/gosocks5
        rm -rf ${Path_Ctl}
        echo -e "${Success} 成功卸载 Socks5 "
        sleep 3s
        Show_Menu
    else
        echo -e "${Error} 未安装 Socks5"
        sleep 3s
        Show_Menu
    fi
}

#启动socks5
function Start_Socks5() {
    systemctl start socks5
    echo -e "${Success} 成功启动 Socks5"
    sleep 3s
    Show_Menu
}

#停止socks5
function Stop_Socks5() {
    systemctl stop socks5
    echo -e "${Success} 成功停止 Socks5"
    sleep 3s
    Show_Menu
}

#重启socks5
function Restart_Socks5() {
    systemctl restart socks5
    echo -e "${Success} 成功重启 Socks5"
    sleep 3s
    Show_Menu
}

#查看配置
function Show_Config() {
    echo -e "${Info} 正在获取配置中"
    Get_Port=$(sed -n '2 p' /etc/gosocks5/socks5.json | grep -o -P '(?<="ListenPort": ).*(?=,)')
    Get_User=$(sed -n '6 p' /etc/gosocks5/socks5.json | grep -o -P '(?<="UserName": ").*(?=")')
    Get_Pwd=$(sed -n '7 p' /etc/gosocks5/socks5.json | grep -o -P '(?<="Password": ").*(?=")')
    sleep 1s
    echo -e "—————————————————————————————————————————
    获取Socks5配置完成 !\n
    本地监听端口: ${Font_Green}${Get_Port}${Font_None}
    认证用户名\t: ${Font_Green}${Get_User}${Font_None}
    认证密码\t: ${Font_Green}${Get_Pwd}${Font_None}
—————————————————————————————————————————"
}
    

#检测端口
function Check_Port() {
    if hash netstat 2>/dev/null; then
        if [ ! -n "$1" ]; then
            echo -e "${Error} 未传入端口"
            exit 1
        else
            Get_Port_Info=$(netstat -nap | grep LISTEN | grep "$1")
            if [ ! -z "$Get_Port_Info" ]; then
                echo -e "${Error} 端口[$1]已被占用"
                exit 1
            fi
        fi
    else
        echo -e "${Error} Netstat组件丢失，请手动安装net-tools后重新运行脚本"
        exit 1
    fi
}

#更新脚本
function Update_Shell() {
    echo -e "${Info} 当前版本为 [ ${Shell_Version} ]，开始检测最新版本..."
    Shell_NewVer=$(wget --no-check-certificate -qO- "https://github.weifeng.workers.dev/https://github.com/wf-nb/Gosocks5/blob/latest/Gosocks5.sh"|grep 'Shell_Version="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1)
    [[ -z ${Shell_NewVer} ]] && echo -e "${Error} 检测最新版本失败" && Show_Menu
    if [ $(awk -v Shell_NewVer="$Shell_NewVer" -v Shell_Version="$Shell_Version"  'BEGIN{print(Shell_NewVer>Shell_Version)?"1":"0"}') ]; then
        echo -e "${Info} 发现新版本[ ${Shell_NewVer} ]，是否更新？[Y/n]"
        read -p "(默认: Y):" Read_YN
        [[ -z "${Read_YN}" ]] && Read_YN="Y"
        if [[ ${Read_YN} == [Yy] ]]; then
            wget -N --no-check-certificate https://github.weifeng.workers.dev/https://github.com/wf-nb/Gosocks5/blob/latest/Gosocks5.sh && chmod +x socks5.sh
            echo -e "${Success} 脚本已更新为最新版本[ ${Shell_NewVer} ]"
            sleep 3s
            Show_Menu
        else
            echo -e "${Success} 已取消..."
            sleep 3s
            Show_Menu
        fi
    else
        echo -e "${Info} 当前已是最新版本[ ${Shell_Version} ]"
        sleep 3s
        Show_Menu
    fi
}

#脚本菜单
function Show_Menu() {
    echo -e "          Gosocks5"${Font_red}[${Shell_Version}]${Font_None}"
  ----------- Weifeng -----------
  特性: (1)本脚本采用systemd及命令行对Socks5进行管理
        (2)能够在不借助其他工具(如screen)的情况下实现后台运行
        (3)机器reboot后Socks5会自动启动

 ${Font_Green}1.${Font_None} 安装    Socks5
 ${Font_Green}2.${Font_None} 卸载    Socks5
————————————
 ${Font_Green}3.${Font_None} 启动    Socks5
 ${Font_Green}4.${Font_None} 停止    Socks5
 ${Font_Green}5.${Font_None} 重启    Socks5
————————————
 ${Font_Green}6.${Font_None} 查看 Socks5 配置
 ${Font_Green}7.${Font_None} 更新Gosocks5脚本
————————————" && echo
    if [[ -e "/etc/gosocks5/socks5" ]]; then
        Check_Status
        if [ ! -z "$Get_Pid" ]; then
            echo -e " 当前状态: Socks5 ${Font_Green}已安装${Font_None} 并 ${Font_Green}已启动${Font_None}"
        else
            echo -e " 当前状态: Socks5 ${Font_Green}已安装${Font_None} 但 ${Font_Red}未启动${Font_None}"
        fi
    else
        echo -e " 当前状态: Socks5 ${Font_Red}未安装${Font_None}"
    fi
    read -e -p " 请输入数字 [1-7]:" Read_Num
    case "$Read_Num" in
    1)
        Install_Socks5
    ;;
    2)
        Uninstall_Socks5
    ;;
    3)
        Start_Socks5
    ;;
    4)
        Stop_Socks5
    ;;
    5)
        Restart_Socks5
    ;;
    6)
        Show_Config
    ;;
    7)
        Update_Shell
    ;;
    *)
        echo "请输入正确数字 [1-7]"
    ;;
    esac
}

Check_System
Show_Menu
