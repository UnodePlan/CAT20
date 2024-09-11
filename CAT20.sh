#!/bin/bash

# 检查是否以 root 身份运行
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "\033[31m此脚本必须以 root 身份运行。\033[0m"
        echo -e "\033[31m请使用 'sudo -i' 切换到 root 用户并重试。\033[0m"
        exit 1
    fi
}

# 更新系统并安装基本依赖和工具
install_base_dependencies() {
    echo -e "\033[33m更新系统包并安装基本依赖...\033[0m"
    apt-get update -qq
    apt-get install -y wget curl tar unzip jq npm
}

# 安装 Docker 和 Docker Compose
install_docker_and_compose() {
    echo -e "\033[33m安装 Docker...\033[0m"
    apt-get install -y docker.io

    echo -e "\033[33m安装 Docker Compose...\033[0m"
    local compose_version
    compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')
    local compose_url="https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)"
    local destination="/usr/local/bin/docker-compose"

    wget -O "$destination" "$compose_url" --progress=bar:force
    chmod +x "$destination"
}

# 安装 Node.js 和 Yarn
install_node_and_yarn() {
    echo -e "\033[33m安装 Node.js 和 Yarn...\033[0m"
    npm install -g n
    n stable
    npm install -g yarn
}

# 拉取 Git 仓库并编译项目
clone_and_build() {
    echo -e "\033[33m克隆 Git 仓库并编译项目...\033[0m"

    local repo_url="https://github.com/CATProtocol/cat-token-box"
    local repo_dir="cat-token-box"

    git clone "$repo_url"
    cd "$repo_dir" || { echo -e "\033[31m无法进入目录 $repo_dir。\033[0m"; exit 1; }

    echo -e "\033[34m安装依赖...\033[0m"
    yarn install

    echo -e "\033[34m编译项目...\033[0m"
    yarn build

    echo -e "\033[32m编译完成。\033[0m"
}

# 运行 Docker 容器
run_docker_containers() {
    echo -e "\033[33m运行 Docker 容器...\033[0m"

    cd packages/tracker/ || { echo -e "\033[31m无法进入 packages/tracker 目录。\033[0m"; exit 1; }

    echo -e "\033[34m设置权限...\033[0m"
    chmod 777 docker/data docker/pgdata

    echo -e "\033[34m启动 Docker Compose...\033[0m"
    docker-compose up -d

    cd ../../ || { echo -e "\033[31m无法返回上级目录。\033[0m"; exit 1; }

    echo -e "\033[34m构建 Docker 镜像...\033[0m"
    docker build -t tracker:latest .

    echo -e "\033[34m运行 Docker 容器...\033[0m"
    docker run -d \
        --name tracker \
        --add-host="host.docker.internal:host-gateway" \
        -e DATABASE_HOST="host.docker.internal" \
        -e RPC_HOST="host.docker.internal" \
        -p 3000:3000 \
        tracker:latest

    echo -e "\033[32mDocker 容器已启动。\033[0m"
}

