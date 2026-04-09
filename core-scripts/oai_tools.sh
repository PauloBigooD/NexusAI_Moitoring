#!/bin/bash

## Author:   Paulo Eduardo da Silva Junior - paulo.eduardo.093@ufrn.edu.br - Tel: +55 (84) 9 8808-0933
## GitHub:   https://github.com/PauloBigooD
## Linkedin: https://www.linkedin.com/in/paulo-eduardo-5a18b3174/

set -e

## Variável de escolha de opção
COMMAND="$1"
## Work directory path is the current directory
WORK_DIR=$PWD
## Lista de versões disponíveis
VERSION_UHD=("UHD-4.7" "UHD-4.6" "UHD-4.5" "UHD-4.4" "UHD-4.3" "UHD-4.2" "UHD-4.1")
## Definindo o URL do repositório OAI - RAN
REPO_OAI_RAN="https://gitlab.eurecom.fr/oai/openairinterface5g.git"
## Versão da branch OAI - RAN
VERSION_RAN="develop"
## Definindo o URL do repositório OAI - CORE
REPO_OAI_CORE="https://gitlab.eurecom.fr/oai/cn5g/oai-cn5g-fed.git"
## Versão da imagem Docker
DOCKER_IMAGE_OAI="v1.5.0"
## Interface de rede
INTERFACE_PC="enp3s"

DOCKER_CMD="docker compose"
[[ $# -eq 2 ]] && DOCKER_CMD="docker compose"

# Função para verificar se um pacote está instalado
function is_installed(){
    dpkg -l | grep -q "$1"
    }

# Função para instalar pacotes se não estiverem instalados
function install_package() {
    for package in "$@"; do
        if ! is_installed "$package"; then
            echo "Instalando $package..."
            sudo apt-get install -y "$package"
        else
            echo "$package já está instalado."
        fi
    done
    }

# Função para gerenciar performance mode
function performance_mode(){
    install_package "linux-image-lowlatency" "linux-headers-lowlatency"
    if grep -m 1 'vendor_id' /proc/cpuinfo | grep -q 'GenuineIntel'; then
        echo "Intel CPU detectado. Configurando..."
        sudo sed -i '/^GRUB_CMDLINE_LINUX=/d' /etc/default/grub
        echo 'GRUB_CMDLINE_LINUX="quiet intel_pstate=disable processor.max_cstate=1 intel_idle.max_cstate=0"' | sudo tee -a /etc/default/grub
        echo 'blacklist intel_powerclamp' | sudo tee -a /etc/modprobe.d/blacklist.conf
        echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
        sudo update-grub
        install_package "i7z"
        install_package "cpufrequtils"
        sudo systemctl restart cpufrequtils
    elif grep -m 1 'vendor_id' /proc/cpuinfo | grep -q 'AuthenticAMD'; then
        echo "AMD CPU detectado. Configurando..."
        sudo sed -i '/^GRUB_CMDLINE_LINUX=/d' /etc/default/grub
        echo 'GRUB_CMDLINE_LINUX="quiet amd_pstate=disable processor.max_cstate=1 idle=nomwait processor.max_cstate=0"' | sudo tee -a /etc/default/grub
        echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
        sudo update-grub
        install_package "cpufrequtils"
        sudo systemctl restart cpufrequtils
    else
        echo "CPU não identificada."
    fi
    }

# Função para verificar dispositivos USRP
function check_usrp_device(){
    echo "Realizando a verificação da USRP"
    uhd_find_devices 2>&1 | {
    skip=1  # Variável para controlar a primeira linha
    output=""

    while read -r line; do
        if [ $skip -eq 1 ]; then
            skip=0  # Ignora a primeira linha
            continue
        fi
        if echo "$line" | grep -q "No UHD Devices Found"; then
            echo "Verifique se a USRP encontra-se conectada a uma porta USB 3.0"
        fi
    done
    }
    uhd_find_devices
    echo "--------------------------------------------------"
    }

# Função que verifica acionamento da dashboard OAI
function dashboard_check(){
    # Condição que verifica o uso da Dashboard
    if [ "$2" = "-d" ];then
        dash="$2"
        echo -e "Dashboard \e[92mON\e[0m"
    elif [[ "$2" == -* ]];then
        dash=" "
        echo -e "Parâmetro inválido, este deve ser igual a \e[33m-d\e[0m"
    else
        dash=" "
        echo -e "Dashboard \e[31mOFF\e[0m"
    fi
    }

# Função que instala o modo performance
function init_performance(){
    ## Performance mode
	sudo /etc/init.d/cpufrequtils restart
    ## Configuration of the packer forwarding
	sudo sysctl net.ipv4.conf.all.forwarding=1
	sudo iptables -P FORWARD ACCEPT
    }

# Função para compilar e instalar UHD
function install_libuhd() {
    # Verifica se a UHD já está instalada
    if command -v uhd_find_devices &> /dev/null; then
        echo "A biblioteca UHD já está instalada."
        read -p "Deseja reinstalá-la? (s/n): " resposta
        case "$resposta" in
            [Ss]* )
                echo "Reinstalando a biblioteca UHD..."
                ;;
            [Nn]* )
                echo "Nenhuma ação será realizada."
                return 0
                ;;
            * )
                echo "Resposta inválida. Nenhuma ação será realizada."
                return 1
                ;;
        esac
    fi
    echo "Removendo instalações anteriores..."
    sudo rm -rf /usr/local/lib/cmake/uhd
    sudo rm -rf /usr/local/share/doc/uhd
    sudo rm -rf /usr/share/uhd
    sudo rm -rf /usr/share/doc/uhd
    sudo rm -rf /usr/lib/cmake/uhd
    sudo rm -rf ./uhd
    sudo rm -rf /usr/local/lib/uhd
    sudo rm -rf /usr/local/include/uhd
    sudo rm -rf /usr/local/share/uhd

    echo "Escolha a versão da UHD para instalar:"
    for i in "${!VERSION_UHD[@]}"; do
        echo "$((i+1)). ${VERSION_UHD[i]}"
    done
    read -p "Digite o número correspondente à versão desejada: " escolha
    if [[ "$escolha" -ge 1 && "$escolha" -le "${#VERSION_UHD[@]}" ]]; then
        VERSAO_SELECIONADA="${VERSION_UHD[$((escolha-1))]}"
    else
        echo "Escolha inválida. Tente novamente."
        escolher_versao
    fi
    echo "Instalando dependências..."
    sudo apt-get update
    install_package "autoconf " "automake" "ccache" "build-essential" "cmake" "doxygen" "ethtool" "g++" "inetutils-tools" "libboost-all-dev" "libncurses5" "libncurses5-dev" "libusb-1.0-0" "libusb-1.0-0-dev" "libusb-dev" "python3-dev" "python3-mako" "python3-numpy" "python3-requests" "python3-scipy" "python3-setuptools" "python3-ruamel.yaml"
    echo "Instalando UHD versão: $VERSAO_SELECIONADA"
    git clone --branch "$VERSAO_SELECIONADA" https://github.com/EttusResearch/uhd.git
    cd uhd/host || exit
    mkdir build
    cd build || exit
    cmake ../
    make -j"$(nproc)"
    sudo make install
    sudo ldconfig
    # Verificação da instalação
    echo "Verificando a instalação..."
    uhd_find_devices
    uhd_usrp_probe
    }

