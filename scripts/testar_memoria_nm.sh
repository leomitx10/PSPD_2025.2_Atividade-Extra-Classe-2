#!/bin/bash

# ======================================================
# TESTE DE MEMÓRIA DO NODEMANAGER (yarn.nodemanager.resource.memory-mb)
# Com suporte ao YARN + JobHistory Server
# ======================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_TESTES_DIR="$PROJECT_DIR/config_testes"

echo "===== TESTE DE MEMÓRIA DO NODEMANAGER ====="
echo ""

# ------------------------------------------------------
# VERIFICAR CONTAINERS
# ------------------------------------------------------
echo "Verificando containers..."
if ! docker ps | grep -q hadoop-master; then
    echo "Iniciando containers..."
    cd "$PROJECT_DIR"
    docker-compose up -d
    echo "Aguardando containers iniciarem (30s)..."
    sleep 30
fi

# ------------------------------------------------------
# ATIVAR JOBHISTORY SERVER (IMPORTANTE PARA RELATÓRIO)
# ------------------------------------------------------
echo "Ativando JobHistory Server..."
docker exec hadoop-master bash -c "\$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh stop historyserver" >/dev/null 2>&1
docker exec hadoop-master bash -c "\$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh start historyserver"
sleep 3
echo "JobHistory ativo em: http://localhost:19888/jobhistory"
echo ""

# ------------------------------------------------------
# VERIFICAR MASSA DE DADOS
# ------------------------------------------------------
if [ ! -f "$PROJECT_DIR/massa_de_dados/massa_unica.txt" ]; then
    echo "ERRO: massa_unica.txt não encontrado."
    exit 1
fi

TAMANHO_BYTES=$(stat -c%s "$PROJECT_DIR/massa_de_dados/massa_unica.txt")
echo "Arquivo de teste: $TAMANHO_BYTES bytes"
echo ""

# ------------------------------------------------------
# FUNÇÃO DE TESTE
# ------------------------------------------------------
testar_memoria() {
    local MEMORIA_MB=$1
    local CONFIG_FILE="yarn-site-memoria-${MEMORIA_MB}mb.xml"

    echo ""
    echo "=== Testando memória NodeManager = ${MEMORIA_MB}MB ==="

    # ------------------------------------------------------
    # APLICAR CONFIGURAÇÃO
    # ------------------------------------------------------
    docker cp "$CONFIG_TESTES_DIR/$CONFIG_FILE" hadoop-master:/opt/hadoop/etc/hadoop/yarn-site.xml
    docker cp "$CONFIG_TESTES_DIR/$CONFIG_FILE" hadoop-slave1:/opt/hadoop/etc/hadoop/yarn-site.xml
    docker cp "$CONFIG_TESTES_DIR/$CONFIG_FILE" hadoop-slave2:/opt/hadoop/etc/hadoop/yarn-site.xml

    # Reiniciar APENAS NodeManagers (não o YARN todo)
    docker exec hadoop-slave1 bash -c "\$HADOOP_HOME/sbin/yarn-daemon.sh stop nodemanager" >/dev/null 2>&1
    docker exec hadoop-slave2 bash -c "\$HADOOP_HOME/sbin/yarn-daemon.sh stop nodemanager" >/dev/null 2>&1
    sleep 4
    docker exec hadoop-slave1 bash -c "\$HADOOP_HOME/sbin/yarn-daemon.sh start nodemanager"
    docker exec hadoop-slave2 bash -c "\$HADOOP_HOME/sbin/yarn-daemon.sh start nodemanager"
    sleep 8

    # ------------------------------------------------------
    # PREPARAR HDFS
    # ------------------------------------------------------
    docker exec hadoop-master hdfs dfs -rm -r /test_memoria_input /test_memoria_output >/dev/null 2>&1
    docker exec hadoop-master hdfs dfs -mkdir -p /test_memoria_input
    docker exec hadoop-master hdfs dfs -put /massa_de_dados/massa_unica.txt /test_memoria_input/

    # ------------------------------------------------------
    # EXECUTAR WORDCOUNT (APARECE NO YARN!)
    # ------------------------------------------------------
    echo "Executando WordCount..."
    INICIO_WC=$(date +%s.%N)

    docker exec hadoop-master hadoop jar \
        /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
        wordcount \
        /test_memoria_input \
        /test_memoria_output \
        > /tmp/wc_mem_${MEMORIA_MB}.log 2>&1

    FIM_WC=$(date +%s.%N)
    TEMPO_WC=$(echo "$FIM_WC - $INICIO_WC" | bc)

    # ------------------------------------------------------
    # COLETAR MÉTRICAS
    # ------------------------------------------------------
    MAP_TASKS=$(grep "Launched map tasks" /tmp/wc_mem_${MEMORIA_MB}.log | grep -oP "=\K\d+" || echo "0")
    REDUCE_TASKS=$(grep "Launched reduce tasks" /tmp/wc_mem_${MEMORIA_MB}.log | grep -oP "=\K\d+" || echo "0")

    # Paralelismo teórico
    MEMORIA_TOTAL=$((MEMORIA_MB * 2))  # 2 DataNodes
    MEMORIA_AM=512
    MEMORIA_DISPONIVEL=$((MEMORIA_TOTAL - MEMORIA_AM))
    CONTAINERS_MAX=$((MEMORIA_DISPONIVEL / 1024))
    if [ $CONTAINERS_MAX -lt 1 ]; then
        CONTAINERS_MAX=1
    fi

    # ------------------------------------------------------
    # SALVAR RESULTADOS
    # ------------------------------------------------------
    echo "MEMORIA=${MEMORIA_MB}|MAP_TASKS=$MAP_TASKS|REDUCE_TASKS=$REDUCE_TASKS|TEMPO_WC=$TEMPO_WC|CONTAINERS_MAX=$CONTAINERS_MAX" \
        >> /tmp/memoria_results.txt

    echo "OK - Teste finalizado."
}

