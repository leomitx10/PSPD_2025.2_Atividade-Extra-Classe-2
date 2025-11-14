#!/bin/bash

# Script para monitorar job YARN ativo em tempo real

echo "🔍 Monitorando jobs ativos no YARN..."
echo ""

# Função para limpar a tela e mostrar progresso
monitorar() {
    while true; do
        clear
        echo "=========================================="
        echo "MONITOR DE JOBS YARN - $(date '+%H:%M:%S')"
        echo "=========================================="
        echo ""
        
        # Listar aplicações em execução
        echo "📊 APLICAÇÕES ATIVAS:"
        echo ""
        sudo docker exec hadoop-master yarn application -list 2>/dev/null | grep -A 100 "Application-Id"
        
        echo ""
        echo "=========================================="
        echo "DETALHES DO JOB MAIS RECENTE:"
        echo "=========================================="
        echo ""
        
        # Pegar ID da aplicação mais recente
        APP_ID=$(sudo docker exec hadoop-master yarn application -list 2>/dev/null | grep "application_" | tail -1 | awk '{print $1}')
        
        if [ -n "$APP_ID" ]; then
            echo "📌 Job ID: $APP_ID"
            echo ""
            
            # Mostrar status detalhado
            sudo docker exec hadoop-master yarn application -status "$APP_ID" 2>/dev/null | grep -E "(Application Name|State|Progress|Start-Time|Elapsed|Tracking)"
            
            echo ""
            echo "=========================================="
            echo "RECURSOS DO CLUSTER:"
            echo "=========================================="
            echo ""
            
            # Status dos nodes
            echo "🖥️  Nodes ativos:"
            sudo docker ps --filter "name=hadoop" --format "  - {{.Names}} ({{.Status}})"
            
            echo ""
            echo "💾 HDFS:"
            sudo docker exec hadoop-master hdfs dfsadmin -report 2>/dev/null | grep -E "(Live datanodes|DFS Used%|DFS Remaining%)" | head -5
            
        else
            echo "ℹ️  Nenhum job em execução no momento."
        fi
        
        echo ""
        echo "=========================================="
        echo "Pressione Ctrl+C para sair"
        echo "Atualizando a cada 5 segundos..."
        echo "=========================================="
        
        sleep 5
    done
}

# Iniciar monitoramento
monitorar
