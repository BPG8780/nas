#!/bin/bash
RED='\E[1;31m'
RED_W='\E[41;37m'
END='\E[0m'
echoType='echo -e'
echoContent(){
  case $1 in
  # 红色
  "red")
    # shellcheck disable=SC2154
    ${echoType} "\033[31m$2\033[0m"
    ;;
    # 绿色
  "green")
    ${echoType} "\033[32m$2\033[0m"
    ;;
    # 黄色
  "yellow")
    ${echoType} "\033[33m$2\033[0m"
    ;;
    # 蓝色
  "blue")
    ${echoType} "\033[34m$2\033[0m"
    ;;
    # 紫色
  "purple")
    ${echoType} "\033[35m$2\033[0m"
    ;;
    # 天蓝色
  "skyBlue")
    ${echoType} "\033[36m$2\033[0m"
    ;;
    # 白色
  "white")
    ${echoType} "\033[37m$2\033[0m"
    ;;
  esac
}
clear
# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误: $ 必须使用root用户运行此脚本！\n" && exit 1
apt install lsof -y || yum install lsof -y
function check_docker(){
  if test -z "$(which docker)"; then
    echoContent yellow "检测到系统未安装docker，开始安装docker"
    curl -fsSL https://get.docker.com | bash -s docker
  fi
  if test -z "$(which docker-compose)"; then
    echoContent yellow "检测到系统未安装docker-compose，开始安装docker-compose"
    curl -L "https://github.com/docker/compose/releases/download/v2.15.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
  fi
}
function install_rclone(){
  if [[ ! -f /usr/bin/rclone ]];then
    echoContent yellow "正在安装rclone,请稍等..."
    if [[ `which unzip` == "" ]]; then
      apt install unzip -y|| yum install unzip -y
    fi
    curl https://rclone.org/install.sh | bash
    if [[ -f /usr/bin/rclone ]];then
      sleep 1s
      echoContent green "Rclone安装成功."
    else
      echoContent red "Rclone安装失败，请重新运行脚本安装."
      exit 1
    fi
  else
    echoContent skyBlue "本机已安装rclone.无须安装."
  fi
  sleep 2s
  menu
}

