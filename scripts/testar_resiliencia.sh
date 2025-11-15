#!/bin/bash

echo "=========================================="
echo "TESTE COMPLETO DE RESILIÊNCIA HADOOP"
echo "=========================================="
echo ""

# Criar diretório de logs
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_DIR="logs_resiliencia/teste_${TIMESTAMP}"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/teste_resiliencia.log"

# Função para logar
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Função para capturar estado do cluster
capturar_estado() {
    local MOMENTO=$1
    log " == Capturando estado: $MOMENTO"
    
    docker ps --filter "name=hadoop" \
        --format "table {{.Names}}\t{{.Status}}" > "$LOG_DIR/containers_${MOMENTO}.txt"

    docker exec hadoop-master yarn node -list -all 2>/dev/null \
        > "$LOG_DIR/nodes_${MOMENTO}.txt"
}

# Função para executar cenário
executar_cenario() {
    local NUM=$1
    local DESCRICAO=$2
    local ACAO=$3
    
    log ""
    log "=========================================="
    log "CENÁRIO $NUM: $DESCRICAO"
    log "=========================================="
    
    docker exec hadoop-master hdfs dfs -rm -r -f /user/root/wordcount_output_cenario_${NUM} 2>/dev/null
    
    log " == Iniciando wordcount..."
    docker exec hadoop-master bash -c "
        hadoop jar \$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
            wordcount \
            /user/root/wordcount_input \
            /user/root/wordcount_output_cenario_${NUM}
    " > "$LOG_DIR/wordcount_cenario_${NUM}.log" 2>&1 &
    
    JOB_PID=$!
    log "Job iniciado (PID: $JOB_PID)"
    
    log " == Aguardando 12s para job inicializar..."
    sleep 12 

    capturar_estado "cenario_${NUM}_antes_falha"
    
    log " == Executando ação: $ACAO"
    eval "$ACAO"
    
    capturar_estado "cenario_${NUM}_durante_falha"
    
    log " == Aguardando 20s com falha ativa..."
    sleep 20   

    # Recuperação automática
    if [[ "$ACAO" == *"docker stop"* ]]; then
        local NODE=$(echo "$ACAO" | grep -oP 'hadoop-slave[0-9]+')
        if [ -n "$NODE" ]; then
            log " - Recuperando node: $NODE"
            docker start $NODE
            sleep 6   
        fi
    fi
    
    capturar_estado "cenario_${NUM}_apos_recuperacao"
    
    log " == Aguardando job terminar..."
    wait $JOB_PID
    JOB_EXIT_CODE=$?
    
    log "Job finalizado (exit code: $JOB_EXIT_CODE)"
    
    if docker exec hadoop-master hdfs dfs -test -d /user/root/wordcount_output_cenario_${NUM}/_SUCCESS 2>/dev/null; then
        log " == SUCESSO"
        RESULTADO="SUCESSO"
    else
        log " XX FALHA"
        RESULTADO="FALHA"
    fi
    
    echo "Cenário $NUM: $DESCRICAO - $RESULTADO" >> "$LOG_DIR/resultados.txt"
    
    log " == Intervalo curto (8s) antes do próximo cenário..."
    sleep 8   
}

# Verificação inicial
log " == Verificando cluster..."
if ! docker ps | grep -q "hadoop-master"; then
    log " XX ERRO: Cluster não está rodando!"
    exit 1
fi

log " == Verificando dados no HDFS..."
if ! docker exec hadoop-master hdfs dfs -test -d /user/root/wordcount_input 2>/dev/null; then
    log " XX ERRO: wordcount_input não encontrado!"
    exit 1
fi

log ""
log "=========================================="
log "INICIANDO TESTES DE RESILIÊNCIA (OTIMIZADO)"
log "Logs: $LOG_DIR"
log "=========================================="
log ""

capturar_estado "inicial"

# ============================
# CENÁRIO 1 (baseline)
# ============================
executar_cenario 1 \
    "Baseline - Execução normal (3 nodes ativos)" \
    "log 'Nenhuma falha simulada'"

# ============================
# CENÁRIO 2 (falha slave1)
# ============================
executar_cenario 2 \
    "Falha de 1 slave (slave1)" \
    "docker stop hadoop-slave1"

# ============================
# CENÁRIO 3 (falha slave2)
# ============================
executar_cenario 3 \
    "Falha de 1 slave (slave2)" \
    "docker stop hadoop-slave2"

# ============================
# CENÁRIO 4 (reduzido, mas realista)
# ============================

log ""
log "=========================================="
log "CENÁRIO 4: Falha escalonada de ambos os slaves (otimizado)"
log "=========================================="

docker exec hadoop-master hdfs dfs -rm -r -f /user/root/wordcount_output_cenario_4 2>/dev/null

docker exec hadoop-master bash -c "
    hadoop jar \$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples.jar \
        wordcount \
        /user/root/wordcount_input \
        /user/root/wordcount_output_cenario_4
" > "$LOG_DIR/wordcount_cenario_4.log" 2>&1 &

JOB_PID=$!

sleep 12 

capturar_estado "cenario_4_antes"

docker stop hadoop-slave1
sleep 12   

docker stop hadoop-slave2
sleep 6    

capturar_estado "cenario_4_durante"

log " == Aguardando 20s..."
sleep 20   

docker start hadoop-slave1 hadoop-slave2
sleep 10   

capturar_estado "cenario_4_apos"

wait $JOB_PID

if docker exec hadoop-master hdfs dfs -test -d /user/root/wordcount_output_cenario_4/_SUCCESS 2>/dev/null; then
    echo "Cenário 4: Sucesso" >> "$LOG_DIR/resultados.txt"
else
    echo "Cenário 4: Falha" >> "$LOG_DIR/resultados.txt"
fi

# ============================
# CENÁRIO 5 (leve)
# ============================

log ""
log "=========================================="
log "CENÁRIO 5: Falha + recuperação rápida (otimizado)"
log "=========================================="

docker exec hadoop-master hdfs dfs -rm -r -f /user/root/wordcount_output_cenario_5 2>/dev/null

docker exec hadoop-master bash -c "
    hadoop jar \$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples.jar \
        wordcount \
        /user/root/wordcount_input \
        /user/root/wordcount_output_cenario_5
" > "$LOG_DIR/wordcount_cenario_5.log" 2>&1 &

JOB_PID=$!

sleep 12

docker stop hadoop-slave1
sleep 8  

docker start hadoop-slave1
sleep 6   

wait $JOB_PID

if docker exec hadoop-master hdfs dfs -test -d /user/root/wordcount_output_cenario_5/_SUCCESS 2>/dev/null; then
    echo "Cenário 5: Sucesso" >> "$LOG_DIR/resultados.txt"
else
    echo "Cenário 5: Falha" >> "$LOG_DIR/resultados.txt"
fi

capturar_estado "final"

log ""
log "=========================================="
log "TESTE CONCLUÍDO"
log "=========================================="
cat "$LOG_DIR/resultados.txt" | tee -a "$LOG_FILE"
log "Logs salvos em: $LOG_DIR"
log ""