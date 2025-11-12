#!/bin/bash

echo "=========================================="
echo "EXECUTAR WORDCOUNT NO HADOOP"
echo "=========================================="
echo ""

if [ ! -d "/tmp/hadoop_input" ]; then
    echo "ERRO: Dados não encontrados!"
    echo "Execute primeiro: ./gerar_dados.sh"
    exit 1
fi

echo "Passo 1: Removendo diretórios antigos no HDFS..."
docker exec hadoop-master hdfs dfs -rm -r -f /user/root/wordcount_input 2>/dev/null
docker exec hadoop-master hdfs dfs -rm -r -f /user/root/wordcount_output 2>/dev/null
echo ""

echo "Passo 2: Criando diretório de entrada no HDFS..."
docker exec hadoop-master hdfs dfs -mkdir -p /user/root/wordcount_input
echo ""

echo "Passo 3: Copiando arquivos para o container..."
for arquivo in /tmp/hadoop_input/*.txt; do
    nome_arquivo=$(basename "$arquivo")
    echo "  Copiando $nome_arquivo..."
    docker cp "$arquivo" hadoop-master:/tmp/
done
echo ""

echo "Passo 4: Fazendo upload dos arquivos para o HDFS..."
docker exec hadoop-master bash -c "hdfs dfs -put /tmp/*.txt /user/root/wordcount_input/"
echo ""

echo "Passo 5: Verificando arquivos no HDFS..."
docker exec hadoop-master hdfs dfs -ls /user/root/wordcount_input/
echo ""

echo "Passo 6: Verificando espaço HDFS usado..."
docker exec hadoop-master hdfs dfs -du -h /user/root/wordcount_input/
echo ""

echo "=========================================="
echo "INICIANDO WORDCOUNT"
echo "=========================================="
echo ""
echo "Monitoramento disponível em:"
echo "  ResourceManager UI: http://localhost:8088"
echo "  NameNode UI: http://localhost:9870"
echo ""
echo "Tempo estimado: 3-5 minutos"
echo ""
echo "Iniciando job..."
echo ""

START_TIME=$(date +%s)

docker exec hadoop-master hadoop jar \
    /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
    wordcount \
    /user/root/wordcount_input \
    /user/root/wordcount_output

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "=========================================="
echo "WORDCOUNT CONCLUÍDO!"
echo "=========================================="
echo "Tempo de execução: ${MINUTES}m ${SECONDS}s"
echo ""

echo "Passo 7: Verificando resultado..."
docker exec hadoop-master hdfs dfs -ls /user/root/wordcount_output/
echo ""

echo "Passo 8: Top 20 palavras mais frequentes:"
docker exec hadoop-master hdfs dfs -cat /user/root/wordcount_output/part-r-00000 | \
    sort -t$'\t' -k2 -nr | head -20
echo ""

echo "=========================================="
echo "Para ver resultado completo:"
echo "  docker exec hadoop-master hdfs dfs -cat /user/root/wordcount_output/part-r-00000"
echo "=========================================="
