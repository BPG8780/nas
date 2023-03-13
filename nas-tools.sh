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
  nas-tools:
    image: jxxghp/nas-tools:latest
    ports:
      - 3000:3000
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
    image: nevinee/qbittorrent
    container_name: qbittorrent
    restart: always
    tty: true
    network_mode: bridge
    hostname: qbitorrent
    volumes:
      - /home/qbittorrent/data:/data
      - /media/video:/media/video    
    tmpfs:
      - /tmp
    environment:          
      - WEBUI_PORT=8080   
      - BT_PORT=34567     
      - PUID=0         
      - PGID=0
      - PGROUPS=0
      - TZ=Asia/Shanghai         
    ports:
      - 8080:8080        
      - 34567:34567      
      - 34567:34567/udp
    restart: unless-stopped
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
      - PUID=1000
      - PGID=1000
      - GIDLIST=022
      - TZ=Asia/Shanghai
    volumes:
      - /home/emby/programdata:/config
      - /media/video:/media/video
      - /media/video2:/media/video2
    ports:
      - 8096:8096
      - 8920:8920
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
      - PUID=1000
      - PGID=1000
      - GIDLIST=022
      - TZ=Asia/Shanghai
    volumes:
      - /home/emby/programdata:/config
      - /media/video:/media/video
      - /media/video2:/media/video2
    ports:
      - 8096:8096
      - 8920:8920
    devices:
      - /dev/dri:/dev/dri
    restart: unless-stopped
