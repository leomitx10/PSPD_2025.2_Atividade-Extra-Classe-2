#!/bin/bash


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_TESTES_DIR="$PROJECT_DIR/config_testes"

echo "===== TESTE DE FATOR DE REPLICACAO HDFS ===== "
echo ""

if ! docker ps | grep -q hadoop-master; then
    echo "Iniciando containers..."
    cd "$PROJECT_DIR"
    docker-compose up -d
    sleep 30
fi

if [ ! -f "$PROJECT_DIR/massa_de_dados/massa_unica.txt" ]; then
    echo "ERRO: Arquivo massa_unica.txt não encontrado."
    exit 1
fi

TAMANHO_ARQUIVO=$(du -h "$PROJECT_DIR/massa_de_dados/massa_unica.txt" | cut -f1)
echo "Arquivo de teste: massa_unica.txt ($TAMANHO_ARQUIVO)"
echo ""

testar_replicacao() {
    local REPLICACAO=$1
    local CONFIG_FILE="hdfs-site-replication-${REPLICACAO}.xml"

    echo "-----------------------------------------------"
    echo "TESTE COM REPLICACAO = $REPLICACAO"
    echo "-----------------------------------------------"

    docker exec hadoop-master cp /opt/hadoop/etc/hadoop/hdfs-site.xml /opt/hadoop/etc/hadoop/hdfs-site.xml.backup 2>/dev/null || true

    docker cp "$CONFIG_TESTES_DIR/$CONFIG_FILE" hadoop-master:/opt/hadoop/etc/hadoop/hdfs-site.xml
    docker cp "$CONFIG_TESTES_DIR/$CONFIG_FILE" hadoop-slave1:/opt/hadoop/etc/hadoop/hdfs-site.xml
    docker cp "$CONFIG_TESTES_DIR/$CONFIG_FILE" hadoop-slave2:/opt/hadoop/etc/hadoop/hdfs-site.xml

    docker exec hadoop-master bash -c "$HADOOP_HOME/sbin/stop-dfs.sh" >/dev/null 2>&1
    sleep 3
    docker exec hadoop-master bash -c "$HADOOP_HOME/sbin/start-dfs.sh" >/dev/null 2>&1
    sleep 10

    docker exec hadoop-master hdfs dfs -rm -r /test_replication 2>/dev/null || true
    docker exec hadoop-master hdfs dfs -mkdir -p /test_replication

    INICIO_UPLOAD=$(date +%s.%N)
    docker exec hadoop-master hdfs dfs -put /massa_de_dados/massa_unica.txt /test_replication/
    FIM_UPLOAD=$(date +%s.%N)
    TEMPO_UPLOAD=$(echo "$FIM_UPLOAD - $INICIO_UPLOAD" | bc)

    sleep 2

    REPL_EFETIVO=$(docker exec hadoop-master hdfs fsck /test_replication/massa_unica.txt -files -blocks -locations 2>/dev/null | grep -oP "replication factor\s+\K\d+" || echo $REPLICACAO)

    ESPACO_USADO=$(docker exec hadoop-master hdfs dfs -du -h /test_replication/massa_unica.txt | awk '{print $1" "$2}')
    ESPACO_TOTAL=$(docker exec hadoop-master hdfs dfs -du -h /test_replication/massa_unica.txt | awk '{print $3" "$4}')

    INICIO_LEITURA=$(date +%s.%N)
    docker exec hadoop-master hdfs dfs -cat /test_replication/massa_unica.txt > /dev/null 2>&1
    FIM_LEITURA=$(date +%s.%N)
    TEMPO_LEITURA=$(echo "$FIM_LEITURA - $INICIO_LEITURA" | bc)

    NUM_DATANODES=$(docker exec hadoop-master hdfs dfsadmin -report 2>/dev/null | grep -c "^Name:" || echo "0")

    echo "REPLICACAO=$REPLICACAO|UPLOAD=$TEMPO_UPLOAD|LEITURA=$TEMPO_LEITURA|ESPACO_USADO=$ESPACO_USADO|ESPACO_TOTAL=$ESPACO_TOTAL|DATANODES=$NUM_DATANODES" >> /tmp/replication_results.txt

    #docker exec hadoop-master hdfs dfs -rm -r /test_replication >/dev/null 2>&1
}

rm -f /tmp/replication_results.txt

echo "Iniciando testes de replicação..."
echo ""

testar_replicacao 1
sleep 2
testar_replicacao 2
sleep 2
testar_replicacao 3

echo ""
echo "Restaurando replicacao padrao (2)..."
docker cp "$CONFIG_TESTES_DIR/hdfs-site-replication-2.xml" hadoop-master:/opt/hadoop/etc/hadoop/hdfs-site.xml
docker cp "$CONFIG_TESTES_DIR/hdfs-site-replication-2.xml" hadoop-slave1:/opt/hadoop/etc/hadoop/hdfs-site.xml
docker cp "$CONFIG_TESTES_DIR/hdfs-site-replication-2.xml" hadoop-slave2:/opt/hadoop/etc/hadoop/hdfs-site.xml
docker exec hadoop-master bash -c "$HADOOP_HOME/sbin/stop-dfs.sh" >/dev/null 2>&1
sleep 3
docker exec hadoop-master bash -c "$HADOOP_HOME/sbin/start-dfs.sh" >/dev/null 2>&1

echo ""
echo "==================== RESULTADOS ===================="

i=1
while IFS='|' read -r line; do
    REPL=$(echo "$line" | grep -oP "REPLICACAO=\K\d+")
    UP=$(echo "$line" | grep -oP "UPLOAD=\K[\d.]+")
    LEI=$(echo "$line" | grep -oP "LEITURA=\K[\d.]+")
    ESP=$(echo "$line" | grep -oP "ESPACO_TOTAL=\K.*")

    echo "Resultado $i:"
    echo "Replicacao: $REPL"
    echo "Tempo de upload: $UP s"
    echo "Tempo de leitura: $LEI s"
    echo "Espaco total: $ESP"
    echo ""
    i=$((i+1))

done < /tmp/replication_results.txt
