#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"


echo "===== TESTE DE TOLERÂNCIA A FALHAS - HADOOP WORDCOUNT ====="
echo ""

if [ ! -f "$PROJECT_DIR/massa_de_dados/massa_unica.txt" ]; then
    echo "massa_unica.txt não encontrado."
    exit 1
fi

TAMANHO_ARQUIVO=$(du -h "$PROJECT_DIR/massa_de_dados/massa_unica.txt" | cut -f1)

docker ps --format "{{.Names}}\t{{.Status}}" | grep hadoop | column -t
echo ""

docker exec hadoop-master hdfs dfs -rm -r /test_tol_input /test_tol_output >/dev/null 2>&1
docker exec hadoop-master hdfs dfs -mkdir -p /test_tol_input

echo "Enviando arquivo para HDFS..."
docker exec hadoop-master hdfs dfs -put /massa_de_dados/massa_unica.txt /test_tol_input/


echo "Análise de blocos e replicação:"
FSCK_OUTPUT=$(docker exec hadoop-master hdfs fsck /test_tol_input/massa_unica.txt -files -blocks -locations 2>/dev/null)
NUM_BLOCOS=$(echo "$FSCK_OUTPUT" | grep -c "blk_")
REPLICATION=$(docker exec hadoop-master hdfs dfs -stat %r /test_tol_input/massa_unica.txt 2>/dev/null)
echo "   • Número de blocos: $NUM_BLOCOS"
echo "   • Fator de replicação: $REPLICATION"
echo ""

rm -f /tmp/tolerancia_results.txt


docker exec hadoop-master hdfs dfs -rm -r /test_tol_output >/dev/null 2>&1
INI1=$(date +%s.%N)

docker exec hadoop-master bash -c "hadoop jar \
  /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
  wordcount /test_tol_input /test_tol_output > /tmp/tol_t1.log 2>&1"

RES1=$?
FIM1=$(date +%s.%N)
TEMPO1=$(echo "$FIM1 - $INI1" | bc)

docker cp hadoop-master:/tmp/tol_t1.log /tmp/tol_t1.log 2>/dev/null || true
MAP1=$(grep "Launched map tasks" /tmp/tol_t1.log 2>/dev/null | grep -oP "=\K\d+" || echo "N/A")


docker exec hadoop-master hdfs dfs -rm -r /test_tol_output >/dev/null 2>&1
INI2=$(date +%s.%N)

docker exec -d hadoop-master bash -c "hadoop jar \
  /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
  wordcount /test_tol_input /test_tol_output > /tmp/tol_t2.log 2>&1"

sleep 5
docker stop hadoop-slave1 >/dev/null 2>&1

# Aguardar conclusão do job
sleep 60

FIM2=$(date +%s.%N)
TEMPO2=$(echo "$FIM2 - $INI2" | bc)

docker cp hadoop-master:/tmp/tol_t2.log /tmp/tol_t2.log 2>/dev/null || true
MAP2=$(grep "Launched map tasks" /tmp/tol_t2.log 2>/dev/null | grep -oP "=\K\d+" || echo "N/A")
RES2=$(grep -q "completed successfully" /tmp/tol_t2.log 2>/dev/null && echo 0 || echo 1)

docker start hadoop-slave1 >/dev/null 2>&1
sleep 8


docker exec hadoop-master hdfs dfs -rm -r /test_tol_output >/dev/null 2>&1
INI3=$(date +%s.%N)

docker exec -d hadoop-master bash -c "hadoop jar \
  /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
  wordcount /test_tol_input /test_tol_output > /tmp/tol_t3.log 2>&1"

sleep 5
docker stop hadoop-slave1 hadoop-slave2 >/dev/null 2>&1

echo "Aguardando até 4 minutos pela conclusão do WordCount..."
sleep 60

FIM3=$(date +%s.%N)
TEMPO3=$(echo "$FIM3 - $INI3" | bc)

docker cp hadoop-master:/tmp/tol_t3.log /tmp/tol_t3.log 2>/dev/null || true
MAP3=$(grep "Launched map tasks" /tmp/tol_t3.log 2>/dev/null | grep -oP "=\K\d+" || echo "N/A")
RES3=$(grep -q "completed successfully" /tmp/tol_t3.log 2>/dev/null && echo 0 || echo 1)

docker start hadoop-slave1 hadoop-slave2 >/dev/null 2>&1
sleep 10

docker exec hadoop-master hdfs dfs -rm -r /test_tol_input /test_tol_output >/dev/null 2>&1

echo ""
echo "================ RESULTADOS ================="
echo ""

echo "Resultado 1:"
echo "Cenário: Execução normal"
echo "Status: $( [ $RES1 -eq 0 ] && echo SUCESSO || echo FALHA )"
echo "Tempo: ${TEMPO1} s"
echo "Map tasks: $MAP1"
echo ""

echo "Resultado 2:"
echo "Cenário: Falha 1 DataNode"
echo "Status: $( [ $RES2 -eq 0 ] && echo SUCESSO || echo FALHA )"
echo "Tempo: ${TEMPO2} s"
echo "Map tasks: $MAP2"
echo ""

echo "Resultado 3:"
echo "Cenário: Falha 2 DataNodes"
echo "Status: $( [ $RES3 -eq 0 ] && echo SUCESSO || echo FALHA )"
echo "Tempo: ${TEMPO3} s"
echo "Map tasks: $MAP3"
echo ""

