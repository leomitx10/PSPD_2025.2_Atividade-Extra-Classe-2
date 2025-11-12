#!/bin/bash

echo "Iniciando serviços do Hadoop Slave..."

# Iniciar SSH
service ssh start

# Aguardar master estar disponível
echo "Aguardando master estar disponível..."
sleep 15
echo "Aguardando HDFS estar pronto..."
for i in {1..20}; do
    if $HADOOP_HOME/bin/hdfs dfs -ls / >/dev/null 2>&1; then
        echo "Master detectado e HDFS pronto!"
        break
    fi
    echo "Tentativa $i/20..."
    sleep 3
done

# Iniciar DataNode
echo "Iniciando DataNode..."
$HADOOP_HOME/bin/hdfs --daemon start datanode

# Aguardar DataNode iniciar
sleep 5

# Iniciar NodeManager
echo "Iniciando NodeManager..."
$HADOOP_HOME/bin/yarn --daemon start nodemanager

# Aguardar NodeManager iniciar
sleep 5

# Mostrar processos Java em execução
echo ""
echo "Serviços em execução:"
jps

echo ""
echo "Slave iniciado com sucesso!"

# Manter container rodando
tail -f /dev/null
