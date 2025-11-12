#!/bin/bash

echo "=========================================="
echo "ANALISADOR DE RESULTADOS DOS TESTES"
echo "=========================================="
echo ""

LOG_BASE="../logs_resiliencia"

if [ ! -d "$LOG_BASE" ]; then
    echo "❌ Diretório de logs não encontrado: $LOG_BASE"
    exit 1
fi

# Função para mostrar testes disponíveis
listar_testes() {
    echo "📁 Testes disponíveis:"
    echo ""
    
    local count=0
    
    # Listar testes de resiliência
    for dir in "$LOG_BASE"/teste_*; do
        if [ -d "$dir" ]; then
            count=$((count + 1))
            local nome=$(basename "$dir")
            local data=$(echo "$nome" | grep -oP '\d{8}_\d{6}')
            local timestamp=$(date -d "${data:0:8} ${data:9:2}:${data:11:2}:${data:13:2}" "+%d/%m/%Y %H:%M:%S" 2>/dev/null || echo "Data desconhecida")
            echo "  [$count] Resiliência - $timestamp"
        fi
    done
    
    # Listar testes de performance
    for dir in "$LOG_BASE"/performance_*; do
        if [ -d "$dir" ]; then
            count=$((count + 1))
            local nome=$(basename "$dir")
            local data=$(echo "$nome" | grep -oP '\d{8}_\d{6}')
            local timestamp=$(date -d "${data:0:8} ${data:9:2}:${data:11:2}:${data:13:2}" "+%d/%m/%Y %H:%M:%S" 2>/dev/null || echo "Data desconhecida")
            echo "  [$count] Performance - $timestamp"
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo "  Nenhum teste encontrado."
        echo ""
        echo "Execute primeiro:"
        echo "  ./testar_resiliencia.sh"
        echo "  ./testar_performance.sh"
    fi
    
    echo ""
}

# Função para analisar teste de resiliência
analisar_resiliencia() {
    local DIR=$1
    
    echo "=========================================="
    echo "ANÁLISE DE TESTE DE RESILIÊNCIA"
    echo "=========================================="
    echo "Diretório: $(basename "$DIR")"
    echo ""
    
    if [ -f "$DIR/resultados.txt" ]; then
        echo "📊 RESULTADOS DOS CENÁRIOS:"
        echo ""
        cat "$DIR/resultados.txt" | while read line; do
            if [[ $line == *"SUCESSO"* ]]; then
                echo "  ✅ $line"
            else
                echo "  ❌ $line"
            fi
        done
        echo ""
        
        # Calcular taxa de sucesso
        local total=$(wc -l < "$DIR/resultados.txt")
        local sucessos=$(grep -c "SUCESSO" "$DIR/resultados.txt")
        local taxa=$((sucessos * 100 / total))
        
        echo "📈 ESTATÍSTICAS:"
        echo "  Total de cenários: $total"
        echo "  Sucessos: $sucessos"
        echo "  Falhas: $((total - sucessos))"
        echo "  Taxa de sucesso: ${taxa}%"
        echo ""
    fi
    
    # Análise de logs
    echo "📝 ANÁLISE DOS LOGS:"
    echo ""
    
    for i in {1..5}; do
        if [ -f "$DIR/wordcount_cenario_${i}.log" ]; then
            local erros=$(grep -ci "error\|exception\|failed" "$DIR/wordcount_cenario_${i}.log" 2>/dev/null || echo "0")
            echo "  Cenário $i: $erros erros/exceções encontrados"
        fi
    done
    echo ""
    
    # Estados capturados
    if ls "$DIR"/containers_*.txt >/dev/null 2>&1; then
        echo "📸 ESTADOS CAPTURADOS:"
        echo ""
        for arquivo in "$DIR"/containers_*.txt; do
            local momento=$(basename "$arquivo" | sed 's/containers_//; s/.txt//')
            echo "  - $momento"
        done
        echo ""
    fi
}

