#!/bin/bash

PALAVRAS=(hadoop mapreduce yarn hdfs datanode namenode distributed computing big data processing cluster parallel framework apache java)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASSA_DIR="$SCRIPT_DIR/../massa_de_dados"

mkdir -p "$MASSA_DIR"

OUTPUT="$MASSA_DIR/massa_unica.txt"

> "$OUTPUT"

gera_linhas() {
    local count=$1
    local repeticoes=5000 
    for ((k=0; k<count; k+=repeticoes)); do
        linha=""
        for ((j=0;j<15;j++)); do
            linha+=" ${PALAVRAS[$RANDOM % ${#PALAVRAS[@]}]}"
        done
        yes "$linha" | head -n $repeticoes
    done
}

TOTAL_LINHAS=$((4000000))

gera_linhas "$TOTAL_LINHAS" >> "$OUTPUT"

echo "Arquivo gerado em: $OUTPUT"

echo "Tamanho do arquivo:"
du -h "$OUTPUT"