# 配置环境：安装依赖、拉取代码、编译、运行 Docker 容器
configure_environment() {
    install_base_dependencies
    install_docker_and_compose
    install_node_and_yarn
    clone_and_build
    run_docker_containers

    echo -e "\033[32m环境配置完成。\033[0m"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 创建钱包
create_wallet() {
    echo -e "\033[33m创建钱包...\033[0m"

    cd ~/cat-token-box/packages/cli || { echo -e "\033[31m无法进入 packages/cli 目录。\033[0m"; exit 1; }

    echo -e "\033[34m配置 config.json 文件...\033[0m"
    cat <<EOF > config.json
{
  "network": "fractal-mainnet",
  "tracker": "http://127.0.0.1:3000",
  "dataDir": ".",
  "maxFeeRate": 30,
  "rpc": {
      "url": "http://127.0.0.1:8332",
      "username": "bitcoin",
      "password": "opcatAwesome"
  }
}
EOF

    echo -e "\033[34m执行创建钱包命令...\033[0m"
    yarn cli wallet create

    echo -e "\033[32m钱包创建完成。\033[0m"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 修改 Gas 费用
modify_gas_fee_rate() {
    echo -e "\033[33m修改 Gas 费用...\033[0m"

    cd ~/cat-token-box/packages/cli || { echo -e "\033[31m无法进入目录 ~/cat-token-box/packages/cli。\033[0m"; exit 1; }

    # 读取当前的 maxFeeRate 值
    local current_fee_rate
    current_fee_rate=$(jq '.maxFeeRate' config.json)

    echo -e "\033[34m当前 Gas 费用为: $current_fee_rate\033[0m"

    read -p "请输入新的 Gas 费用: " new_fee_rate
    if ! [[ "$new_fee_rate" =~ ^[0-9]+$ ]]; then
        echo -e "\033[31m请输入一个有效的数字。\033[0m"
        return
    fi

    # 修改 config.json 中的 maxFeeRate
    jq --argjson feeRate "$new_fee_rate" '.maxFeeRate = $feeRate' config.json > tmp.json && mv tmp.json config.json

    echo -e "\033[32mGas 费用已更新为 $new_fee_rate。\033[0m"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 执行单次 mint 命令
mint() {
    echo -e "\033[33m执行单次 mint 命令...\033[0m"

    cd packages/cli || { echo -e "\033[31m无法进入 packages/cli 目录。\033[0m"; exit 1; }

    echo -e "\033[34m执行 mint 命令...\033[0m"
    yarn cli mint -i 45ee725c2c5993b3e4d308842d87e973bf1951f5f7a804b21e4dd964ecd12d6b_0 5

    echo -e "\033[32mMint 操作完成。\033[0m"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 批量执行 mint 命令
batch_mint() {
    echo -e "\033[33m批量铸造...\033[0m"

    cd packages/cli || { echo -e "\033[31m无法进入 packages/cli 目录。\033[0m"; exit 1; }

    read -p "请输入铸造的次数: " COUNT
    if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
        echo -e "\033[31m请输入一个有效的数字。\033[0m"
        exit 1
    fi

    for (( i=1; i<=COUNT; i++ )); do
        echo -e "\033[34m第 $i 次铸造...\033[0m"
        yarn cli mint -i 45ee725c2c5993b3e4d308842d87e973bf1951f5f7a804b21e4dd964ecd12d6b_0 5
        sleep 2  # 可以根据实际情况调整间隔时间
    done

    echo -e "\033[32m批量铸造完成。\033[0m"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 查看钱包文件
view_wallet_file() {
    echo -e "\033[33m查看钱包文件...\033[0m"
    cat /root/cat-token-box/packages/cli/wallet.json
    echo -e "\n"  # 添加换行符
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 查看钱包地址
view_wallet_address() {
    echo -e "\033[33m查看钱包地址...\033[0m"
    cd ~/cat-token-box/packages/cli || { echo -e "\033[31m无法进入目录 ~/cat-token-box/packages/cli。\033[0m"; exit 1; }
    yarn cli wallet address
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 查看是否到账和节点同步情况
check_balances_and_sync() {
    echo -e "\033[33m查看是否到账和节点同步情况...\033[0m"
    cd /root/cat-token-box/packages/cli || { echo -e "\033[31m无法进入目录 /root/cat-token-box/packages/cli。\033[0m"; exit 1; }
    yarn cli wallet balances
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 退出脚本
exit_script() {
    echo -e "\033[32m退出脚本...\033[0m"
    exit 0
}

# 主菜单
main_menu() {
    clear
    echo -e "\033[36m=======================================================================\033[0m"
    echo -e "\033[36m=======================================================================\033[0m"
    echo -e "\033[32m一键式脚本：配置环境、创建钱包、执行 mint 命令、批量铸造、查看钱包文件、查看钱包地址、检查余额及同步情况、修改 Gas 费用和退出脚本\033[0m"
    echo -e "\033[36m=======================================================================\033[0m"
    echo -e "\033[36m=======================================================================\033[0m"
    echo -e "\033[33m请选择一个选项：\033[0m"
    echo "1. 配置环境"
    echo "2. 创建钱包"
    echo "3. 修改 Gas 费用"
    echo "4. 铸造"
    echo "5. 批量铸造"
    echo "6. 查看钱包文件"
    echo "7. 查看钱包地址"
    echo "8. 查看是否到账和节点同步情况"
    echo "9. 退出脚本"
    read -p "输入选项 (1-9): " OPTION

    case $OPTION in
    1) configure_environment ;;
    2) create_wallet ;;
    3) modify_gas_fee_rate ;;
    4) mint ;;
    5) batch_mint ;;
    6) view_wallet_file ;;
    7) view_wallet_address ;;
    8) check_balances_and_sync ;;
    9) exit_script ;;
    *) echo -e "\033[31m无效的选项。\033[0m" ; main_menu ;;
    esac
}

# 确保脚本以 root 身份运行
check_root

# 显示主菜单
main_menu
