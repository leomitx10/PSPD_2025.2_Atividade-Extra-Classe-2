#!/bin/bash

PALAVRAS=(hadoop mapreduce yarn hdfs datanode namenode distributed computing big data processing cluster parallel framework apache java)

# Diretório onde os dados serão gerados (fora do Docker)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASSA_DIR="$SCRIPT_DIR/../massa_de_dados"

mkdir -p "$MASSA_DIR"

OUTPUT="$MASSA_DIR/massa_unica.txt"

# Limpa o arquivo caso já exista
> "$OUTPUT"

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

# Se quiser gerar o equivalente aos 70 arquivos, multiplique o total de linhas por 70
TOTAL_LINHAS=$((1000000))

echo "Gerando massa de dados única..."

# Gera e adiciona ao arquivo final
gera_linhas "$TOTAL_LINHAS" >> "$OUTPUT"

echo "Arquivo gerado em: $OUTPUT"
