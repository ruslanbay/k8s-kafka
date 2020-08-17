FROM adoptopenjdk:8u262-b10-jdk-openj9-0.21.0-bionic

ARG ZOOKEEPER_VERSION=3.5.7

RUN mkdir /logs && \
    groupadd -r usergroup && \
    useradd -r -g usergroup user && \
    chown -R user:usergroup /logs

COPY config /config
ADD certs/certs.tar.gz /
COPY distrib/jmx_prometheus_javaagent-0.12.0.jar /distrib/

ADD distrib/apache-zookeeper-$ZOOKEEPER_VERSION-bin.tar.gz /distrib
COPY scripts/start-zookeeper.sh /distrib/apache-zookeeper-$ZOOKEEPER_VERSION-bin/
RUN chmod -R +x /distrib/apache-zookeeper-$ZOOKEEPER_VERSION-bin/bin && \
    chown -R user:usergroup /distrib

EXPOSE 2181/tcp 2281/tcp 2888/tcp 3888/tcp 7171/tcp

WORKDIR /distrib/apache-zookeeper-$ZOOKEEPER_VERSION-bin

USER user
