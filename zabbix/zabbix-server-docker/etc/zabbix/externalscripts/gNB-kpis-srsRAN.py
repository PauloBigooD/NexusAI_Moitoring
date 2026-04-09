#!/usr/bin/env python3

import json
import re
import os
import time
import sys

def exit_with_empty_json():
    """Imprime um JSON com uma lista de dados vazia e encerra o script."""
    print(json.dumps({"data": []}, indent=4))
    sys.exit(0)

# --- Seção 1: Localizar e Validar o Arquivo de Log ---

LOG_FILE = "/tmp/gnb.log"

if not os.path.exists(LOG_FILE):
    exit_with_empty_json()

# Verifica atualização do arquivo (5 min)
try:
    if (time.time() - os.path.getmtime(LOG_FILE)) > 300:
        exit_with_empty_json()
except OSError:
    exit_with_empty_json()

# --- Seção 2: Ler o Log ---

try:
    with open(LOG_FILE, "r") as f:
        log_text = f.read()
    if not log_text:
        exit_with_empty_json()
except IOError:
    exit_with_empty_json()

# --- Seção 3: Extrair Métricas ---

gnb_data = {}

# Regex ajustados. O PLMN agora busca especificamente o valor numérico (incluindo zeros)
patterns = {
    "{#GNB_NAME}": r"ran_node_name:\s*([\w-]+)",
    "{#GNB_PCI}": r"pci:\s*(\d+)",
    "{#GNB_BAND}": r"band:\s*(\d+)",
    "{#GNB_ARFCN}": r"dl_arfcn:\s*(\d+)",
    "{#GNB_SCS}": r"common_scs:\s*(\d+)",
    "{#GNB_SSB_ARFCN}": r"SSB arfcn:(\d+)",
    "{#GNB_PLMN}": r"Supported PLMNs:\s*(\d+)", # Pega do log de conexão com AMF para garantir precisão
    "{#GNB_PRB}": r"nof_crbs:\s*(\d+)"
}

# Fallback para PLMN se não achar na linha do AMF (pega do config)
if not re.search(patterns["{#GNB_PLMN}"], log_text):
    patterns["{#GNB_PLMN}"] = r"plmn:\s*(\d+)"

for key, pattern in patterns.items():
    match = re.search(pattern, log_text)
    if match:
        val = match.group(1)
        
        # --- LÓGICA DE TIPAGEM ---
        # PLMN e NAME devem ser String (PLMN para manter zeros à esquerda)
        if key in ["{#GNB_PLMN}", "{#GNB_NAME}"]:
            gnb_data[key] = val
        else:
            # Os demais tentamos converter para Inteiro
            try:
                gnb_data[key] = int(val)
            except ValueError:
                gnb_data[key] = val
    else:
        # Valores padrão
        if key in ["{#GNB_NAME}", "{#GNB_PLMN}"]:
            gnb_data[key] = "" 
        else:
            gnb_data[key] = 0

# 3.2 Cell ID (Binário -> Decimal)
cell_id_match = re.search(r'"cellIdentity":\s*"([01]+)"', log_text)
if cell_id_match:
    binary_string = cell_id_match.group(1)
    try:
        # Converte binário para inteiro decimal (ex: 6733824)
        gnb_data["{#GNB_NRCELLID}"] = int(binary_string, 2)
    except ValueError:
        gnb_data["{#GNB_NRCELLID}"] = 0
else:
    gnb_data["{#GNB_NRCELLID}"] = 0

# 3.3 Status (0 ou 1)
idx_start = log_text.rfind("Cell creation")
idx_stop = log_text.rfind("Cell was stopped")

if idx_stop > idx_start:
    gnb_data["{#GNB_STATUS}"] = 0
elif idx_start != -1:
    gnb_data["{#GNB_STATUS}"] = 1
else:
    gnb_data["{#GNB_STATUS}"] = 0

# --- Seção 4: Saída ---

# Validação mínima
if not gnb_data["{#GNB_NAME}"] and gnb_data["{#GNB_PCI}"] == 0:
    exit_with_empty_json()

json_output = {"data": [gnb_data]}

print(json.dumps(json_output, indent=4))
