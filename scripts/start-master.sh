#!/bin/bash

echo "Iniciando serviços do Hadoop Master..."

service ssh start

if [ ! -d "/hadoop/dfs/name/current" ]; then
    $HADOOP_HOME/bin/hdfs namenode -format -force
fi

$HADOOP_HOME/sbin/start-dfs.sh

sleep 10

$HADOOP_HOME/sbin/start-yarn.sh

sleep 5

echo ""
echo "Serviços em execução:"
jps

echo ""
echo "Master iniciado com sucesso!"
echo "NameNode: http://$(hostname -i):9870"
echo "ResourceManager: http://$(hostname -i):8088"

tail -f /dev/null