# ------------------------------------------------------
# EXECUTAR TESTES
# ------------------------------------------------------

rm -f /tmp/memoria_results.txt

echo "Iniciando testes..."
testar_memoria 2048
testar_memoria 4096
testar_memoria 8192

# ------------------------------------------------------
# RESTAURAR CONFIG PADRÃO
# ------------------------------------------------------
echo "Restaurando configuração padrão (4096MB)..."
docker cp "$CONFIG_TESTES_DIR/yarn-site-memoria-4096mb.xml" hadoop-master:/opt/hadoop/etc/hadoop/yarn-site.xml
docker cp "$CONFIG_TESTES_DIR/yarn-site-memoria-4096mb.xml" hadoop-slave1:/opt/hadoop/etc/hadoop/yarn-site.xml
docker cp "$CONFIG_TESTES_DIR/yarn-site-memoria-4096mb.xml" hadoop-slave2:/opt/hadoop/etc/hadoop/yarn-site.xml

echo ""
echo "================ RESULTADOS ================="
echo ""

i=1
while IFS='|' read -r line; do
    MEM=$(echo "$line" | grep -oP "MEMORIA=\K\d+")
    MAP=$(echo "$line" | grep -oP "MAP_TASKS=\K\d+")
    RED=$(echo "$line" | grep -oP "REDUCE_TASKS=\K\d+")
    TEMPO=$(echo "$line" | grep -oP "TEMPO_WC=\K[\d\.]+")
    CONT=$(echo "$line" | grep -oP "CONTAINERS_MAX=\K\d+")

    echo "Resultado $i:"
    echo "Memória NodeManager: ${MEM} MB"
    echo "Map tasks: $MAP"
    echo "Reduce tasks: $RED"
    echo "Containers simultâneos (estimado): $CONT"
    echo "Tempo WordCount: ${TEMPO} s"
    echo ""

    ((i++))
done < /tmp/memoria_results.txt

echo "================ FIM ================="
