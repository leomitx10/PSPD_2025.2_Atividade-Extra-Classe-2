#!/bin/bash

echo "=========================================="
echo "BUILD DO WORDCOUNT - HADOOP MAPREDUCE"
echo "=========================================="
echo ""

# Verificar se Maven está instalado
if ! command -v mvn &> /dev/null; then
    echo "ERRO: Maven não está instalado!"
    echo "Instale com: sudo apt-get install maven"
    exit 1
fi

echo "Maven encontrado:"
mvn --version
echo ""

echo "Passo 1: Limpando builds anteriores..."
mvn clean
echo ""

echo "Passo 2: Compilando código Java..."
echo ""
mvn compile
if [ $? -ne 0 ]; then
    echo ""
    echo "ERRO: Falha na compilação!"
    exit 1
fi

echo ""
echo "Passo 3: Empacotando JAR..."
echo ""
mvn package -DskipTests
if [ $? -ne 0 ]; then
    echo ""
    echo "ERRO: Falha no empacotamento!"
    exit 1
fi

echo ""
echo "=========================================="
echo "BUILD CONCLUÍDO COM SUCESSO!"
echo "=========================================="
echo ""

# Verificar se o JAR foi gerado
if [ -f "target/wordcount.jar" ]; then
    JAR_SIZE=$(du -h target/wordcount.jar | cut -f1)
    echo "JAR gerado:"
    echo "  Local: target/wordcount.jar"
    echo "  Tamanho: $JAR_SIZE"
    echo ""

    echo "Para usar o JAR no cluster Hadoop:"
    echo "  1. Copiar para o container:"
    echo "     docker cp target/wordcount.jar hadoop-master:/opt/hadoop/"
    echo ""
    echo "  2. Executar no Hadoop:"
    echo "     docker exec hadoop-master hadoop jar /opt/hadoop/wordcount.jar \\"
    echo "       br.unb.cic.pspd.wordcount.WordCountDriver \\"
    echo "       /user/root/wordcount_input \\"
    echo "       /user/root/wordcount_output_custom"
    echo ""
else
    echo "ERRO: JAR não foi gerado em target/wordcount.jar"
    exit 1
fi

echo "=========================================="
