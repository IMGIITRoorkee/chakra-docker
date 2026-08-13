#!/bin/bash
set -eo pipefail

# Healthy means the rabbit app booted and runs, raises no alarms,
# and has at least one active listener.

rabbitmqctl eval '
{ true, rabbit_app_booted_and_running } = { rabbit:is_booted(node()), rabbit_app_booted_and_running },
{ [], no_alarms } = { rabbit:alarms(), no_alarms },
[] /= rabbit_networking:active_listeners(),
rabbitmq_node_is_healthy.
' || exit 1
