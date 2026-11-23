#!/bin/bash
# Re-applies the incoming nginx config 10 s after the last change under /home/root2/nginx-incoming.
inotifywait -q -m -r -e close_write,create,delete,moved_to --format '%w%f' /home/root2/nginx-incoming | while read -r _; do
  while read -r -t 10 _; do :; done
  /usr/local/sbin/replica-nginx-apply.sh
done
