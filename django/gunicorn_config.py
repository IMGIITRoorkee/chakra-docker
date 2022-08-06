import os

bind = '0.0.0.0:8000'

reload = True

accesslog = f'/web_server_logs/gunicorn_logs/access.log'
errorlog = f'/web_server_logs/gunicorn_logs/error.log'
timeout = 120
worker_class = "gthread"
