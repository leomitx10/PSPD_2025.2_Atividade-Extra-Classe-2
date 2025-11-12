#!/bin/bash

echo "Iniciando serviços do Hadoop Master..."

# Iniciar SSH
service ssh start

# Formatar NameNode (apenas na primeira execução)
if [ ! -d "/hadoop/dfs/name/current" ]; then
    echo "Formatando NameNode..."
    $HADOOP_HOME/bin/hdfs namenode -format -force
fi

# Iniciar HDFS
echo "Iniciando HDFS..."
$HADOOP_HOME/sbin/start-dfs.sh

# Aguardar HDFS iniciar
sleep 10

# Iniciar YARN
echo "Iniciando YARN..."
$HADOOP_HOME/sbin/start-yarn.sh

# Aguardar YARN iniciar
sleep 5

# Mostrar processos Java em execução
echo ""
echo "Serviços em execução:"
jps

echo ""
echo "Master iniciado com sucesso!"
echo "NameNode: http://$(hostname -i):9870"
echo "ResourceManager: http://$(hostname -i):8088"

# Manter container rodando
tail -f /dev/null
