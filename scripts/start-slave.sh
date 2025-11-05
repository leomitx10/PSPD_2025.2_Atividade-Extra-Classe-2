#!/bin/bash

service ssh start

echo "Hadoop Slave aguardando comandos do master..."

tail -f /dev/null
