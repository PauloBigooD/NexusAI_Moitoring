#!/bin/bash

set -e

WORK_DIR=$PWD
LOG_DIR="$WORK_DIR/logs"
mkdir -p "$LOG_DIR"

TMUX_CONF_FILE="$HOME/.tmux.conf"
[[ ! -f "$TMUX_CONF_FILE" ]] && echo "set -g mouse on" > "$TMUX_CONF_FILE"

log_exec() {
    local log_name="$1"
    shift
    bash -c "$@" 2>&1 | tee "$LOG_DIR/${log_name}_$(date +%Y%m%d_%H%M%S).log"
}

function open_terminal() {
    TMUX_CONF_FILE="$HOME/.tmux.conf"
    [[ ! -f "$TMUX_CONF_FILE" ]] && echo "set -g mouse on" > "$TMUX_CONF_FILE"

    if [[ -n "$SSH_CONNECTION" ]]; then
        tmux new-session -d -s session_$2 "$1; echo -e '\n\nPressione qualquer tecla para sair...'; read -n 1 -s; exit"
        tmux attach-session -t session_$2
    else
        if [[ -n "$DISPLAY" && $XDG_SESSION_TYPE == "x11" ]]; then
            if command -v gnome-terminal &> /dev/null; then
                gnome-terminal -- bash -c "$1; echo -e '\n\nPressione qualquer tecla para sair...'; read -n 1 -s; exit" & disown
            else
                x-terminal-emulator -e bash -c "$1; echo -e '\n\nPressione qualquer tecla para sair...'; read -n 1 -s; exit" & disown
            fi
        else
            tmux new-session -d -s session_$2 "$1; echo -e '\n\nPressione qualquer tecla para sair...'; read -n 1 -s; exit"
            tmux attach-session -t session_$2
        fi
    fi
}

run() {
    local option="$1"
    open_terminal "./core-scripts/oai_tools.sh $option" "$(echo $option | tr -d -- -)"
}

menu() {
    while true; do
        echo -e "\n===================== 🛠 \e[1;36m O-RAN_tools \e[0m🛠 ====================="
        echo  "1) Instalar componentes Git, Docker e UHD"
        echo  "2) Iniciar Servidor de Monitoramento (Zabbix Server; Grafana)"
        echo  "3) Parar Servidor de Monitoramento (Zabbix Server; Grafana)"
        echo -e "\n===================== OAI ====================="
        echo  "4) Dependências 5GC OAI"
        echo  "5) Dependências 5G RAN OAI"
        echo  "6) Iniciar 5GC Local OAI"
        echo  "7) Logs 5GC OAI"
        echo  "8) Parar 5GC OAI"
        echo "9) Iniciar gNB OAI rfsim (Docker 🐳)"
        echo "10) Logs gNB OAI rfsim (Docker 🐳)"
        echo "11) Parar gNB OAI rfsim (Docker 🐳)"
        echo "12) Iniciar gNB OAI rfsim (Bare Metal)"
        echo "13) Iniciar gNB OAI b210 106_PRBs (Bare Metal)"
        echo "14) Iniciar gNB OAI b210 106_PRBs (Docker 🐳)"
        echo "15) Iniciar UE OAI rfsim (Docker 🐳)"
        echo "16) Iniciar UE OAI rfsim (Bare Metal)"
        echo -e "\n===================== FlexRIC ====================="
        echo "17) Instalar FlexRIC"
        echo "18) Iniciar FlexRIC - 127.0.0.1"
        echo "19) Iniciar E2 Node Simulado"
        echo "20) Iniciar xApps FlexRIC"
        echo -e "\n===================== O-RAN SC RIC ====================="
        echo "21) Instalar O-RAN SC RIC"
        echo "22) Iniciar O-RAN SC RIC - 10.0.2.10"
        echo "23) Logs O-RAN SC RIC"
        echo "24) Parar O-RAN SC RIC"
        echo -e "\n===================== Open5GS ====================="
        echo "25) Iniciar 5GC Local Open5GS"
        echo "26) Logs 5GC Open5GS"
        echo "27) Parar 5GC Open5GS"
        echo -e "\n===================== srsRAN ====================="
        echo "28) Dependências 5G RAN srsRAN (Bare Metal)"     
        echo "29) Iniciar gNB srsRAN b210 106_PRBs (Bare Metal)"
        echo "30) Iniciar gNB srsRAN b210 106_PRBs (Docker 🐳)"
        echo "31) Logs gNB srsRAN b210 106_PRBs (Docker 🐳)"
        echo "32) Parar gNB srsRAN b210 106_PRBs (Docker 🐳)"
        echo -e "\n===================== Zabbix Agent ====================="
        echo "33) Instalar Coletor de KPIs (Zabbix Agent)"
        echo -e "\n========================================================"
        echo -e "34) \e[1;31mSair\e[0m"
        read -p "Escolha uma opção: " opt
        case $opt in
            1) run --install ;;
            2) run --startZabbix ;;
            3) run --stopZabbix ;;
            4) run --install_5gc_oai ;;
            5) run --install_RAN_oai ;;                  
            6) run --start_5g_oai_mono ;;
            7) run --logs_5g_oai ;;
            8) run --stop_5g_oai ;;
            9) run --start_gNB_rfsim_docker ;;
            10) run --logs_gNB_rfsim_docker ;;
            11) run --stop_gNB_rfsim_docker ;;
            12) run --start_gNB_rfsim ;;
            13) run --gNB_b106_bm ;;
            14) run --gNB_b106 ;;
            15) run --start_UE_rfsim_docker ;;
            16) run --start_UE_rfsim ;;
            17) run --FlexRIC ;;
            18) run --start_nearRT-RIC ;;
            19) run --start_E2Agent ;;
            20) run --xApps ;;
            21) run --install_scRIC ;;
            22) run --start_scRIC ;;
            23) run --logs_scRIC ;;
            24) run --stop_scRIC ;;      
            25) run --start_Open5GS ;;
            26) run --logs_Open5GS ;;
            27) run --stop_Open5GS ;;
            28) run --install_RAN_srsRAN ;;
            29) run --gNB_b106_bm_srsRAN ;;
            30) run --gNB_srsRAN_docker ;; 
            31) run --logs_srsRAN_docker ;;
            32) run --stop_srsRAN_docker ;; 
            33) run --installZabbix ;;  
            34) echo "Saindo..."; break ;;
            *) echo "Opção inválida!" ;;
	esac
    done
}

menu
