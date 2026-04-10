
# Guia de Implantação: Open5GS no MicroK8s (Single Node)

Este repositório descreve os passos para implantar um CORE 5G (Open5GS) em um cluster Kubernetes Single Node ou Multi Node usando MicroK8s e Helm.

---

## 1. Preparação da Infraestrutura

Instale o MicroK8s e habilite os add-ons necessários (storage e MetalLB).

### 1.1 Instalar MicroK8s

```bash
sudo snap install microk8s --classic
```

### 1.2 Configurar permissões do usuário (opcional)

```bash
sudo usermod -a -G microk8s $USER
newgrp microk8s
sudo chown -f -R $USER ~/.kube
```

### 1.3 Habilitar Storage

```bash
microk8s enable storage
```

### 1.4 Habilitar MetalLB (Load Balancer)

Ajuste a faixa de IPs conforme sua rede. O exemplo abaixo reserva `172.31.0.130–172.31.0.140`.

```bash
microk8s enable metallb:172.31.0.130-172.31.0.140
```

> **Observação:** verifique se a faixa escolhida não conflita com outros dispositivos na rede.

---

## 2. Deployment do Open5GS

Baixe o Helm chart e o arquivo de valores personalizados, crie o namespace e faça o deploy via Helm.

### 2.1 Baixar artefatos

```bash
# Helm Chart
curl -L -o open5gs-0.3.4.tgz https://raw.github.com/FllavioAndrade/open5gs/main/open5gs-0.3.4.tgz

# Arquivo de valores personalizado
curl -L -o values.yaml https://raw.github.com/FllavioAndrade/open5gs/main/values.yaml
```

### 2.2 Criar namespace

```bash
microk8s kubectl create ns open5gs
```

### 2.3 Instalar/atualizar com Helm

```bash
microk8s helm3 upgrade --install open5gs open5gs-0.3.4.tgz -n open5gs -f values.yaml
```

---

## 3. Valores padão de DNN e S-NSSAI (SST / SD)

```yaml
dnn: lance
mcc: "001"
mnc: "01"
tac: 1
s_nssai:
    - sst: 1
        sd: "000001"
```

### 3.2 Notas importantes

- **SST** pode ser passado como `"01"` ou `1` dependendo do formato exigido pelo arquivo.
- **SD** normalmente é uma string de 6 dígitos (hex ou decimal conforme implementação).

### 3.3 Caso edite, Aplicar alterações

Após editar `values.yaml`, aplique novamente:

```bash
microk8s helm3 upgrade --install open5gs open5gs-0.3.4.tgz -n open5gs -f values.yaml
```

> **Dica:** verifique logs do SMF/UPF e a criação de PDU Sessions para confirmar que o DNN `lance` e a S-NSSAI estão sendo usados.

---

## 4. Verificação do Status

Verifique se os pods e serviços subiram corretamente.

### 4.1 Listar pods

```bash
microk8s kubectl get pods -n open5gs
```

### 4.2 Verificar serviços e External-IPs (MetalLB)

```bash
microk8s kubectl get svc -n open5gs -o wide

# Ou para ficar assistindo mudanças:
microk8s kubectl get svc -n open5gs -w
```

### 4.3 Logs de um pod

```bash
microk8s kubectl logs -n open5gs <pod-name>
```

---

## 5. Ajustes e Manutenção

### 5.1 Alterar configurações

1. Edite `values.yaml` conforme necessário.
2. Rode novamente o comando de upgrade para aplicar as mudanças:

```bash
microk8s helm3 upgrade --install open5gs open5gs-0.3.4.tgz -n open5gs -f values.yaml
```

### 5.2 Outros comandos úteis

```bash
# Descrever recursos
microk8s kubectl describe pod <pod-name> -n open5gs

# Acessar shell de um contêiner
microk8s kubectl exec -it -n open5gs <pod-name> -- /bin/bash
```

---

## 6. Construindo uma Infra Multi-Node (Master + Worker) com MicroK8s

Passo a passo para ter um cluster com um nó master e um nó worker usando MicroK8s.

### 6.1 Instalar MicroK8s em ambas as máquinas

```bash
sudo snap install microk8s --classic
sudo usermod -a -G microk8s $USER && newgrp microk8s
```

### 6.2 Habilitar addons no master

```bash
microk8s enable storage helm3
microk8s enable metallb:172.31.0.130-172.31.0.140
```

### 6.3 Gerar comando de join (no master)

```bash
microk8s add-node
```

Saída típica (exemplo):

```
microk8s join 10.0.0.10:25000/abcdef1234567890 --worker
```

Copie o comando completo mostrado.

### 6.4 Executar o join (no worker)

```bash
# Substitua pelo comando mostrado pelo master
sudo microk8s join 10.0.0.10:25000/abcdef1234567890 --worker
```

### 6.5 Verificar os nós (no master)

```bash
microk8s kubectl get nodes
```

### 6.6 Rotular nós (opcional)

```bash
microk8s kubectl label node <master-node-name> node-role.kubernetes.io/master=master
microk8s kubectl label node <worker-node-name> node-role.kubernetes.io/worker=worker
```

### 6.7 Observações de rede e segurança

- Certifique-se de que as portas necessárias estão abertas entre os hosts (por exemplo, `25000/tcp` para o join do MicroK8s e portas de API/K8s).
- MetalLB deve ser configurado **apenas uma vez** no cluster (no master) e funcionará para todo o cluster. Ajuste a faixa de IP para evitar conflitos.

### 6.9 Deploy do Open5GS no cluster multi-node

Depois de o cluster estar pronto, faça o deploy normalmente conforme o [tópico 2 — Deployment do Open5GS](#2-deployment-do-open5gs):

```bash
microk8s kubectl create ns open5gs
microk8s helm3 upgrade --install open5gs open5gs-0.3.4.tgz -n open5gs -f values.yaml
```


