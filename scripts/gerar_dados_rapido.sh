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

# Versão mais rápida: 30 arquivos equivalentes ao invés de 80
# Isso mantém o job rodando por tempo suficiente (2-3 min) para os testes
TOTAL_LINHAS=$((1000000 * 30))

echo "Gerando massa de dados rápida para testes (~30 arquivos equivalentes)..."
echo "Tempo estimado: 30-60 segundos"

# Gera e adiciona ao arquivo final
gera_linhas "$TOTAL_LINHAS" >> "$OUTPUT"

TAMANHO=$(du -h "$OUTPUT" | cut -f1)
echo "✅ Arquivo gerado em: $OUTPUT"
echo "📦 Tamanho: $TAMANHO"
echo ""
echo "⚡ Essa versão é mais rápida mas mantém os jobs com duração razoável para testes"
echo "💡 Para testes de performance completos, use: ./gerar_dados.sh"
