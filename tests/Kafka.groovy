#!/usr/bin/env groovy

import org.apache.commons.lang3.RandomStringUtils
import org.apache.kafka.clients.producer.KafkaProducer
import org.apache.kafka.clients.producer.ProducerRecord
import org.apache.kafka.common.header.internals.RecordHeader
import org.apache.kafka.common.header.internals.RecordHeaders

import org.apache.kafka.clients.consumer.KafkaConsumer
import org.apache.kafka.clients.consumer.ConsumerRecords
import org.apache.kafka.clients.consumer.ConsumerRecord
import java.time.Duration

abstract class KafkaClientBase {
  protected final Properties config
  protected final long testDuration
  protected final String topicName
  
  KafkaClientBase(Map<String, Object> params) {
    this.testDuration = params.testDurationSec as long
    this.topicName = params.topicName as String
    
    this.config = loadConfig()
  }
  
  private Properties loadConfig() {
    def props = new Properties()
    props.put('bootstrap.servers', 'my-cluster-kafka-bootstrap:9093')

    // Performance tuning for producer
    props.put('compression.type', 'none')
    props.put('batch.size', '51200')
    props.put('linger.ms', '5')
    props.put('buffer.memory', '33554432')
    props.put('acks', 'all')
    props.put('send.buffer.bytes', '131072')
    props.put('receive.buffer.bytes', '32768')
    
    // Serialization
    props.put('key.serializer', 'org.apache.kafka.common.serialization.StringSerializer')
    props.put('key.deserializer', 'org.apache.kafka.common.serialization.StringDeserializer')
    props.put('value.serializer', 'org.apache.kafka.common.serialization.StringSerializer')
    props.put('value.deserializer', 'org.apache.kafka.common.serialization.StringDeserializer')

    // Load SSL passwords from files
    def sslKeyPassword = new File('/certs/user/user.password').text?.trim()
    def sslTruststorePassword = new File('/certs/cluster/ca.password').text?.trim()

    // SSL Configuration
    props.put('security.protocol', 'SSL')
    props.put('ssl.key.password', sslKeyPassword)
    props.put('ssl.keystore.location', '/certs/user/user.p12')
    props.put('ssl.keystore.password', sslKeyPassword)
    props.put('ssl.keystore.type', 'PKCS12')
    props.put('ssl.truststore.location', '/certs/cluster/ca.p12')
    props.put('ssl.truststore.password', sslTruststorePassword)
    props.put('ssl.truststore.type', 'PKCS12')
    
    return props
  }
}

class KafkaMessageProducer extends KafkaClientBase {
  private final KafkaProducer<String, String> producer
  private final int messageSize
  private final int messageRate

  KafkaMessageProducer(Map<String, Object> params) {
    super(params)
    this.messageSize = params.msgSizeBytes as int
    this.messageRate = params.msgRatePerThread as int
    this.producer = new KafkaProducer<>(config)
  }

  private ProducerRecord<String, String> createRecord() {
    def message = RandomStringUtils.randomAlphabetic(messageSize)
    def headers = new RecordHeaders([
      new RecordHeader('schemaVersion', '1.0'.bytes),
      new RecordHeader('messageType', 'TEST_MESSAGE'.bytes),
      new RecordHeader('timestamp', System.currentTimeMillis().toString().bytes)
    ])
    
    return new ProducerRecord<>(topicName, null, System.currentTimeMillis(), 
      UUID.randomUUID().toString(), message, headers)
  }

  void produce() {
    try {
      long endTime = System.currentTimeMillis() + (testDuration * 1000)
      long sleepTimeNanos = 1_000_000_000L / messageRate
      long sleepMillis = sleepTimeNanos / 1_000_000L
      int sleepNanos = (int) (sleepTimeNanos % 1_000_000L)

      println "Starting producing: Rate=${messageRate}/s, Size=${messageSize}B, Duration=${testDuration}s"

      while (System.currentTimeMillis() < endTime) {
        producer.send(createRecord()) { metadata, exception ->
          if (exception) {
            println "Error sending message: ${exception.message}"
          }
        }

        if (sleepMillis > 0 || sleepNanos > 0) {
          if (sleepNanos >= 0 && sleepNanos <= 999_999) {
            Thread.sleep(sleepMillis, sleepNanos)
          } else {
            Thread.sleep(sleepMillis)
          }
        }
      }
    } finally {
      producer.close()
      println "Production completed"
    }
  }
}

class KafkaMessageConsumer extends KafkaClientBase {
  private final KafkaConsumer<String, String> consumer
  private final String consumerGroupId
  private final boolean enableLogging

  KafkaMessageConsumer(Map<String, Object> params) {
    super(params)
    this.consumerGroupId = params.consumerGroupId
    this.enableLogging = params.enableLogging?.toBoolean() ?: false
    config.put('group.id', consumerGroupId)
    this.consumer = new KafkaConsumer<>(config)
  }

  void consume() {
    try {
      consumer.subscribe([topicName])
      long endTime = System.currentTimeMillis() + testDuration * 1000
      while (System.currentTimeMillis() < endTime) {
        ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100))
        for (ConsumerRecord<String, String> record : records) {
          if (enableLogging) {
            println "Received: offset=${record.offset()}, partition=${record.partition()}, key=${record.key()}, timestamp=${record.timestamp()}"
          }
        }
        consumer.commitSync()
      }
    } catch (Exception e) {
      if (enableLogging) {
        println "ERROR: ${e.message}"
      }
      throw e
    } finally {
      consumer?.close()
    }
  }
}

// Script execution
def role = props.get('role')
if (!role) {
  throw new IllegalArgumentException('role Jmeter property must be set to "producer" or "consumer"')
}

if (role == 'producer') {
  def params = [
    topicName: props.get('topicName'),
    testDurationSec: props.get('testDurationSec'),
    msgSizeBytes: props.get('msgSizeBytes'),
    msgRatePerThread: props.get('msgRatePerThread')
  ]
  new KafkaMessageProducer(params).produce()
} else if (role == 'consumer') {
  def params = [
    topicName: props.get('topicName'),
    testDurationSec: props.get('testDurationSec'),
    consumerGroupId: props.get('consumerGroupId'),
    enableLogging: props.get('enableLogging')
  ]
  new KafkaMessageConsumer(params).consume()
} else {
  throw new IllegalArgumentException('Unknown role: ' + role)
}
