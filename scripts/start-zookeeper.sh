#!/bin/bash

mkdir /tmp/zookeeper && \
MYID=$( echo $HOSTNAME | grep -Eo "[0-9]+" ) && \
let MYID=MYID+1 && \
echo $MYID > /tmp/zookeeper/myid

export SERVER_JVMFLAGS="
-Xmx256M
-Xms256M
-XX:+UseG1GC
-XX:MaxInlineLevel=15
-XX:MaxGCPauseMillis=20
-XX:+HeapDumpOnOutOfMemoryError
-XX:+ExplicitGCInvokesConcurrent
-XX:InitiatingHeapOccupancyPercent=35
-Dzookeeper.root.logger=INFO,CONSOLE
-Dzookeeper.log.dir=/logs
-Dzookeeper.log.file=zookeeper-server.log
-Dzookeeper.serverCnxnFactory=org.apache.zookeeper.server.NettyServerCnxnFactory
-javaagent:/distrib/jmx_prometheus_javaagent-0.12.0.jar=7171:/config/jmx_exporter_zookeeper.yaml
"
bin/zkServer.sh start-foreground /config/$HOSTNAME.properties
