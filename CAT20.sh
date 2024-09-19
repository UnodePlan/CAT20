#!/bin/bash

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "\033[31mThis script must be run as root.\033[0m"
        exit 1
    fi
}

# Change directory with error handling
cd_with_error_handling() {
    local dir="$1"
    cd "$dir" || { echo -e "\033[31mUnable to enter directory $dir.\033[0m"; exit 1; }
}

# Update system packages and install base dependencies
install_base_dependencies() {
    echo -e "\033[33mUpdating system packages and installing base dependencies...\033[0m"
    apt-get update -qq
    apt-get install -y wget curl tar unzip jq npm
}

# Install Docker and Docker Compose
install_docker_and_compose() {
    echo -e "\033[33mInstalling Docker...\033[0m"
    apt-get install -y docker.io

    echo -e "\033[33mInstalling Docker Compose...\033[0m"
    local compose_version
    compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')
    local compose_url="https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)"
    local destination="/usr/local/bin/docker-compose"

    wget -O "$destination" "$compose_url" --progress=bar:force
    chmod +x "$destination"
}

# Install Node.js and Yarn
install_node_and_yarn() {
    echo -e "\033[33mInstalling Node.js and Yarn...\033[0m"
    npm install -g n
    n stable
    npm install -g yarn
}

# Clone Git repository and build project
clone_and_build() {
    echo -e "\033[33mCloning Git repository and building project...\033[0m"

    local repo_url="https://github.com/CATProtocol/cat-token-box"
    local repo_dir="cat-token-box"

    git clone "$repo_url"
    cd_with_error_handling "$repo_dir"

    echo -e "\033[34mInstalling dependencies...\033[0m"
    yarn install

    echo -e "\033[34mBuilding project...\033[0m"
    yarn build

    echo -e "\033[32mBuild completed.\033[0m"
}

# Run Docker containers
run_docker_containers() {
    echo -e "\033[33mRunning Docker containers...\033[0m"

    cd_with_error_handling "cat-token-box/packages/tracker"

    echo -e "\033[34mSetting permissions...\033[0m"
    chmod 777 docker/data docker/pgdata

    echo -e "\033[34mStarting Docker Compose...\033[0m"
    docker-compose up -d

    cd_with_error_handling "../../"

    echo -e "\033[34mBuilding Docker image...\033[0m"
    docker build -t tracker:latest .

    echo -e "\033[34mRunning Docker container...\033[0m"
    docker run -d \
        --name tracker \
        --add-host="host.docker.internal:host-gateway" \
        -e DATABASE_HOST="host.docker.internal" \
        -e RPC_HOST="host.docker.internal" \
        -p 3000:3000 \
        tracker:latest

    echo -e "\033[32mDocker container started.\033[0m"
}

# Configure environment: install dependencies, clone code, build, and run Docker containers
configure_environment() {
    install_base_dependencies
    install_docker_and_compose
    install_node_and_yarn
    clone_and_build
    run_docker_containers

    echo -e "\033[32mEnvironment configured successfully.\033[0m"
    read -n 1 -s -r -p "Press any key to return to the main menu..."
    main_menu
}

# Create wallet
create_wallet() {
    echo -e "\033[33mCreating wallet...\033[0m"

    cd_with_error_handling "cat-token-box/packages/cli"

    echo -e "\033[34mConfiguring config.json file...\033[0m"
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

    echo -e "\033[34mExecuting wallet creation command...\033[0m"
    yarn cli wallet create

    echo -e "\033[32mWallet created successfully.\033[0m"
    read -n 1 -s -r -p "Press any key to return to the main menu..."
    main_menu
}

