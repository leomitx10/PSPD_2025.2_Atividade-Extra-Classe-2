#!/bin/bash

# =============================
#   Verificação inicial
# =============================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASSA_DIR="$SCRIPT_DIR/../massa_de_dados"

if [ ! -f "$MASSA_DIR/massa_unica.txt" ]; then
    echo "ERRO: Dados não encontrados em $MASSA_DIR/massa_unica.txt"
    echo "Execute primeiro: ./gerar_dados.sh"
    exit 1
fi

# Tempo total do script
SCRIPT_START=$(date +%s)

echo -e "\nVerificando se dados já estão no HDFS..."
if docker exec hadoop-master hdfs dfs -test -e /user/root/wordcount_input/massa_unica.txt 2>/dev/null; then
    echo "✅ Dados já presentes no HDFS. Pulando upload."
else
    echo -e "\nCriando diretório de entrada no HDFS..."
    docker exec hadoop-master hdfs dfs -mkdir -p /user/root/wordcount_input

    echo -e "\nEnviando arquivo para o HDFS..."
    docker exec hadoop-master hdfs dfs -put /massa_de_dados/massa_unica.txt /user/root/wordcount_input/
    
    echo -e "\nVerificando arquivos no HDFS..."
    docker exec hadoop-master hdfs dfs -ls /user/root/wordcount_input/
    
    echo -e "\nVerificando uso de espaço..."
    docker exec hadoop-master hdfs dfs -du -h /user/root/wordcount_input/
fi

echo -e "\nLimpando diretório de saída anterior..."
docker exec hadoop-master hdfs dfs -rm -r /user/root/wordcount_output 2>/dev/null || true
sleep 2

# Verificar se foi removido
if docker exec hadoop-master hdfs dfs -test -e /user/root/wordcount_output 2>/dev/null; then
    echo "⚠️  Diretório ainda existe. Forçando remoção..."
    docker exec hadoop-master hdfs dfs -rm -r -skipTrash /user/root/wordcount_output
    sleep 2
fi

# =============================
#      EXECUÇÃO WORDCOUNT
# =============================
echo -e "\nINICIANDO WORDCOUNT"
echo "ResourceManager UI: http://localhost:8088"
echo "NameNode UI:        http://localhost:9870"
echo ""

WC_START=$(date +%s)

docker exec hadoop-master hadoop jar \
    /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar \
    wordcount \
    /user/root/wordcount_input \
    /user/root/wordcount_output

WC_EXIT_CODE=$?
WC_END=$(date +%s)

# Verificar se o job foi executado com sucesso
if [ $WC_EXIT_CODE -ne 0 ]; then
    echo ""
    echo "❌ ERRO: O WordCount falhou com código de saída $WC_EXIT_CODE"
    echo "Verifique os logs acima para mais detalhes."
    exit 1
fi

# =============================
#      TEMPOS CALCULADOS
# =============================
WC_DURATION=$((WC_END - WC_START))
WC_MIN=$((WC_DURATION / 60))
WC_SEC=$((WC_DURATION % 60))

SCRIPT_END=$(date +%s)
TOTAL=$((SCRIPT_END - SCRIPT_START))
TOTAL_MIN=$((TOTAL / 60))
TOTAL_SEC=$((TOTAL % 60))

echo -e "\nWORDCOUNT CONCLUÍDO!"
echo "Tempo WordCount:       ${WC_MIN}m ${WC_SEC}s"
echo "Tempo total do script: ${TOTAL_MIN}m ${TOTAL_SEC}s"

# =============================
#      RESULTADO FINAL
# =============================
echo -e "\nVerificando resultado..."
docker exec hadoop-master hdfs dfs -ls /user/root/wordcount_output/

echo -e "\nTop 20 palavras:"
docker exec hadoop-master bash -c "
    hdfs dfs -cat /user/root/wordcount_output/part-r-00000 |
    sort -t\$'\t' -k2 -nr | head -20
"

echo -e "\nPara ver o resultado completo:"
echo "  docker exec hadoop-master hdfs dfs -cat /user/root/wordcount_output/part-r-00000"
echo ""
