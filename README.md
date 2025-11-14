# Cluster Hadoop - PSPD 2025.2

Cluster Hadoop distribuído (1 master + 2 slaves) com implementação MapReduce do WordCount para experimentação com Big Data.

---

## Requisitos

- Docker >= 20.10
- Docker Compose >= 1.29
- Linux/WSL2
- Maven (para compilar WordCount customizado)

---

## Arquitetura

```
hadoop-master (NameNode + ResourceManager)
    ├── hadoop-slave1 (DataNode + NodeManager)
    └── hadoop-slave2 (DataNode + NodeManager)
```

**Interfaces Web:**
- HDFS NameNode: http://localhost:9870
- YARN ResourceManager: http://localhost:8088

---

## Implementação WordCount

O projeto inclui implementação customizada do WordCount usando MapReduce:

- **WordCountMapper:** Tokeniza texto e emite pares (palavra, 1)
- **WordCountReducer:** Agrega contagens de cada palavra
- **WordCountDriver:** Configura e executa o job MapReduce

**Otimizações:** Combiner para agregação local, reutilização de objetos, limpeza de dados.

---

## Guia de Execução

### 1. Iniciar o Cluster

```bash
# Subir containers
docker-compose up --build -d

# Aguardar 30s para inicialização
sleep 30

# Verificar status
docker ps --filter "name=hadoop"
```

### 2. Compilar WordCount Customizado (Opcional)

```bash
# Instalar Maven
sudo apt-get update && sudo apt-get install maven -y

# Compilar
./build.sh

# Copiar JAR para o container
docker cp target/wordcount.jar hadoop-master:/opt/hadoop/
```

### 3. Executar Testes

#### Método 1: Menu Interativo

```bash
docker exec -it hadoop-master bash
cd /scripts
./menu.sh
```

Opções disponíveis:
- 1: Gerar dados
- 2: WordCount básico
- 3: Múltiplos WordCounts simultâneos
- 6: Teste de performance
- 7: Teste de resiliência

#### Método 2: Comandos Diretos

**Gerar dados:**
```bash
docker exec -it hadoop-master bash
cd /scripts
./gerar_dados.sh
```

**WordCount básico (JAR exemplo do Hadoop):**
```bash
cd /scripts
./executar_wordcount.sh
```

**WordCount customizado:**
```bash
docker exec hadoop-master hadoop jar /opt/hadoop/wordcount.jar \
    br.unb.cic.pspd.wordcount.WordCountDriver \
    /user/root/wordcount_input \
    /user/root/wordcount_output_custom
```

**Teste de performance:**
```bash
cd /scripts
./testar_performance.sh
```
- Testa com 3, 2 e 1 nó
- Mede tempo de execução e speedup
- Logs em: `logs_resiliencia/performance_*/`

**Teste de resiliência:**
```bash
cd /scripts
./testar_resiliencia.sh
```
- 5 cenários de falhas
- Simula perda de nós durante execução
- Logs em: `logs_resiliencia/teste_*/`

**Múltiplos jobs simultâneos:**
```bash
cd /scripts
./executar_multiplos_wordcount.sh 3  # 3 jobs em paralelo
```

### 4. Visualizar Resultados

```bash
# Ver output do WordCount
docker exec hadoop-master hdfs dfs -cat /user/root/wordcount_output/part-r-00000 | head -20

# Ver top 20 palavras mais frequentes
docker exec hadoop-master hdfs dfs -cat /user/root/wordcount_output/part-r-00000 | \
    sort -t$'\t' -k2 -nr | head -20

# Status do HDFS
docker exec hadoop-master hdfs dfsadmin -report

# Aplicações YARN
docker exec hadoop-master yarn application -list -appStates ALL
```

### 5. Coletar Evidências

```bash
# Copiar logs de performance
docker cp hadoop-master:/scripts/logs_resiliencia/performance_*/resultados.csv \
    evidencias/logs/

# Copiar logs de resiliência
docker cp hadoop-master:/scripts/logs_resiliencia/teste_*/resultados.txt \
    evidencias/logs/

# Salvar configurações testadas
cp config/*.xml evidencias/configs/
```

