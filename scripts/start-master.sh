#!/bin/bash

service ssh start

if [ ! -d "/hadoop/dfs/name/current" ]; then
    echo "Formatando o NameNode..."
    hdfs namenode -format -force
fi

$HADOOP_HOME/sbin/start-dfs.sh

$HADOOP_HOME/sbin/start-yarn.sh

echo "Hadoop Master iniciado!"
echo "NameNode UI: http://localhost:9870"
echo "ResourceManager UI: http://localhost:8088"

tail -f /dev/null
