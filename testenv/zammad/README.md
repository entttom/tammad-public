# Zammad-Testinstanz für Tammad

Eine lokale Zammad-Instanz mit festen Testdaten, um die App gegen einen echten
Server zu testen. Sie wird bei Bedarf in Docker aufgebaut und danach wieder
vollständig entfernt – dauerhaft gespeichert wird nichts außer diesem Ordner.

## Voraussetzungen

- Docker Desktop mit Docker Compose v2 (≥ 2.23.1)
- Docker sollte mindestens **6 GB RAM** zugeteilt haben (Elasticsearch)
- Beim ersten Aufbau werden einige GB Images geladen (danach aus dem Cache)
- Port 8080 frei (anpassbar über `TAMMAD_ZAMMAD_PORT`)

## Aufbauen

```bash
testenv/zammad/setup.sh
```

Das Skript

1. holt das offizielle [zammad-docker-compose](https://github.com/zammad/zammad-docker-compose)
   in einer festgelegten Version (Zammad 7.2.0, Elasticsearch 9.5.3,
   PostgreSQL 17.11) nach `testenv/zammad/.work/`,
2. startet den Stack als Compose-Projekt `tammad-test` auf http://localhost:8080,
3. wartet, bis Migrationen und Suchindex fertig sind,
4. erzeugt zufällige Passwörter in `testenv/zammad/.work/credentials.env`
   (git-ignoriert, nur lokal) und
5. legt mit `seed.rb` die Testdaten an (Dauer insgesamt ca. 3–5 Minuten).

## Anmelden

Die Zugangsdaten stehen in `testenv/zammad/.work/credentials.env`.

| Zweck | Wert |
|---|---|
| Server-URL (App und Browser) | `http://localhost:8080` |
| Admin + Agent | `ADMIN_LOGIN` (`tammadadmin`) oder `admin@tammad.test` / `ADMIN_PASSWORD` |
| Zweiter Agent | `agent@tammad.test` / `AGENT_PASSWORD` |
| API-Token (Admin) | `ADMIN_API_TOKEN` – für die Anmeldeart „Token“ |

In der App die Anmeldeart **Basic Auth** wählen. `http://` ist nur für
`localhost` erlaubt (App Transport Security); echte Server brauchen `https://`.

## Testdaten (`seed.rb`)

- Agenten: Ada Admin, Bruno Agent; Kunden: Alex Muster und ein Kunde **ohne Namen**
- 15 aktive Gruppen (Pagination), eine inaktive Gruppe, eine Gruppe mit `note = null`
- eigene States: „in Bearbeitung“ (Typ open), „Wartet auf Kunde“ (Typ pending reminder)
- SLA: Tickets mit Priorität „3 high“ eskalieren eine Minute nach Erstellung
- Tickets für jeden Filter: HTML-Mail mit eingebettetem Bild, Link, Script-Tag und
  PDF-Anhang; interne Notiz; überfällige Wiedervorlagen (auch im eigenen State);
  abonniertes (Mention) und nicht zugewiesenes Ticket; 24 Massentickets
- Textbausteine und eine ausgehende E-Mail-Adresse. Es gibt keinen Mailserver:
  Antworten werden angelegt, der Versand schlägt fehl und Zammad vermerkt das als Notiz.

## Integrationstests

```bash
testenv/zammad/run-integration-tests.sh
```

Führt `TammadTests/ZammadIntegrationTests` gegen die Instanz aus (Listen,
Filter inkl. eigener States, Suche, HTML/Inline-Bild/Anhang, Bearbeiten mit
Pending-State und Owner, Antwort mit Sonderzeichen). Ohne Instanz werden diese
Tests im normalen Testlauf übersprungen. Anderen Simulator wählen:
`TAMMAD_TEST_DESTINATION='platform=iOS Simulator,name=iPad Pro 11-inch (M5)'`.

## Anhalten, entfernen, neu aufbauen

```bash
docker compose -p tammad-test stop      # anhalten, Daten bleiben
docker compose -p tammad-test start     # wieder starten
testenv/zammad/teardown.sh              # Container + Volumes (alle Daten) löschen
testenv/zammad/teardown.sh --images     # zusätzlich die Images (~ mehrere GB) löschen
```

Nach `teardown.sh` baut `setup.sh` die Instanz jederzeit identisch neu auf.

## Erkenntnisse aus Tests gegen Zammad 7.2

Diese Punkte haben Änderungen an der App ausgelöst und sind hier festgehalten,
damit sie bei Zammad-Updates erneut geprüft werden:

- `state.state_type.name` ist **nicht** im Suchindex → Filter „Offen“ und
  „Warten erreicht“ arbeiten mit `state_id`.
- `GET /api/v1/tickets` sortiert nach ID aufsteigend → die Ticketliste nutzt die
  Suche mit `sort_by`/`order_by`.
- Sortiert die Suche nur nach einem Feld, ist die Reihenfolge bei Gleichstand
  (z. B. fast alle Tickets mit Priorität „2 normal“) bei jeder Anfrage anders →
  Seiten überschneiden sich, Tickets fehlen. Die App sendet deshalb Ersatzschlüssel
  als Array (`sort_by[]=priority_id&sort_by[]=updated_at&sort_by[]=id`, ebenso `order_by[]`).
- `GET /api/v1/online_notifications` ignoriert `page`/`per_page` und liefert die
  neuesten 200 Benachrichtigungen.
- `expand=true` liefert bei Kunde/Owner den **Login**, nicht den Namen → Namen
  werden über die Benutzersuche aufgelöst.
- Die Ticket-Notiz (`note`) wird HTML-maskiert gespeichert (`&` → `&amp;`).
- Eingebettete Bilder stehen zusätzlich in `attachments`; der Artikeltext verweist
  auf `/api/v1/ticket_attachment/…?view=inline` (nur mit Anmeldung ladbar).
- E-Mail-Antworten verlangen eine E-Mail-Adresse an der Gruppe.
- Jede Anfrage mit abgelehnten Zugangsdaten zählt als fehlgeschlagene Anmeldung;
  nach `password_max_login_failed` (Standard 5) wird das Konto gesperrt → die App
  prüft gespeicherte Zugangsdaten beim Start mit genau einer Anfrage und sendet
  nach einem 401 nichts mehr mit denselben Daten.

Gesperrtes Testkonto zurücksetzen:

```bash
docker compose -p tammad-test exec zammad-railsserver bundle exec rails r 'User.find_by!(login: "tammadadmin").update!(login_failed: 0)'
```

## Hinweise

- Nur für lokale Tests – feste Testdaten, keine Härtung, `http`.
- Dieser Ordner enthält keine Geheimnisse; Passwörter entstehen erst beim Aufbau.
- Der Workflow `sync-to-repo-tammad.yml` spiegelt Nicht-Swift-Dateien ins
  öffentliche Repo – dieser Ordner wird also mitveröffentlicht.