**Screenshots necessários:** Ver checklist em `evidencias/README.md`

### 6. Parar o Cluster

```bash
docker-compose down
```

---

## Testes de Configuração (Item 1.2)

Testar impacto de 5 alterações nos arquivos de configuração:

### Alteração 1: Replicação HDFS
**Arquivo:** `config/hdfs-site.xml`
**Parâmetro:** `dfs.replication` (atual: 2)
**Testar:** 1 ou 3
```bash
# Editar config/hdfs-site.xml
docker-compose down
docker-compose up --build -d
# Executar WordCount e comparar
```

### Alteração 2: Tamanho do Bloco
**Arquivo:** `config/hdfs-site.xml`
**Parâmetro:** `dfs.blocksize` (atual: 64 MB)
**Testar:** 128 MB (134217728)

### Alteração 3: Memória NodeManagers
**Arquivo:** `config/yarn-site.xml`
**Parâmetro:** `yarn.nodemanager.resource.memory-mb` (atual: 4096)
**Testar:** 2048 ou 8192

### Alteração 4: vCores NodeManagers
**Arquivo:** `config/yarn-site.xml`
**Parâmetro:** `yarn.nodemanager.resource.cpu-vcores` (atual: 4)
**Testar:** 2 ou 8

### Alteração 5: Memória Tasks Map/Reduce
**Arquivo:** `config/mapred-site.xml`
**Parâmetros:** `mapreduce.map.memory.mb` (atual: 1024), `mapreduce.reduce.memory.mb` (atual: 2048)
**Testar:** Map=512, Reduce=1024

**Processo:**
1. Editar arquivo de configuração
2. Reiniciar cluster: `docker-compose down && docker-compose up --build -d`
3. Executar WordCount
4. Anotar tempo e número de tasks
5. Capturar screenshot da interface YARN
6. Salvar configuração em `evidencias/configs/`

---

## Comandos Úteis

### Gerenciamento
```bash
# Iniciar
docker-compose up -d

# Parar
docker-compose down

# Logs
docker logs -f hadoop-master
docker logs -f hadoop-slave1
```

### HDFS
```bash
# Listar arquivos
docker exec hadoop-master hdfs dfs -ls /user/root/

# Ver conteúdo
docker exec hadoop-master hdfs dfs -cat /user/root/arquivo.txt

# Relatório do cluster
docker exec hadoop-master hdfs dfsadmin -report
```

### YARN
```bash
# Listar aplicações
docker exec hadoop-master yarn application -list

# Listar nós
docker exec hadoop-master yarn node -list

# Ver logs de aplicação
docker exec hadoop-master yarn logs -applicationId <app_id>
```

---

## Estrutura do Projeto

```
PSPD_2025.2_Atividade-Extra-Classe-2/
├── src/main/java/br/unb/cic/pspd/wordcount/  # Código WordCount
│   ├── WordCountMapper.java
│   ├── WordCountReducer.java
│   └── WordCountDriver.java
├── config/                        # Configurações Hadoop
├── scripts/                       # Scripts de teste
├── evidencias/                    # Evidências coletadas
├── pom.xml                        # Build Maven
├── build.sh                       # Script de compilação
├── docker-compose.yml             # Definição do cluster
└── README.md                      # Este arquivo
```

---

## Troubleshooting

**Containers não iniciam:**
```bash
docker-compose logs
docker-compose down -v
docker-compose up --build -d
```

**Slaves não conectam:**
```bash
docker restart hadoop-slave1 hadoop-slave2
docker logs hadoop-slave1
```

**HDFS em Safe Mode:**
```bash
docker exec hadoop-master hdfs dfsadmin -safemode leave
```

**Out of Memory:**
- Aumentar memória em `config/yarn-site.xml`
- Ou reduzir dados em `scripts/gerar_dados.sh`

---

## Referências

- [Hadoop 3.3.6 Documentation](https://hadoop.apache.org/docs/r3.3.6/)
- [MapReduce Tutorial](https://hadoop.apache.org/docs/stable/hadoop-mapreduce-client/hadoop-mapreduce-client-core/MapReduceTutorial.html)

---

**Grupo PSPD 2025.2 - UnB/FCTE**
