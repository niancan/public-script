#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#=================================================
#	System Required: CentOS 6+/Debian 6+/Ubuntu 14.04+
#	Description: Install the ShadowsocksR mudbjson server
#=================================================
sh_ver="1.0.0"

filepath=$(cd "$(dirname "$0")"; pwd)  #home目录
file=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')	#home目录

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Blue_font_prefix="\033[35m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"

Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Blue_font_prefix}[注意]${Font_color_suffix}"
Separator_1="——————————————————————————————"
Separator_2="===================================================================================="

## ssr setting info
ssr_folder="${HOME}/shadowsocksr"
config_user_api_file="${ssr_folder}/userapiconfig.py"
ssr_log_file="${ssr_folder}/ssserver.log"

## sodiumr setting info
Libsodiumr_file="/usr/local/lib/libsodium.so"
Libsodiumr_ver_backup="1.0.18"

## other setting info
Server_Speeder_file="/serverspeeder/bin/serverSpeeder.sh"
LotServer_file="/appex/bin/serverSpeeder.sh"
BBR_file="${file}/tcp.sh"
speed_file="${file}/LemonBench.sh"




#======================检查root===========================

check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前账号非ROOT(或没有ROOT权限)，无法继续操作，请使用${Green_background_prefix} sudo su ${Font_color_suffix}来获取临时ROOT权限（执行后会提示输入当前账号的密码）。" && exit 1
}

#======================获取 IP===========================
Get_IP(){
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ip}" ]]; then
		ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ip}" ]]; then
				ip="VPS_IP"
			fi
		fi
	fi
}
#======================安装 依赖===========================
Installation_dependency(){
	if [[ ${release} == "centos" ]]; then
		Centos_yum
	else
		Debian_apt
	fi
	Check_python
	#echo "nameserver 8.8.8.8" > /etc/resolv.conf
	#echo "nameserver 8.8.4.4" >> /etc/resolv.conf
	#设置时区
	#\cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	echo "设置 system timezone(时区)..."
	timedatectl set-timezone Asia/Taipei && systemctl stop ntpd.service && ntpdate us.pool.ntp.org
}
#======================Centos 依赖===========================
Centos_yum(){
	yum update
	yum install -y vim net-tools git ntp
}
#======================Debian 依赖===========================
Debian_apt(){
	apt-get update
	cat /etc/issue |grep 9\..*>/dev/null
	if [[ $? = 0 ]]; then
		apt-get install -y vim unzip cron net-tools
	else
		apt-get install -y vim unzip cron
	fi
}
#======================python 依赖===========================
Check_python(){
	python_ver=`python -h`
	if [[ -z ${python_ver} ]]; then
		echo -e "${Info} 没有安装Python，开始安装..."
		if [[ ${release} == "centos" ]]; then
			yum install -y python python-pip
		else
			apt-get install -y python python-pip
		fi
	fi
}
#======================检查系统===========================
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	bit=`uname -m`
}
#======================安装SSR===========================
Install_SSR(){

	echo ${Separator_1} &&echo "请输入 node_id"
	read -e -p "(默认: 0):" ssr_node_id
	[[ -z "${ssr_node_id}" ]] && ssr_node_id=0
	echo && echo ${Separator_1} && echo -e "	node_id : ${Green_font_prefix}${ssr_node_id}${Font_color_suffix}" && echo ${Separator_1} && echo

	check_root
	[[ -e ${ssr_folder} ]] && echo -e "${Error} ShadowsocksR 文件夹已存在，请检查( 如安装失败或者存在旧版本，请先卸载 ) !" && exit 1

	echo -e "${Info} 开始安装/配置 ShadowsocksR依赖..."
	
	Installation_dependency

	if [[ -e ${Libsodiumr_file} ]]; then
		echo -e "${Red_font_prefix}libsodium 已安装${Font_color_suffix}"
	else
		Install_Libsodium
	fi
	
	echo -e "${Info} 开始下载/安装 ShadowsocksR文件..."
	Download_SSR
	echo -e "${Info} 所有步骤 安装完毕，开始启动 ShadowsocksR服务端..."
	Start_SSR
}
#======================卸载SSR===========================
Uninstall_SSR(){
	[[ ! -e ${ssr_folder} ]] && echo -e "${Error} 没有安装 ShadowsocksR，请检查 !" && exit 1
	echo "确定要 卸载ShadowsocksR？[y/N]" && echo
	read -e -p "(默认: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_pid
		[[ ! -z "${PID}" ]] && kill -9 ${PID}
		rm -rf ${ssr_folder}
		echo && echo " ShadowsocksR 卸载完成 !" && echo
	else
		echo && echo " 卸载已取消..." && echo
	fi
}
#======================检查 ShadowsocksR状态===========================
SSR_installation_status(){
	[[ ! -e ${ssr_folder} ]] && echo -e "${Error} 没有发现 ShadowsocksR 文件夹，请检查 !" && exit 1
}
#======================启动 ShadowsocksR===========================
Start_SSR(){
	SSR_installation_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Error} ShadowsocksR 正在运行 !" && exit 1
	
	python_ver="python"
	ulimit -n 512000
	nohup "${python_ver}" "${ssr_folder}/server.py" a >> ssserver.log 2>&1 &
	sleep 2s
	check_pid
	if [[ ! -z "${PID}" ]]; then
		echo -e "${Info_font_prefix}[信息]${Font_suffix} ShadowsocksR 启动成功 !"
	else
		echo -e "${Error_font_prefix}[错误]${Font_suffix} ShadowsocksR 启动失败 !" && exit 1
	fi
}
#======================停止 ShadowsocksR===========================
Stop_SSR(){
	SSR_installation_status
	check_pid
	[[ -z ${PID} ]] && echo -e "${Error} ShadowsocksR 未运行 !" && exit 1
	[[ ! -z "${PID}" ]] && kill -9 ${PID} 
	echo -e “${Info} ShadowsocksR 已停止”
}
#======================重启 ShadowsocksR===========================
Restart_SSR(){
	SSR_installation_status
	check_pid
	Stop_SSR
	Start_SSR
}
#======================查看 ShadowsocksR 日志===========================
View_Log(){
	SSR_installation_status
	[[ ! -e ${ssr_log_file} ]] && echo -e "${Error} ShadowsocksR日志文件不存在 !" && exit 1
	echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} 终止查看日志" && echo -e "如果需要查看完整日志内容，请用 ${Red_font_prefix}cat ${ssr_log_file}${Font_color_suffix} 命令。" && echo
	tail -f ${ssr_log_file}
}

