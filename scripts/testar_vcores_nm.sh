#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_TESTES_DIR="$PROJECT_DIR/config_testes"

echo "===== TESTE DE vCORES DO NODEMANAGER ====="
echo ""

echo "Verificando containers..."
if ! docker ps | grep -q hadoop-master; then
    echo "Iniciando containers..."
    cd "$PROJECT_DIR"
    docker-compose up -d
    echo "Aguardando containers iniciarem (30s)..."
    sleep 30
fi

echo "Ativando JobHistory Server..."
docker exec hadoop-master bash -c "\$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh stop historyserver" >/dev/null 2>&1
docker exec hadoop-master bash -c "\$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh start historyserver"
sleep 3
echo "JobHistory ativo em: http://localhost:19888/jobhistory"
echo ""

if [ ! -f "$PROJECT_DIR/massa_de_dados/massa_unica.txt" ]; then
    echo "ERRO: massa_unica.txt não encontrado."
    exit 1
fi

TAMANHO_BYTES=$(stat -c%s "$PROJECT_DIR/massa_de_dados/massa_unica.txt")
echo "Arquivo de teste: $TAMANHO_BYTES bytes"
echo ""


testar_vcores() {
    local VCORES=$1
    local CONFIG_FILE="yarn-site-vcores-${VCORES}.xml"

    echo ""
    echo "=== Testando vCores = ${VCORES} ==="

    docker cp "$CONFIG_TESTES_DIR/$CONFIG_FILE" hadoop-master:/opt/hadoop/etc/hadoop/yarn-site.xml
    docker cp "$CONFIG_TESTES_DIR/$CONFIG_FILE" hadoop-slave1:/opt/hadoop/etc/hadoop/yarn-site.xml
    docker cp "$CONFIG_TESTES_DIR/$CONFIG_FILE" hadoop-slave2:/opt/hadoop/etc/hadoop/yarn-site.xml

    echo "Reiniciando NodeManagers..."
    docker exec hadoop-slave1 bash -c "\$HADOOP_HOME/sbin/yarn-daemon.sh stop nodemanager" >/dev/null 2>&1
    docker exec hadoop-slave2 bash -c "\$HADOOP_HOME/sbin/yarn-daemon.sh stop nodemanager" >/dev/null 2>&1
    sleep 4

    docker exec hadoop-slave1 bash -c "\$HADOOP_HOME/sbin/yarn-daemon.sh start nodemanager"
    docker exec hadoop-slave2 bash -c "\$HADOOP_HOME/sbin/yarn-daemon.sh start nodemanager"
    sleep 8

    docker exec hadoop-master hdfs dfs -rm -r /test_vcores_input /test_vcores_output >/dev/null 2>&1
    docker exec hadoop-master hdfs dfs -mkdir -p /test_vcores_input
    docker exec hadoop-master hdfs dfs -put /massa_de_dados/massa_unica.txt /test_vcores_input/

    echo "Executando WordCount..."
    INICIO_WC=$(date +%s.%N)

    docker exec hadoop-master hadoop jar \
        /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
        wordcount \
        /test_vcores_input \
        /test_vcores_output \
        > /tmp/wc_vcores_${VCORES}.log 2>&1

    FIM_WC=$(date +%s.%N)
    TEMPO_WC=$(echo "$FIM_WC - $INICIO_WC" | bc)

    MAP_TASKS=$(grep "Launched map tasks" /tmp/wc_vcores_${VCORES}.log | grep -oP "=\K\d+" || echo "0")
    REDUCE_TASKS=$(grep "Launched reduce tasks" /tmp/wc_vcores_${VCORES}.log | grep -oP "=\K\d+" || echo "0")

    VCORES_TOTAL=$((VCORES * 2))

    echo "VCORES=${VCORES}|MAP_TASKS=$MAP_TASKS|REDUCE_TASKS=$REDUCE_TASKS|TEMPO_WC=$TEMPO_WC|VCORES_TOTAL=$VCORES_TOTAL" \
        >> /tmp/vcores_results.txt

    echo "OK - Teste finalizado."
}

rm -f /tmp/vcores_results.txt

echo "Iniciando testes..."
testar_vcores 2
testar_vcores 4
testar_vcores 8

echo "Restaurando padrão (4 vCores)..."
docker cp "$CONFIG_TESTES_DIR/yarn-site-vcores-4.xml" hadoop-master:/opt/hadoop/etc/hadoop/yarn-site.xml
docker cp "$CONFIG_TESTES_DIR/yarn-site-vcores-4.xml" hadoop-slave1:/opt/hadoop/etc/hadoop/yarn-site.xml
docker cp "$CONFIG_TESTES_DIR/yarn-site-vcores-4.xml" hadoop-slave2:/opt/hadoop/etc/hadoop/yarn-site.xml

echo ""
echo "================ RESULTADOS ================="
echo ""

i=1
while IFS='|' read -r line; do
    VC=$(echo "$line" | grep -oP "VCORES=\K\d+")
    MAP=$(echo "$line" | grep -oP "MAP_TASKS=\K\d+")
    RED=$(echo "$line" | grep -oP "REDUCE_TASKS=\K\d+")
    TEMPO=$(echo "$line" | grep -oP "TEMPO_WC=\K[\d\.]+")
    TOTAL=$(echo "$line" | grep -oP "VCORES_TOTAL=\K\d+")

    echo "Resultado $i:"
    echo "vCores por NodeManager: $VC"
    echo "vCores total no cluster: $TOTAL"
    echo "Map tasks: $MAP"
    echo "Reduce tasks: $RED"
    echo "Tempo WordCount: ${TEMPO} s"
    echo ""

    ((i++))
done < /tmp/vcores_results.txt


