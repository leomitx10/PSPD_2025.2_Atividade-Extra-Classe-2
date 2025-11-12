#!/bin/bash

echo "=========================================="
echo "MONITORAMENTO DE JOBS HADOOP"
echo "=========================================="
echo ""

# Função para obter status dos containers
mostrar_status_containers() {
    echo "📦 Status dos Containers:"
    docker ps --filter "name=hadoop" --format "table {{.Names}}\t{{.Status}}" | sed 's/^/  /'
    echo ""
}

# Função para obter jobs ativos
mostrar_jobs_ativos() {
    echo "🔄 Jobs em Execução:"
    JOBS=$(docker exec hadoop-master yarn application -list -appStates RUNNING 2>/dev/null | tail -n +3)
    
    if [ -z "$JOBS" ]; then
        echo "  Nenhum job em execução"
    else
        echo "$JOBS" | awk '{print "  - "$2" ("$6")"}' 2>/dev/null || echo "  Nenhum job em execução"
    fi
    echo ""
}

# Função para obter recursos do cluster
mostrar_recursos() {
    echo "💾 Recursos do Cluster:"
    NODES=$(docker exec hadoop-master yarn node -list -all 2>/dev/null | tail -n +3)
    
    if [ -z "$NODES" ]; then
        echo "  ⚠️  Nenhum node disponível"
    else
        echo "$NODES" | while read line; do
            NODE_ID=$(echo "$line" | awk '{print $1}')
            NODE_STATE=$(echo "$line" | awk '{print $2}')
            echo "  - $NODE_ID [$NODE_STATE]"
        done
    fi
    echo ""
}

# Função para obter estatísticas do HDFS
mostrar_hdfs() {
    echo "📊 HDFS Status:"
    HDFS_REPORT=$(docker exec hadoop-master hdfs dfsadmin -report 2>/dev/null | grep -E "Live datanodes|Configured Capacity|DFS Used|DFS Remaining")
    echo "$HDFS_REPORT" | sed 's/^/  /'
    echo ""
}

# Função para obter processos JVM
mostrar_processos() {
    echo "☕ Processos Java (Master):"
    docker exec hadoop-master jps 2>/dev/null | grep -v "Jps" | sed 's/^/  /'
    echo ""
}

# Verificar se foi passado argumento para modo contínuo
MODO_CONTINUO=false
INTERVALO=5

if [ "$1" == "-c" ] || [ "$1" == "--continuo" ]; then
    MODO_CONTINUO=true
    if [ -n "$2" ]; then
        INTERVALO=$2
    fi
fi

if [ "$MODO_CONTINUO" == true ]; then
    echo "Modo contínuo ativado (atualização a cada ${INTERVALO}s)"
    echo "Pressione Ctrl+C para sair"
    echo ""
    
    while true; do
        clear
        echo "=========================================="
        echo "MONITORAMENTO CONTÍNUO - $(date '+%H:%M:%S')"
        echo "=========================================="
        echo ""
        
        mostrar_status_containers
        mostrar_jobs_ativos
        mostrar_recursos
        mostrar_hdfs
        mostrar_processos
        
        echo "Interfaces Web:"
        echo "  ResourceManager: http://localhost:8088/cluster"
        echo "  NameNode: http://localhost:9870"
        echo ""
        echo "Próxima atualização em ${INTERVALO}s..."
        
        sleep $INTERVALO
    done
else
    # Modo único (snapshot)
    mostrar_status_containers
    mostrar_jobs_ativos
    mostrar_recursos
    mostrar_hdfs
    mostrar_processos
    
    echo "=========================================="
    echo "Interfaces Web:"
    echo "  ResourceManager: http://localhost:8088/cluster"
    echo "  NameNode: http://localhost:9870"
    echo ""
    echo "Para monitoramento contínuo:"
    echo "  ./monitorar_jobs.sh -c [intervalo_segundos]"
    echo "=========================================="
fi
