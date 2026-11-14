#!/bin/bash
# Post-deploy smoke test: exercises each service the way editors do and exits non-zero on the first broken one.
# Run on the Chakra server from the chakra-docker checkout after every deploy or restart.
set -uo pipefail

BACKEND=${BACKEND_CONTAINER:-chakra-docker_chakra-backend_1}
HOST=${CHAKRA_HOST:-canvas.channeli.in}
CORE_URL=${CORE_URL:-http://127.0.0.1:5000}

failed=0
check() {  # check <name> <command...>
  local name=$1; shift
  if out=$("$@" 2>&1 </dev/null); then echo "ok   $name"; else echo "FAIL $name: $(tail -3 <<<"$out")"; failed=1; fi
}
http_200() { [ "$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$@")" = 200 ]; }
in_backend() {  # same environment as the web workers: compose runs them after `source chakra_backend/.env`
  docker exec -i "$BACKEND" bash -c 'source chakra_backend/.env && "$@"' _ "$@"
}

render_preview() {  # backend -> transpiler round trip on a real published page, as the editor preview does
  in_backend python manage.py shell <<'PY'
from generator.models import XMLPage
from generator.utils.transpiler import generate_html
page = XMLPage.objects.filter(page__isnull=False, file__isnull=False).order_by('pk').first()
html = generate_html(page.file.path, write_stdout=True)
assert b'<html' in html.lower(), f'no <html> in preview of page {page.pk}'
PY
}

check backend-admin http_200 -H "Host: $HOST" http://127.0.0.1:8000/admin/login/
check frontend http_200 http://127.0.0.1:3000/login/
check site-tls http_200 -k --resolve "$HOST:443:127.0.0.1" "https://$HOST/login/"
check transpiler-ready http_200 "$CORE_URL/health/ready"
check preview-render render_preview
check celery-worker in_backend celery -A chakra_backend inspect ping --timeout 10
[ -x "$HOME/chakra-env-guard.sh" ] && check config-unchanged "$HOME/chakra-env-guard.sh" check

exit $failed
