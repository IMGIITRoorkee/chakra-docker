import os

# Every service runs with network_mode: host, so 0.0.0.0 would publish Gunicorn
# on every host interface and let LAN clients bypass nginx's TLS, rate limit and
# path allowlist. nginx proxies to 127.0.0.1:8000 (conf.d/includes/upstreams.conf).
bind = '127.0.0.1:8000'

accesslog = f'/web_server_logs/gunicorn_logs/access.log'
errorlog = f'/web_server_logs/gunicorn_logs/error.log'
timeout = 120
worker_class = "gthread"
