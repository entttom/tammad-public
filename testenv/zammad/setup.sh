#!/usr/bin/env bash
# Baut die lokale Zammad-Testinstanz für Tammad auf (Docker) und befüllt sie mit
# Testdaten. Siehe README.md. Nichts davon ist für den Produktivbetrieb gedacht.
set -euo pipefail

cd "$(dirname "$0")"
HERE="$(pwd)"
WORK="$HERE/.work"                       # git-ignoriert: Compose-Checkout + Zugangsdaten
PROJECT="${TAMMAD_ZAMMAD_PROJECT:-tammad-test}"
PORT="${TAMMAD_ZAMMAD_PORT:-8080}"
# Offizielles Setup, festgelegt auf einen geprüften Stand (Zammad 7.2.0,
# Elasticsearch 9.5.3, PostgreSQL 17.11). Zum Aktualisieren Commit ändern.
COMPOSE_REPO="https://github.com/zammad/zammad-docker-compose.git"
COMPOSE_COMMIT="${TAMMAD_ZAMMAD_COMPOSE_COMMIT:-7849456602ce1b57a721b60529e90bc974f19244}"
CREDENTIALS="$WORK/credentials.env"

command -v docker >/dev/null || { echo "Docker fehlt (Docker Desktop installieren)." >&2; exit 1; }
docker compose version >/dev/null || { echo "Docker Compose v2 fehlt." >&2; exit 1; }

mkdir -p "$WORK"
if [ ! -d "$WORK/zammad-docker-compose/.git" ]; then
  echo "→ Hole zammad-docker-compose @ ${COMPOSE_COMMIT:0:7}"
  git init -q "$WORK/zammad-docker-compose"
  git -C "$WORK/zammad-docker-compose" remote add origin "$COMPOSE_REPO"
fi
git -C "$WORK/zammad-docker-compose" fetch -q --depth 1 origin "$COMPOSE_COMMIT"
git -C "$WORK/zammad-docker-compose" checkout -q --force FETCH_HEAD

compose() {
  NGINX_EXPOSE_PORT="$PORT" docker compose -p "$PROJECT" \
    --project-directory "$WORK/zammad-docker-compose" \
    -f "$WORK/zammad-docker-compose/docker-compose.yml" "$@"
}

echo "→ Starte Container (Projekt '$PROJECT', Port $PORT) – beim ersten Mal werden einige GB geladen"
compose up -d

echo "→ Warte auf zammad-init (Migrationen + Suchindex)"
for _ in $(seq 1 180); do
  state="$(compose ps -a --format '{{.Service}} {{.State}} {{.ExitCode}}' | awk '$1=="zammad-init"{print $2" "$3}')"
  case "$state" in
    "exited 0") break ;;
    exited*) echo "zammad-init ist fehlgeschlagen:" >&2; compose logs --tail 50 zammad-init >&2; exit 1 ;;
  esac
  sleep 5
done
[ "$state" = "exited 0" ] || { echo "Zeitüberschreitung beim Warten auf zammad-init." >&2; exit 1; }

# Zugangsdaten nur beim ersten Aufbau erzeugen (danach wiederverwenden).
if [ ! -f "$CREDENTIALS" ]; then
  gen() { LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 14; }
  umask 077
  cat > "$CREDENTIALS" <<EOF
ZAMMAD_URL=http://localhost:$PORT
ADMIN_LOGIN=tammadadmin
ADMIN_EMAIL=admin@tammad.test
ADMIN_PASSWORD=Tm$(gen)x7Q
AGENT_LOGIN=agent@tammad.test
AGENT_PASSWORD=Tm$(gen)x7Q
EOF
fi
# shellcheck disable=SC1090
. "$CREDENTIALS"

echo "→ Lege Testdaten an"
compose exec -T zammad-railsserver bash -c 'cat > /tmp/seed.rb' < "$HERE/seed.rb"
seed_output="$(compose exec -T -e ADMIN_PASSWORD="$ADMIN_PASSWORD" -e AGENT_PASSWORD="$AGENT_PASSWORD" \
  zammad-railsserver bundle exec rails r /tmp/seed.rb 2>&1)" || { echo "$seed_output" | tail -30 >&2; exit 1; }
echo "$seed_output" | grep '^SEED_OK'
token="$(echo "$seed_output" | sed -n 's/^API_TOKEN=//p')"
grep -v '^ADMIN_API_TOKEN=' "$CREDENTIALS" > "$CREDENTIALS.tmp" && mv "$CREDENTIALS.tmp" "$CREDENTIALS"
echo "ADMIN_API_TOKEN=$token" >> "$CREDENTIALS"
chmod 600 "$CREDENTIALS"

cat <<EOF

✓ Zammad läuft: http://localhost:$PORT
  Logins und Passwörter: $CREDENTIALS
  In der App: Server-URL http://localhost:$PORT, Basic Auth mit ADMIN_LOGIN/ADMIN_PASSWORD
  Integrationstests:  ./run-integration-tests.sh
  Anhalten:           docker compose -p $PROJECT stop
  Komplett entfernen: ./teardown.sh
EOF
