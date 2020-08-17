FROM adoptopenjdk:8u262-b10-jdk-openj9-0.21.0-bionic

EXPOSE 1099/tcp 4000/tcp

ADD certs/certs.tar.gz /
ADD distrib/apache-jmeter-5.3.tgz /distrib
COPY distrib/pepper-box-1.0.jar /distrib/apache-jmeter-5.3/lib/ext/
COPY tests /tests
COPY config/jmeter-user.properties /distrib/apache-jmeter-5.3/bin/user.properties

WORKDIR /distrib/apache-jmeter-5.3/bin