EOF
  echo 2
  else
    echo
  fi  
  docker-compose -f /root/docker-compose.yml up -d
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
function insall_oracle(){
  echoContent yellow  "(选择1)单纯CPU占用不低于10%(选择2)CPU+内存同时占用(选择3)设置每十二小时占用网络一次(选择4)停止运行脚本卸载"
  read oracle
  if test -z "$(which speedtest-cli)"; then
    echoContent yellow "检测到系统未安装speedtest-cli，开始安装speedtest-cli"
    apt install speedtest-cli || yum install speedtest-cli
  fi
  if [[ ${oracle} == "1" ]]; then
    bash <(curl -sL https://ghproxy.com/https://raw.githubusercontent.com/BPG8780/nas/main/oracle-CPU_2.sh)
  elif [[ ${oracle} == "2" ]]; then
    bash <(curl -sL https://ghproxy.com/https://raw.githubusercontent.com/BPG8780/nas/main/oracle-CPU_2.sh) -cm
  elif [[ ${oracle} == "3" ]]; then
    bash <(curl -sL https://ghproxy.com/https://raw.githubusercontent.com/BPG8780/nas/main/oracle-CPU_2.sh) -S
    cat > /usr/lib/systemd/system/Speedtest.timer <<EOF
[Unit]
Description=Runs mytimer every hour
[Timer]
OnUnitActiveSec=12h
Unit=Speedtest.service
[Install]
WantedBy=multi-user.target
EOF
  echo 2
  systemctl start Speedtest.service && systemctl start Speedtest.timer && systemctl enable Speedtest.timer && systemctl status Speedtest.timer
  elif [[ ${oracle} == "4" ]]; then
    systemctl stop KeepCpuMemory
		systemctl disable KeepCpuMemory
		rm /root/cpumemory.py && rm /etc/systemd/system/KeepCpuMemory.service
  else
    echo
  fi
  sleep 2s
  menu
}
function insall_root(){
  echoContent yellow "一键修改ROOT(Y/n)"
  read rootyn
  if [[ ${rootyn} == "Y" ]]||[[ ${rootyn} == "y" ]]; then
    bash <(curl -sL https://ghproxy.com/https://raw.githubusercontent.com/BPG8780/nas/main/root.sh)
  else
    echo
  fi
  sleep 2s
  menu
}
function insall_XUI(){
  echoContent yellow "X-UI纯IPV4/纯IPV6的VPS直接运行一键脚本(Y/n)"
  read xuiyn
  if [[ ${xuiyn} == "Y" ]]||[[ ${xuiyn} == "y" ]]; then
    wget -N https://gitlab.com/rwkgyg/x-ui-yg/raw/main/install.sh && bash install.sh
  else
    echo
  fi
  sleep 2s
  menu
}
function insall_WARP(){
  echoContent yellow "Cloudflare WARP多功能一键脚本(Y/n) 2启动脚本"
  read warpyn
  if [[ ${warpyn} == "Y" ]]||[[ ${warpyn} == "y" ]]; then
    wget -N --no-check-certificate https://gitlab.com/rwkgyg/CFwarp/raw/main/CFwarp.sh && bash CFwarp.sh
  elif [[ ${warpyn} == "2" ]]; then
    ./CFwarp.sh
  else
    echo
  fi
  sleep 2s
  menu
}
function insall_Alist(){
  echoContent yellow  "一键安装Alist(1)安装(2更新)(3)卸载"
  read Alist
  if [[ ${Alist} == "1" ]]; then
    curl -fsSL "https://alist.nn.ci/v3.sh" | bash -s install
  elif [[ ${Alist} == "2" ]]; then
    curl -fsSL "https://alist.nn.ci/v3.sh" | bash -s update
  elif [[ ${Alist} == "3" ]]; then
    curl -fsSL "https://alist.nn.ci/v3.sh" | bash -s uninstall
    else
    echo
  fi
}
function insall_nezha(){
  echoContent yellow  "安装哪吒监控(1)"
  read nezha
  if [[ ${nezha} == "1" ]]; then
    curl -L https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh  -o nezha.sh && chmod +x nezha.sh && sudo ./nezha.sh
    else
    echo
  fi  
}
function insall_java_oci_manage(){
  echoContent yellow  "(1)安装R探长(2)启动或重启(3)查看日志(ctrl + c退出日志)(4)终止程序(5)卸载程序"
  read oci
  if [[ ${oci} == "1" ]]; then
    wget -O gz_client_bot.tar.gz  https://github.com/semicons/java_oci_manage/releases/latest/download/gz_client_bot.tar.gz && tar -zxvf gz_client_bot.tar.gz --exclude=client_config  && tar -zxvf gz_client_bot.tar.gz --skip-old-files client_config && chmod +x sh_client_bot.sh && bash sh_client_bot.sh
   elif [[ ${oci} == "2" ]]; then
    bash sh_client_bot.sh
   elif [[ ${oci} == "3" ]]; then
    tail -f log_r_client.log
   elif [[ ${oci} == "4" ]]; then
    ps -ef | grep r_client.jar | grep -v grep | awk '{print $2}' | xargs kill -9
   elif [[ ${oci} == "5" ]]; then
    rm -rf gz_client_bot.tar.gz client_config r_client.jar sh_client_bot.sh log_r_client.log debug-.log
    else
    echo
  fi
  sleep 2s
  menu  
}
function check_docker1(){
    echoContent yellow "(1)安装docker(2)安装docker-compose(3)停止所有的容器(4)启动所有的容器(5)删除所有的容器(6)删除所有的镜像"
   read docker
  if [[ ${docker} == "1" ]]; then
    curl -fsSL https://get.docker.com | bash -s docker
    systemctl enable docker
  elif [[ ${docker} == "2" ]]; then
    curl -L "https://github.com/docker/compose/releases/download/v2.15.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
  elif [[ ${docker} == "3" ]]; then
   docker stop $(docker ps -aq)
  elif [[ ${docker} == "4" ]]; then
   docker start $(docker ps -aq)
  elif [[ ${docker} == "5" ]]; then
   docker rm $(docker ps -aq)
  elif [[ ${docker} == "6" ]]; then
   docker rmi $(docker images -q)
    else
    echo
  fi
  sleep 2s
  menu  
}
function insall_BBR(){
  echoContent yellow  "安装BBR/BBRPlus/锐速(Y/n)"
  read BBRyn
  if [[ ${BBRyn} == "Y" ]]||[[ ${BBRyn} == "y" ]]; then
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
    else
    echo
  fi  
}
function insall_E5Sub(){
  echoContent red  "搭建须知先创建目录修改config.yml配置文件再启动搭建"
  echoContent yellow  "(1)创建e5sub目录(2)搭建ARM版(3)搭建AMD版(4)启动搭建"
  read E5Sub
  if [[ ${E5Sub} == "1" ]]; then
    mkdir /opt/e5sub && touch /opt/e5sub/e5sub.db
    wget --no-check-certificate -O /opt/e5sub/config.yml https://ghproxy.com/https://raw.githubusercontent.com/BPG8780/BPG/main/config.yml.example
  elif [[ ${E5Sub} == "2" ]]; then
    wget --no-check-certificate -O /opt/e5sub/docker-compose.yml https://raw.githubusercontent.com/BPG8780/BPG/main/ARM/docker-compose.yml.example
  elif [[ ${E5Sub} == "3" ]]; then
    wget --no-check-certificate -O /opt/e5sub/docker-compose.yml https://raw.githubusercontent.com/BPG8780/BPG/main/AMD/docker-compose.yml.example
  elif [[ ${E5Sub} == "4" ]]; then
    cd /opt/e5sub && docker-compose up -d
    else
    echo
  fi
  sleep 2s
  menu  
}
function insall_dujiaoka(){
  echoContent red  "搭建先看。。https://www.ioiox.com/archives/159.html"
  echoContent yellow  "(1)创建主目录(2)下载Docker-compose文件(3)启动搭建(4)停止服务"
  read dujiaoka
  if [[ ${dujiaoka} == "1" ]]; then
    mkdir dujiaoka && cd dujiaoka && mkdir storage uploads && chmod -R 777 storage uploads
    wget --no-check-certificate -O /root/dujiaoka/env.conf https://ghproxy.com/https://raw.githubusercontent.com/BPG8780/dujiaoka/main/env.conf.example && chmod -R 777 env.conf
  elif [[ ${dujiaoka} == "2" ]]; then
    wget --no-check-certificate -O /root/dujiaoka/docker-compose.yml https://ghproxy.com/https://raw.githubusercontent.com/BPG8780/dujiaoka/main/docker-compose.yml.example
  elif [[ ${dujiaoka} == "3" ]]; then
    docker-compose -f /root/dujiaoka/docker-compose.yml up -d
  elif [[ ${dujiaoka} == "4" ]]; then
    cd /dujiaoka && docker-compose down
    else
    echo
  fi
  sleep 2s
  menu  
}
function insall_cloudflared(){
  echoContent yellow  "cloudflared tunnel一键部署更新版(1)"
  read cloudflared
  if [[ ${cloudflared} == "1" ]]; then
    bash <(curl -sL https://ghproxy.com/https://raw.githubusercontent.com/BPG8780/nas/main/onekey-argo-tunnel.sh)
    else
    echo
  fi  
}
function insall_Halo(){
  echoContent yellow  "安装Halo博客"
  read Halo
  if [[ ${Halo} == "1" ]]; then
    mkdir ~/halo && cd ~/halo
	cat >docker-compose.yml <<EOF
EOF	
  else
    echo
  fi
  sleep 2s
  menu
}
function insall_proxy(){
  echoContent purple  "请选择反代方式：\n1、Cloudflared Tunnel穿透(墙内建议选择此项，域名需要托管在Cloudflare)\n2、Nginx反代"
  read pproxy
  if [[ ${pproxy} == "1" ]]; then
    bash <(curl -sL https://ghproxy.20120714.xyz/https://raw.githubusercontent.com/07031218/normal-shell/net/onekey-argo-tunnel.sh)
  elif [[ ${pproxy} == "2" ]]; then
    echoContent yellow "开始安装nginx并准备签发证书，请提前将相应域名的A记录解析到该机器······\n在下面执行步骤中，有询问y或n的地方全部输入y"
    sleep 3s
    bash <(curl -sL https://cdn.jsdelivr.net/gh/07031218/one-key-for-let-s-Encrypt@main/run.sh)
    # echoContent purple  `echo -n -e "是否要对nas-tools进行反代处理,请输入Y/N："`
    # read ppproxy
    # if [[ ${ppproxy} == "Y" ]]||[[ ${ppproxy} == "y" ]]; then
      read -p "请输入前面注册的域名地址,http://" domain && printf "\n"
      sed -i '18,$d' /etc/nginx/conf.d/${domain}.conf
      cat > proxypass.conf << EOF
    #PROXY-START/
    location / {
      proxy_pass http://127.0.0.1:3000;
    }
    #PROXY-END/
    location /.well-known/acme-challenge/ {
            alias /certs/${domain}/certificate/challenges/;
            try_files \$uri =404;
    }
    location /download {
            autoindex on;
            autoindex_exact_size off;
            autoindex_localtime on;
    }
}
EOF
    sed  -i '17r proxypass.conf' /etc/nginx/conf.d/${domain}.conf
    rm proxypass.conf
    service nginx restart
    echoContent green "反代完成，你现在可以通过https://${domain} 来访问nas-tools了"
    # fi
  fi
  if [[ `lsof -i:8096|awk 'NR>1{print $2}'` != "" ]]; then
    echoContent yellow `echo -n -e "检测到该机器安装了Emby-Server，请问是否需要反代Emby[Y/n]:"`
    read pppproxy
    if [[ ${pppproxy} == "Y" ]]||[[ ${pppproxy} == "y" ]]; then
####
      if [[ ${pproxy} == "1" ]]; then
        bash <(curl -sL https://ghproxy.20120714.xyz/https://raw.githubusercontent.com/07031218/normal-shell/net/onekey-argo-tunnel.sh)
      elif [[ ${pproxy} == "2" ]]; then
        echoContent yellow "开始安装nginx并准备签发证书，请提前将相应域名的A记录解析到该机器······\n在下面执行步骤中，有询问y或n的地方全部输入y"
        sleep 3s
        bash <(curl -sL https://cdn.jsdelivr.net/gh/07031218/one-key-for-let-s-Encrypt@main/run.sh)
        # echoContent purple  `echo -n -e "是否要对nas-tools进行反代处理,请输入Y/N："`
        # read ppproxy
        # if [[ ${ppproxy} == "Y" ]]||[[ ${ppproxy} == "y" ]]; then
          read -p "请输入前面注册的域名地址,http://" domain && printf "\n"
          sed -i '18,$d' /etc/nginx/conf.d/${domain}.conf
          cat > proxypass.conf << EOF
  #PROXY-START/
      location  ~* \.(php|jsp|cgi|asp|aspx)\$
      {
          proxy_pass http://127.0.0.1:8096;
          proxy_set_header Host \$host;
          proxy_set_header X-Real-IP \$remote_addr;
          proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
          proxy_set_header REMOTE-HOST \$remote_addr;
      }
      location / {
          proxy_pass http://127.0.0.1:8096;
          proxy_set_header Host \$host;
          proxy_set_header X-Real-IP \$remote_addr;
          #proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
          proxy_set_header REMOTE-HOST \$remote_addr;
           
          # Plex start
          # 解决视频预览进度条无法拖动的问题
          proxy_set_header Range \$http_range;
          proxy_set_header If-Range \$http_if_range;
          proxy_no_cache \$http_range \$http_if_range;
          
          # 反带流式，不进行缓冲
          client_max_body_size 0;
          proxy_http_version 1.1;
          proxy_request_buffering off;
          #proxy_ignore_client_abort on;
          
          # 同时反带WebSocket协议
          proxy_set_header X-Forwarded-For \$remote_addr:\$remote_port;
          proxy_set_header Upgrade \$http_upgrade;
          proxy_set_header Connection upgrade; 
          
          gzip off;
          # Plex end
          
          add_header X-Cache \$upstream_cache_status;
          
                  
          #Set Nginx Cache
          add_header Cache-Control no-cache;
          expires 12h;
      }
       
      #PROXY-END/
      location /.well-known/acme-challenge/ {
              alias /certs/${domain}/certificate/challenges/;
              try_files \$uri =404;
      }
    location /download {
            autoindex on;
            autoindex_exact_size off;
            autoindex_localtime on;
    }
  }
EOF
        sed  -i '17r proxypass.conf' /etc/nginx/conf.d/${domain}.conf
        rm proxypass.conf
        service nginx restart
        echoContent green "反代完成，你现在可以通过https://${domain} 来访问Emby-server了"
        # fi
      fi
####
    fi
  fi
}
function check_dir_file(){
        if [ "${1:0-1:1}" = "/" ] && [ -d "$1" ];then
                return 0
        elif [ -f "$1" ];then
                return 0
        fi
        return 1
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
ExecStart = /usr/bin/rclone mount ${list[rclone_config_name]}: ${path} --umask 0000 --default-permissions --allow-non-empty --allow-other --transfers 8 --buffer-size 128M --low-level-retries 200 --vfs-cache-max-age 10s --multi-thread-streams 1024 --multi-thread-cutoff 128M --network-mode --vfs-cache-mode full --vfs-cache-max-size 100G --vfs-read-chunk-size-limit off --buffer-size 64K --vfs-read-chunk-size 64K --vfs-read-wait 0ms -v --vfs-read-chunk-size-limit 100G --vfs-read-wait 0ms --cache-dir=/tmp/vfs_cache
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
#                粑屁TG：https://t.me/BPG878                      #
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
echoContent yellow "1. 安装Nas-tools
2. 安装Rclone
3. Rclone获取配置
4. Rclone挂载网盘
5. 甲骨文(龟壳)保号脚本
6. 修改ROOT密码
7. 安装X-UI面板
8. 安装WARP
9. 安装Alist
10. 安装哪吒监控
11. 安装R探长
12. Docker安装以管理
13. 安装BBR/BBRPlus/锐速
14. 搭建E5sub_Docker-compose部署
15. 搭建独角数卡Docker-compose部署
16. Cloudflared tunnel一键部署
17. 安装Halo博客"
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
      insall_oracle;;
    6)
      insall_root;;
    7)
      insall_XUI;;
    8)
      insall_WARP;;      
    9)
      insall_Alist;;
    10)
      insall_nezha;;
    11)
      insall_java_oci_manage;;
    12)
      check_docker1;;
    13)
      insall_BBR;;
    14)
      insall_E5Sub;;
    15)
      insall_dujiaoka;;
    16)
      insall_cloudflared;;
    17)
      insall_Halo;;
    0)
      exit 0;;
    *)
      echoContent red "选择错误，请重新选择。"
      sleep 3s
      menu;;
  esac
}
menu
