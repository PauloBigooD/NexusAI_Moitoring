#!/usr/bin/env python3

import json
import subprocess
import re
import os
import time

# Comando para encontrar o caminho do arquivo (busca no $HOME para evitar erros de permissão)
cmd = "find / -type f -wholename '*/openairinterface5g/cmake_targets/ran_build/build/nrMAC_stats.log' 2>/dev/null"

try:
    file_path = subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()
    if not file_path:
        #print("Arquivo nrMAC_stats.log não encontrado.")
        exit(1)
except Exception as e:
    #print("Erro ao localizar o arquivo:", e)
    exit(1)

# Verifica o tempo da última modificação do arquivo
try:
    last_modified = os.path.getmtime(file_path)
    current_time = time.time()
    elapsed_time = current_time - last_modified

    if elapsed_time > 120:  # Mais de 2 minutos sem atualização
        #print(f"Aviso: O arquivo {file_path} não foi atualizado nos últimos 2 minutos.")
        exit(1)

except Exception as e:
    #print(f"Erro ao verificar o tempo de modificação do arquivo: {e}")
    exit(1)

# Função para ler o conteúdo do arquivo
def read_log_file(log_file):
    try:
        with open(log_file, "r") as f:
            return f.read()
    except FileNotFoundError:
        print(f"Erro: Arquivo {log_file} não encontrado ao tentar abrir.")
        return None

# Lê o conteúdo do arquivo
log_text = read_log_file(file_path)
if not log_text:
    #print("Não foi possível ler o arquivo.")
    exit(1)

# Expressões regulares para capturar as informações necessárias
patterns = {
    "{#MAC_UE_RNTI}": r"UE RNTI ([0-9a-fA-F]+)",
    "{#MAC_CU_UE_ID}": r"CU-UE-ID (\d+)",
    "{#MAC_PH}": r"PH (\d+) dB",
    "{#MAC_AVG_RSRP}": r"average RSRP (-?\d+)",
    "{#MAC_PCMAX}": r"PCMAX (\d+) dBm",
    "{#MAC_NPRB}": r"NPRB (\d+)",
    "{#MAC_DLSCH_ROUNDS}": r"dlsch_rounds ([\d/]+)",
    "{#MAC_DLSCH_ERRORS}": r"dlsch_errors (\d+)",
    "{#MAC_PUCCH0_DTX}": r"pucch0_DTX (\d+)",
    "{#MAC_ULSCH_ROUNDS}": r"ulsch_rounds ([\d/]+)",
    "{#MAC_ULSCH_ERRORS}": r"ulsch_errors (\d+)",
    "{#MAC_ULSCH_DTX}": r"ulsch_DTX (\d+)",
    "{#MAC_QM}": r"Qm (\d+)",
    "{#MAC_DELTA_MCS}": r"deltaMCS (\d+) dB",
    "{#MAC_SNR}": r"SNR ([\d\.]+) dB"
}

# Dicionário para armazenar os dados capturados
data = {}

# Extração dos dados
for key, pattern in patterns.items():
    match = re.search(pattern, log_text)
    if match:
        value = match.group(1)
        if key in ["{#MAC_DLSCH_rounds}", "{#MAC_ULSCH_rounds}"]:
            data[key] = value  # Mantém como string
        else:
            data[key] = int(value) if value.isdigit() else value

# Captura as linhas completas de LCID
for lcid in [1, 2, 4]:
    lcid_match = re.search(fr"LCID {lcid}:\s*TX\s*(\d+)\s*RX\s*(\d+)", log_text)
    if lcid_match:
        data[f"{{#MAC_LCID_{lcid}_TX}}"] = int(lcid_match.group(1))
        data[f"{{#MAC_LCID_{lcid}_RX}}"] = int(lcid_match.group(2))

# Captura a linha completa do MAC
mac_match = re.search(r"MAC:\s*TX\s*(\d+)\s*RX\s*(\d+)", log_text)
if mac_match:
    data["{#MAC_MAC_TX}"] = int(mac_match.group(1))
    data["{#MAC_MAC_RX}"] = int(mac_match.group(2))

# Criar o JSON final no formato esperado
json_data = {"data": [data]}

# Remover valores None do JSON final
json_data["data"] = [{k: v for k, v in json_data["data"][0].items() if v is not None}]

# Imprimir JSON formatado
print(json.dumps(json_data, indent=4))
