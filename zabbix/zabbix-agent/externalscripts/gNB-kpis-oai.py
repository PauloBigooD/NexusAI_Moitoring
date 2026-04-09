#!/usr/bin/env python3

import json
import subprocess
import re
import os
import time

# Comando para encontrar o caminho do arquivo (busca no $HOME para evitar erros de permissão)
cmd = "find / -type f -wholename '*/openairinterface5g/cmake_targets/ran_build/build/nrRRC_stats.log' 2>/dev/null"

try:
    file_path = subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()
    if not file_path:
        #print("Arquivo nrRRC_stats.log não encontrado.")
        exit(1)
    #print("Arquivo encontrado em:", file_path)  # Debug
except Exception as e:
    #print("Erro ao localizar o arquivo:", e)
    exit(1)

# Verifica a última modificação do arquivo
try:
    last_modified = os.path.getmtime(file_path)
    current_time = time.time()
    elapsed_time = current_time - last_modified

    if elapsed_time > 120:
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
        #print(f"Erro: Arquivo {log_file} não encontrado ao tentar abrir.")
        return None

# Lê o conteúdo do arquivo
log_text = read_log_file(file_path)
if not log_text:
    #print("Não foi possível ler o arquivo.")
    exit(1)


# Expressões regulares para capturar as informações necessárias
patterns = {
    #"last RRC activity": r"last RRC activity:\s+(\d+)",
    #"PDU session": r"PDU session\s+(\d+)",
    #"PDU session ID": r"PDU session\s+\d+\s+ID\s+(\d+)",
    #"associated DU": r"associated DU:\s+\((.*?)\)",
    "{#GNB_NRCELLID}": r"nrCellID\s+(\d+)",
    "{#GNB_PCI}": r"PCI\s+(\d+)",
    "{#GNB_SSB_ARFCN}": r"SSB ARFCN\s+(\d+)",
    "{#GNB_BAND}": r"band\s+(\d+)",
    "{#GNB_ARFCN}": r"ARFCN\s+(\d+)",
    "{#GNB_SCS}": r"SCS\s+(\d+)",
    "{#GNB_PRB}": r"PRB\s+(\d+)",
    "{#GNB_AMF_DU_ID}": r"DU ID\s+(\d+)",
    "{#GNB_NAME}": r"\[\d+\] DU ID \d+ \((.*?)\)",
    "{#GNB_TOTAL_CONECTED}": r"(\d+) connected DUs"
}

# Dicionário para armazenar os dados capturados
data = {}

# Extração dos dados
for key, pattern in patterns.items():
    match = re.search(pattern, log_text)
    if match:
        value = match.group(1)
        data[key] = int(value) if value.isdigit() else value  # Converte para inteiro se for número

# Criar o JSON final no formato esperado
json_data = {"data": [data]}

# Remover valores None do JSON final
json_data["data"] = [{k: v for k, v in json_data["data"][0].items() if v is not None}]

# Imprimir JSON formatado
print(json.dumps(json_data, indent=4))

