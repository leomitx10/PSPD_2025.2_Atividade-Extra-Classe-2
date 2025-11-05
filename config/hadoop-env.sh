#!/usr/bin/env bash

export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

export HADOOP_CONF_DIR=${HADOOP_CONF_DIR:-"/opt/hadoop/etc/hadoop"}

for f in $HADOOP_HOME/contrib/capacity-scheduler/*.jar; do
  if [ "$HADOOP_CLASSPATH" ]; then
    export HADOOP_CLASSPATH=$HADOOP_CLASSPATH:$f
  else
    export HADOOP_CLASSPATH=$f
  fi
done

export HADOOP_HEAPSIZE_MAX=1024

export HADOOP_OPTS="$HADOOP_OPTS -Djava.net.preferIPv4Stack=true"

export HDFS_NAMENODE_OPTS="-Dhadoop.security.logger=INFO,RFAS"
export HDFS_DATANODE_OPTS="-Dhadoop.security.logger=ERROR,RFAS"
export HDFS_SECONDARYNAMENODE_OPTS="-Dhadoop.security.logger=INFO,RFAS"

export YARN_RESOURCEMANAGER_OPTS="-Dhadoop.security.logger=INFO,RFAS"
export YARN_NODEMANAGER_OPTS="-Dhadoop.security.logger=INFO,RFAS"

export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root
