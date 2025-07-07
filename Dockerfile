FROM docker.io/eclipse-temurin:21-jdk-alpine

ENV SCALA_VERSION="2.13" \
    KAFKA_VERSION="4.0.0" \
    JMETER_VERSION="5.6.3" \
    JMETER_HOME="/apps/jmeter"

RUN apk add ca-certificates \
    curl \
    nss \
    tar \
    tzdata \
    && rm -rf /var/cache/apk/*

RUN mkdir -p /apps/jmeter

# # Create non-root user
# RUN adduser -D -u 1000 jmeter

# # Create apps directory
# RUN mkdir -p /apps && \
#     chown -R jmeter:jmeter /apps

# # Switch to non-root user
# USER jmeter

# Download and install Kafka and JMeter
RUN cd /apps && \
    curl -L --silent https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-${JMETER_VERSION}.tgz -o jmeter.tgz && \
    tar -xzf jmeter.tgz --strip-components=1 -C /apps/jmeter && \
    rm jmeter.tgz && \
    curl -L --silent https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -o kafka.tgz && \
    tar -xzf kafka.tgz --strip-components=2 -C /apps/jmeter/lib kafka_${SCALA_VERSION}-${KAFKA_VERSION}/libs && \
    rm kafka.tgz

WORKDIR /tests

CMD ["/bin/sh", "-c", "sleep infinity"]

LABEL org.opencontainers.image.title="alpine-jdk21-kafka4-jmeter" \
      org.opencontainers.image.description="Lightweight Alpine-based container with Eclipse Temurin JDK 21, Apache Kafka 4.0.0, and Apache JMeter 5.6.3 for performance testing." \
      org.opencontainers.image.source="https://github.com/${GITHUB_USER}/k8s-kafka" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.ref.name="${BUILD_VERSION}" \
      org.opencontainers.image.licenses="GPL-3.0" \
      org.opencontainers.image.vendor="${GITHUB_USER}" \
      org.opencontainers.image.authors="${GITHUB_USER}" \
      org.opencontainers.image.documentation="https://github.com/${GITHUB_USER}/k8s-kafka#readme"
