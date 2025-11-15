#!/bin/bash

echo "============================================================"
echo "TESTES AUTOMATIZADOS - CONFIGURAÇÕES HADOOP"
echo "============================================================"
echo "Alteração 1: Fator de Replicação (dfs.replication)"
echo "Alteração 2: Tamanho do Bloco (dfs.blocksize)"
echo "Alteração 3: Memória NodeManager (yarn.nodemanager.resource.memory-mb)"
echo "Alteração 4: vCores NodeManager (yarn.nodemanager.resource.cpu-vcores)"
echo "Alteração 5: Memória Tasks Map/Reduce (mapreduce.map/reduce.memory.mb)"
echo "============================================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_DIR="logs_resiliencia/testes_config_${TIMESTAMP}"
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/master.log"
}

# Backup das configurações originais
backup_config() {
    cp "$CONFIG_DIR/hdfs-site.xml" "$LOG_DIR/hdfs-site.xml.backup"
    cp "$CONFIG_DIR/yarn-site.xml" "$LOG_DIR/yarn-site.xml.backup"
    cp "$CONFIG_DIR/mapred-site.xml" "$LOG_DIR/mapred-site.xml.backup"
    log "Backup das configurações originais salvo em $LOG_DIR/"
}

# Restaurar configurações originais
restore_config() {
    cp "$LOG_DIR/hdfs-site.xml.backup" "$CONFIG_DIR/hdfs-site.xml"
    cp "$LOG_DIR/yarn-site.xml.backup" "$CONFIG_DIR/yarn-site.xml"
    cp "$LOG_DIR/mapred-site.xml.backup" "$CONFIG_DIR/mapred-site.xml"
    aplicar_config_cluster
    log "Configurações originais restauradas"
}

# Alterar configuração HDFS
alterar_config_hdfs() {
    local REPLICACAO=$1
    local BLOCKSIZE=$2

    log "Alterando HDFS: replicação=$REPLICACAO, blocksize=$BLOCKSIZE"

    sed -i "/<name>dfs.replication<\/name>/,/<\/property>/ s|<value>[0-9]*</value>|<value>$REPLICACAO</value>|" "$CONFIG_DIR/hdfs-site.xml"
    sed -i "/<name>dfs.blocksize<\/name>/,/<\/property>/ s|<value>[0-9]*</value>|<value>$BLOCKSIZE</value>|" "$CONFIG_DIR/hdfs-site.xml"
}

# Alterar configuração YARN
alterar_config_yarn() {
    local MEMORY_MB=$1
    local VCORES=$2

    log "Alterando YARN: memory=$MEMORY_MB MB, vcores=$VCORES"

    sed -i "/<name>yarn.nodemanager.resource.memory-mb<\/name>/,/<\/property>/ s|<value>[0-9]*</value>|<value>$MEMORY_MB</value>|" "$CONFIG_DIR/yarn-site.xml"
    sed -i "/<name>yarn.nodemanager.resource.cpu-vcores<\/name>/,/<\/property>/ s|<value>[0-9]*</value>|<value>$VCORES</value>|" "$CONFIG_DIR/yarn-site.xml"

    # Ajustar também o maximum-allocation-mb para não exceder o total
    sed -i "/<name>yarn.scheduler.maximum-allocation-mb<\/name>/,/<\/property>/ s|<value>[0-9]*</value>|<value>$MEMORY_MB</value>|" "$CONFIG_DIR/yarn-site.xml"
}

# Alterar configuração MapReduce
alterar_config_mapred() {
    local MAP_MEMORY=$1
    local REDUCE_MEMORY=$2

    log "Alterando MapReduce: map.memory=$MAP_MEMORY MB, reduce.memory=$REDUCE_MEMORY MB"

    sed -i "/<name>mapreduce.map.memory.mb<\/name>/,/<\/property>/ s|<value>[0-9]*</value>|<value>$MAP_MEMORY</value>|" "$CONFIG_DIR/mapred-site.xml"
    sed -i "/<name>mapreduce.reduce.memory.mb<\/name>/,/<\/property>/ s|<value>[0-9]*</value>|<value>$REDUCE_MEMORY</value>|" "$CONFIG_DIR/mapred-site.xml"
}