#======================获取 ShadowsocksR 进程ID===========================
check_pid(){
	PID=`ps -ef |grep -v grep | grep server.py |awk '{print $2}'`
}
#======================下载 ShadowsocksR===========================
Download_SSR(){

	cd /tmp && git clone https://manlove@bitbucket.org/NianCan/nimaqu-shadowsocksr.git shadowsocksr
	[[ ! -e "shadowsocksr" ]] && echo -e "${Error} ShadowsocksR服务端 下载失败 !" && exit 1
	mv -f shadowsocksr ${HOME}
	cd ${ssr_folder}
	
	pip install --upgrade pip setuptools
	pip install -r requirements.txt
	
	bash init.sh ${ssr_node_id}
	
	
	echo -e "${Info} ShadowsocksR服务端 下载完成 !"
}
#=======================监控ssr状态==========================
Set_crontab_monitor_ssr(){
	echo -e "功能未实现
	—— 说明：该功能适合于SSR服务端经常进程结束，启动该功能后会每分钟检测一次，当进程不存在则自动启动SSR服务端。"
}


#=======================安装BBR==========================
Install_BBR(){
	BBR_installation_status
	bash "${BBR_file}"
}

#=======================下载BBR脚本==========================
BBR_installation_status(){
	if [[ ! -e ${BBR_file} ]]; then
		echo -e "${Error} 没有发现 BBR脚本，开始下载..."
		cd "${file}"
		if ! wget -N --no-check-certificate https://github.com/cx9208/Linux-NetSpeed/raw/master/tcp.sh; then
			echo -e "${Error} BBR 脚本下载失败 !" && exit 1
		else
			echo -e "${Info} BBR 脚本下载完成 !"
			chmod +x bbr.sh
		fi
	fi
}

