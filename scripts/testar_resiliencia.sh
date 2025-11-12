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
    log "📸 Capturando estado: $MOMENTO"
    
    # Status dos containers
    docker ps --filter "name=hadoop" --format "table {{.Names}}\t{{.Status}}" > "$LOG_DIR/containers_${MOMENTO}.txt"
    
    # Jobs em execução
    docker exec hadoop-master yarn application -list -appStates ALL 2>/dev/null > "$LOG_DIR/jobs_${MOMENTO}.txt"
    
    # Nodes do YARN
    docker exec hadoop-master yarn node -list -all 2>/dev/null > "$LOG_DIR/nodes_${MOMENTO}.txt"
    
    # Status do HDFS
    docker exec hadoop-master hdfs dfsadmin -report 2>/dev/null > "$LOG_DIR/hdfs_${MOMENTO}.txt"
}

# Função para executar cenário de teste
executar_cenario() {
    local NUM=$1
    local DESCRICAO=$2
    local ACAO=$3
    
    log ""
    log "=========================================="
    log "CENÁRIO $NUM: $DESCRICAO"
    log "=========================================="
    
    # Limpar outputs anteriores
    docker exec hadoop-master hdfs dfs -rm -r -f /user/root/wordcount_output_cenario_${NUM} 2>/dev/null
    
    # Iniciar job
    log "🚀 Iniciando wordcount..."
    docker exec hadoop-master bash -c "
        hadoop jar \$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
            wordcount \
            /user/root/wordcount_input \
            /user/root/wordcount_output_cenario_${NUM}
    " > "$LOG_DIR/wordcount_cenario_${NUM}.log" 2>&1 &
    
    JOB_PID=$!
    log "Job iniciado (PID: $JOB_PID)"
    
    # Aguardar job iniciar
    log "⏰ Aguardando 30s para job inicializar..."
    sleep 30
    
    capturar_estado "cenario_${NUM}_antes_falha"
    
    # Executar ação (simular falha)
    log "💥 Executando ação: $ACAO"
    eval "$ACAO"
    
    capturar_estado "cenario_${NUM}_durante_falha"
    
    # Aguardar com falha
    log "⏰ Aguardando 45s com falha ativa..."
    sleep 45
    
    # Recuperar (se aplicável)
    if [[ "$ACAO" == *"docker stop"* ]]; then
        local NODE=$(echo "$ACAO" | grep -oP 'hadoop-slave[0-9]+')
        if [ -n "$NODE" ]; then
            log "🔄 Recuperando node: $NODE"
            docker start $NODE
            sleep 10
        fi
    fi
    
    capturar_estado "cenario_${NUM}_apos_recuperacao"
    
    # Aguardar job terminar
    log "⏰ Aguardando job terminar..."
    wait $JOB_PID
    JOB_EXIT_CODE=$?
    
    log "✅ Job finalizado (exit code: $JOB_EXIT_CODE)"
    
    # Verificar resultado
    if docker exec hadoop-master hdfs dfs -test -d /user/root/wordcount_output_cenario_${NUM}/_SUCCESS 2>/dev/null; then
        log "✅ SUCESSO: Output gerado com sucesso"
        RESULTADO="SUCESSO"
    else
        log "❌ FALHA: Output não foi gerado corretamente"
        RESULTADO="FALHA"
    fi
    
    # Salvar resultado
    echo "Cenário $NUM: $DESCRICAO - $RESULTADO" >> "$LOG_DIR/resultados.txt"
    
    # Aguardar antes do próximo cenário
    log "⏰ Aguardando 30s antes do próximo cenário..."
    sleep 30
}

# Verificar se o cluster está rodando
log "🔍 Verificando cluster..."
if ! docker ps | grep -q "hadoop-master"; then
    log "❌ ERRO: Cluster não está rodando!"
    log "Execute: docker-compose up -d"
    exit 1
fi

# Verificar se há dados no HDFS
log "🔍 Verificando dados no HDFS..."
if ! docker exec hadoop-master hdfs dfs -test -d /user/root/wordcount_input 2>/dev/null; then
    log "❌ ERRO: Dados não encontrados no HDFS!"
    log "Execute: ./gerar_dados.sh && ./executar_wordcount.sh"
    exit 1
fi

log ""
log "=========================================="
log "INICIANDO TESTES DE RESILIÊNCIA"
log "=========================================="
log "Logs serão salvos em: $LOG_DIR"
log ""

# Capturar estado inicial
capturar_estado "inicial"

# CENÁRIO 1: Baseline (sem falhas)
executar_cenario 1 \
    "Baseline - Execução normal (3 nodes ativos)" \
    "log 'Nenhuma falha simulada'"