# Aplicar configurações no cluster
aplicar_config_cluster() {
    log "Aplicando configurações no cluster..."

    # Copiar todos os arquivos de configuração para todos os containers
    for file in hdfs-site.xml yarn-site.xml mapred-site.xml; do
        docker cp "$CONFIG_DIR/$file" hadoop-master:/opt/hadoop/etc/hadoop/$file
        docker cp "$CONFIG_DIR/$file" hadoop-slave1:/opt/hadoop/etc/hadoop/$file
        docker cp "$CONFIG_DIR/$file" hadoop-slave2:/opt/hadoop/etc/hadoop/$file
    done

    # Reiniciar cluster
    log "Reiniciando HDFS e YARN..."
    docker exec hadoop-master bash -c "\$HADOOP_HOME/sbin/stop-yarn.sh" >/dev/null 2>&1
    sleep 2
    docker exec hadoop-master bash -c "\$HADOOP_HOME/sbin/stop-dfs.sh" >/dev/null 2>&1
    sleep 3

    docker exec hadoop-master bash -c "\$HADOOP_HOME/sbin/start-dfs.sh" >/dev/null 2>&1
    sleep 5
    docker exec hadoop-master bash -c "\$HADOOP_HOME/sbin/start-yarn.sh" >/dev/null 2>&1
    sleep 5

    # Verificar configurações aplicadas
    local REP=$(docker exec hadoop-master bash -c "hdfs getconf -confKey dfs.replication" 2>/dev/null)
    local BLOCK=$(docker exec hadoop-master bash -c "hdfs getconf -confKey dfs.blocksize" 2>/dev/null)
    log "Configuração ativa: rep=$REP, block=$BLOCK"
}

# Preparar dados no HDFS
preparar_dados() {
    log "Limpando dados antigos do HDFS..."
    docker exec hadoop-master hdfs dfs -rm -r -f /user/root/wordcount_input >/dev/null 2>&1
    docker exec hadoop-master hdfs dfs -rm -r -f /user/root/wordcount_output* >/dev/null 2>&1

    log "Enviando dados para HDFS..."
    docker exec hadoop-master hdfs dfs -mkdir -p /user/root/wordcount_input
    docker exec hadoop-master hdfs dfs -put /massa_de_dados/massa_unica.txt /user/root/wordcount_input/

    sleep 3

    # Verificar uso de armazenamento e blocos
    local STORAGE=$(docker exec hadoop-master hdfs dfs -du -h /user/root/wordcount_input/massa_unica.txt 2>/dev/null | awk '{print $1 $2}')
    log "Espaço usado no HDFS: $STORAGE"

    # Contar número de blocos
    local NUM_BLOCOS=$(docker exec hadoop-master hdfs fsck /user/root/wordcount_input/massa_unica.txt -files -blocks 2>/dev/null | grep -c "blk_")
    log "Número de blocos criados: $NUM_BLOCOS"
}

# Executar bateria de testes (versão genérica)
executar_testes() {
    local NOME=$1
    shift
    local DESCRICAO="$@"

    log ""
    log "============================================================"
    log "TESTE: $NOME"
    log "$DESCRICAO"
    log "============================================================"

    aplicar_config_cluster
    preparar_dados

    # Executar teste de performance
    log ""
    log ">>> Executando TESTE DE PERFORMANCE <<<"
    cd "$SCRIPT_DIR"
    ./testar_performance.sh 2>&1 | tee "$LOG_DIR/${NOME}_performance.log"

    # Executar teste de resiliência
    log ""
    log ">>> Executando TESTE DE RESILIÊNCIA <<<"
    cd "$SCRIPT_DIR"
    ./testar_resiliencia.sh 2>&1 | tee "$LOG_DIR/${NOME}_resiliencia.log"

    log ""
    log "Testes concluídos para: $NOME"
    log "Aguardando 10s antes do próximo teste..."
    sleep 10
}

# Verificação inicial
log "============================================================"
log "VERIFICAÇÕES INICIAIS"
log "============================================================"

if ! docker ps | grep -q "hadoop-master"; then
    log "ERRO: Cluster não está rodando."
    log "Execute: docker-compose up -d"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/../massa_de_dados/massa_unica.txt" ]; then
    log "ERRO: massa_unica.txt não encontrado."
    log "Execute: ./gerar_dados.sh"
    exit 1
fi

# Garantir todos os nodes ativos
docker start hadoop-master hadoop-slave1 hadoop-slave2 >/dev/null 2>&1
sleep 3

# Fazer backup da configuração original
backup_config

log ""
log "============================================================"
log "INÍCIO DOS TESTES"
log "============================================================"
log "Logs salvos em: $LOG_DIR"
log ""