# Função para analisar teste de performance
analisar_performance() {
    local DIR=$1
    
    echo "=========================================="
    echo "ANÁLISE DE TESTE DE PERFORMANCE"
    echo "=========================================="
    echo "Diretório: $(basename "$DIR")"
    echo ""
    
    if [ -f "$DIR/resultados.csv" ]; then
        echo "📊 RESULTADOS:"
        echo ""
        echo "Nodes | Tempo (s) | Tempo (m:s) | Status"
        echo "------|-----------|-------------|--------"
        
        tail -n +2 "$DIR/resultados.csv" | while IFS=, read -r nodes tempo status map reduce; do
            local minutos=$((tempo / 60))
            local segundos=$((tempo % 60))
            printf "%5s | %9s | %11s | %s\n" "$nodes" "$tempo" "${minutos}m ${segundos}s" "$status"
        done
        echo ""
        
        # Calcular speedup
        local tempo_3nodes=$(awk -F, 'NR==2 {print $2}' "$DIR/resultados.csv")
        local tempo_2nodes=$(awk -F, 'NR==3 {print $2}' "$DIR/resultados.csv")
        local tempo_1node=$(awk -F, 'NR==4 {print $2}' "$DIR/resultados.csv")
        
        echo "📈 ANÁLISE DE ESCALABILIDADE:"
        echo ""
        
        if [ -n "$tempo_3nodes" ] && [ -n "$tempo_2nodes" ] && [ "$tempo_2nodes" -gt 0 ]; then
            local speedup=$(awk "BEGIN {printf \"%.2f\", $tempo_2nodes / $tempo_3nodes}")
            local eficiencia=$(awk "BEGIN {printf \"%.1f\", ($tempo_2nodes / $tempo_3nodes) / 1.5 * 100}")
            echo "  3 nodes vs 2 nodes:"
            echo "    Speedup: ${speedup}x"
            echo "    Eficiência: ${eficiencia}%"
            echo ""
        fi
        
        if [ -n "$tempo_3nodes" ] && [ -n "$tempo_1node" ] && [ "$tempo_1node" -gt 0 ]; then
            local speedup=$(awk "BEGIN {printf \"%.2f\", $tempo_1node / $tempo_3nodes}")
            local eficiencia=$(awk "BEGIN {printf \"%.1f\", ($tempo_1node / $tempo_3nodes) / 3 * 100}")
            echo "  3 nodes vs 1 node:"
            echo "    Speedup: ${speedup}x"
            echo "    Eficiência: ${eficiencia}%"
            echo ""
        fi
        
        # Análise de tasks
        echo "📊 DISTRIBUIÇÃO DE TAREFAS:"
        echo ""
        tail -n +2 "$DIR/resultados.csv" | while IFS=, read -r nodes tempo status map reduce; do
            if [ "$map" != "0" ]; then
                echo "  $nodes nodes: Map=$map, Reduce=$reduce"
            fi
        done
        echo ""
    fi
}

# Função para comparar múltiplos testes
comparar_testes() {
    echo "=========================================="
    echo "COMPARAÇÃO DE TESTES DE PERFORMANCE"
    echo "=========================================="
    echo ""
    
    echo "Teste | Data/Hora | 3 nodes | 2 nodes | 1 node | Speedup 3vs1"
    echo "------|-----------|---------|---------|--------|-------------"
    
    local count=1
    for dir in "$LOG_BASE"/performance_*; do
        if [ -d "$dir" ] && [ -f "$dir/resultados.csv" ]; then
            local nome=$(basename "$dir")
            local data=$(echo "$nome" | grep -oP '\d{8}_\d{6}')
            local timestamp=$(date -d "${data:0:8} ${data:9:2}:${data:11:2}:${data:13:2}" "+%d/%m %H:%M" 2>/dev/null || echo "?")
            
            local tempo_3=$(awk -F, 'NR==2 {print $2}' "$dir/resultados.csv")
            local tempo_2=$(awk -F, 'NR==3 {print $2}' "$dir/resultados.csv")
            local tempo_1=$(awk -F, 'NR==4 {print $2}' "$dir/resultados.csv")
            
            local speedup="N/A"
            if [ -n "$tempo_3" ] && [ -n "$tempo_1" ] && [ "$tempo_3" -gt 0 ]; then
                speedup=$(awk "BEGIN {printf \"%.2fx\", $tempo_1 / $tempo_3}")
            fi
            
            printf "%5s | %-10s | %7ss | %7ss | %6ss | %s\n" \
                "$count" "$timestamp" "${tempo_3:-N/A}" "${tempo_2:-N/A}" "${tempo_1:-N/A}" "$speedup"
            
            count=$((count + 1))
        fi
    done
    echo ""
}

