#!/bin/bash

# Check if running as root
root_access() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root."
        exit 1
    fi
}

# Detect Linux distribution
detect_distribution() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        case "${ID}" in
            ubuntu|debian)
                package_manager="apt-get"
                ;;
            centos)
                package_manager="yum"
                ;;
            fedora)
                package_manager="dnf"
                ;;
            *)
                echo "Unsupported distribution!"
                exit 1
                ;;
        esac
    else
        echo "Unsupported distribution!"
        exit 1
    fi
}

# Detect the system architecture
detect_architecture() {
    case "$(uname -m)" in
        x86_64)
            arch="amd64"
            ;;
        i386|i686)
            arch="386"
            ;;
        armv7l)
            arch="armv7"
            ;;
        aarch64)
            arch="arm64"
            ;;
        *)
            echo "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
}

# Detect OS platform
detect_platform() {
    case "$(uname)" in
        Linux)
            platform="linux"
            ;;
        FreeBSD)
            platform="freebsd"
            ;;
        Darwin)
            platform="darwin"
            ;;
        *)
            echo "Unsupported platform: $(uname)"
            exit 1
            ;;
    esac
}

# Check dependencies
check_dependencies() {
    root_access
    detect_distribution
    local dependencies=("wget" "nano" "gunzip" "jq")

    for dep in "${dependencies[@]}"; do
        if ! command -v "${dep}" &> /dev/null; then
            echo "${dep} is not installed. Installing..."
            sudo "${package_manager}" install "${dep}" -y
        fi
    done
}

