#!/bin/bash

export KAFKA_HEAP_OPTS="
-Xms512M
-Xmx512M
-XX:+UseG1GC
-XX:MaxGCPauseMillis=20
-XX:InitiatingHeapOccupancyPercent=35
-XX:+ExplicitGCInvokesConcurrent
-XX:+PrintGCDetails
-XX:+PrintGCDateStamps
-XX:+PrintGCTimeStamps
-XX:+UseGCLogFileRotation
-XX:NumberOfGCLogFiles=10
-XX:GCLogFileSize=100M
"
export KAFKA_OPTS="
-Dzookeeper.client.secure=true
-Dzookeeper.ssl.keyStore.location=/certs/$HOSTNAME.jks
-Dzookeeper.ssl.keyStore.password=kafkapilot
-Dzookeeper.ssl.trustStore.location=/certs/kafkaCA-trusted.jks
-Dzookeeper.ssl.trustStore.password=kafkapilot
-Dzookeeper.clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty
-javaagent:/distrib/jmx_prometheus_javaagent-0.12.0.jar=7171:/config/jmx_exporter_kafka.yaml
"
bin/kafka-server-start.sh /config/$HOSTNAME.properties
