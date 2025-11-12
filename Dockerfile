FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HADOOP_VERSION=3.3.6
ENV HADOOP_HOME=/opt/hadoop
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

RUN apt-get update && apt-get install -y \
    openjdk-8-jdk \
    ssh \
    rsync \
    wget \
    nano \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Baixar Hadoop de espelho mais rápido (dlcdn.apache.org)
RUN wget -q --show-progress https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz || \
    wget -q --show-progress https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar -xzf hadoop-${HADOOP_VERSION}.tar.gz && \
    mv hadoop-${HADOOP_VERSION} ${HADOOP_HOME} && \
    rm hadoop-${HADOOP_VERSION}.tar.gz

RUN ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && \
    chmod 0600 ~/.ssh/authorized_keys

COPY config/* ${HADOOP_HOME}/etc/hadoop/

RUN mkdir -p /hadoop/dfs/name /hadoop/dfs/data /hadoop/tmp

EXPOSE 9870 8088 9000 9864 8042

CMD ["/bin/bash"]
