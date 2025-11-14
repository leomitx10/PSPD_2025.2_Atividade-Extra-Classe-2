#!/bin/bash

PALAVRAS=(hadoop mapreduce yarn hdfs datanode namenode distributed computing big data processing cluster parallel framework apache java)

mkdir -p /tmp/hadoop_input

gera_linhas() {
    local count=$1
    local repeticoes=5000  # tamanho do bloco
    for ((k=0; k<count; k+=repeticoes)); do
        linha=""
        for ((j=0;j<15;j++)); do
            linha+=" ${PALAVRAS[$RANDOM % ${#PALAVRAS[@]}]}"
        done
        yes "$linha" | head -n $repeticoes
    done
}

for i in {1..70}; do
    echo "Gerando arquivo $i..."
    gera_linhas 1000000 > "/tmp/hadoop_input/livro_${i}.txt"
done
