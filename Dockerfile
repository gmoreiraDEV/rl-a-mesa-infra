FROM apache/kafka:4.0.0

# Railway volumes are mounted as root. Kafka's upstream image runs as UID 1000,
# which cannot format a fresh mounted KRaft log directory.
USER root

# Keep Kafka metadata away from filesystem-managed entries such as lost+found.
ENV KAFKA_LOG_DIRS=/var/lib/kafka/data/kraft
