#!/bin/bash

echo "=========================================="
echo "TESTE DE PERFORMANCE - ESCALABILIDADE"
echo "=========================================="
echo ""

# Criar diretório de logs
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_DIR="logs_resiliencia/performance_${TIMESTAMP}"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/teste_performance.log"

# Função para logar
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Função para executar teste com N nodes
executar_teste() {
    local NODES_ATIVOS=$1
    local DESCRICAO=$2
    
    log ""
    log "=========================================="
    log "TESTE: $DESCRICAO"
    log "Nodes ativos: $NODES_ATIVOS"
    log "=========================================="
    
    # Garantir que todos os nodes estão ativos inicialmente
    docker start hadoop-master hadoop-slave1 hadoop-slave2 2>/dev/null
    sleep 10
    
    # Configurar cenário (parar nodes se necessário)
    if [ "$NODES_ATIVOS" == "1" ]; then
        log "🔴 Parando ambos os slaves..."
        docker stop hadoop-slave1 hadoop-slave2
        sleep 5
    elif [ "$NODES_ATIVOS" == "2" ]; then
        log "🔴 Parando slave2..."
        docker stop hadoop-slave2
        sleep 5
    fi
    
    # Verificar status
    log "📊 Status do cluster:"
    docker ps --filter "name=hadoop" --format "table {{.Names}}\t{{.Status}}" | tee -a "$LOG_FILE"
    
    # Limpar output anterior
    docker exec hadoop-master hdfs dfs -rm -r -f /user/root/wordcount_output_perf_${NODES_ATIVOS}nodes 2>/dev/null
    
    # Executar wordcount e medir tempo
    log ""
    log "🚀 Iniciando wordcount..."
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
        log "✅ Job concluído com sucesso"
        log "⏱️  Tempo de execução: ${MINUTES}m ${SECONDS}s (${DURATION}s)"
        
        # Extrair estatísticas do log
        MAP_TASKS=$(grep "Launched map tasks=" "$LOG_DIR/wordcount_${NODES_ATIVOS}nodes.log" | tail -1 | grep -oP '\d+')
        REDUCE_TASKS=$(grep "Launched reduce tasks=" "$LOG_DIR/wordcount_${NODES_ATIVOS}nodes.log" | tail -1 | grep -oP '\d+')
        
        log "📊 Tarefas: Map=$MAP_TASKS, Reduce=$REDUCE_TASKS"
        
        # Salvar resultado
        echo "${NODES_ATIVOS},${DURATION},SUCESSO,${MAP_TASKS},${REDUCE_TASKS}" >> "$LOG_DIR/resultados.csv"
    else
        log "❌ Job falhou (exit code: $EXIT_CODE)"
        echo "${NODES_ATIVOS},${DURATION},FALHA,0,0" >> "$LOG_DIR/resultados.csv"
    fi
    
    # Aguardar antes do próximo teste
    log "⏰ Aguardando 20s antes do próximo teste..."
    sleep 20
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
log "INICIANDO TESTES DE PERFORMANCE"
log "=========================================="
log "Objetivo: Avaliar impacto do número de nodes"
log "Logs serão salvos em: $LOG_DIR"
log ""

# Criar arquivo CSV com cabeçalho
echo "nodes,tempo_segundos,status,map_tasks,reduce_tasks" > "$LOG_DIR/resultados.csv"

# Teste 1: Com 3 nodes (master + 2 slaves) - Baseline
executar_teste "3" "Baseline - 3 nodes (1 master + 2 slaves)"

# Teste 2: Com 2 nodes (master + 1 slave)
executar_teste "2" "Reduzido - 2 nodes (1 master + 1 slave)"

# Teste 3: Com 1 node (apenas master)
executar_teste "1" "Mínimo - 1 node (apenas master)"

# Restaurar todos os nodes
log ""
log "🔄 Restaurando todos os nodes..."
docker start hadoop-master hadoop-slave1 hadoop-slave2 2>/dev/null
sleep 10

# Teste 4: Com 3 nodes novamente (verificar consistência)
executar_teste "3" "Verificação - 3 nodes novamente"

# Gerar relatório
log ""
log "=========================================="
log "TESTE DE PERFORMANCE CONCLUÍDO!"
log "=========================================="
log ""
log "📊 RESUMO DOS RESULTADOS:"
log ""

# Ler e exibir resultados
echo "Nodes | Tempo (s) | Tempo (m:s) | Status" | tee -a "$LOG_FILE"
echo "------|-----------|-------------|--------" | tee -a "$LOG_FILE"

tail -n +2 "$LOG_DIR/resultados.csv" | while IFS=, read -r nodes tempo status map reduce; do
    minutos=$((tempo / 60))
    segundos=$((tempo % 60))
    printf "%5s | %9s | %11s | %s\n" "$nodes" "$tempo" "${minutos}m ${segundos}s" "$status" | tee -a "$LOG_FILE"
done

log ""
log "📈 ANÁLISE:"
log ""

# Calcular speedup
TEMPO_3NODES=$(awk -F, 'NR==2 {print $2}' "$LOG_DIR/resultados.csv")
TEMPO_2NODES=$(awk -F, 'NR==3 {print $2}' "$LOG_DIR/resultados.csv")
TEMPO_1NODE=$(awk -F, 'NR==4 {print $2}' "$LOG_DIR/resultados.csv")

if [ -n "$TEMPO_3NODES" ] && [ -n "$TEMPO_2NODES" ] && [ "$TEMPO_2NODES" -gt 0 ]; then
    SPEEDUP_2=$(awk "BEGIN {printf \"%.2f\", $TEMPO_2NODES / $TEMPO_3NODES}")
    log "  Speedup 3 nodes vs 2 nodes: ${SPEEDUP_2}x"
fi

if [ -n "$TEMPO_3NODES" ] && [ -n "$TEMPO_1NODE" ] && [ "$TEMPO_1NODE" -gt 0 ]; then
    SPEEDUP_1=$(awk "BEGIN {printf \"%.2f\", $TEMPO_1NODE / $TEMPO_3NODES}")
    log "  Speedup 3 nodes vs 1 node: ${SPEEDUP_1}x"
fi

log ""
log "📁 Arquivos gerados:"
log "  - Resumo: $LOG_FILE"
log "  - CSV: $LOG_DIR/resultados.csv"
log "  - Logs individuais: $LOG_DIR/wordcount_*.log"
log ""
log "=========================================="

echo ""
echo "✅ Teste de performance concluído!"
echo "Resultados em: $LOG_DIR"
