#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_TESTES_DIR="$PROJECT_DIR/config_testes"

echo "TESTE DE TAMANHO DE BLOCO"
echo ""

echo "Verificando containers..."
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

testar_blocksize() {
    local BLOCKSIZE_MB=$1
    local CONFIG_FILE="hdfs-site-blocksize-${BLOCKSIZE_MB}mb.xml"

    echo "=== Blocksize = ${BLOCKSIZE_MB}MB ==="

    docker cp "$CONFIG_TESTES_DIR/$CONFIG_FILE" hadoop-master:/opt/hadoop/etc/hadoop/hdfs-site.xml
    docker cp "$CONFIG_TESTES_DIR/$CONFIG_FILE" hadoop-slave1:/opt/hadoop/etc/hadoop/hdfs-site.xml
    docker cp "$CONFIG_TESTES_DIR/$CONFIG_FILE" hadoop-slave2:/opt/hadoop/etc/hadoop/hdfs-site.xml

    docker exec hadoop-master bash -c "\$HADOOP_HOME/sbin/stop-dfs.sh" >/dev/null 2>&1
    sleep 5
    docker exec hadoop-master bash -c "\$HADOOP_HOME/sbin/start-dfs.sh" >/dev/null 2>&1
    sleep 8
    docker exec hadoop-master hdfs dfsadmin -safemode wait >/dev/null 2>&1

    docker exec hadoop-master hdfs dfs -rm -r /test_blocksize_input /test_blocksize_output >/dev/null 2>&1
    docker exec hadoop-master hdfs dfs -mkdir -p /test_blocksize_input

    INICIO_UPLOAD=$(date +%s.%N)
    docker exec hadoop-master hdfs dfs -put /massa_de_dados/massa_unica.txt /test_blocksize_input/
    FIM_UPLOAD=$(date +%s.%N)
    TEMPO_UPLOAD=$(echo "$FIM_UPLOAD - $INICIO_UPLOAD" | bc)

    FSCK_OUTPUT=$(docker exec hadoop-master hdfs fsck /test_blocksize_input/massa_unica.txt -files -blocks -locations 2>/dev/null)
    NUM_BLOCOS=$(echo "$FSCK_OUTPUT" | grep -c "blk_" || echo "0")


    INICIO_WC=$(date +%s.%N)
    docker exec hadoop-master hadoop jar \
        /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
        wordcount \
        /test_blocksize_input \
        /test_blocksize_output > /tmp/wc_block_${BLOCKSIZE_MB}.log 2>&1
    FIM_WC=$(date +%s.%N)
    TEMPO_WC=$(echo "$FIM_WC - $INICIO_WC" | bc)

    MAP_TASKS=$(grep "Launched map tasks" /tmp/wc_block_${BLOCKSIZE_MB}.log | grep -oP "=\K\d+" || echo "$NUM_BLOCOS")
    REDUCE_TASKS=$(grep "Launched reduce tasks" /tmp/wc_block_${BLOCKSIZE_MB}.log | grep -oP "=\K\d+" || echo "1")

    METADATA_POR_BLOCO=150
    METADATA_BYTES=$((NUM_BLOCOS * METADATA_POR_BLOCO))

    echo "BLOCKSIZE=${BLOCKSIZE_MB}|BLOCOS=$NUM_BLOCOS|MAP_TASKS=$MAP_TASKS|TEMPO_WC=$TEMPO_WC|UPLOAD=$TEMPO_UPLOAD|METADATA=$METADATA_BYTES" >> /tmp/blocksize_results.txt

    docker exec hadoop-master hdfs dfs -rm -r /test_blocksize_input /test_blocksize_output >/dev/null 2>&1

    echo ""
}


rm -f /tmp/blocksize_results.txt

testar_blocksize 32
testar_blocksize 64
testar_blocksize 128

echo ""
echo "================ RESULTADOS ================="
echo ""

i=1
while IFS='|' read -r line; do
    BLOCKSIZE=$(echo "$line" | grep -oP "BLOCKSIZE=\K\d+")
    BLOCOS=$(echo "$line" | grep -oP "BLOCOS=\K\d+")
    MAP_TASKS=$(echo "$line" | grep -oP "MAP_TASKS=\K\d+")
    TEMPO_WC=$(echo "$line" | grep -oP "TEMPO_WC=\K[\d\.]+")
    UPLOAD=$(echo "$line" | grep -oP "UPLOAD=\K[\d\.]+")
    METADATA=$(echo "$line" | grep -oP "METADATA=\K\d+")

    echo "Resultado $i:"
    echo "Blocksize: ${BLOCKSIZE} MB"
    echo "Blocos: $BLOCOS"
    echo "Map tasks: $MAP_TASKS"
    echo "Tempo WordCount: ${TEMPO_WC} s"
    echo "Tempo de upload: ${UPLOAD} s"
    echo "Metadata: ${METADATA} bytes"
    echo ""

    ((i++))
done < /tmp/blocksize_results.txt
