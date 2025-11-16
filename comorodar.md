# COMO RODAR ESTE PROJETO HADOOP

Siga os passos abaixo para rodar o cluster Hadoop e executar os testes pela primeira vez.

---

## 1. Pré-requisitos

- **Docker** e **Docker Compose** instalados no sistema.
- Sistema operacional Linux (recomendado Ubuntu 20.04+).

---

## 2. Clonar o Projeto

```bash
git clone <url-do-repositorio>
cd PSPD_2025.2_Atividade-Extra-Classe-2
```

---

## 3. Construir e Subir o Cluster

```bash
docker-compose up --build -d
```

Aguarde o download das imagens e a inicialização dos containers.

---

## 4. Acessar o Container Master

```bash
docker exec -it hadoop-master bash
```

---

## 5. Gerar Dados de Teste

No terminal do container master:

```bash
cd scripts
./gerar_dados.sh
```

---

## 6. Executar o WordCount

Ainda no terminal do container master:

```bash
./executar_wordcount.sh
```

---

## 7. Executar Testes de Performance e Resiliência

```bash
./testar_performance.sh
./testar_resiliencia.sh
```

---

## 8. Monitorar o Cluster

- **Web HDFS (NameNode):** http://localhost:9870
- **Web YARN (ResourceManager):** http://localhost:8088

---

## 9. Parar o Cluster

```bash
docker-compose down
```

---
