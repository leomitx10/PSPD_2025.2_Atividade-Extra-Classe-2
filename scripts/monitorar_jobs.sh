#!/bin/bash

status_containers() {
    echo "Containers:"
    docker ps --filter "name=hadoop" --format "{{.Names}} - {{.Status}}"
    echo
}

jobs_ativos() {
    echo "Jobs:"
    JOBS=$(docker exec hadoop-master yarn application -list -appStates RUNNING 2>/dev/null | tail -n +3)
    [ -z "$JOBS" ] && echo "Nenhum job" || echo "$JOBS" | awk '{print "- "$2" ("$6")"}'
    echo
}

recursos() {
    echo "Recursos:"
    NODES=$(docker exec hadoop-master yarn node -list -all 2>/dev/null | tail -n +3)
    [ -z "$NODES" ] && echo "Nenhum node" || echo "$NODES" | awk '{print "- "$1" ["$2"]"}'
    echo
}

hdfs() {
    echo "HDFS:"
    docker exec hadoop-master hdfs dfsadmin -report 2>/dev/null | grep -E "Live datanodes|Configured Capacity|DFS Used|DFS Remaining"
    echo
}

processos() {
    echo "JVM:"
    docker exec hadoop-master jps 2>/dev/null | grep -v Jps
    echo
}

INTERVALO=${2:-5}
CONTINUO=false
[ "$1" = "-c" ] || [ "$1" = "--continuo" ] && CONTINUO=true

if $CONTINUO; then
    echo "Modo contínuo (${INTERVALO}s). Ctrl+C para parar."
    sleep 1
    while true; do
        clear
        echo "=== $(date '+%H:%M:%S') ==="
        status_containers
        jobs_ativos
        recursos
        hdfs
        processos
        echo "ResourceManager: http://localhost:8088/cluster"
        echo "NameNode: http://localhost:9870"
        echo "Atualiza em ${INTERVALO}s..."
        sleep $INTERVALO
    done
else
    status_containers
    jobs_ativos
    recursos
    hdfs
    processos
    echo "ResourceManager: http://localhost:8088/cluster"
    echo "NameNode: http://localhost:9870"
    echo "Modo contínuo: ./monitorar_jobs.sh -c [segundos]"
fi
