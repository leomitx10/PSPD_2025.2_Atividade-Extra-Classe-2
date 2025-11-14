#!/bin/bash

echo "=========================================="
echo "TESTE DE PERFORMANCE - ESCALABILIDADE"
echo "=========================================="
echo ""

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_DIR="logs_resiliencia/performance_${TIMESTAMP}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/teste_performance.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

executar_teste() {
    local NODES_ATIVOS=$1
    local DESCRICAO=$2
    
    log ""
    log "=========================================="
    log "TESTE: $DESCRICAO"
    log "Nodes ativos: $NODES_ATIVOS"
    log "=========================================="
    
    docker start hadoop-master hadoop-slave1 hadoop-slave2 >/dev/null 2>&1
    sleep 10
    
    if [ "$NODES_ATIVOS" == "1" ]; then
        docker stop hadoop-slave1 hadoop-slave2 >/dev/null 2>&1
        sleep 5
    elif [ "$NODES_ATIVOS" == "2" ]; then
        docker stop hadoop-slave2 >/dev/null 2>&1
        sleep 5
    fi
    
    log "Status do cluster:"
    docker ps --filter "name=hadoop" --format "table {{.Names}}\t{{.Status}}" | tee -a "$LOG_FILE"
    
    docker exec hadoop-master hdfs dfs -rm -r -f /user/root/wordcount_output_perf_${NODES_ATIVOS}nodes >/dev/null 2>&1
    
    log ""
    log "Iniciando wordcount..."
    START_TIME=$(date +%s)
    
    docker exec hadoop-master bash -c "
        hadoop jar \$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
            wordcount \
            /user/root/wordcount_input \
            /user/root/wordcount_output_perf_${NODES_ATIVOS}nodes
    " > "$LOG_DIR/wordcount_${NODES_ATIVOS}nodes.log" 2>&1
    
    EXIT_CODE=$?
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    log ""
    if [ $EXIT_CODE -eq 0 ]; then
        log "Job concluído com sucesso"
        log "Tempo de execução: ${MINUTES}m ${SECONDS}s (${DURATION}s)"
        
        MAP_TASKS=$(grep "Launched map tasks=" "$LOG_DIR/wordcount_${NODES_ATIVOS}nodes.log" | tail -1 | grep -oP '\d+')
        REDUCE_TASKS=$(grep "Launched reduce tasks=" "$LOG_DIR/wordcount_${NODES_ATIVOS}nodes.log" | tail -1 | grep -oP '\d+')
        
        log "Tarefas: Map=$MAP_TASKS, Reduce=$REDUCE_TASKS"
        
        echo "${NODES_ATIVOS},${DURATION},SUCESSO,${MAP_TASKS},${REDUCE_TASKS}" >> "$LOG_DIR/resultados.csv"
    else
        log "Job falhou (exit code: $EXIT_CODE)"
        echo "${NODES_ATIVOS},${DURATION},FALHA,0,0" >> "$LOG_DIR/resultados.csv"
    fi
    
    log "Aguardando 20s antes do próximo teste..."
    sleep 20
}

log "Verificando cluster..."
if ! docker ps | grep -q "hadoop-master"; then
    log "ERRO: Cluster não está rodando."
    exit 1
fi

log "Verificando dados no HDFS..."
if ! docker exec hadoop-master hdfs dfs -test -d /user/root/wordcount_input >/dev/null 2>&1; then
    log "ERRO: Dados não encontrados no HDFS."
    exit 1
fi

log ""
log "=========================================="
log "INICIANDO TESTES DE PERFORMANCE"
log "=========================================="
log "Objetivo: Avaliar impacto do número de nodes"
log "Logs em: $LOG_DIR"
log ""

echo "nodes,tempo_segundos,status,map_tasks,reduce_tasks" > "$LOG_DIR/resultados.csv"

executar_teste "3" "Baseline - 3 nodes"
executar_teste "2" "Teste com 2 nodes"
executar_teste "1" "Teste com 1 node"

log ""
log "Restaurando todos os nodes..."
docker start hadoop-master hadoop-slave1 hadoop-slave2 >/dev/null 2>&1
sleep 10

executar_teste "3" "Teste final com 3 nodes"

log ""
log "=========================================="
log "TESTE DE PERFORMANCE CONCLUÍDO"
log "=========================================="
log ""

echo "Nodes | Tempo (s) | Tempo (m:s) | Status" | tee -a "$LOG_FILE"
echo "------|-----------|-------------|--------" | tee -a "$LOG_FILE"

tail -n +2 "$LOG_DIR/resultados.csv" | while IFS=, read -r nodes tempo status map reduce; do
    minutos=$((tempo / 60))
    segundos=$((tempo % 60))
    printf "%5s | %9s | %11s | %s\n" "$nodes" "$tempo" "${minutos}m ${segundos}s" "$status" | tee -a "$LOG_FILE"
done

log ""

TEMPO_3NODES=$(awk -F, 'NR==2 {print $2}' "$LOG_DIR/resultados.csv")
TEMPO_2NODES=$(awk -F, 'NR==3 {print $2}' "$LOG_DIR/resultados.csv")
TEMPO_1NODE=$(awk -F, 'NR==4 {print $2}' "$LOG_DIR/resultados.csv")

log "Análise:"

if [ -n "$TEMPO_3NODES" ] && [ -n "$TEMPO_2NODES" ] && [ "$TEMPO_2NODES" -gt 0 ]; then
    SPEEDUP_2=$(awk "BEGIN {printf \"%.2f\", $TEMPO_2NODES / $TEMPO_3NODES}")
    log "Speedup 3 nodes vs 2 nodes: ${SPEEDUP_2}x"
fi

if [ -n "$TEMPO_3NODES" ] && [ -n "$TEMPO_1NODE" ] && [ "$TEMPO_1NODE" -gt 0 ]; then
    SPEEDUP_1=$(awk "BEGIN {printf \"%.2f\", $TEMPO_1NODE / $TEMPO_3NODES}")
    log "Speedup 3 nodes vs 1 node: ${SPEEDUP_1}x"
fi

log ""
log "Arquivos gerados:"
log "  - Resumo: $LOG_FILE"
log "  - CSV: $LOG_DIR/resultados.csv"
log "  - Logs dos jobs: $LOG_DIR/wordcount_*.log"
log "=========================================="

echo ""
echo "Teste de performance concluído."
echo "Resultados em: $LOG_DIR"
