#!/usr/bin/env python3

import json
import subprocess
import re

def get_docker_logs(container_name: str, tail: int = 200000000) -> str:
    """Obtém os logs do contêiner Docker."""
    try:
        logs = subprocess.check_output(
            ["docker", "logs", container_name, "--tail", str(tail)], 
            stderr=subprocess.STDOUT, text=True
        )
        return logs
    except subprocess.CalledProcessError:
        return ""

# Nome do contêiner
container_name = "oai-smf-A"
log_text = get_docker_logs(container_name)


# Expressão regular ajustada para capturar melhor os dados do log
ue_pattern = re.compile(
    r"SUPI:\s*(\S+).*?"
    r"PDU Session ID:\s*(\d+).*?"
    r"DNN:\s*(\S+).*?"
    r"S-NSSAI:\s*SST=(\d+),\s*SD=([0-9A-Fa-f]+).*?"
    r"PDN type:\s*(\S+).*?"
    r"PAA IPv4:\s*(\d+\.\d+\.\d+\.\d+).*?"
    r"Default QFI:\s*(\d+).*?"
    r"UL FTEID:\s*TEID=\d+,\s*IPv4=(\d+\.\d+\.\d+\.\d+).*?"
    r"DL FTEID:\s*TEID=\d+,\s*IPv4=(\d+\.\d+\.\d+\.\d+)",
    re.DOTALL
)

# Aplicando regex no log capturado
ue_data = []
for match in ue_pattern.finditer(log_text):
    ue_info = {
        "{#SUPI}": match.group(1),
        "{#PDU_SESSION_ID}": int(match.group(2)),
        "{#DNN}": match.group(3),
        "{#SST}": int(match.group(4)),
        "{#SD}": match.group(5),
        "{#PDN_TYPE}": match.group(6),
        "{#UE_IPV4}": match.group(7),
        "{#QFI}": int(match.group(8)),
        "{#UL_AMF_IP}": match.group(9),
        "{#DL_GNB_IP}": match.group(10),
    }
    ue_data.append(ue_info)


# Gera JSON final
json_data = {"data": ue_data}
print(json.dumps(json_data, indent=4))
