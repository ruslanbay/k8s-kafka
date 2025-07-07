#!/bin/sh

# Default values (if any) can be set here or leave empty to require mandatory input
CLIENT_TYPE=""
TEST_DURATION_SEC=""
TOPIC_NAME=""
CONSUMER_GROUP_ID=""
THREADS_NUMBER=""
MSG_RATE_PER_THREAD=""
MSG_SIZE_BYTES=""
ENABLE_LOGGING="false"

usage() {
  cat <<EOF
Usage: $0 [options]

Required options:
  --client-type TYPE             Client type: producer or consumer
  --test-duration-sec SEC        Test duration in seconds
  --topic-name NAME              Kafka topic name
  --consumer-group-id ID         Kafka consumer group ID
  --threads-number NUM           Number of threads
  --msg-rate-per-thread RATE     Message rate per thread
  --msg-size-bytes BYTES         Message size in bytes

Optional:
  --enable-logging               Enable verbose logging to stdout (default: disabled)

Example:
  $0 --client-type producer \
     --test-duration-sec 60 \
     --topic-name myTopic \
     --consumer-group-id myGroup \
     --threads-number 10 \
     --msg-rate-per-thread 100 \
     --msg-size-bytes 512 \
     --enable-logging

EOF
  exit 1
}

# Parse named parameters
while [ "$#" -gt 0 ]; do
  case "$1" in
    --client-type)
      CLIENT_TYPE="$2"
      shift 2
      ;;
    --test-duration-sec)
      TEST_DURATION_SEC="$2"
      shift 2
      ;;
    --topic-name)
      TOPIC_NAME="$2"
      shift 2
      ;;
    --consumer-group-id)
      CONSUMER_GROUP_ID="$2"
      shift 2
      ;;
    --threads-number)
      THREADS_NUMBER="$2"
      shift 2
      ;;
    --msg-rate-per-thread)
      MSG_RATE_PER_THREAD="$2"
      shift 2
      ;;
    --msg-size-bytes)
      MSG_SIZE_BYTES="$2"
      shift 2
      ;;
    --enable-logging)
      ENABLE_LOGGING="true"
      shift 1
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      usage
      ;;
  esac
done

# Validate required parameters
missing_params=0

check_param() {
  if [ -z "$2" ]; then
    echo "Error: Missing required parameter $1" >&2
    missing_params=1
  fi
}

check_param "--client-type" "$CLIENT_TYPE"
check_param "--test-duration-sec" "$TEST_DURATION_SEC"
check_param "--topic-name" "$TOPIC_NAME"
check_param "--threads-number" "$THREADS_NUMBER"

case "$CLIENT_TYPE" in
  producer)
    # Check producer-specific parameters
    check_param "--msg-rate-per-thread" "$MSG_RATE_PER_THREAD"
    check_param "--msg-size-bytes" "$MSG_SIZE_BYTES"
    ;;
  consumer)
    # Check consumer-specific parameters
    check_param "--consumer-group-id" "$CONSUMER_GROUP_ID"
    ;;
  *)
    echo "Error: Invalid or missing --client-type. Must be 'producer' or 'consumer'." >&2
    missing_params=1
    ;;
esac

if [ "$missing_params" -eq 1 ]; then
  usage
fi

export TZ="UTC"

/apps/jmeter/bin/jmeter -n -t /tests/jmeter-groovy.jmx \
  -JenableLogging="$ENABLE_LOGGING" \
  -Jrole="$CLIENT_TYPE" \
  -JtestDurationSec="$TEST_DURATION_SEC" \
  -JtopicName="$TOPIC_NAME" \
  -JconsumerGroupId="$CONSUMER_GROUP_ID" \
  -JthreadsNumber="$THREADS_NUMBER" \
  -JmsgRatePerThread="$MSG_RATE_PER_THREAD" \
  -JmsgSizeBytes="$MSG_SIZE_BYTES"