# ============================================================
# ALTERAÇÃO 1: FATOR DE REPLICAÇÃO
# ============================================================
log ""
log "============================================================"
log "ALTERAÇÃO 1: FATOR DE REPLICAÇÃO HDFS"
log "============================================================"

# Restaurar configurações padrão primeiro
restore_config

# Teste 1.1: Replicação = 1
alterar_config_hdfs 1 134217728
executar_testes "ALT1_REP1" "Replicação=1, Blocksize=128MB"

# Teste 1.2: Replicação = 2 (padrão)
alterar_config_hdfs 2 134217728
executar_testes "ALT1_REP2" "Replicação=2, Blocksize=128MB"

# Teste 1.3: Replicação = 3
alterar_config_hdfs 3 134217728
executar_testes "ALT1_REP3" "Replicação=3, Blocksize=128MB"

# ============================================================
# ALTERAÇÃO 2: TAMANHO DO BLOCO
# ============================================================
log ""
log "============================================================"
log "ALTERAÇÃO 2: TAMANHO DO BLOCO HDFS"
log "============================================================"

# Restaurar configurações padrão
restore_config

# Teste 2.1: Blocksize = 32 MB
alterar_config_hdfs 2 33554432
executar_testes "ALT2_BLOCK32MB" "Replicação=2, Blocksize=32MB"

# Teste 2.2: Blocksize = 64 MB
alterar_config_hdfs 2 67108864
executar_testes "ALT2_BLOCK64MB" "Replicação=2, Blocksize=64MB"

# Teste 2.3: Blocksize = 128 MB (padrão atual)
alterar_config_hdfs 2 134217728
executar_testes "ALT2_BLOCK128MB" "Replicação=2, Blocksize=128MB"

# ============================================================
# ALTERAÇÃO 3: MEMÓRIA NODEMANAGER
# ============================================================
log ""
log "============================================================"
log "ALTERAÇÃO 3: MEMÓRIA DOS NODEMANAGERS"
log "============================================================"

# Restaurar configurações padrão
restore_config

# Teste 3.1: 2048 MB (2 GB)
alterar_config_yarn 2048 8
executar_testes "ALT3_MEM2GB" "NodeManager Memory=2GB, vCores=8"

# Teste 3.2: 4096 MB (4 GB) - padrão
alterar_config_yarn 4096 8
executar_testes "ALT3_MEM4GB" "NodeManager Memory=4GB, vCores=8"

# Teste 3.3: 8192 MB (8 GB)
alterar_config_yarn 8192 8
executar_testes "ALT3_MEM8GB" "NodeManager Memory=8GB, vCores=8"

# ============================================================
# ALTERAÇÃO 4: vCORES NODEMANAGER
# ============================================================
log ""
log "============================================================"
log "ALTERAÇÃO 4: vCORES DOS NODEMANAGERS"
log "============================================================"

# Restaurar configurações padrão
restore_config

# Teste 4.1: 2 vCores
alterar_config_yarn 8192 2
executar_testes "ALT4_VCORES2" "NodeManager Memory=8GB, vCores=2"

# Teste 4.2: 4 vCores - padrão
alterar_config_yarn 8192 4
executar_testes "ALT4_VCORES4" "NodeManager Memory=8GB, vCores=4"

# Teste 4.3: 8 vCores
alterar_config_yarn 8192 8
executar_testes "ALT4_VCORES8" "NodeManager Memory=8GB, vCores=8"

# ============================================================
# ALTERAÇÃO 5: MEMÓRIA DAS TASKS MAP/REDUCE
# ============================================================
log ""
log "============================================================"
log "ALTERAÇÃO 5: MEMÓRIA DAS TASKS MAP/REDUCE"
log "============================================================"

# Restaurar configurações padrão
restore_config

# Teste 5.1: Map=512MB, Reduce=1024MB (reduzidos)
alterar_config_mapred 512 1024
executar_testes "ALT5_TASK_SMALL" "Map=512MB, Reduce=1024MB"

# Teste 5.2: Map=1024MB, Reduce=1024MB (padrão atual)
alterar_config_mapred 1024 1024
executar_testes "ALT5_TASK_MEDIUM" "Map=1024MB, Reduce=1024MB"

# Teste 5.3: Map=1024MB, Reduce=2048MB
alterar_config_mapred 1024 2048
executar_testes "ALT5_TASK_LARGE" "Map=1024MB, Reduce=2048MB"