# CENÁRIO 2: Falha de 1 slave durante execução
executar_cenario 2 \
    "Falha de 1 slave (slave1) durante execução" \
    "docker stop hadoop-slave1"

# CENÁRIO 3: Falha de outro slave
executar_cenario 3 \
    "Falha de 1 slave (slave2) durante execução" \
    "docker stop hadoop-slave2"

# CENÁRIO 4: Falha dos 2 slaves (crítico)
log ""
log "=========================================="
log "CENÁRIO 4: Falha de ambos os slaves"
log "=========================================="
log "🚀 Iniciando wordcount..."
docker exec hadoop-master hdfs dfs -rm -r -f /user/root/wordcount_output_cenario_4 2>/dev/null

docker exec hadoop-master bash -c "
    hadoop jar \$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
        wordcount \
        /user/root/wordcount_input \
        /user/root/wordcount_output_cenario_4
" > "$LOG_DIR/wordcount_cenario_4.log" 2>&1 &

JOB_PID=$!
log "Job iniciado (PID: $JOB_PID)"

log "⏰ Aguardando 30s..."
sleep 30

capturar_estado "cenario_4_antes_falha"

log "💥 Parando slave1..."
docker stop hadoop-slave1
sleep 10

log "💥 Parando slave2..."
docker stop hadoop-slave2
sleep 10

capturar_estado "cenario_4_durante_falha"

log "⏰ Aguardando 60s com ambos slaves parados..."
sleep 60

log "🔄 Reiniciando slaves..."
docker start hadoop-slave1 hadoop-slave2
sleep 15

capturar_estado "cenario_4_apos_recuperacao"

log "⏰ Aguardando job terminar ou falhar..."
wait $JOB_PID
JOB_EXIT_CODE=$?

log "Job finalizado (exit code: $JOB_EXIT_CODE)"

if docker exec hadoop-master hdfs dfs -test -d /user/root/wordcount_output_cenario_4/_SUCCESS 2>/dev/null; then
    log "✅ SUCESSO: Output gerado"
    echo "Cenário 4: Falha de ambos os slaves - SUCESSO" >> "$LOG_DIR/resultados.txt"
else
    log "❌ FALHA: Output não gerado"
    echo "Cenário 4: Falha de ambos os slaves - FALHA" >> "$LOG_DIR/resultados.txt"
fi

# CENÁRIO 5: Recuperação rápida (teste de elasticidade)
log ""
log "=========================================="
log "CENÁRIO 5: Falha e recuperação rápida"
log "=========================================="
log "🚀 Iniciando wordcount..."
docker exec hadoop-master hdfs dfs -rm -r -f /user/root/wordcount_output_cenario_5 2>/dev/null

docker exec hadoop-master bash -c "
    hadoop jar \$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
        wordcount \
        /user/root/wordcount_input \
        /user/root/wordcount_output_cenario_5
" > "$LOG_DIR/wordcount_cenario_5.log" 2>&1 &

JOB_PID=$!

log "⏰ Aguardando 30s..."
sleep 30

log "💥 Parando slave1..."
docker stop hadoop-slave1
sleep 15

log "🔄 Reiniciando slave1 (recuperação rápida)..."
docker start hadoop-slave1
sleep 10

log "⏰ Aguardando job terminar..."
wait $JOB_PID

if docker exec hadoop-master hdfs dfs -test -d /user/root/wordcount_output_cenario_5/_SUCCESS 2>/dev/null; then
    log "✅ SUCESSO"
    echo "Cenário 5: Recuperação rápida - SUCESSO" >> "$LOG_DIR/resultados.txt"
else
    log "❌ FALHA"
    echo "Cenário 5: Recuperação rápida - FALHA" >> "$LOG_DIR/resultados.txt"
fi

# Capturar estado final
capturar_estado "final"

# Gerar relatório
log ""
log "=========================================="
log "TESTE CONCLUÍDO!"
log "=========================================="
log ""
log "📊 RESULTADOS:"
cat "$LOG_DIR/resultados.txt" | tee -a "$LOG_FILE"

log ""
log "📁 Logs e evidências salvos em: $LOG_DIR"
log ""
log "Para análise detalhada, consulte:"
log "  - Log principal: $LOG_FILE"
log "  - Logs individuais: $LOG_DIR/wordcount_cenario_*.log"
log "  - Estados capturados: $LOG_DIR/*_*.txt"
log ""
log "=========================================="

echo ""
echo "✅ Teste de resiliência concluído!"
echo "Resultados em: $LOG_DIR"