# Função que instala o Docker
function install_docker(){
    if is_installed docker; then
        echo "Docker já instalado."
    else
        echo "Instalando Docker..."
        # Instalar dependências comuns
        install_package "apt-transport-https" "ca-certificates" "curl" "gnupg" "lsb-release" "python3-pip"
        # Criar o diretório para armazenar a chave GPG, caso não exista
        sudo mkdir -p /etc/apt/keyrings
        # Adicionar chave GPG do Docker
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc
        sudo gpg --no-default-keyring --keyring /etc/apt/keyrings/docker.gpg --import /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        # Detectar a distribuição do sistema
        DISTRO=$(lsb_release -si)
        CODENAME=$(lsb_release -cs)
        if [[ "$DISTRO" == "Ubuntu" ]]; then
            echo "Distribuição Ubuntu detectada."
            echo "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        elif [[ "$DISTRO" == "Debian" ]]; then
            echo "Distribuição Debian detectada."
            echo "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/debian $CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        elif [[ "$DISTRO" == "CentOS" || "$DISTRO" == "RHEL" || "$DISTRO" == "Fedora" ]]; then
            echo "Distribuição baseada em RedHat detectada."
            # Para distribuições como CentOS/RHEL/Fedora, usamos repositórios diferentes
            curl -fsSL https://download.docker.com/linux/centos/docker-ce.repo | sudo tee /etc/yum.repos.d/docker-ce.repo > /dev/null
        else
            echo "Distribuição não suportada para instalação automatizada."
            exit 1
        fi
        # Atualizar repositórios e instalar Docker
        sudo apt-get update
        install_package "docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin"
        # Instalar Docker Compose via pip3 (opcional, se não instalado com o plugin)
        sudo pip3 install docker-compose
        docker login
    fi
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo apt-get clean
    }

