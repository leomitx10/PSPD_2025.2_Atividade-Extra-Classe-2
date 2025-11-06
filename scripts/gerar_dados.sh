#!/bin/bash

echo "=========================================="
echo "GERADOR DE DADOS PARA WORDCOUNT"
echo "=========================================="
echo ""

PALAVRAS=(
    "hadoop" "mapreduce" "yarn" "hdfs" "datanode" "namenode" 
    "distributed" "computing" "big" "data" "processing" "cluster"
    "parallel" "framework" "apache" "java" "streaming" "job"
    "task" "container" "resource" "manager" "node" "slave" "master"
    "replication" "block" "filesystem" "scalable" "fault" "tolerant"
    "analytics" "batch" "realtime" "spark" "hive" "pig" "hbase"
    "ecosystem" "storage" "compute" "memory" "cpu" "disk" "network"
    "performance" "optimization" "tuning" "configuration" "monitoring"
    "deployment" "docker" "container" "orchestration" "kubernetes"
    "cloud" "aws" "azure" "gcp" "onpremise" "hybrid" "infrastructure"
    "database" "nosql" "sql" "query" "index" "search" "aggregation"
    "pipeline" "workflow" "scheduling" "coordinator" "oozie" "airflow"
    "security" "authentication" "authorization" "encryption" "kerberos"
    "compression" "codec" "snappy" "gzip" "lzo" "bzip2" "parquet"
    "avro" "orc" "json" "xml" "csv" "format" "schema" "metadata"
)

gerar_linha() {
    local num_palavras=$((10 + RANDOM % 20)) 
    local linha=""
    for ((i=0; i<num_palavras; i++)); do
        local idx=$((RANDOM % ${#PALAVRAS[@]}))
        linha="$linha ${PALAVRAS[$idx]}"
    done
    echo "$linha"
}

mkdir -p /tmp/hadoop_input

echo "Gerando arquivos de texto..."
echo "Isso pode levar alguns minutos..."
echo ""

for arquivo_num in {1..10}; do
    arquivo="/tmp/hadoop_input/livro_${arquivo_num}.txt"
    echo "Gerando arquivo ${arquivo_num}/10: ${arquivo}"
    
    for ((linha=1; linha<=500000; linha++)); do
        gerar_linha >> "$arquivo"
        
        if [ $((linha % 50000)) -eq 0 ]; then
            echo "  Progresso: ${linha}/500000 linhas"
        fi
    done
    
    echo "  Arquivo ${arquivo_num} concluído: $(du -h $arquivo | cut -f1)"
    echo ""
done

echo "=========================================="
echo "RESUMO DOS ARQUIVOS GERADOS"
echo "=========================================="
ls -lh /tmp/hadoop_input/
echo ""
echo "Tamanho total:"
du -sh /tmp/hadoop_input/
echo ""
echo "Arquivos prontos para upload no HDFS!"
echo "=========================================="
