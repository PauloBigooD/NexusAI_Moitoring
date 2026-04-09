#!/usr/bin/env python3

import json
import subprocess
import re

def get_docker_logs(container_name: str, tail: int = 11) -> str:
    try:
        logs = subprocess.check_output(
            ["docker", "logs", container_name, "--tail", str(tail)], 
            stderr=subprocess.STDOUT, text=True
        )
        return logs
    except subprocess.CalledProcessError as e:
        #print(f"Erro ao executar comando Docker: {e.output}")
        return ""

container_name = "oai-amf-A"
logs = get_docker_logs(container_name)
if not logs:
    #print("Nenhum log capturado ou container não acessível.")
    exit(1)

ue_pattern = re.compile(r"\|\s*(\d+)\s*\|\s*(5GMM-[A-Z]+)\s*\|\s*(\d+)\s*\|\s*(\d*)\s*\|\s*(\d*)\s*\|\s*(\d*)\s*\|\s*([\d, ]+)\s*\|\s*(\d*)\s*\|")

data = {"data": []}


# Processamento dos dados do UE
ue_matches = list(ue_pattern.finditer(logs))
if not ue_matches:
    print("Nenhuma informação de UE encontrada nos logs.")
for match in ue_matches:
    index, state, imsi, guti, ran_ue_ngap_id, amf_ue_id, plmn, cell_id = match.groups()
    data["data"].append({
        "{#UE_INDEX}": int(index),
        "{#UE_5GMM}": state,
        "{#UE_IMSI}": imsi,
        "{#UE_GUTI}": guti if guti else None,
        "{#UE_RAN_NGAP_ID}": int(ran_ue_ngap_id) if ran_ue_ngap_id else None,
        "{#UE_AMF_ID}": int(amf_ue_id) if amf_ue_id else None,
        "{#UE_PLMN}": plmn.strip(),
        "{#UE_CELL_ID}": int(cell_id) if cell_id else None
    })

json_output = json.dumps(data, indent=4)

output_file = "/tmp/oai_amf_ue.json"
with open(output_file, "w") as f:
    f.write(json_output)

print(json_output)
