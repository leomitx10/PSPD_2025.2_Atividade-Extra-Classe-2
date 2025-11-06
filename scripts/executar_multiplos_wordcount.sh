#!/bin/bash

echo "=========================================="
echo "EXECUTAR MÚLTIPLOS WORDCOUNTS SIMULTÂNEOS"
echo "=========================================="
echo ""

if [ ! -d "/tmp/hadoop_input" ]; then
    echo "ERRO: Dados não encontrados!"
    echo "Execute primeiro: ./gerar_dados.sh"
    exit 1
fi

NUM_JOBS=${1:-3}  

echo "Configuração:"
echo "  - Número de jobs simultâneos: $NUM_JOBS"
echo "  - Dados de entrada: /tmp/hadoop_input/"
echo ""

echo "Preparando HDFS..."
docker exec hadoop-master hdfs dfs -mkdir -p /user/root/wordcount_input
docker exec hadoop-master hdfs dfs -rm -r -f /user/root/wordcount_input/* 2>/dev/null

echo "Verificando dados no HDFS..."
HDFS_COUNT=$(docker exec hadoop-master hdfs dfs -ls /user/root/wordcount_input/ 2>/dev/null | grep -c ".txt" || echo "0")

if [ "$HDFS_COUNT" -eq "0" ]; then
    echo "Copiando dados para HDFS..."
    for arquivo in /tmp/hadoop_input/*.txt; do
        nome_arquivo=$(basename "$arquivo")
        docker cp "$arquivo" hadoop-master:/tmp/
    done
    docker exec hadoop-master bash -c "hdfs dfs -put /tmp/*.txt /user/root/wordcount_input/"
fi

echo ""
echo "=========================================="
echo "INICIANDO $NUM_JOBS JOBS SIMULTÂNEOS"
echo "=========================================="
echo ""
echo "Monitoramento disponível em:"
echo "  ResourceManager UI: http://localhost:8088/cluster/apps"
echo "  NameNode UI: http://localhost:9870"
echo ""
echo "Use outro terminal para monitorar:"
echo "  ./monitorar_jobs.sh"
echo ""

declare -a PIDS

for i in $(seq 1 $NUM_JOBS); do
    echo "🚀 Iniciando Job $i de $NUM_JOBS..."
    
    docker exec hadoop-master hdfs dfs -rm -r -f /user/root/wordcount_output_${i} 2>/dev/null
    
    docker exec hadoop-master bash -c "
        echo '=== JOB $i INICIADO ===' && \
        hadoop jar \$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
            wordcount \
            /user/root/wordcount_input \
            /user/root/wordcount_output_${i} && \
        echo '=== JOB $i CONCLUÍDO ==='
    " > /tmp/wordcount_job_${i}.log 2>&1 &
    
    PIDS[$i]=$!
    echo "   Job $i iniciado (PID: ${PIDS[$i]})"
    
    sleep 2
done

echo ""
echo "=========================================="
echo "TODOS OS JOBS FORAM INICIADOS"
echo "=========================================="
echo ""
echo "Aguardando conclusão dos jobs..."
echo "Isso pode levar 3-5 minutos por job"
echo ""

START_TIME=$(date +%s)

for i in $(seq 1 $NUM_JOBS); do
    echo "⏳ Aguardando Job $i (PID: ${PIDS[$i]})..."
    wait ${PIDS[$i]}
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo "Job $i concluído com sucesso!"
    else
        echo "Job $i falhou (código: $EXIT_CODE)"
    fi
    
    echo "   Log resumido:"
    tail -5 /tmp/wordcount_job_${i}.log | sed 's/^/   /'
    echo ""
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "=========================================="
echo "TODOS OS JOBS CONCLUÍDOS!"
echo "=========================================="
echo "Tempo total de execução: ${MINUTES}m ${SECONDS}s"
echo ""

echo "Resultados disponíveis em:"
for i in $(seq 1 $NUM_JOBS); do
    echo "  Job $i: /user/root/wordcount_output_${i}"
done
echo ""

echo "Para ver top 10 palavras do Job 1:"
echo "  docker exec hadoop-master hdfs dfs -cat /user/root/wordcount_output_1/part-r-00000 | sort -t\$'\\t' -k2 -nr | head -10"
echo ""

echo "Para ver estatísticas dos jobs:"
echo "  docker exec hadoop-master yarn application -list -appStates ALL | tail -$((NUM_JOBS + 1))"
echo "=========================================="
