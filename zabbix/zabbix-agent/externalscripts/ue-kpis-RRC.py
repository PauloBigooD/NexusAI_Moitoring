#!/usr/bin/env python3

import json
import subprocess
import re
import os
import time
import sys

# --- JSON vazio padrão para exceções ---
def print_empty_json_and_exit():
    print(json.dumps({"data": []}, indent=4))
    sys.exit(0)

# Localização do arquivo
cmd = "find / -type f -wholename '*/openairinterface5g/cmake_targets/ran_build/build/nrRRC_stats.log' 2>/dev/null"

try:
    proc = subprocess.run(
        cmd, shell=True, capture_output=True, text=True, timeout=60
    )
    file_path = proc.stdout.strip().split('\n')[0]

    if not file_path:
        print_empty_json_and_exit()

except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
    print_empty_json_and_exit()

# Verificação de tempo de modificação
try:
    last_modified = os.path.getmtime(file_path)
    if (time.time() - last_modified) > 120:
        print_empty_json_and_exit()
except OSError:
    print_empty_json_and_exit()

# Leitura do arquivo
try:
    log_text = open(file_path).read()
except Exception:
    print_empty_json_and_exit()

if not log_text:
    print_empty_json_and_exit()

# Parsing dos blocos de UE
all_ues_data = []

ue_block_pattern = re.compile(
    r"UE \d+ CU UE ID.*?(?:\n\s+.*)+",
    re.MULTILINE
)
ue_blocks = ue_block_pattern.finditer(log_text)

integer_keys = [
    "{#RRC_ACTIVITY}",
    "{#PDU_ID}",
    "{#PDU_UE_ID}",
    "{#CU_UE_ID}",
    "{#DU_UE_ID}"
]

for match in ue_blocks:
    block_text = match.group(0)
    ue_data = {}

    # Inicializa métricas RF (sempre presentes)
    ue_data["{#RSRP}"] = None
    ue_data["{#RSRQ}"] = None
    ue_data["{#SINR}"] = None

    patterns = {
        "{#RRC_ACTIVITY}": r"last RRC activity:\s+(\d+)",
        "{#PDU_ID}": r"PDU session\s+(\d+)",
        "{#RSRP}": r"RSRP (-?[\d\.]+) dBm",
        "{#RSRQ}": r"RSRQ (-?[\d\.]+) dB",
        "{#SINR}": r"SINR ([\d\.]+) dB",
        "{#PDU_UE_ID}": r"PDU session\s+\d+\s+ID\s+(\d+)",
        "{#TYPE_DU}": r"associated DU:\s+\((.*?)\)",
        "{#CU_UE_ID}": r"CU UE ID (\d+)",
        "{#RNTI}": r"RNTI ([0-9a-fA-F]+)",
        "{#DU_UE_ID}": r"DU UE ID (\d+)",
    }

    for key, pattern in patterns.items():
        value_match = re.search(pattern, block_text)
        if value_match:
            value_str = value_match.group(1)

            if key in integer_keys:
                ue_data[key] = int(value_str)
            else:
                try:
                    ue_data[key] = int(value_str)
                except ValueError:
                    ue_data[key] = value_str

    # Só adiciona UE válida
    if ue_data.get("{#RNTI}"):
        all_ues_data.append(ue_data)

# Se nenhum UE foi encontrado
if not all_ues_data:
    print_empty_json_and_exit()

# JSON final
json_data = {"data": all_ues_data}
print(json.dumps(json_data, indent=4))

