#!/bin/bash

# 检测docker是否已安装
function check_docker(){
  if test -z "$(which docker)"; then
    echoContent yellow "检测到系统未安装docker，开始安装docker"
    curl -fsSL https://get.docker.com | bash -s docker
  fi
  if test -z "$(which docker-compose)"; then
    echoContent yellow "检测到系统未安装docker-compose，开始安装docker-compose"
    RELEASE=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    curl -L "https://github.com/docker/compose/releases/download/$RELEASE/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
  fi
}

# 创建目录的函数
create_directory() {
    # 判断/opt/GPT目录是否已存在
    if [ -d "/opt/GPT" ]; then
        echo "Directory already exists!"
        exit 1
    else
        # 创建/opt/GPT目录
        sudo mkdir /opt/GPT
        
        # 更改/opt/GPT目录权限
        sudo chown $USER:$USER /opt/GPT
        
        # 输出成功信息
        echo "Directory created successfully!"
    fi
}

# 写入内容的函数
write_content() {
    # 判断/opt/GPT目录是否存在
    if [ ! -d "/opt/GPT" ]; then
        echo "Directory does not exist!"
        exit 1
    fi

    # 判断docker-compose.yml文件是否已存在
    if [ ! -f "/opt/GPT/docker-compose.yml" ]; then
        echo "File does not exist!"
        exit 1
    fi
    
    # 读取输入的变量值
    read -p "Enter OPENAI_API_KEY: " OPENAI_API_KEY
    read -p "Enter AUTH_SECRET_KEY: " AUTH_SECRET_KEY
    read -p "Enter OPENAI_API_MODEL: " OPENAI_API_MODEL

    # 在docker-compose.yml文件末尾添加内容（固定的OPENAI_API_BASE_URL和BOOT_OPTIONS）
    sudo tee -a /opt/GPT/docker-compose.yml << EOF

services:
  app:
    image: chenzhaoyu94/chatgpt-web:latest
    environment:
      OPENAI_API_KEY: $OPENAI_API_KEY
      OPENAI_API_BASE_URL: https://api.openai.com
      AUTH_SECRET_KEY: $AUTH_SECRET_KEY
      OPENAI_API_MODEL: $OPENAI_API_MODEL
      BOOT_OPTIONS: "--server.port=3002"
    privileged: true
    network_mode: "host"
EOF

    # 输出成功信息
    echo "Content written successfully!"
}

# 检测并安装docker和docker-compose
check_docker

# 创建目录
create_directory

# 写入文件内容
write_content