#=======================锐速操作==========================
Configure_Server_Speeder(){
	echo && echo -e "
 ${Green_font_prefix}1.${Font_color_suffix} 安装 锐速
 ${Green_font_prefix}2.${Font_color_suffix} 卸载 锐速
————————
 ${Green_font_prefix}3.${Font_color_suffix} 启动 锐速
 ${Green_font_prefix}4.${Font_color_suffix} 停止 锐速
 ${Green_font_prefix}5.${Font_color_suffix} 重启 锐速
 ${Green_font_prefix}6.${Font_color_suffix} 查看 锐速 状态
 
 注意： 锐速和LotServer不能同时安装/启动！" && echo
	read -e -p "(默认: 取消):" server_speeder_num
	[[ -z "${server_speeder_num}" ]] && echo "已取消..." && exit 1
	if [[ ${server_speeder_num} == "1" ]]; then
		Install_ServerSpeeder
	elif [[ ${server_speeder_num} == "2" ]]; then
		Server_Speeder_installation_status
		Uninstall_ServerSpeeder
	elif [[ ${server_speeder_num} == "3" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} start
		${Server_Speeder_file} status
	elif [[ ${server_speeder_num} == "4" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} stop
	elif [[ ${server_speeder_num} == "5" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} restart
		${Server_Speeder_file} status
	elif [[ ${server_speeder_num} == "6" ]]; then
		Server_Speeder_installation_status
		${Server_Speeder_file} status
	else
		echo -e "${Error} 请输入正确的数字(1-6)" && exit 1
	fi
}
#=======================安装锐速==========================
Install_ServerSpeeder(){
	[[ -e ${Server_Speeder_file} ]] && echo -e "${Error} 锐速(Server Speeder) 已安装 !" && exit 1
	#借用91yun.rog的开心版锐速
	wget --no-check-certificate -qO /tmp/serverspeeder.sh https://raw.githubusercontent.com/91yun/serverspeeder/master/serverspeeder.sh
	[[ ! -e "/tmp/serverspeeder.sh" ]] && echo -e "${Error} 锐速安装脚本下载失败 !" && exit 1
	bash /tmp/serverspeeder.sh
	sleep 2s
	PID=`ps -ef |grep -v grep |grep "serverspeeder" |awk '{print $2}'`
	if [[ ! -z ${PID} ]]; then
		rm -rf /tmp/serverspeeder.sh
		rm -rf /tmp/91yunserverspeeder
		rm -rf /tmp/91yunserverspeeder.tar.gz
		echo -e "${Info} 锐速(Server Speeder) 安装完成 !" && exit 1
	else
		echo -e "${Error} 锐速(Server Speeder) 安装失败 !" && exit 1
	fi
}
#=======================卸载锐速==========================
Uninstall_ServerSpeeder(){
	echo "确定要卸载 锐速(Server Speeder)？[y/N]" && echo
	read -e -p "(默认: n):" unyn
	[[ -z ${unyn} ]] && echo && echo "已取消..." && exit 1
	if [[ ${unyn} == [Yy] ]]; then
		chattr -i /serverspeeder/etc/apx*
		/serverspeeder/bin/serverSpeeder.sh uninstall -f
		echo && echo "锐速(Server Speeder) 卸载完成 !" && echo
	fi
}
#=======================锐速检测==========================
Server_Speeder_installation_status(){
	[[ ! -e ${Server_Speeder_file} ]] && echo -e "${Error} 没有安装 锐速(Server Speeder)，请检查 !" && exit 1
}

#=======================LotServer操作==========================
Configure_LotServer(){
	echo && echo -e "
 ${Green_font_prefix}1.${Font_color_suffix} 安装 LotServer
 ${Green_font_prefix}2.${Font_color_suffix} 卸载 LotServer
————————
 ${Green_font_prefix}3.${Font_color_suffix} 启动 LotServer
 ${Green_font_prefix}4.${Font_color_suffix} 停止 LotServer
 ${Green_font_prefix}5.${Font_color_suffix} 重启 LotServer
 ${Green_font_prefix}6.${Font_color_suffix} 查看 LotServer 状态
 
 注意： 锐速和LotServer不能同时安装/启动！" && echo
	read -e -p "(默认: 取消):" lotserver_num
	[[ -z "${lotserver_num}" ]] && echo "已取消..." && exit 1
	if [[ ${lotserver_num} == "1" ]]; then
		Install_LotServer
	elif [[ ${lotserver_num} == "2" ]]; then
		LotServer_installation_status
		Uninstall_LotServer
	elif [[ ${lotserver_num} == "3" ]]; then
		LotServer_installation_status
		${LotServer_file} start
		${LotServer_file} status
	elif [[ ${lotserver_num} == "4" ]]; then
		LotServer_installation_status
		${LotServer_file} stop
	elif [[ ${lotserver_num} == "5" ]]; then
		LotServer_installation_status
		${LotServer_file} restart
		${LotServer_file} status
	elif [[ ${lotserver_num} == "6" ]]; then
		LotServer_installation_status
		${LotServer_file} status
	else
		echo -e "${Error} 请输入正确的数字(1-6)" && exit 1
	fi
}
#=======================安装LotServer==========================
Install_LotServer(){
	[[ -e ${LotServer_file} ]] && echo -e "${Error} LotServer 已安装 !" && exit 1
	#Github: https://github.com/0oVicero0/serverSpeeder_Install
	wget --no-check-certificate -qO /tmp/appex.sh "https://raw.githubusercontent.com/0oVicero0/serverSpeeder_Install/master/appex.sh"
	[[ ! -e "/tmp/appex.sh" ]] && echo -e "${Error} LotServer 安装脚本下载失败 !" && exit 1
	bash /tmp/appex.sh 'install'
	sleep 2s
	PID=`ps -ef |grep -v grep |grep "appex" |awk '{print $2}'`
	if [[ ! -z ${PID} ]]; then
		echo -e "${Info} LotServer 安装完成 !" && exit 1
	else
		echo -e "${Error} LotServer 安装失败 !" && exit 1
	fi
}
#=======================卸载LotServer==========================
Uninstall_LotServer(){
	echo "确定要卸载 LotServer？[y/N]" && echo
	read -e -p "(默认: n):" unyn
	[[ -z ${unyn} ]] && echo && echo "已取消..." && exit 1
	if [[ ${unyn} == [Yy] ]]; then
		wget --no-check-certificate -qO /tmp/appex.sh "https://raw.githubusercontent.com/0oVicero0/serverSpeeder_Install/master/appex.sh" && bash /tmp/appex.sh 'uninstall'
		echo && echo "LotServer 卸载完成 !" && echo
	fi
}
#=======================LotServer检测==========================
LotServer_installation_status(){
	[[ ! -e ${LotServer_file} ]] && echo -e "${Error} 没有安装 LotServer，请检查 !" && exit 1
}


#=======================封禁 BT PT SPAM==========================
BanBTPTSPAM(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubiBackup/doubi/master/ban_iptables.sh && chmod +x ban_iptables.sh && bash ban_iptables.sh banall
	rm -rf ban_iptables.sh
}

#=======================解封 BT PT SPAM==========================
UnBanBTPTSPAM(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubiBackup/doubi/master/ban_iptables.sh && chmod +x ban_iptables.sh && bash ban_iptables.sh unbanall
	rm -rf ban_iptables.sh
}
#=======================完整测试==========================
speed_full(){
	speed_check
	bash "${speed_file}" -F
}
#=======================网络测试==========================
speed_net(){
	speed_check
	bash "${speed_file}" -spfull
}
#=======================路由追踪==========================
speed_bt(){
	speed_check
	bash "${speed_file}" -btfull
}

#=======================检查测试环境==========================
speed_check(){
	if [[ ! -e ${speed_file} ]]; then
		echo -e "${Error} 没有发现 测试脚本，开始下载..."
		cd "${file}"
		if ! wget -N --no-check-certificate https://ilemonrain.com/download/shell/LemonBench.sh; then
			echo -e "${Error} 测试 脚本下载失败 !" && exit 1
		else
			echo -e "${Info} 测试 脚本下载完成 !"
			chmod +x LemonBench.sh
		fi
	fi
}
#=======================菜单状态信息==========================
menu_status(){
	if [[ -e ${ssr_folder} ]]; then
		check_pid
		if [[ ! -z "${PID}" ]]; then
			echo -e "                      当前状态: ${Green_font_prefix}已安装ShadowsocksR${Font_color_suffix} 并 ${Red_font_prefix}已启动${Font_color_suffix}"
		else
			echo -e "                      当前状态: ${Green_font_prefix}已安装ShadowsocksR${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
		fi
		cd "${ssr_folder}"
	else
		echo -e "                      当前状态: ${Red_font_prefix}未安装ShadowsocksR${Font_color_suffix}"
	fi
}
#=======================获取Libsodium最新版本==========================
Check_Libsodium_ver(){
	echo -e "${Info} 开始获取 libsodium 最新版本..."
	Libsodiumr_ver=$(wget -qO- "https://github.com/jedisct1/libsodium/tags"|grep "/jedisct1/libsodium/releases/tag/"|head -1|sed -r 's/.*tag\/(.+)\">.*/\1/')
	[[ -z ${Libsodiumr_ver} ]] && Libsodiumr_ver=${Libsodiumr_ver_backup}
	echo -e "${Info} libsodium 最新版本为 ${Green_font_prefix}${Libsodiumr_ver}${Font_color_suffix} !"
}
#=======================检查Libsodium是否安装==========================
Check_Libsodium(){
	if [[ -e ${Libsodiumr_file} ]]; then
		echo -e "${Red_font_prefix}libsodium 已安装${Font_color_suffix}"
	else
		echo -e "${Red_font_prefix}libsodium 未安装${Font_color_suffix}"
	fi
}
#=======================安装Libsodium最新版本==========================
Install_Libsodium(){
	if [[ -e ${Libsodiumr_file} ]]; then
		echo -e "${Error} libsodium 已安装 , 是否覆盖安装(更新)？[y/N]"
		read -e -p "(默认: n):" yn
		[[ -z ${yn} ]] && yn="n"
		if [[ ${yn} == [Nn] ]]; then
			echo "已取消..." && exit 1
		fi
	else
		echo -e "${Info} libsodium 未安装，开始安装..."
	fi
	Check_Libsodium_ver
	if [[ ${release} == "centos" ]]; then
		yum update
		echo -e "${Info} 安装依赖..."
		yum -y groupinstall "Development Tools"
		echo -e "${Info} 下载..."
		wget  --no-check-certificate -N "https://download.libsodium.org/libsodium/releases/libsodium-${Libsodiumr_ver}.tar.gz"
		echo -e "${Info} 解压..."
		tar -xzf libsodium-${Libsodiumr_ver}.tar.gz && cd libsodium-${Libsodiumr_ver}
		echo -e "${Info} 编译安装..."
		./configure --disable-maintainer-mode && make -j2 && make install
		echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
	else
		apt-get update
		echo -e "${Info} 安装依赖..."
		apt-get install -y build-essential
		echo -e "${Info} 下载..."
		wget  --no-check-certificate -N "https://download.libsodium.org/libsodium/releases/libsodium-${Libsodiumr_ver}.tar.gz"
		echo -e "${Info} 解压..."
		tar -xzf libsodium-${Libsodiumr_ver}.tar.gz && cd libsodium-${Libsodiumr_ver}
		echo -e "${Info} 编译安装..."
		./configure --disable-maintainer-mode && make -j2 && make install
	fi
	ldconfig
	cd .. && rm -rf libsodium-${Libsodiumr_ver}.tar.gz && rm -rf libsodium-${Libsodiumr_ver}
	[[ ! -e ${Libsodiumr_file} ]] && echo -e "${Error} libsodium 安装失败 !" && exit 1
	echo && echo -e "${Info} libsodium 安装成功 !" && echo
}

#=======================脚本开始==========================
check_sys
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && [[ ${release} != "centos" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1
echo -e "============================== Bayria 命 令 行 ====================================="
Get_IP
ssr_server_pub_addr="${ip}"
echo -e "                      Bayria 一键管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}"
echo -e "                      IP : ${Red_font_prefix}${ssr_server_pub_addr}${Font_color_suffix}" 
menu_status&& echo ${Separator_2}
echo -e "
  ${Green_font_prefix}1.${Font_color_suffix} 安装 ShadowsocksR　　　　　　　　　　${Green_font_prefix}2.${Font_color_suffix} 卸载 ShadowsocksR
  ${Green_font_prefix}3.${Font_color_suffix} 安装 libsodium(chacha20)             ${Green_font_prefix}4.${Font_color_suffix} 监控 ShadowsocksR服务端运行状态
                                             
${Separator_2}
 ${Tip} $(Check_Libsodium)
 ${Tip} salsa20/chacha20-*系列加密方式，需要额外安装依赖 libsodium ，否则会无法启动ShadowsocksR !
 ${Tip} 如果使用 auth_chain_* 系列协议，建议加密方式选择 none (该系列协议自带 RC4 加密)，混淆随意 
 ${Tip} 如果使用 ShadowsocksR 代理游戏，建议选择 混淆兼容原版或 plain 混淆，然后客户端选择 plain，否则会增加延迟 !
 另外, 如果你选择了 tls1.2_ticket_auth，那么客户端可以选择 tls1.2_ticket_fastauth，这样即能伪装又不会增加延迟 !
 如果你是在日本、美国等热门地区搭建，那么选择 plain 混淆可能被墙几率更低 !
${Separator_2}

  ${Green_font_prefix}5.${Font_color_suffix} 启动 ShadowsocksR                    ${Green_font_prefix}6.${Font_color_suffix} 停止 ShadowsocksR
  ${Green_font_prefix}7.${Font_color_suffix} 重启 ShadowsocksR                    ${Green_font_prefix}8.${Font_color_suffix} 查看 ShadowsocksR 日志
  
${Separator_2}

  ${Green_font_prefix}9.${Font_color_suffix}  配置 BBR                           ${Green_font_prefix}10.${Font_color_suffix} 配置 锐速(ServerSpeeder)
  ${Green_font_prefix}11.${Font_color_suffix} 配置 LotServer(锐速母公司)
  ${Green_font_prefix}12.${Font_color_suffix} 一键封禁 BT/PT/SPAM (iptables)     ${Green_font_prefix}13.${Font_color_suffix} 一键解封 BT/PT/SPAM (iptables)
  
${Separator_2}
${Tip} 锐速/LotServer/BBR 不支持 OpenVZ！
${Tip} 锐速和LotServer不能共存！
${Separator_2}

  ${Green_font_prefix}12.${Font_color_suffix} 一键封禁 BT/PT/SPAM (iptables)     ${Green_font_prefix}13.${Font_color_suffix} 一键解封 BT/PT/SPAM (iptables)

${Separator_2}

  ${Green_font_prefix}14.${Font_color_suffix} 全面测试                           ${Green_font_prefix}15.${Font_color_suffix} 网速测试
  ${Green_font_prefix}16.${Font_color_suffix} 路由追踪
  
${Separator_2}
 "
	
	echo && read -e -p "请输入数字 [1-16]：" num
case "$num" in
	1)
	Install_SSR
	;;
	2)
	Uninstall_SSR
	;;
	3)
	Install_Libsodium
	;;
	4)
	Set_crontab_monitor_ssr
	;;
	5)
	Start_SSR
	;;
	6)
	Stop_SSR
	;;
	7)
	Restart_SSR
	;;
	8)
	View_Log
	;;
	9)
	Install_BBR
	;;
	10)
	Configure_Server_Speeder
	;;
	11)
	Configure_LotServer
	;;
	12)
	BanBTPTSPAM
	;;
	13)
	UnBanBTPTSPAM
	;;
	14)
	speed_full
	;;
	15)
	speed_net
	;;
	16)
	speed_bt
	;;
	*)
	echo -e "${Error} 请输入正确的数字 [1-16]"
	;;
esac