function install_gclone(){
   if [[ -f /usr/bin/rclone ]];then
    echo
    echoContent yellow "本机已安装Rclone.无须安装."
  fi
  echoContent purple "开始使用Rclone来获取配置，请按照命令行提示操作·····"
  rclone config
}
function install_nas-tools(){
  if [[ `docker ps|grep nas-tools` != "" ]]; then
    echo
    echoContent red "⚠️ 检测到本机已安装过nas-tools,程序退出······"
    exit 1
  fi
  cat >/root/docker-compose.yml <<EOF
version: "3"
services: 
#自动追剧必备
  nas-tools:
    image: jxxghp/nas-tools:latest
    ports:
      - 3000:3000
    deploy:
      resources:
         limits:
            cpus: "2.00"
            memory: 5G
         reservations:
            memory: 200M
    volumes:
      - /home/nas-tools/config:/config
      - /downloads:/downloads
      - /media:/media
      - /root/.config/rclone:/root/.config/rclone
    environment: 
      - PUID=1555
      - PGID=1555
      - UMASK=022
      - TZ=Asia/Shanghai
      - NASTOOL_AUTO_UPDATE=true
    restart: always
    network_mode: bridge
    hostname: nas-tools
    container_name: nas-tools
  qbittorrent:
    container_name: qbittorrent
    image: cr.hotio.dev/hotio/qbittorrent
    ports:
      - "8080:8080"
    environment:
      - PUID=1000
      - PGID=1000
      - UMASK=002
      - TZ=Asia/Shanghai
    volumes:
      - /home/qbittorrent/config:/config
      - /media/video:/media/video
      - /downloads:/downloads
    deploy:
      resources:
         limits:
            cpus: "2.00"
            memory: 5G
         reservations:
            memory: 200M
  jackett:
    image: lscr.io/linuxserver/jackett
    container_name: jackett
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Shanghai
      - AUTO_UPDATE=true 
    volumes:
      - /home/jackett:/config
      - /downloads:/downloads
    ports:
      - 9117:9117
    restart: always
  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    environment:
      - LOG_LEVEL=info
      - LOG_HTML=false
      - CAPTCHA_SOLVER=none
      - TZ=Asia/Shanghaiœ
    ports:
      - "8191:8191"
    restart: unless-stopped
  chinesesubfinder:
    container_name: chinesesubfinder
    image: allanpk716/chinesesubfinder:latest
    volumes:
      - /home/chinesesubfinder:/config
      - /media/video:/media/video
      - /home/chinesesubfinder/cache:/app/cache
    environment:
      - PUID=0
      - PGID=0
      - TZ=Asia/Shanghai
    ports:
      - 19035:19035
    restart: unless-stopped
  nginx-proxy-manager-zh:
    image: 'chishin/nginx-proxy-manager-zh:latest'
    restart: always
    ports:
      - '800:800'
      - '81:81'
      - '443:443'
    volumes:
      - /home/nginx/data:/data
      - /home/nginx/letsencrypt:/etc/letsencrypt
EOF
  echoContent yellow `echo -ne "请问是否安装Emby开心版到本机《《《特别注意(1)是ARM版本,(2)是AMD版本》》》[n/不用]"`
  read emby
  if [ "$emby" = "1" ]; then
    cat>>/root/docker-compose.yml <<EOF
  emby:
    image: codion/emby_crack:4.7.6.0-ARM
    container_name: emby
    environment:
      - PUID=0
      - PGID=0
      - GIDLIST=0
      - TZ=Asia/Shanghai
    volumes:
      - /home/emby/programdata:/config
      - /media/video:/media/video
    ports:
      - 8096:8096
      - 8920:8920
    deploy:
      resources:
         limits:
            cpus: "2.00"
            memory: 5G
         reservations:
            memory: 200M
    devices:
      - /dev/dri:/dev/dri
    restart: unless-stopped
EOF
  echo 1
elif [ "$emby" = "2" ]; then
    cat>>/root/docker-compose.yml <<EOF
  emby:
    image: codion/emby_crack:4.7.6.0-X86
    container_name: emby
    environment:
      - PUID=0
      - PGID=0
      - GIDLIST=0
      - TZ=Asia/Shanghai
    volumes:
      - /home/emby/programdata:/config
      - /media/video:/media/video
    ports:
      - 8096:8096
      - 8920:8920
    deploy:
      resources:
         limits:
            cpus: "2.00"
            memory: 5G
         reservations:
            memory: 200M
    devices:
      - /dev/dri:/dev/dri
    restart: unless-stopped
EOF
  echo 2
  else
    echo
  fi  
  docker-compose --compatibility up -d
  if [[ $? -eq 0 ]]; then
    echoContent green "qbittorrent、jackett、flaresolverr、chinesesubfinder、nginx安装完毕······"
    echoContent yellow "开始将检测网盘挂载状态写入开机启动项···"
    cat >/etc/init.d/check <<EOF
#!/bin/bash
dir1=/media/video
# dir2=/mnt/onedrive
while true; do
    sleep 5s
    if [[ -d $dir1 ]]; then
        if [[ `ls $dir1` != "" ]]; then
            docker restart chinesesubfinder
            docker restart qbittorrent
            docker restart nas-tools
            docker restart nginx-proxy-manager-zh
            if [[ `docker ps |grep emby` != "" ]];then
              docker restart emby
            fi
            break
        else
            echo "No path!"
        fi
    fi
done
EOF
    chmod +x /etc/init.d/check
    update-rc.d check defaults
    echoContent green "检测网盘挂载状态写入开机启动项完成···"
    if [[ ${embyyn} == "Y" ]]||[[ ${embyyn} == "y" ]]; then
      echoContent green "qbittorrent端口8080（初始用户名admin，密码adminadmin）,nas-tools端口3000(默认用户名admin,密码password), nginx端口81(Email: admin@example.com,密码changeme)，Emby端口:8096"
    else
      echoContent green "qbittorrent端口8080（初始用户名admin，密码adminadmin, nas-tools端口3000(默认用户名admin,密码password), nginx端口81(Email: admin@example.com,密码changeme)，Emby端口:8096"
    fi
  else
    echoContent red "qbittorrent、jackett、flaresolverr、chinesesubfinder、nginx安装失败······"
  fi
}
function check_rclone(){
        check_dir_file "/usr/bin/rclone"
        [ "$?" -ne 0 ] && echoContent red "未检测到rclone程序.请先安装rclone." && exit 1
        check_dir_file "/root/.config/rclone/rclone.conf"
        [ "$?" -ne 0 ] && echoContent red "未检测到rclone配置文件.请先安装rclone." && exit 1
        return 0
}
curr_date(){
        curr_date=`date +[%Y-%m-%d"_"%H:%M:%S]`
        echo -e "`echo -e "${RED}${curr_date}${END}"`"
}
function mount_drive(){
  check_rclone
        i=1

        list=()

        for item in $(sed -n "/\[.*\]/p" ~/.config/rclone/rclone.conf | grep -Eo "[0-9A-Za-z-]+")
        do
                list[i]=${item}
                i=$((i+1))
        done
        while [[ 0 ]]
        do
                while [[ 0 ]]
                do
                        echo
                        echo -e "本地已配置网盘列表:"
                        echo
                echo -e "${RED}+-------------------------+${END}"
                        for((j=1;j<=${#list[@]};j++))
                        do
                temp="${j}：${list[j]}"
                count=$((`echo "${temp}" | wc -m` -1))
                if [ "${count}" -le 6 ];then
                    temp="${temp}\t\t\t"
                elif [ "${count}" -gt 6 ] && [ "$count" -le 14 ];then
                    temp="${temp}\t\t"
                elif [ "${count}" -gt 14 ];then
                    temp="${temp}\t"
                fi
                                echo -e "${RED}| ${temp}  |${END}"
                                echo -e "${RED}+-------------------------+${END}"
                        done


                        echo
                        read -n3 -p "请选择需要挂载的网盘（输入数字即可）：" rclone_config_name
                        if [ ${rclone_config_name} -le ${#list[@]} ] && [ -n ${rclone_config_name} ];then
                                echo
                                echo -e "`curr_date` 您选择了：${RED}${list[rclone_config_name]}${END}"
                                break
                        fi
                        echo
                        echo "输入不正确，请重新输入。"
                        echo
                done
                echo
                read -p "请输入需要挂载目录的路径（如不是绝对路径则挂载到/media/video下）:" path
                if [[ "${path:0:1}" != "/" ]];then
                        path="/media/video/${path}"
                fi
                while [[ 0 ]]
                do
                        echo
                        echo -e "您选择了 ${RED}${list[rclone_config_name]}${END} 网盘，挂载路径为 ${RED}${path}${END}."
                        read -n1 -p "确认无误[Y/n]:" result
                        echo
                        case ${result} in
                                Y | y)
                                        echo
                                        break 2;;
                                n | N)
                                        continue 2;;
                                *)
                                        echo
                                        continue;;
                        esac
                done

        done


        fusermount -qzu "${path}"
        if [[ ! -d ${path} ]];then
                echo
                echo -e "`curr_date`  ${RED}${path}${END} 不存在，正在创建..."
                mkdir -p ${path}
                sleep 1s
                echo
                echo -e "`curr_date` 创建完成！"
        fi



        echo
        echo -e "`curr_date` 正在检查服务是否存在..."
        if [[ -f /lib/systemd/system/rclone-${list[rclone_config_name]}.service ]];then

                echo -e "`curr_date` 找到服务 \"${RED}rclone-${list[rclone_config_name]}.service${END}\"正在删除，请稍等..."
                systemctl stop rclone-${list[rclone_config_name]}.service &> /dev/null
                systemctl disable rclone-${list[rclone_config_name]}.service &> /dev/null
                rm /lib/systemd/system/rclone-${list[rclone_config_name]}.service &> /dev/null
                sleep 2s
                echo -e "`curr_date` 删除成功。"
        fi
        echo -e "`curr_date` 正在创建服务 \"${RED}rclone-${list[rclone_config_name]}.service${END}\"请稍等..."
        echo "[Unit]
Description = rclone mount for ${list[rclone_config_name]}
AssertPathIsDirectory=${path}
Wants=network-online.target
After=network-online.target
[Service]
Type=notify
KillMode=none
Restart=on-failure
RestartSec=5
User = root
ExecStart = /usr/bin/rclone mount ${list[rclone_config_name]}: ${path} --umask 000 --allow-other --allow-non-empty --multi-thread-streams 1024 --multi-thread-cutoff 128M --network-mode --vfs-cache-mode minimal --vfs-cache-max-age 10s --cache-dir=/tmp/vfs_cache --vfs-cache-max-size 100G --vfs-read-chunk-size-limit off --buffer-size 64K --vfs-read-chunk-size 64K --vfs-read-wait 0ms --vfs-read-chunk-size-limit 64K --log-level INFO --log-file=/media/rclone.log
ExecStop=/bin/fusermount -u ${path}
Restart = on-abort
[Install]
WantedBy = multi-user.target" > /lib/systemd/system/rclone-${list[rclone_config_name]}.service
        sleep 2s
        echo -e "`curr_date` 服务创建成功。"
        if [ ! -f /etc/fuse.conf ]; then
                echo -e "`curr_date` 未找到fuse包.正在安装..."
                sleep 1s
                if [[ "${release}" = "centos" ]];then
                        yum install fuse -y
                elif [[ "${release}" = "debian" || "${release}" = "ubuntu" ]];then
                        apt-get install fuse -y
                fi
                echo
                echo -e "`curr_date` fuse安装完成."
                echo
        fi

        sleep 2s
        echo
        echo -e "`curr_date` 启动服务..."
        systemctl start rclone-${list[rclone_config_name]}.service &> /dev/null
        sleep 1s
        echo -e "`curr_date` 添加开机启动..."
        systemctl enable rclone-${list[rclone_config_name]}.service &> /dev/null
        if [[ $? ]];then
                echo
                echo -e "已为网盘 ${RED}${list[rclone_config_name]}${END} 创建服务 ${RED}reclone-${list[rclone_config_name]}.service${END}.并已添加开机挂载.\n您可以通过 ${RED}systemctl [start|stop|status]${END} 进行挂载服务管理。"
                echo
                echo
                sleep 2s
        else
                echo
                echo -e "`curr_date` 警告:未知错误."
        fi

}
function menu(){
  clear
    echoContent green "
###################################################################
#                      脚本Fork翔翎居                             #
#                   Nas-tools 一键梭哈脚本                        #
#                  Emby开心版是ARM64/AMD64                        #
#                博客：https://bug.878088.xyz                     #
#                        粑屁修改版                               #
#                                                                 #
#                                                                 #
###################################################################"
echoContent red "请注意：不建议内存低于2GB，磁盘空间低于40G的设备执行安装"
echo
echo
echoContent skyBlue "友情提醒：
如果打算映射rclone挂载的网盘给qBittorrent、chinesesubfinder和Emby；
请先完成网盘挂载(挂载目录选择默认的/media/video)"
echoContent white "-----------------------------------------"
echo -e "${RED}0. 退出脚本${END}"
echoContent white "-----------------------------------------"
echoContent yellow "1. 一键安装Nas-tools
2. 安装Rclone
3. Rclone获取配置
4. Rclone挂载网盘"
  read -p "请选择输入菜单对应数字开始执行：" select_menu
  case "${select_menu}" in
    1)
      check_docker
      install_nas-tools;;
    2)
      install_rclone;;
    3)
      install_gclone;;
    4)
      mount_drive;;
    5)
      insall_proxy;;
    0)
      exit 0;;
    *)
      echoContent red "选择错误，请重新选择。"
      sleep 3s
      menu;;
  esac
}
menu