# Função que clona o repositorio da RAN do oai
function clone_repo_RAN(){
    cd $WORK_DIR || exit
    if [ -d "openairinterface5g" ]; then
        echo "Removendo diretório existente 'openairinterface5g'..."
        sudo rm -rf openairinterface5g
    fi
    if [ ! -d "openairinterface5g" ]; then
        echo "Clone OpenAirInterface 4G/5G RAN repository"
        git clone "$REPO_OAI_RAN"
        cd openairinterface5g || exit
        git checkout $VERSION_RAN
    else
        echo "Erro: Não foi possível remover o diretório."
    fi
    }

# Função que clona repositorio do CORE do 
function clone_REPO_OAI_CORE(){
    if [ -d "oai-cn5g-fed" ]; then
        echo "Removendo o diretório existente ' oai-cn5g-fed'..."
        sudo rm -rf  oai-cn5g-fed
    fi
    if [ ! -d "oai-cn5g-fed" ]; then
        echo "Clone OpenAirInterface 5G Core repository"
        git clone "$REPO_OAI_CORE"
        cd oai-cn5g-fed || exit
        git checkout -f $DOCKER_IMAGE_OAI
    else
        echo "Erro: Não foi possível remover o diretório."
    fi
    }

# Função para configurar e compilar a RAN do OpenAirInterface
function build_oai_RAN(){
    echo "Install OAI dependencies and Build OAI RAN"
    cd $WORK_DIR || exit
    cd openairinterface5g || exit
    source oaienv
    cd cmake_targets || exit
    sudo ./build_oai -I
    sudo ./build_oai -I --install-optional-packages
    sudo ./build_oai -w USRP --ninja --build-e2 --gNB --eNB --nrUE -C --build-lib "uescope nrscope enbscope telnetsrv"
    }

# Função que realiza o deploy da RAN e CORE do OAI
function start_5g_oai_mono(){
    stop_5g_oai
    sudo sysctl net.ipv4.conf.all.forwarding=1
    sudo iptables -P FORWARD ACCEPT
    sudo sysctl -w net.core.wmem_max=33554432
    sudo sysctl -w net.core.rmem_max=33554432
    sudo sysctl -w net.core.wmem_default=33554432
    sudo sysctl -w net.core.rmem_default=33554432
    cd $WORK_DIR/core-scripts || exit
    sudo python3 core-network.py --type start-basic --scenario 1
    sleep 20
    docker ps -a
    }

# Função que realiza o deploy da RAN e CORE do OAI
function start_5g_oai_dist(){
    stop_5g_oai
    sudo sysctl net.ipv4.conf.all.forwarding=1
    sudo iptables -P FORWARD ACCEPT
    sudo sysctl -w net.core.wmem_max=33554432
    sudo sysctl -w net.core.rmem_max=33554432
    sudo sysctl -w net.core.wmem_default=33554432
    sudo sysctl -w net.core.rmem_default=33554432
    cd $WORK_DIR/core-scripts || exit
    sudo sudo docker compose -f docker-compose-basic-nrf-macvlan.yaml up -d
    docker ps -a
    }

# Função para realizar pull imagens docker 5G
function pull_docker_5g(){
    echo "Pulling the images from Docker Hub"   
    ## Pulling the images from Docker Hub
    sudo docker pull oaisoftwarealliance/oai-amf:$DOCKER_IMAGE_OAI
    sudo docker pull oaisoftwarealliance/oai-nrf:$DOCKER_IMAGE_OAI
    sudo docker pull oaisoftwarealliance/oai-smf:$DOCKER_IMAGE_OAI
    sudo docker pull oaisoftwarealliance/oai-udr:$DOCKER_IMAGE_OAI
    sudo docker pull oaisoftwarealliance/oai-udm:$DOCKER_IMAGE_OAI
    sudo docker pull oaisoftwarealliance/oai-ausf:$DOCKER_IMAGE_OAI
    sudo docker pull oaisoftwarealliance/oai-spgwu-tiny:$DOCKER_IMAGE_OAI
    sudo docker pull oaisoftwarealliance/trf-gen-cn5g:latest
    ## Tag Docker Images
    sudo docker image tag oaisoftwarealliance/trf-gen-cn5g:latest trf-gen-cn5g:latest
    sudo docker image tag oaisoftwarealliance/oai-amf:$DOCKER_IMAGE_OAI oai-amf:$DOCKER_IMAGE_OAI
    sudo docker image tag oaisoftwarealliance/oai-nrf:$DOCKER_IMAGE_OAI oai-nrf:$DOCKER_IMAGE_OAI
    sudo docker image tag oaisoftwarealliance/oai-smf:$DOCKER_IMAGE_OAI oai-smf:$DOCKER_IMAGE_OAI
    sudo docker image tag oaisoftwarealliance/oai-udr:$DOCKER_IMAGE_OAI oai-udr:$DOCKER_IMAGE_OAI
    sudo docker image tag oaisoftwarealliance/oai-udm:$DOCKER_IMAGE_OAI oai-udm:$DOCKER_IMAGE_OAI
    sudo docker image tag oaisoftwarealliance/oai-ausf:$DOCKER_IMAGE_OAI oai-ausf:$DOCKER_IMAGE_OAI
    sudo docker image tag oaisoftwarealliance/oai-spgwu-tiny:$DOCKER_IMAGE_OAI oai-spgwu-tiny:$DOCKER_IMAGE_OAI
    }