# Get the latest version tag from GitHub releases
get_latest_version() {
    latest_release=$(wget -qO- https://github.com/go-gost/gost/releases | grep -oP '(?<=/go-gost/gost/releases/tag/)[^"]+' | grep 'nightly' | head -n 1)

    if [ -z "$latest_release" ]; then
        echo "Failed to fetch the latest release version."
        exit 1
    fi

    echo "Latest release found: $latest_release"
}

# Install gost
install_gost() {
    get_latest_version
    check_dependencies
    detect_architecture
    detect_platform

    # Remove the "v" from the version in the filename
    release_filename=$(echo "$latest_release" | sed 's/^v//')

    # Build the correct download URL
    binary_url="https://github.com/go-gost/gost/releases/download/${latest_release}/gost_${release_filename}_${platform}_${arch}.tar.gz"

    echo "Downloading gost from $binary_url"
    wget "$binary_url"
    if [ $? -ne 0 ]; then
        echo "Failed to download the binary. Please check the URL or try a different architecture."
        exit 1
    fi

    tar -xzf "gost_${release_filename}_${platform}_${arch}.tar.gz"
    sudo mv gost-*/gost /usr/local/bin/gost
    sudo chmod +x /usr/local/bin/gost
}

#get inputs for 1
get_inputs1() {
    read -p "Enter foreign IP [External-ip] : " foreign_ip
    read -p "Enter Iran Port [Internal-port] :" port
    read -p "Enter Config Port [External-port] :" configport
    read -p "Enter 'udp' for UDP connection (default is: tcp): " connection_type
    connection_type=${connection_type:-tcp}
    argument="-L $connection_type://:$port/$foreign_ip:$configport"
    
    read -p "Do you want to add more ports? (yes/no): " add_more_ports
    while [ "$add_more_ports" == "yes" ]; do
        read -p "Please enter additional config port(s) separated by commas (e.g., 2087,2095): " additional_config_ports
        IFS=',' read -r -a ports_array <<< "$additional_config_ports"
        for new_port in "${ports_array[@]}"; do
            argument="-L $connection_type://:$new_port/$foreign_ip:$new_port $argument"
        done
        read -p "Do you want to add more ports? (yes/no): " add_more_ports
    done
        
    cd /etc/systemd/system

    cat <<EOL>> gost.service
[Unit]
Description=GO Simple Tunnel
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost $argument

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable gost.service
    sudo systemctl start gost.service
}

#install
install() {
    install_gost
    get_inputs1
}

#get inputs for 2
get_inputs2() {
    read -p "Which server do you want to use? (Enter '1' for Iran[Internal] or '2' for Foreign[External] ) : " server_choice
    if [ "$server_choice" == "1" ]; then
        read -p "Enter foreign IP [External-ip] : " foreign_ip
        read -p "Please Enter servers connection Port : " port
        read -p "Please Enter your Config Port : " config_port
        read -p "Enter 'udp' for UDP connection (default is: tcp): " connection_type
        connection_type=${connection_type:-tcp}
        argument="-L $connection_type://:$config_port/127.0.0.1:$config_port -F relay+kcp://$foreign_ip:$port"
        
        read -p "Do you want to add more ports? (yes/no): " add_more_ports
        while [ "$add_more_ports" == "yes" ]; do
            read -p "Please enter additional config port(s) separated by commas (e.g., 2087,2095): " additional_config_ports
            IFS=',' read -r -a ports_array <<< "$additional_config_ports"
            for new_port in "${ports_array[@]}"; do
                argument="-L $connection_type://:$new_port/127.0.0.1:$new_port $argument"
            done
            read -p "Do you want to add more ports? (yes/no): " add_more_ports
        done

    elif [ "$server_choice" == "2" ]; then
        read -p "Enter servers connection Port : " port
        argument="-L relay+kcp://:$port"
    else
        echo "Invalid choice. Please enter '1' or '2'."
        exit 1
    fi

    cd /etc/systemd/system

    cat <<EOL>> gost.service
[Unit]
Description=GO Simple Tunnel
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost $argument

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable gost.service
    sudo systemctl start gost.service
}

#install kcp
install_kcp() {
    install_gost
    get_inputs2
}

#get inputs for 3
get_inputs3() {
    read -p "Which server do you want to use? (Enter '1' for Iran[Internal] or '2' for Foreign[External] ) : " server_choice
    if [ "$server_choice" == "1" ]; then
        read -p "Enter foreign IP [External-ip] : " foreign_ip
        read -p "Please Enter servers connection Port : " port
        read -p "Please Enter your Config Port : " config_port
        read -p "Enter 'udp' for UDP connection (default is: tcp): " connection_type
        connection_type=${connection_type:-tcp}
        argument="-L $connection_type://:$config_port/127.0.0.1:$config_port -F relay+wss://$foreign_ip:$port"
        
        read -p "Do you want to add more ports? (yes/no): " add_more_ports
        while [ "$add_more_ports" == "yes" ]; do
            read -p "Please enter additional config port(s) separated by commas (e.g., 2087,2095): " additional_config_ports
            IFS=',' read -r -a ports_array <<< "$additional_config_ports"
            for new_port in "${ports_array[@]}"; do
                argument="-L $connection_type://:$new_port/127.0.0.1:$new_port $argument"
            done
            read -p "Do you want to add more ports? (yes/no): " add_more_ports
        done

    elif [ "$server_choice" == "2" ]; then
        read -p "Enter servers connection Port : " port
        argument="-L relay+wss://:$port"
    else
        echo "Invalid choice. Please enter '1' or '2'."
        exit 1
    fi

    cd /etc/systemd/system

    cat <<EOL>> gost.service
[Unit]
Description=GO Simple Tunnel
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost $argument

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable gost.service
    sudo systemctl start gost.service
}

#install wss
install_wss() {
    install_gost
    get_inputs3 
}

#get inputs for 4
get_inputs4() {
    read -p "Which server do you want to use? (Enter '1' for Iran[Internal] or '2' for Foreign[External] ) : " server_choice
    if [ "$server_choice" == "1" ]; then
        read -p "Enter foreign IP [External-ip] : " foreign_ip
        read -p "Please Enter servers connection Port : " port
        read -p "Please Enter your Config Port : " config_port
        read -p "Enter 'udp' for UDP connection (default is: tcp): " connection_type
        connection_type=${connection_type:-tcp}
        argument="-L $connection_type://:$config_port/127.0.0.1:$config_port -F relay://$foreign_ip:$port"
        
        read -p "Do you want to add more ports? (yes/no): " add_more_ports
        while [ "$add_more_ports" == "yes" ]; do
            read -p "Please enter additional config port(s) separated by commas (e.g., 2087,2095): " additional_config_ports
            IFS=',' read -r -a ports_array <<< "$additional_config_ports"
            for new_port in "${ports_array[@]}"; do
                argument="-L $connection_type://:$new_port/127.0.0.1:$new_port $argument"
            done
            read -p "Do you want to add more ports? (yes/no): " add_more_ports
        done

    elif [ "$server_choice" == "2" ]; then
        read -p "Enter servers connection Port : " port
        argument="-L relay://:$port"
        
    else
        echo "Invalid choice. Please enter '1' or '2'."
        exit 1
    fi

    cd /etc/systemd/system

    cat <<EOL>> gost.service
[Unit]
Description=GO Simple Tunnel
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost $argument

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable gost.service
    sudo systemctl start gost.service
}

#install tls
install_relay() {
    install_gost
    get_inputs4
}

get_inputs5() {
    read -p "Which server do you want to use? (Enter '1' for Iran[Internal] or '2' for Foreign[External]): " server_choice
    if [ "$server_choice" == "1" ]; then
        read -p "Enter foreign IP [External-ip]: " foreign_ip
        read -p "Please enter the server's connection port: " port
        read -p "Please enter your config port: " config_port
        read -p "Enter 'udp' for UDP connection (default is: tcp): " connection_type
        connection_type=${connection_type:-tcp}
        argument="-L $connection_type://:$config_port/127.0.0.1:$config_port -F relay+quic://$foreign_ip:$port"

        read -p "Do you want to add more ports? (yes/no): " add_more_ports
        while [ "$add_more_ports" == "yes" ]; do
            read -p "Please enter additional config port(s) separated by commas (e.g., 2087,2095): " additional_config_ports
            IFS=',' read -r -a ports_array <<< "$additional_config_ports"
            for new_port in "${ports_array[@]}"; do
                argument="-L $connection_type://:$new_port/127.0.0.1:$new_port $argument"
            done
            read -p "Do you want to add more ports? (yes/no): " add_more_ports
        done

    elif [ "$server_choice" == "2" ]; then
        read -p "Enter server's connection port: " port
        argument="-L relay+quic://:$port"

    else
        echo "Invalid choice. Please enter '1' or '2'."
        exit 1
    fi

    cd /etc/systemd/system

    cat <<EOL>> gost.service
[Unit]
Description=GO Simple Tunnel
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost $argument

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable gost.service
    sudo systemctl start gost.service
}


#install quic
install_quic() {
    install_gost
    get_inputs5
}

get_inputs6() {
    read -p "Which server do you want to use? (Enter '1' for Iran[Internal] or '2' for Foreign[External]): " server_choice
    if [ "$server_choice" == "1" ]; then
        read -p "Enter foreign IP [External-ip]: " foreign_ip
        read -p "Please enter the server's connection port: " port
        read -p "Please enter your config port: " config_port
        read -p "Enter your protocol (e.g : relay+wss) : " protocol
        read -p "Enter 'udp' for UDP connection (default is: tcp): " connection_type
        connection_type=${connection_type:-tcp}
        argument="-L $connection_type://:$config_port/127.0.0.1:$config_port -F $protocol://$foreign_ip:$port"

        read -p "Do you want to add more ports? (yes/no): " add_more_ports
        while [ "$add_more_ports" == "yes" ]; do
            read -p "Please enter additional config port(s) separated by commas (e.g., 2087,2095): " additional_config_ports
            IFS=',' read -r -a ports_array <<< "$additional_config_ports"
            for new_port in "${ports_array[@]}"; do
                argument="-L $connection_type://:$new_port/127.0.0.1:$new_port $argument"
            done
            read -p "Do you want to add more ports? (yes/no): " add_more_ports
        done

    elif [ "$server_choice" == "2" ]; then
        read -p "Enter server's connection port: " port
        read -p "Enter your protocol (e.g : relay+wss) : " protocol
        argument="-L $protocol://:$port"

    else
        echo "Invalid choice. Please enter '1' or '2'."
        exit 1
    fi

    cd /etc/systemd/system

    cat <<EOL>> gost.service
[Unit]
Description=GO Simple Tunnel
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost $argument

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable gost.service
    sudo systemctl start gost.service
}

#install custom
install_custom() {
    install_gost
    get_inputs6
}

#Uninstall 
uninstall() {
    if ! command -v gost &> /dev/null
    then
        echo "Gost is not installed."
        return
    fi
    
    sudo systemctl stop gost.service
    sudo systemctl disable gost.service
    sudo rm /etc/systemd/system/gost.service
    sudo systemctl daemon-reload
    sudo rm /usr/local/bin/gost
    echo "GO Simple Tunnel (gost) has been uninstalled."
}



# Main menu
clear
echo "By --> Peyman * Github.com/Ptechgithub * "
echo ""
echo " --------#- Go simple Tunnel-#--------"
echo "1) Install Gost [only Internal Server]"
echo " ----------------------------"
echo "2) Install Gost [relay]"
echo " ----------------------------"
echo "3) Install Gost [relay + wss]"
echo " ----------------------------"
echo "4) Install Gost [relay + kcp]"
echo " ----------------------------"
echo "5) Install Gost [relay + quic]"
echo " ----------------------------"
echo "6) Install Custom"
echo " ----------------------------"
echo "7) Uninstall Gost"
echo " ----------------------------"
echo "0) exit"
read -p "Please choose: " choice

case $choice in

    1)
        install
        ;;
    2)
        install_relay
        ;;
     3)
        install_wss
        ;;
     4)
        install_kcp
        ;;
     5)
        install_quic
       ;;
     6)
         install_custom
        ;;
      7)
         uninstall
        ;;
    0)
        exit
        ;;
    *)
        echo "Invalid choice. Please try again."
        ;;
esac
