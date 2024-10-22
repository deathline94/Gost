#!/bin/bash

# Check if running as root
root_access() {
    # Check if the  script is running as root
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root."
        exit 1
    fi
}

#Check dependencies
check_dependencies() {
    root_access
    local dependencies=("wget" "nano" "gunzip")
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "${dep}" &> /dev/null; then
            echo "${dep} is not installed. Installing..."
            sudo "${package_manager}" install "${dep}" -y
        fi
    done
}

#Check installed service 
check_installed() {
    if [ -f "/etc/systemd/system/gost.service" ]; then
        echo "The service is already installed."
        exit 1
    fi
}

install_gost() {
    check_installed
    check_dependencies

    # Detect OS
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')

    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        i686|i386) ARCH="386" ;;
        armv7l) ARCH="armv7" ;;
        armv6l) ARCH="armv6" ;;
        armv5tel) ARCH="armv5" ;;
        aarch64) ARCH="arm64" ;;
        mips) ARCH="mips_softfloat" ;;
        mipsle) ARCH="mipsle_softfloat" ;;
        mips64) ARCH="mips64_hardfloat" ;;
        mips64le) ARCH="mips64le_hardfloat" ;;
        riscv64) ARCH="riscv64" ;;
        s390x) ARCH="s390x" ;;
    esac

    # Define file extension based on OS
    EXT="tar.gz"
    if [ "$OS" == "windows" ]; then
        EXT="zip"
    fi

    # Fetch the latest release (including nightly, beta, etc.)
    LATEST_VERSION=$(curl -s https://api.github.com/repos/go-gost/gost/releases | grep 'tag_name' | head -n 1 | cut -d '"' -f 4)

    # Construct the filename
    FILE_NAME="gost_${LATEST_VERSION}_${OS}_${ARCH}.${EXT}"

    # Download and extract the appropriate file
    wget https://github.com/go-gost/gost/releases/download/${LATEST_VERSION}/${FILE_NAME}

    if [ "$EXT" == "tar.gz" ]; then
        tar -xzf ${FILE_NAME}
    else
        unzip ${FILE_NAME}
    fi

    # Move binary to /usr/local/bin
    sudo mv gost /usr/local/bin/gost
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