# Função que pausa o 5G OAI
function stop_5g_oai(){
    cd $WORK_DIR/core-scripts
    sudo docker rm -f rfsim5g-oai-gnb
    sudo python3 core-network.py --type stop-basic
    }

# Função que gera o log do AMF 5G OAI
function logs_5g_oai() {
    ## Verifica se o contêiner 5G Core está em execução
    if sudo docker inspect -f '{{.State.Running}}' oai-amf | grep true > /dev/null; then
        ## Exibe os logs do 5G Core
        echo "Exibindo logs do 5G Core..."
        sudo docker logs -f oai-amf
    else
        ## Exibe mensagem se o 5G Core não estiver em execução
        echo "O 5G Core não está em execução. Por favor, selecione a opção 6 do menu para iniciar o Core 5G."
    fi
    }

# Função para checar mcc, mnc e IP do arquivo de configuração da gNB
function chek_gNB_conf(){
    sudo docker rm -f rfsim5g-oai-gnb
    sudo docker rm -f oai-gnb oai-gnb-2 
    #check_usrp_device
    if [ "$4" = "docker" ]; then
        cd "$WORK_DIR" || exit
        ${DOCKER_CMD} -f core-scripts/docker-compose/docker-compose-"$1""$2"-PRB"$3""$5".yaml up
    else
        dashboard_check
        # Caminho do arquivo de configuração
        CONFIG_FILE="conf/${1}${2}PRB${3}bm${5}.conf"             
        # Inicializa a variável de IP
        IP_ADDRESS=""        
        # Novos valores
        NEW_MCC=001
        NEW_MNC=01
        NEW_TRACKING_AREA_CODE=0x0001
        NEW_AMF_IP="192.168.70.132"
        NEW_SNSSAI="snssaiList = ({ sst = 1; sd = 0x1 });"
        # Laço para verificar as interfaces enp3s0 até enp3s4
        for i in {0..4}; do
            INTERFACE="$INTERFACE_PC$i"
            IP_ADDRESS=$(ip -4 addr show "$INTERFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
            if [ -n "$IP_ADDRESS" ]; then
                break
            fi
        done
        # Verifica se um endereço IP foi encontrado
        if [ -z "$IP_ADDRESS" ]; then
            echo "Nenhum endereço IP encontrado para as interfaces $INTERFACE_PC a enp3s4"
            exit 1
        fi
        # Faz as substituições no arquivo de configuração
        sed -i.bak \
            -e "s/mcc = [0-9]\{3\};/mcc = $NEW_MCC;/" \
            -e "s/mnc = [0-9]\{2\};/mnc = $NEW_MNC;/" \
            -e "s/tracking_area_code = [0-9a-fx]*;/tracking_area_code = $NEW_TRACKING_AREA_CODE;/" \
            -e "s/snssaiList = ({ sst = 1; sd = [0-9a-fx]* });/$NEW_SNSSAI/" \
            -e "s/amf_ip_address = ({ ipv4 = \"[0-9.]*\";/amf_ip_address = ({ ipv4 = \"$NEW_AMF_IP\";/" \
            -e "s/GNB_IPV4_ADDRESS_FOR_NG_AMF *= *\"[0-9.\/]*\";/GNB_IPV4_ADDRESS_FOR_NG_AMF = \"$IP_ADDRESS\";/" \
            -e "s/GNB_IPV4_ADDRESS_FOR_NGU *= *\"[0-9.\/]*\";/GNB_IPV4_ADDRESS_FOR_NGU = \"$IP_ADDRESS\";/" \
            -e "s/GNB_INTERFACE_NAME_FOR_NG_AMF *= *\"[^\"]*\";/GNB_INTERFACE_NAME_FOR_NG_AMF = \"$INTERFACE\";/" \
            -e "s/GNB_INTERFACE_NAME_FOR_NGU *= *\"[^\"]*\";/GNB_INTERFACE_NAME_FOR_NGU = \"$INTERFACE\";/" \
        "$CONFIG_FILE"
        # Exibe uma mensagem de sucesso
        echo "Configurações atualizadas com sucesso no arquivo: $CONFIG_FILE"
        cd openairinterface5g/cmake_targets/ran_build/build/
        # Iniciar o softmodem
        sudo RFSIMULATOR=server ./nr-softmodem -E --rfsim --sa -O ../../../../conf/${1}${2}PRB${3}bm${5}.conf --gNBs.[0].min_rxtxtime 6 --continuous-tx $dash
    fi
    }

function start_nearRT-RIC(){
    cd flexric
    ./build/examples/ric/nearRT-RIC
    }

function start_E2Agent(){
    cd flexric
    ./build/examples/emulator/agent/emu_agent_gnb
    }

function start_gNB_rfsim_docker(){
    echo "Encerrando gNB rfSIM Docker"
    cd "$WORK_DIR" || exit
    ${DOCKER_CMD} -f core-scripts/docker-compose/docker-compose-b210-PRB106-rfSIM.yaml down
    echo "Iniciando gNB rfSIM Docker"
    ${DOCKER_CMD} -f core-scripts/docker-compose/docker-compose-b210-PRB106-rfSIM.yaml up -d
    docker logs -f rfsim5g-oai-gnb
    }

function start_gNB_rfsim(){
    cd openairinterface5g/cmake_targets/ran_build/build/
    # Iniciar o softmodem
    sudo ./nr-softmodem -E --rfsimulator server --rfsim --sa -O ../../../../conf/b210PRB106bm.conf --continuous-tx --gNBs.[0].min_rxtxtime 6
    }

function logs_gNB_rfsim_docker(){
    docker logs -f rfsim5g-oai-gnb
    }
    
function stop_gNB_rfsim_docker(){
    cd "$WORK_DIR" || exit
    echo "Encerrando gNB rfSIM Docker"
    ${DOCKER_CMD} -f core-scripts/docker-compose/docker-compose-b210-PRB106-rfSIM.yaml down   
    }

function start_UE_rfsim(){
    CONFIG_FILE="openairinterface5g/targets/PROJECTS/GENERIC-NR-5GC/CONF/ue.conf"
    NEW_imsi="001010000000003"
    NEW_key="fec86ba6eb707ed08905757b1bb44b8f"
    NEW_opc="C42449363BBAD02B66D16BC975D77CC1"
    NEW_dnn="oai"
    NEW_nssai_sst=1
    NEW_nssai_sd=1
    sed -i.bak \
        -e "s/imsi *= *\"[^\"]*\";/imsi = \"$NEW_imsi\";/" \
        -e "s/key *= *\"[^\"]*\";/key = \"$NEW_key\";/" \
        -e "s/opc *= *\"[^\"]*\";/opc = \"$NEW_opc\";/" \
        -e "s/dnn *= *\"[^\"]*\";/dnn = \"$NEW_dnn\";/" \
        -e "s/nssai_sst *= *[0-9]*;/nssai_sst = $NEW_nssai_sst;/" \
        -e "s/nssai_sd *= *[0-9]*;/nssai_sd = $NEW_nssai_sd;/" \
        "$CONFIG_FILE"
    echo "Configurações atualizadas com sucesso no arquivo: $CONFIG_FILE"  
    cd openairinterface5g/cmake_targets/ran_build/build/
    sudo ./nr-uesoftmodem --rfsimulator.serveraddr 192.168.70.129 -r 106 --numerology 1 --band 78 -C 3619200000 --rfsim --sa -O ../../../targets/PROJECTS/GENERIC-NR-5GC/CONF/ue.conf
    }

function start_UE_rfsim_docker(){
    echo "Encerrando UE rfSIM Docker"
    cd "$WORK_DIR" || exit
    ${DOCKER_CMD} -f core-scripts/docker-compose/docker-compose-ue.yaml down
    echo "Iniciando UE rfSIM Docker"
    ${DOCKER_CMD} -f core-scripts/docker-compose/docker-compose-ue.yaml up
    docker logs -f rfsim5g-oai-ue
    }

function FlexRIC() {
    echo "================================================"
    echo "Instalando dependências do FlexRIC"
    echo "================================================"
    sudo apt-get update
    install_package "automake" "g++" "make" "libpcre2-dev" "byacc" "cmake" "python3-dev" "libsctp-dev" "bison" "libconfig-dev" "cmake-curses-gui" "pkg-config" "libconfig++-dev"
    cd $WORK_DIR || exit
    if [ -d "swig" ]; then
        echo "Removendo diretório existente 'swig'..."
        sudo rm -rf swig
    fi
    if [ ! -d "swig" ]; then
    echo "================================================"
    echo "Instalando SWIG"
    echo "================================================"
    git clone https://github.com/swig/swig.git
    cd "$WORK_DIR"/swig || { echo "Erro ao acessar o diretório swig"; exit 1; }
    git checkout release-4.1
    ./autogen.sh || { echo "Erro no autogen.sh do SWIG"; exit 1; }
    ./configure --prefix=/usr/ || { echo "Erro na configuração do SWIG"; exit 1; }
    make -j8 || { echo "Erro ao compilar SWIG"; exit 1; }
    sudo make install || { echo "Erro ao instalar SWIG"; exit 1; }
    cd $WORK_DIR || exit
    else
        echo "Erro: Não foi possível remover o diretório."
    fi

    if [ -d "flexric" ]; then
        echo "[INFO] Removendo FlexRIC antigo..."
        sudo rm -rf flexric
    fi

    echo "============================================"
    echo "  Escolha a branch do FlexRIC"
    echo "============================================"
    echo "1) 37e85a00 (OAI compatível)"
    echo "2) dev       (OAI compatível)"
    echo "3) br-flexric (srsRAN compatível)"
    read -p "Selecione [1-3]: " BRANCH_OPT

    case $BRANCH_OPT in
        1) FLEXRIC_BRANCH="37e85a00" ;;
        2) FLEXRIC_BRANCH="dev" ;;
        3) FLEXRIC_BRANCH="br-flexric" ;;
        *)
            echo "Opção inválida. Abortando."
            return 1
            ;;
    esac   
    echo "================================================"
    echo "[INFO] Clonando FlexRIC branch: $FLEXRIC_BRANCH"
    echo "================================================"
    git clone https://gitlab.eurecom.fr/mosaic5g/flexric.git
    cd flexric || exit 1
    git checkout "$FLEXRIC_BRANCH"

    ############################################
    # xAPP COPY LOGIC
    ############################################
    rm -f examples/xApp/c/monitor/CMakeLists.txt
    echo "================================================"
    echo "[INFO] Copiando xApp MONITOR"
    echo "================================================"

    if [[ "$FLEXRIC_BRANCH" == "37e85a00" || "$FLEXRIC_BRANCH" == "dev" ]]; then
        echo "[INFO] xApp para OAI"
        cp -f $WORK_DIR/xApp/flexRIC/oai/* examples/xApp/c/monitor/
        mkdir -p build
        cd build || { echo "Erro ao acessar diretório build"; exit 1; }
        cmake -DSWIG_EXECUTABLE=/usr/bin/swig .. || { echo "Erro no comando cmake"; exit 1; }
        make -j8 || { echo "Erro ao compilar FlexRIC"; exit 1; }
        sudo make install || { echo "Erro ao instalar FlexRIC"; exit 1; }

    elif [[ "$FLEXRIC_BRANCH" == "br-flexric" ]]; then
        echo "[INFO] xApp para srsRAN"
        cp -f $WORK_DIR/xApp/flexRIC/srsRAN/* examples/xApp/c/monitor/
        mkdir build
        export LibConfig_INCLUDE_DIR=/usr/include
        export LibConfig_LIBRARY=/usr/lib/x86_64-linux-gnu/libconfig.so
        cd build || { echo "Erro ao acessar diretório build"; exit 1; }
        cmake -DKPM_VERSION=KPM_V3_00 -DXAPP_DB=NONE_XAPP -DSWIG_EXECUTABLE=/usr/bin/swig ../ || { echo "Erro no comando cmake"; exit 1; }
        make || { echo "Erro ao compilar FlexRIC"; exit 1; }
        sudo make install || { echo "Erro ao instalar FlexRIC"; exit 1; }
    fi

    if type clone_repo_RAN >/dev/null 2>&1; then
        clone_repo_RAN
    else
        echo "Função clone_repo_RAN não encontrada. Certifique-se de que está definida."
    fi
    # Chamada para build_oai_RAN (necessário definir antes de usar)
    if type build_oai_RAN >/dev/null 2>&1; then
        build_oai_RAN
    else
        echo "Função build_oai_RAN não encontrada. Certifique-se de que está definida."
    fi
    }

function xApps(){
    while true; do
        echo -e "
        --------------------------------------------------------------------------------------------------------------------------------------------------
        | 1 - xapp_kpm_moni               <-> Start the KPM monitor xApp - measurements stated in 2.1.1 E2SM-KPM.                                        |
        | 2 - xapp_rc_moni                <-> Start the RC monitor xApp - aperiodic subscription for UE RRC State Change.                                |
        | 3 - xapp_kpm_rc                 <-> Start the RC control xApp - RAN control function QoS flow mapping configuration (e.g. creating a new DRB). |
        | 4 - xapp_gtp_mac_rlc_pdcp_moni  <-> Start the (MAC + RLC + PDCP + GTP) monitor xApp.                                                           |
        | 5 - xappMON_RAN_OAI             <-> Collect the E2SMs capabilities E2 Node OAI                                                                 |
        | 6 - xappMON_RAN_srsRAN          <-> Collect the E2SMs capabilities E2 Node OAI                                                                 |
        --------------------------------------------------------------------------------------------------------------------------------------------------
        "
    read -p "Escolha uma opção para deploy: " escolha
    case $escolha in
        1) ./flexric/build/examples/xApp/c/monitor/xapp_kpm_moni ;;
        2) ./flexric/build/examples/xApp/c/monitor/xapp_rc_moni ;;
        3) ./flexric/build/examples/xApp/c/kpm_rc/xapp_kpm_rc ;;
        4) ./flexric/build/examples/xApp/c/monitor/xapp_gtp_mac_rlc_pdcp_moni ;;
        5) ./flexric/build/examples/xApp/c/monitor/xappMON ;;
        6) ./flexric/build/examples/xApp/c/monitor/xappMON_srs ;;
        *) echo "Opção inválida! Tente novamente." ;;
        esac
        echo ""
    done    
    }

function startZabbix(){
    cd zabbix/zabbix-server-docker/
    docker compose up -d
    }

function stopZabbix(){
    cd zabbix/zabbix-server-docker/
    docker compose down
    }

function installZabbix(){
    cd zabbix/zabbix-agent/ || return
    echo "=========================================="
    echo "Instalação do coletor de KPIs Zabbix Agent"
    echo "=========================================="
    read -p "Informe o hostname: " HOSTNAME
    read -p "Informe o IP do Zabbix Server: " SERVER
    read -p "Informe o metadata (ex: O-RAN): " METADATA
    echo ""
    echo "Instalando com os seguintes parâmetros:"
    echo "Hostname: $HOSTNAME"
    echo "Server: $SERVER"
    echo "Metadata: $METADATA"
    echo ""
    sudo ./install_zabbix_agent2.sh \
        --hostname "$HOSTNAME" \
        --server "$SERVER" \
        --metadata "$METADATA"
    }

function install_scRIC(){
    sudo rm -rf oran-sc-ric
    echo "Instalando dependências do O-RAN SC RIC"
    git clone https://github.com/srsran/oran-sc-ric
    cd ./oran-sc-ric
    echo "Copiando xAppMON"
    cp $WORK_DIR/xApp/scRIC/xappMON-SC.py ./xApps/python/
    }

function start_scRIC(){
    echo "Iniciando O-RAN SC RIC"
    cd ./oran-sc-ric
    docker compose up -d
    }

function logs_scRIC(){
    cd ./oran-sc-ric
    docker compose logs -f
    }

function stop_scRIC(){
    cd ./oran-sc-ric
    docker compose down
    }

function start_Open5GS(){
    cd ./open5GS
    docker compose --env-file open5gs/open5gs.env -f docker-compose.yml up -d 5gc
    echo "Iniciando Open5GS"
    sleep 10
    docker logs -f open5gs_5gc
    #OPEN_5GS_ENV_FILE=open5gs/open5gs.env docker compose -f docker-compose.yml up 5gc -d
    }

function stop_Open5GS(){
    cd ./open5GS
    docker compose --env-file open5gs/open5gs.env -f docker-compose.yml down 5gc
    #OPEN_5GS_ENV_FILE=open5gs/open5gs.env docker compose -f docker-compose.yml down
    }

function logs_Open5GS(){
    docker logs -f open5gs_5gc
    }

function install_RAN_srsRAN(){
    echo "Instalando dependências"
    install_package "cmake" "make" "gcc-10" "g++-10" "libgtest-dev" "pkg-config" "libfftw3-dev" "libmbedtls-dev" "libsctp-dev" "libyaml-cpp-dev" "libdw-dev" "libbfd-dev" "libdwarf-dev" "binutils-dev"
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 100
    sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 100
    sudo rm -rf mbedtls
    echo "Clonando mbedtls"
    git clone https://github.com/Mbed-TLS/mbedtls.git
    cd mbedtls
    git checkout v3.5.2
    mkdir build && cd build
    cmake ..
    make -j$(nproc)
    sudo make install
    sudo ldconfig
    cd ../..
    sudo rm -rf libzmq
    echo "Clonando libzmq"
    export CXXFLAGS="-Wno-stringop-overflow -Wno-error=stringop-overflow"
    git clone https://github.com/zeromq/libzmq.git
    cd libzmq
    mkdir build && cd build
    cmake ..
    make -j$(nproc)
    sudo make install
    sudo ldconfig
    cd ..
    sudo rm -rf czmq
    echo "Clonando czmq"
    git clone https://github.com/zeromq/czmq.git
    cd czmq
    ./autogen.sh
    ./configure
    make
    sudo make install
    sudo ldconfig
    cd ..
    echo "Ativar modo performance"
    cd $WORK_DIR/srsRAN/utils/
    ./srsran_performance.sh
    cd ..
    sudo rm -rf build
    mkdir build
    cd build
    echo "Build srsRAN"
    cmake ../ -DENABLE_EXPORT=ON -DENABLE_ZEROMQ=ON
    make -j`nproc`
    sudo make install
    echo "Instalado com sucesso"
    }

function gNB_b106_bm_srsRAN(){
    cd $WORK_DIR/srsRAN/utils/
    ./gnb_up_b210_256QAM_MIMO_30Mhz.sh
    }

function gNB_srsRAN_docker(){
    sudo docker rm -f srsran_gnb
    cd $WORK_DIR/srsRAN/docker
    sudo docker compose up -d
    sudo docker logs -f srsran_gnb
    }

function logs_gNB_srsRAN_docker(){
    sudo docker logs -f srsran_gnb
    }

function stop_gNB_srsRAN_docker(){
    echo "Encerrando gNB srsRAN"
    cd $WORK_DIR/srsRAN/docker
    sudo docker compose -f docker-compose.yaml down
    }

# Case principal
case "${COMMAND}" in
    "--install")
        install_package "git"
        install_docker
        install_libuhd
        performance_mode
        ;;
    "--stop_srsRAN_docker")
        stop_gNB_srsRAN_docker
        ;;
    "--logs_srsRAN_docker")
        logs_gNB_srsRAN_docker
        ;;
    "--gNB_srsRAN_docker")
        gNB_srsRAN_docker
        ;;
    "--gNB_b106_bm_srsRAN")
        gNB_b106_bm_srsRAN
        ;;
    "--install_RAN_srsRAN")
        install_RAN_srsRAN
        ;; 
    "--start_Open5GS")
        start_Open5GS
        ;;    
    "--logs_Open5GS")
        logs_Open5GS
        ;;
    "--stop_Open5GS")
        stop_Open5GS
        ;;
    "--start_scRIC")
        start_scRIC
        ;;
    "--stop_scRIC")
        stop_scRIC
        ;;
    "--install_scRIC")
        install_scRIC
        ;;
    "--logs_scRIC")
        logs_scRIC
        ;;
    "--installZabbix")
        installZabbix
        ;;
    "--startZabbix")
        startZabbix
        ;;
    "--stopZabbix")
        stopZabbix
        ;;
    "--install_5gc_oai")
        pull_docker_5g
        ;;
    "--install_RAN_oai")
        clone_repo_RAN
        build_oai_RAN       
        ;;
    "--start_5g_oai_mono")
        init_performance
        start_5g_oai_mono
        ;;
    "--start_5g_oai_dist")
        init_performance
        start_5g_oai_dist
        ;;
    "--stop_5g_oai")
        stop_5g_oai
        ;;
    "--logs_5g_oai")
        logs_5g_oai
        ;;
    "--gNB_b106")
        chek_gNB_conf "b" "210" "106" "docker" ""      
        ;;
    "--gNB_b106_bm")
        chek_gNB_conf "b" "210" "106" "" ""      
        ;;
    "--FlexRIC")
        FlexRIC
        ;;
    "--start_nearRT-RIC")
        start_nearRT-RIC
        ;;
    "--start_E2Agent")
        start_E2Agent
        ;;
    "--start_gNB_rfsim")
        start_gNB_rfsim
        ;;
    "--start_gNB_rfsim_docker")
        start_gNB_rfsim_docker
        ;;
    "--stop_gNB_rfsim_docker")
        stop_gNB_rfsim_docker
        ;;
    "--logs_gNB_rfsim_docker")
        logs_gNB_rfsim_docker
        ;;
    "--start_UE_rfsim")
        start_UE_rfsim
        ;;
    "--start_UE_rfsim_docker")
        start_UE_rfsim_docker
        ;;
    "--xApps")
        xApps
        ;;
        *)
echo " COMMAND not Found."
show_help
exit 127;
;;
esac
