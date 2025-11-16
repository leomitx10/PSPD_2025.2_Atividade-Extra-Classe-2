#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_TESTES_DIR="$PROJECT_DIR/config_testes"

echo "===== TESTE DE MEMÓRIA DAS TASKS MAP/REDUCE ====="
echo ""


if ! docker ps | grep -q hadoop-master; then
    echo "Iniciando containers..."
    cd "$PROJECT_DIR"
    docker-compose up -d
    sleep 30
fi

if [ ! -f "$PROJECT_DIR/massa_de_dados/massa_unica.txt" ]; then
    echo "ERRO: massa_unica.txt não encontrado."
    exit 1
fi

TAMANHO_BYTES=$(stat -c%s "$PROJECT_DIR/massa_de_dados/massa_unica.txt")
echo "Arquivo de teste: $TAMANHO_BYTES bytes"
echo ""

testar_memtask() {
    local MAP_MB=$1
    local REDUCE_MB=$2
    local CONFIG_FILE="mapred-site-memtask-${MAP_MB}-${REDUCE_MB}.xml"

    echo "=== Map=${MAP_MB}MB / Reduce=${REDUCE_MB}MB ==="

    docker cp "$CONFIG_TESTES_DIR/$CONFIG_FILE" hadoop-master:/opt/hadoop/etc/hadoop/mapred-site.xml
    docker cp "$CONFIG_TESTES_DIR/$CONFIG_FILE" hadoop-slave1:/opt/hadoop/etc/hadoop/mapred-site.xml
    docker cp "$CONFIG_TESTES_DIR/$CONFIG_FILE" hadoop-slave2:/opt/hadoop/etc/hadoop/mapred-site.xml

    echo "Reiniciando YARN..."
    docker exec hadoop-master bash -c "\$HADOOP_HOME/sbin/stop-yarn.sh" >/dev/null 2>&1
    sleep 5
    docker exec hadoop-master bash -c "\$HADOOP_HOME/sbin/start-yarn.sh" >/dev/null 2>&1
    sleep 15
    
    echo "Aguardando NodeManagers ficarem ativos..."
    for i in {1..30}; do
        ACTIVE_NM=$(docker exec hadoop-master yarn node -list 2>/dev/null | grep -c "RUNNING" || echo 0)
        if [ "$ACTIVE_NM" -ge 2 ]; then
            echo "NodeManagers ativos: $ACTIVE_NM"
            break
        fi
        sleep 2
    done

    docker exec hadoop-master hdfs dfs -rm -r /test_memtask_input /test_memtask_output >/dev/null 2>&1
    docker exec hadoop-master hdfs dfs -mkdir -p /test_memtask_input
    docker exec hadoop-master hdfs dfs -put /massa_de_dados/massa_unica.txt /test_memtask_input/ >/dev/null 2>&1

    echo "Executando WordCount (verifique em http://localhost:8088)..."
    INICIO_WC=$(date +%s.%N)
    docker exec hadoop-master bash -c "hadoop jar \
        /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
        wordcount \
        /test_memtask_input \
        /test_memtask_output > /tmp/wc_memtask_${MAP_MB}_${REDUCE_MB}.log 2>&1"
    docker cp hadoop-master:/tmp/wc_memtask_${MAP_MB}_${REDUCE_MB}.log /tmp/wc_memtask_${MAP_MB}_${REDUCE_MB}.log 2>/dev/null || true
    FIM_WC=$(date +%s.%N)
    TEMPO_WC=$(echo "$FIM_WC - $INICIO_WC" | bc)

    MAP_TASKS=$(grep "Launched map tasks" /tmp/wc_memtask_${MAP_MB}_${REDUCE_MB}.log 2>/dev/null | grep -oP "=\K\d+" || echo "0")
    REDUCE_TASKS=$(grep "Launched reduce tasks" /tmp/wc_memtask_${MAP_MB}_${REDUCE_MB}.log 2>/dev/null | grep -oP "=\K\d+" || echo "0")
    
    REEXEC=$(grep "Resubmitting" /tmp/wc_memtask_${MAP_MB}_${REDUCE_MB}.log 2>/dev/null | wc -l)
    FAILED=$(grep "failed" /tmp/wc_memtask_${MAP_MB}_${REDUCE_MB}.log 2>/dev/null | wc -l)

    printf "MAP_MB=%s|REDUCE_MB=%s|MAP_TASKS=%s|REDUCE_TASKS=%s|REEXEC=%s|FAILED=%s|TEMPO_WC=%s\n" \
        "$MAP_MB" "$REDUCE_MB" "$MAP_TASKS" "$REDUCE_TASKS" "$REEXEC" "$FAILED" "$TEMPO_WC" >> /tmp/memtask_results.txt

    docker exec hadoop-master hdfs dfs -rm -r /test_memtask_input /test_memtask_output >/dev/null 2>&1

    echo ""
}

rm -f /tmp/memtask_results.txt

echo "Iniciando testes..."
testar_memtask 512 1024
testar_memtask 1024 2048

echo "Restaurando configuração padrão (1024/2048 MB)..."
docker cp "$CONFIG_TESTES_DIR/mapred-site-memtask-1024-2048.xml" hadoop-master:/opt/hadoop/etc/hadoop/mapred-site.xml
docker cp "$CONFIG_TESTES_DIR/mapred-site-memtask-1024-2048.xml" hadoop-slave1:/opt/hadoop/etc/hadoop/mapred-site.xml
docker cp "$CONFIG_TESTES_DIR/mapred-site-memtask-1024-2048.xml" hadoop-slave2:/opt/hadoop/etc/hadoop/mapred-site.xml
docker exec hadoop-master bash -c "\$HADOOP_HOME/sbin/stop-yarn.sh" >/dev/null 2>&1
sleep 3
docker exec hadoop-master bash -c "\$HADOOP_HOME/sbin/start-yarn.sh" >/dev/null 2>&1

echo ""
echo "================ RESULTADOS ================="
echo ""

i=1
while IFS='|' read -r line; do
    MAP_MB=$(echo "$line" | grep -oP "MAP_MB=\K\d+")
    REDUCE_MB=$(echo "$line" | grep -oP "REDUCE_MB=\K\d+")
    MAP_TASKS=$(echo "$line" | grep -oP "MAP_TASKS=\K\d+")
    REDUCE_TASKS=$(echo "$line" | grep -oP "REDUCE_TASKS=\K\d+")
    REEXEC=$(echo "$line" | grep -oP "REEXEC=\K\d+")
    FAILED=$(echo "$line" | grep -oP "FAILED=\K\d+")
    TEMPO_WC=$(echo "$line" | grep -oP "TEMPO_WC=\K[\d\.]+")

    echo "Resultado $i:"
    echo "Map memory: ${MAP_MB} MB"
    echo "Reduce memory: ${REDUCE_MB} MB"
    echo "Map tasks: $MAP_TASKS"
    echo "Reduce tasks: $REDUCE_TASKS"
    echo "Tasks reexecutadas: $REEXEC"
    echo "Tasks falhadas: $FAILED"
    echo "Tempo WordCount: ${TEMPO_WC} s"
    echo ""

    ((i++))
done < /tmp/memtask_results.txt


