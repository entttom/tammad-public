# Tammad

iOS-App für Zammad. Ermöglicht den Zugriff auf Tickets, Artikel und Benutzer sowie Push-Benachrichtigungen. Erfordert eine Zammad-Instanz mit installiertem Push-Plugin.

## Voraussetzungen

- Xcode 15 oder neuer
- iOS 17+
- Zammad-Server mit erreichbarer API
- Firebase-Projekt (für Push)
- Optional: Zammad Push Plugin auf dem Server

## Projektstruktur

- **Tammad/** – Haupt-App (SwiftUI): Views, ViewModels, Services, Models
- **TammadTests/** – Unit-Tests
- **zammad_plugin/** – Zammad-Plugin (Ruby) für Push-Benachrichtigungen und Mobile-Device-Registrierung

Die App nutzt die Zammad-REST-API für Login, Tickets, Artikel und Stammdaten. Push wird über Firebase Cloud Messaging und das Plugin angebunden.

## Build

Projekt in Xcode öffnen (`Tammad.xcodeproj`), Scheme „Tammad“ wählen und bauen. Für Push und In-App-Käufe müssen Firebase bzw. StoreKit in App Store Connect und im Projekt konfiguriert werden.

Vor dem ersten Lauf:

1. `GoogleService-Info.plist` von Firebase in den Tammad-Target-Ordner legen (falls noch nicht vorhanden).
2. In Zammad eine Anwendung (API Token) anlegen und in der App unter Einstellungen eintragen.

## In-App-Käufe

Abos werden über StoreKit 2 verwaltet. Produkt-IDs: `com.tammad.subscription.monthly`, `com.tammad.subscription.yearly`. Details und Einrichtung in App Store Connect stehen in `IAP_SETUP.md`.

## Zammad Push Plugin

Das Plugin in `zammad_plugin/` wird auf dem Zammad-Server installiert. Es registriert Geräte, speichert Push-Einstellungen und löst Benachrichtigungen bei Ticket-/Artikel-Events aus. Siehe `zammad_plugin/README.md` für Installation und Anpassungen.


