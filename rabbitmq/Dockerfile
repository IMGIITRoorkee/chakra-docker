# Use RabbitMQ from the Debian Linux project
FROM rabbitmq:3.10.7-management

# Add labels for metadata
LABEL maintainer="IMG, IIT Roorkee <https://img.channeli.in>"

# Containers use host networking, so keep every listener (AMQP, management,
# Prometheus, epmd and inter-node traffic) on loopback. The node name resolves
# to 127.0.1.1 (Debian and Ubuntu hosts), which epmd and the CLI must also reach.
COPY loopback.conf /etc/rabbitmq/conf.d/20-loopback.conf
ENV ERL_EPMD_ADDRESS=127.0.0.1,127.0.1.1
ENV RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS="-kernel inet_dist_use_interface {127,0,1,1}"