# Função para gerar relatório completo
gerar_relatorio() {
    local OUTPUT="$LOG_BASE/relatorio_completo.txt"
    
    echo "Gerando relatório completo..."
    
    {
        echo "=========================================="
        echo "RELATÓRIO COMPLETO DOS TESTES HADOOP"
        echo "=========================================="
        echo "Data: $(date '+%d/%m/%Y %H:%M:%S')"
        echo ""
        
        echo "=========================================="
        echo "TESTES DE RESILIÊNCIA"
        echo "=========================================="
        echo ""
        
        for dir in "$LOG_BASE"/teste_*; do
            if [ -d "$dir" ]; then
                echo "Teste: $(basename "$dir")"
                echo "----------------------------------------"
                if [ -f "$dir/resultados.txt" ]; then
                    cat "$dir/resultados.txt"
                fi
                echo ""
            fi
        done
        
        echo "=========================================="
        echo "TESTES DE PERFORMANCE"
        echo "=========================================="
        echo ""
        
        for dir in "$LOG_BASE"/performance_*; do
            if [ -d "$dir" ]; then
                echo "Teste: $(basename "$dir")"
                echo "----------------------------------------"
                if [ -f "$dir/resultados.csv" ]; then
                    cat "$dir/resultados.csv"
                fi
                echo ""
            fi
        done
        
    } > "$OUTPUT"
    
    echo "✅ Relatório gerado: $OUTPUT"
    echo ""
}

# Menu principal
mostrar_menu() {
    echo "Escolha uma opção:"
    echo ""
    echo "  1) Listar todos os testes"
    echo "  2) Analisar último teste de resiliência"
    echo "  3) Analisar último teste de performance"
    echo "  4) Comparar testes de performance"
    echo "  5) Gerar relatório completo"
    echo "  6) Limpar logs antigos"
    echo "  0) Sair"
    echo ""
}

# Programa principal
if [ $# -eq 0 ]; then
    # Modo interativo
    while true; do
        listar_testes
        mostrar_menu
        read -p "Opção: " opcao
        echo ""
        
        case $opcao in
            1)
                listar_testes
                ;;
            2)
                ULTIMO=$(ls -td "$LOG_BASE"/teste_* 2>/dev/null | head -1)
                if [ -n "$ULTIMO" ]; then
                    analisar_resiliencia "$ULTIMO"
                else
                    echo "❌ Nenhum teste de resiliência encontrado."
                fi
                ;;
            3)
                ULTIMO=$(ls -td "$LOG_BASE"/performance_* 2>/dev/null | head -1)
                if [ -n "$ULTIMO" ]; then
                    analisar_performance "$ULTIMO"
                else
                    echo "❌ Nenhum teste de performance encontrado."
                fi
                ;;
            4)
                comparar_testes
                ;;
            5)
                gerar_relatorio
                ;;
            6)
                read -p "Tem certeza que deseja limpar todos os logs? (s/n): " confirma
                if [ "$confirma" == "s" ]; then
                    rm -rf "$LOG_BASE"/*
                    echo "✅ Logs limpos!"
                else
                    echo "Operação cancelada."
                fi
                ;;
            0)
                echo "Saindo..."
                exit 0
                ;;
            *)
                echo "❌ Opção inválida!"
                ;;
        esac
        
        echo ""
        read -p "Pressione Enter para continuar..."
        clear
    done
else
    # Modo linha de comando
    case $1 in
        listar)
            listar_testes
            ;;
        resiliencia)
            ULTIMO=$(ls -td "$LOG_BASE"/teste_* 2>/dev/null | head -1)
            if [ -n "$ULTIMO" ]; then
                analisar_resiliencia "$ULTIMO"
            fi
            ;;
        performance)
            ULTIMO=$(ls -td "$LOG_BASE"/performance_* 2>/dev/null | head -1)
            if [ -n "$ULTIMO" ]; then
                analisar_performance "$ULTIMO"
            fi
            ;;
        comparar)
            comparar_testes
            ;;
        relatorio)
            gerar_relatorio
            ;;
        *)
            echo "Uso: $0 {listar|resiliencia|performance|comparar|relatorio}"
            exit 1
            ;;
    esac
fi