# ============================================================
# FINALIZAÇÃO
# ============================================================
log ""
log "============================================================"
log "TODOS OS TESTES CONCLUÍDOS!"
log "============================================================"

# Restaurar configuração original
restore_config

log ""
log "============================================================"
log "RESUMO DOS TESTES EXECUTADOS"
log "============================================================"
log ""
log "ALTERAÇÃO 1: Fator de Replicação (dfs.replication)"
log "  - Replicação = 1, 2, 3"
log ""
log "ALTERAÇÃO 2: Tamanho do Bloco (dfs.blocksize)"
log "  - Blocksize = 32 MB, 64 MB, 128 MB"
log ""
log "ALTERAÇÃO 3: Memória NodeManager (yarn.nodemanager.resource.memory-mb)"
log "  - Memory = 2048 MB, 4096 MB, 8192 MB"
log ""
log "ALTERAÇÃO 4: vCores NodeManager (yarn.nodemanager.resource.cpu-vcores)"
log "  - vCores = 2, 4, 8"
log ""
log "ALTERAÇÃO 5: Memória Tasks (mapreduce.map/reduce.memory.mb)"
log "  - Map=512/Reduce=1024, Map=1024/Reduce=1024, Map=1024/Reduce=2048"
log ""
log "Total: 15 configurações testadas"
log "Testes por configuração: Performance + Resiliência"
log ""
log "============================================================"
log "ANÁLISE ESPERADA DOS RESULTADOS"
log "============================================================"
log ""
log "ALTERAÇÃO 1 - Fator de Replicação:"
log "  Rep=1: Sem tolerância a falhas, menor espaço"
log "  Rep=2: Tolerância a 1 falha, equilibrado"
log "  Rep=3: Tolerância a 2 falhas, mais espaço e paralelismo"
log ""
log "ALTERAÇÃO 2 - Tamanho do Bloco:"
log "  32MB: Mais blocos, mais paralelismo, maior overhead metadata"
log "  64MB: Equilibrado"
log "  128MB: Menos blocos, menos overhead, ideal para Big Data"
log ""
log "ALTERAÇÃO 3 - Memória NodeManager:"
log "  2GB: Limita containers simultâneos, menor paralelismo"
log "  4GB: Configuração média"
log "  8GB: Mais containers simultâneos, maior paralelismo"
log ""
log "ALTERAÇÃO 4 - vCores NodeManager:"
log "  2 cores: Menor paralelismo CPU"
log "  4 cores: Configuração média"
log "  8 cores: Maior paralelismo se CPU disponível"
log ""
log "ALTERAÇÃO 5 - Memória Tasks Map/Reduce:"
log "  Map=512MB, Reduce=1GB: Mais tasks simultâneas, risco OOM"
log "  Map=1GB, Reduce=1GB: Configuração atual"
log "  Map=1GB, Reduce=2GB: Menos tasks, mais memória por task"
log ""
log "============================================================"
log "ARQUIVOS GERADOS"
log "============================================================"
log ""
log "Master log: $LOG_DIR/master.log"
log ""
log "ALTERAÇÃO 1 - Fator de Replicação (3 testes):"
log "  ALT1_REP1, ALT1_REP2, ALT1_REP3"
log ""
log "ALTERAÇÃO 2 - Tamanho do Bloco (3 testes):"
log "  ALT2_BLOCK32MB, ALT2_BLOCK64MB, ALT2_BLOCK128MB"
log ""
log "ALTERAÇÃO 3 - Memória NodeManager (3 testes):"
log "  ALT3_MEM2GB, ALT3_MEM4GB, ALT3_MEM8GB"
log ""
log "ALTERAÇÃO 4 - vCores NodeManager (3 testes):"
log "  ALT4_VCORES2, ALT4_VCORES4, ALT4_VCORES8"
log ""
log "ALTERAÇÃO 5 - Memória Tasks (3 testes):"
log "  ALT5_TASK_SMALL, ALT5_TASK_MEDIUM, ALT5_TASK_LARGE"
log ""
log "Total: 15 configurações × 2 testes = 30 arquivos de log"
log "Cada teste gera: {NOME}_performance.log e {NOME}_resiliencia.log"
log ""
log "Backups: hdfs-site.xml.backup, yarn-site.xml.backup, mapred-site.xml.backup"
log "============================================================"

echo ""
echo "Todos os testes foram concluídos!"
echo "Verifique os resultados em: $LOG_DIR"
