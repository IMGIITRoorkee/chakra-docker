bind = '127.0.0.1:8000'

accesslog = '/web_server_logs/gunicorn_logs/access.log'
errorlog = '/web_server_logs/gunicorn_logs/error.log'
timeout = 120
worker_class = "gthread"
threads = 4
