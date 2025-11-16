#!/bin/bash

service ssh start

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

echo "Iniciando DataNode..."
$HADOOP_HOME/bin/hdfs --daemon start datanode

sleep 5

echo "Iniciando NodeManager..."
$HADOOP_HOME/bin/yarn --daemon start nodemanager

sleep 5

echo ""
echo "Serviços em execução:"
jps

echo ""
echo "Slave iniciado com sucesso!"

tail -f /dev/null