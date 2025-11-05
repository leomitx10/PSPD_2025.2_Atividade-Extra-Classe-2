#!/bin/bash

echo "=========================================="
echo "VERIFICAÇÃO DAS 5 ALTERAÇÕES DE PARÂMETROS"
echo "=========================================="
echo ""

echo "1. TAMANHO DE BLOCO HDFS (Alteração 1)"
echo "   Esperado: 67108864 bytes (64 MB)"
echo "   Atual:"
docker exec hadoop-master hdfs getconf -confKey dfs.blocksize
echo ""

echo "2. MEMÓRIA DO NODEMANAGER (Alteração 2)"
echo "   Esperado: 4096 MB"
echo "   Atual:"
docker exec hadoop-master bash -c "cat \$HADOOP_HOME/etc/hadoop/yarn-site.xml | grep -A 1 'yarn.nodemanager.resource.memory-mb' | grep '<value>' | sed 's/<[^>]*>//g' | xargs"
echo ""

echo "3. CPU VCORES DO NODEMANAGER (Alteração 3)"
echo "   Esperado: 4 vcores"
echo "   Atual:"
docker exec hadoop-master bash -c "cat \$HADOOP_HOME/etc/hadoop/yarn-site.xml | grep -A 1 'yarn.nodemanager.resource.cpu-vcores' | grep '<value>' | sed 's/<[^>]*>//g' | xargs"
echo ""

echo "4. LIMITES DO SCHEDULER YARN (Alteração 4)"
echo "   Mínimo esperado: 512 MB"
echo "   Máximo esperado: 4096 MB"
echo "   Atual:"
docker exec hadoop-master bash -c "cat \$HADOOP_HOME/etc/hadoop/yarn-site.xml | grep -A 1 'yarn.scheduler.minimum-allocation-mb' | grep '<value>' | sed 's/<[^>]*>//g' | xargs"
docker exec hadoop-master bash -c "cat \$HADOOP_HOME/etc/hadoop/yarn-site.xml | grep -A 1 'yarn.scheduler.maximum-allocation-mb' | grep '<value>' | sed 's/<[^>]*>//g' | xargs"
echo ""

echo "5. RECURSOS MAP/REDUCE (Alteração 5)"
echo "   Map: 1024 MB, 1 vcore"
echo "   Reduce: 2048 MB, 2 vcores"
echo "   Atual:"
docker exec hadoop-master bash -c "cat \$HADOOP_HOME/etc/hadoop/mapred-site.xml | grep -A 1 'mapreduce.map.memory.mb' | grep '<value>' | sed 's/<[^>]*>//g' | xargs"
docker exec hadoop-master bash -c "cat \$HADOOP_HOME/etc/hadoop/mapred-site.xml | grep -A 1 'mapreduce.reduce.memory.mb' | grep '<value>' | sed 's/<[^>]*>//g' | xargs"
echo ""

echo "=========================================="
echo "STATUS DO CLUSTER"
echo "=========================================="
echo ""

echo "Nós YARN disponíveis:"
docker exec hadoop-master yarn node -list 2>/dev/null || echo "Aguardando YARN inicializar..."
echo ""

echo "Relatório HDFS:"
docker exec hadoop-master hdfs dfsadmin -report 2>/dev/null | head -20 || echo "Aguardando HDFS inicializar..."
echo ""

echo "=========================================="
echo "Para monitorar via interface web:"
echo "  NameNode UI (HDFS): http://localhost:9870"
echo "  ResourceManager UI (YARN): http://localhost:8088"
echo "=========================================="
