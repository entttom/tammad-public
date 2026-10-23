#!/usr/bin/env bash
# Führt die Integrationstests (TammadTests/ZammadIntegrationTests) gegen die
# lokale Testinstanz aus. Voraussetzung: ./setup.sh wurde ausgeführt.
set -euo pipefail

cd "$(dirname "$0")"
CREDENTIALS=".work/credentials.env"
[ -f "$CREDENTIALS" ] || { echo "Keine Zugangsdaten – zuerst ./setup.sh ausführen." >&2; exit 1; }
# shellcheck disable=SC1090
. "$CREDENTIALS"

DESTINATION="${TAMMAD_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"

# TEST_RUNNER_-Variablen werden (ohne Präfix) an den Testprozess übergeben.
# Ad-hoc-Signatur, damit der Schlüsselbund im Simulator funktioniert.
cd ../..
TEST_RUNNER_ZAMMAD_URL="$ZAMMAD_URL" \
TEST_RUNNER_ZAMMAD_ADMIN_LOGIN="$ADMIN_LOGIN" \
TEST_RUNNER_ZAMMAD_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
xcodebuild test \
  -scheme Tammad \
  -destination "$DESTINATION" \
  -only-testing:TammadTests/ZammadIntegrationTests \
  -collect-test-diagnostics never \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=
