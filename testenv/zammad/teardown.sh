#!/usr/bin/env bash
# Entfernt die lokale Zammad-Testinstanz vollständig: Container, Netzwerke und
# Volumes (alle Testdaten). Mit --images werden auch die Docker-Images gelöscht.
# Die Instanz lässt sich jederzeit mit ./setup.sh neu aufbauen.
set -euo pipefail

cd "$(dirname "$0")"
PROJECT="${TAMMAD_ZAMMAD_PROJECT:-tammad-test}"

args=(down --volumes --remove-orphans)
if [ "${1:-}" = "--images" ]; then
  args+=(--rmi all)
fi

# Funktioniert allein über den Projektnamen – auch ohne .work/-Checkout.
docker compose -p "$PROJECT" "${args[@]}"

# Zugangsdaten gehören zur gelöschten Instanz; beim nächsten Aufbau neu erzeugen.
rm -f .work/credentials.env
echo "✓ Testinstanz '$PROJECT' entfernt."