# Modify Gas fee rate
modify_gas_fee_rate() {
    echo -e "\033[33mModifying Gas fee rate...\033[0m"

    cd_with_error_handling "cat-token-box/packages/cli"

    local current_fee_rate
    current_fee_rate=$(jq '.maxFeeRate' config.json)

    echo -e "\033[34mCurrent Gas fee rate is: $current_fee_rate\033[0m"

    read -p "Enter new Gas fee rate: " new_fee_rate
    if ! [[ "$new_fee_rate" =~ ^[0-9]+$ ]]; then
        echo -e "\033[31mPlease enter a valid number.\033[0m"
        return
    fi

    jq --argjson feeRate "$new_fee_rate" '.maxFeeRate = $feeRate' config.json > tmp.json && mv tmp.json config.json

    echo -e "\033[32mGas fee rate updated to $new_fee_rate.\033[0m"
    read -n 1 -s -r -p "Press any key to return to the main menu..."
    main_menu
}

# Execute single mint command
mint() {
    echo -e "\033[33mExecuting single mint command...\033[0m"

    cd_with_error_handling "cat-token-box/packages/cli"

    echo -e "\033[34mExecuting mint command...\033[0m"
    yarn cli mint -i 45ee725c2c5993b3e4d308842d87e973bf1951f5f7a804b21e4dd964ecd12d6b_0 5

    echo -e "\033[32mMint operation completed.\033[0m"
    read -n 1 -s -r -p "Press any key to return to the main menu..."
    main_menu
}

# Batch mint
batch_mint() {
    echo -e "\033[33mBatch minting...\033[0m"

    cd_with_error_handling "cat-token-box/packages/cli"

    read -p "Enter number of mints: " count
    if ! [[ "$count" =~ ^[0-9]+$ ]]; then
        echo -e "\033[31mPlease enter a valid number.\033[0m"
        exit 1
    fi

    for (( i=1; i<=count; i++ )); do
        echo -e "\033[34mBatch mint $i...\033[0m"
        yarn cli mint -i 45ee725c2c5993b3e4d308842d87e973bf1951f5f7a804b21e4dd964ecd12d6b_0 5
        sleep 2  # Adjust sleep duration as needed
    done

    echo -e "\033[32mBatch minting completed.\033[0m"
    read -n 1 -s -r -p "Press any key to return to the main menu..."
    main_menu
}

# View wallet file
view_wallet_file() {
    echo -e "\033[33mViewing wallet file...\033[0m"
    cat "cat-token-box/packages/cli/wallet.json"
    echo -e "\n"
    read -n 1 -s -r -p "Press any key to return to the main menu..."
    main_menu
}

# View wallet address
view_wallet_address() {
    echo -e "\033[33mViewing wallet address...\033[0m"
    cd_with_error_handling "cat-token-box/packages/cli"
    yarn cli wallet address
    read -n 1 -s -r -p "Press any key to return to the main menu..."
    main_menu
}

# Check balances and sync status
check_balances_and_sync() {
    echo -e "\033[33mChecking balances and sync status...\033[0m"
    cd_with_error_handling "cat-token-box/packages/cli"
    yarn cli wallet balances
    read -n 1 -s -r -p "Press any key to return to the main menu..."
    main_menu
}

# Exit script
exit_script() {
    echo -e "\033[32mExiting script...\033[0m"
    exit 0
}

# Main menu
main_menu() {
    clear
    echo "======================================================================="
    echo -e "\033[33mPlease select an option:\033[0m"
    echo "1. Configure environment"
    echo "2. Create wallet"
    echo "3. Modify Gas fee rate"
    echo "4. Mint"
    echo "5. Batch mint"
    echo "6. View wallet file"
    echo "7. View wallet address"
    echo "8. Check balances and sync status"
    echo "9. Exit script"
    read -p "Enter option (1-9): " option

    case $option in
    1) configure_environment ;;
    2) create_wallet ;;
    3) modify_gas_fee_rate ;;
    4) mint ;;
    5) batch_mint ;;
    6) view_wallet_file ;;
    7) view_wallet_address ;;
    8) check_balances_and_sync ;;
    9) exit_script ;;
    *) echo -e "\033[31mInvalid option.\033[0m" ; main_menu ;;
    esac
}

# Ensure the script is run as root
check_root

# Display main menu
main_menu
