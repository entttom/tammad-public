# Native Zammad-KI in Tammad

Stand: 23. Oktober 2026

## Verhalten nach dem Update

Tammad prüft nach bestätigter Anmeldung bzw. Sitzungswiederherstellung die KI-Fähigkeiten der aktuellen Instanz. Die Anmeldung wartet nicht auf diese Prüfung.

Bestandsnutzer erhalten beim ersten geeigneten Start nach dem Update einen einmaligen Auswahldialog, wenn bereits ein KI-API-Schlüssel hinterlegt war, Premium aktiv ist und tatsächlich nutzbare native Schreibwerkzeuge erkannt wurden. Bis zur Auswahl bleibt der bisherige eigene Anbieter aktiv. Die Auswahlmöglichkeiten sind:

- **Automatisch (empfohlen):** Zammad für unterstützte Aktionen. Externer Fallback ist standardmäßig aus und muss separat ausdrücklich aktiviert werden.
- **Zammad-KI:** ausschließlich die native Server-KI, ohne zusätzliche Zugangsdaten oder Modellwahl.
- **Eigener KI-Anbieter:** bisheriger OpenAI-kompatibler Endpunkt mit Schlüssel, Modell, Antwortvorlagen und freien Anweisungen.

Der Dialog enthält eine ausdrückliche Speichern-Aktion und lässt sich nicht versehentlich wegwischen. Schlüssel und Modell bleiben bei jeder Auswahl erhalten. Die Entscheidung gilt dauerhaft und kann jederzeit in den KI-Einstellungen geändert werden. Es gibt keinen erneuten Dialog bei jedem weiteren App-Update.

Ein nicht erreichbarer Server oder deaktivierte KI verbraucht den Hinweis nicht; er kann bei einem späteren geeigneten Start erscheinen. Die Prüfung der Bestandskonfiguration erfolgt erst mit bestätigter Anmeldung, damit ein beim Gerätestart gesperrter Schlüsselbund nicht als fehlender Schlüssel gewertet wird. Frische Installationen werden durch späteres Hinzufügen eines Schlüssels nicht nachträglich als Bestandsinstallation behandelt. Mehrere iPad-Fenster teilen sich eine einzige Präsentation und Entscheidung. Offene Sheets und anstehende Push-Navigation haben Vorrang.

## Erkennung und Rechte

1. `GET /api/v1/version` mit der vorhandenen Zammad-Authentifizierung. Semantischer Vergleich einschließlich Vorabversionen und Build-Metadaten. Bekannte Versionen unter 7.0.0 bleiben ausgeschlossen.
2. `POST /graphql`, `applicationConfig { key value }`. Auswertung von `ai_provider`, `ai_assistance_text_tools`, `ai_assistance_ticket_summary` sowie `ai_assistance_text_tools_fixed_instructions`. Fehlende oder nicht interpretierbare Werte bleiben unbekannt.
3. `aiAssistanceTextToolsList`, einschließlich `internalId`, `instruction` und `active`. Inaktive, ungültige oder doppelte Werkzeuge werden herausgefiltert. Der Server prüft die Benutzerrechte. Im Ticketeditor werden zusätzlich Ticket- und Gruppenparameter übergeben. Die aktuelle Ticketgruppe wird dafür erneut vom Server geladen, damit zwischenzeitlich verschobene Tickets keine veraltete Werkzeugauswahl verwenden. Gruppen verwenden Zammads rohe globale ID `gid://zammad/Group/…`.

**Abweichung vom ursprünglichen API-Beispiel:** In Zammad 7.0 verlangt der Versions-Endpunkt `admin`. Eine ausschließlich auf diesem Endpunkt beruhende Freischaltung würde normale Agenten ausschließen. Bei 403/404 bzw. nicht lesbarer Versionsantwort zeigt Tammad daher die Version als unbekannt an und prüft die tatsächlichen Agenten-KI-APIs. Es behauptet dabei keine bestätigte Serverversion. Positive Flags allein reichen nicht aus: Die Werkzeug-API muss tatsächlich erfolgreich geantwortet haben und nutzbare Werkzeuge liefern. Ein 401 wird weiterhin als ungültige Anmeldung behandelt. Administratorrechte und zusätzliche KI-Zugangsdaten sind für die Nutzung nicht erforderlich.

Die allgemeine Werkzeugliste und die Liste für bestehende Tickets verwenden in Zammad unterschiedliche Gruppenrechte. Deshalb fragt der Ticketeditor seine kontextbezogenen Werkzeuge auch dann gesondert ab, wenn die allgemeine Liste leer ist.

Version und Erkennung sind an die laufende Anmeldung gebunden. Gleichzeitige Erkennungsanfragen werden zusammengefasst, erfolgreiche Ergebnisse bis zu fünf Minuten wiederverwendet. Öffnen der KI-Einstellungen und manuelles Aktualisieren prüfen neu. Vor jeder nativen Textverarbeitung werden die Konfiguration und die für das Ticket nutzbaren Werkzeuge erneut geprüft; die Versionsabfrage wird dabei aus dem Sitzungscache übernommen. Logout, Serverwechsel und geänderte Zugangsdaten verwerfen den Cache. Späte Antworten einer früheren Sitzung dürfen keine neue Sitzung verändern oder Ticketinhalt an deren Server senden.

Die Ticketzusammenfassung wird als **Servereinstellung** angezeigt. Dies ist keine Zusicherung für jedes einzelne Ticket. Eine eigene Zusammenfassungsansicht bzw. deren Ausführung ist nicht Bestandteil dieser Textwerkzeug-Integration.

## Verwendung im Ticketeditor

Über die KI-Schaltfläche lassen sich bei nativer KI vorhandene Entwürfe mit den tatsächlich verfügbaren Serverwerkzeugen bearbeiten. Die ursprüngliche Eingabe und das bearbeitbare Ergebnis bleiben getrennt. Erst **Übernehmen** ändert den Composer.

Bei einer Entwurfsbearbeitung wird der ursprüngliche Entwurf ersetzt, wenn er unverändert ist. Wurde er inzwischen beispielsweise in einem anderen iPad-Fenster geändert, bleibt er erhalten und der Vorschlag wird angehängt. Neue Antwortvorschläge werden an vorhandenen Text angehängt. Eine leere Antwort, ein Fehler oder ein Abbruch verändert den Composer nicht.

Für die eigene Anbieter-Konfiguration bleiben positive, negative, allgemeine und benutzerdefinierte Antworten erhalten. Vor der ersten externen Datenweitergabe gilt weiterhin die vorhandene Zustimmung pro Organisation und Anbieter. Der Dialog nennt den konkreten Anbieter. Die aktuelle Quelle wird im KI-Editor angezeigt. Laufende Generierungen können abgebrochen werden; doppelte schnelle Taps starten nur eine Anfrage.

## Vollständige Antworten über Zammad konfigurieren

Zammads Standardvorgaben behandeln die Eingabe ausdrücklich als zu überarbeitenden Text. Tammad verwendet deshalb keine Prompt-Tricks, um Kundenanfragen als neue Anweisungen auszuführen.

Für native vollständige Antwortvorschläge:

1. Ein Zammad-Administrator prüft, ob die festen Vorgaben des Schreibassistenten vollständige Kundenantworten zulassen. Die bekannten Standardverbote müssen dazu serverseitig bewusst durch passende, getestete Vorgaben ersetzt werden. Tammad selbst ändert die Serverkonfiguration nicht.
2. Der Administrator richtet geeignete Werkzeuge für positive, negative und/oder allgemeine Kundenantworten ein und testet deren Verhalten, Berechtigungen und Gruppenverfügbarkeit. Die Werkzeuganweisung definiert die Antwortaufgabe; der Eingabetext bleibt die Kundenanfrage. Ticketkontext kann über die von Zammad unterstützten Vorlagenvariablen einbezogen werden.
3. In Tammad unter **KI-Einstellungen → Werkzeuge für vollständige Antworten** die angezeigten Servervorgaben prüfen und deren Eignung ausdrücklich bestätigen.
4. Die Antworttypen einzeln den passenden Werkzeugen zuordnen. Es gibt keine automatische Zuordnung anhand von Namen.

Sind die festen Vorgaben unbekannt oder enthalten sie die bekannten Standardverbote, bleiben ausschließlich Entwurfswerkzeuge verfügbar. Bei nicht eindeutig interpretierbaren, individuell formulierten Vorgaben ist die ausdrückliche Bestätigung der vom Administrator getesteten Konfiguration erforderlich; natürliche Sprache lässt sich nicht allgemein automatisch auf semantische Eignung beweisen.

Zuordnungen gelten pro vollständiger Instanzadresse einschließlich Installationspfad. Die Bestätigung bindet sich an Prüfsummen der festen Servervorgaben und der ausgewählten Werkzeuganweisungen. Ändert sich eine dieser Anweisungen, ist die bisherige Zuordnung für Antwortgenerierung nicht mehr freigegeben und muss neu geprüft/bestätigt werden. Gruppen- und Kontorechte werden unabhängig davon erneut serverseitig angewendet.

Freie benutzerdefinierte Prompts bietet Tammad über native Zammad-Schreibwerkzeuge nicht an. Dafür kann der Nutzer seinen eigenen Anbieter ausdrücklich auswählen. Ein Laufzeitfehler eines nativen Werkzeugs führt niemals automatisch zu einem externen Request, auch wenn der automatische Modus einen Fallback erlaubt. Dieser Fallback dient der Auswahl bei fehlender Funktionsunterstützung, nicht dem verdeckten Wiederholen fehlgeschlagener Anfragen bei einem anderen Dienst.

## Premium, Datenschutz und Fehler

Alle Ausführungswege im Ticketeditor prüfen weiterhin `SubscriptionManager.hasActiveSubscription`. Die native Ausführung prüft Premium nochmals vor dem eigentlichen Request und vor Übernahme des Ergebnisses. Es gibt keine neue Abo-Stufe, keinen Proxy und keinen Zugriff auf den LLM-Schlüssel des Zammad-Servers. Serverkontingente und Anbietergebühren sind vom Tammad-Abo unabhängig.

Native Requests verwenden die vorhandenen Zammad-Credentials, Redirect-Regeln und die bestehende Sperre bereits abgelehnter Zugangsdaten. Timeout: 20 Sekunden für Erkennung, 120 Sekunden für Textverarbeitung. Ticketinhalt, Schlüssel und Serverfehlermeldungen mit möglicherweise sensiblen Nutzdaten werden nicht in neue Logs geschrieben. HTML-Antworten werden für den vorhandenen Klartext-Composer konvertiert.

401, 403, 404, 422, GraphQL-Fehler bei HTTP 200, leere/ungültige Antworten, Netzwerkfehler, Timeout, geänderte Serverkonfiguration und verlorene Berechtigungen werden abgefangen. Beide Sprachen, Hell-/Dunkelmodus und adaptive native Formulare werden unterstützt.

## Dateien

Neu:

- `Tammad/Models/ZammadAICapabilities.swift`: Versionen, Fähigkeitsstatus, GraphQL-Werte, Werkzeuge, Zuordnungen, Fehler.
- `Tammad/Services/ZammadAICapabilityService.swift`: Erkennung, Cache, GraphQL und Kontextfilter.
- `Tammad/Services/ZammadAIService.swift`: native Ausführung und funktionsabhängige Anbieterauswahl.
- `Tammad/Services/AIProviderMigration.swift`: einmalige Bestandsnutzer-Auswahl und Fensterkoordination.
- `Tammad/Views/AIProviderChoiceView.swift`: Auswahldialog nach dem Update.
- `Tammad/Views/ZammadAISettingsSections.swift`: Status, Werkzeuge und Zuordnungen.
- `TammadTests/ZammadAITests.swift`: gemockte Kernabläufe und visuelle Layout-Fixtures.
- `Docs/Native-Zammad-AI.md`: diese Dokumentation.

Erweitert:

- `README.md`: Hinweis und Verweis auf diese Einrichtungsschritte in beiden Sprachen.
- `Models/AISettings.swift`: drei Modi, Fallback-Opt-in, servergebundene Zuordnungen, kompatible Codable-Migration.
- `Services/AIService.swift`: erhaltene externe Implementierung, injizierbare Test-Abhängigkeiten und Änderungsmitteilung.
- `Services/ZammadService.swift`: wiederverwendeter authentifizierter KI-Request, Instanzidentität und Cache-Rücksetzung.
- `Services/AppState.swift`: nicht blockierende Erkennung nach Login und Erfassung der Bestandsinstallation.
- `ViewModels/AISettingsViewModel.swift`, `ViewModels/AIReplyViewModel.swift`: Auswahl, Migration, Werkzeugzuordnung und getrennte Ausführungswege.
- `ViewModels/ArticleCreateViewModel.swift`, `Views/Tickets/ArticleComposerContent.swift`: Ticket-/Gruppenkontext und geschützte Übernahme.
- `Views/AISettingsView.swift`, `Views/AIReplyView.swift`, `Views/RootView.swift`: integrierte Einstellungen, Textverarbeitung und Hinweis.
- `Resources/Localizable.xcstrings`: alle neuen sichtbaren Texte in Deutsch und Englisch.
- `Tammad.xcodeproj/project.pbxproj`: Testdatei eingebunden. Neue App-Dateien werden durch die vorhandene synchronisierte Projektgruppe automatisch eingebunden. Bereits vorhandene fremde Projektänderungen bleiben erhalten.

## Prüfung

Die Tests verwenden lokale HTTP-Fixtures und keine produktiven Zugangsdaten. Simulator-Build und erste Gesamtsuite erfolgreich. Die neuen KI-Tests decken Migration, Versionen, Agenten ohne Versionsrechte, tatsächliche Capability-Prüfung, GraphQL-Fehler, Berechtigungen, Gruppenkontext, Einstellungen, Opt-in-Fallback, native/externe Ausführung, Premium, Abbruch, Sitzungswechsel, Anweisungsänderungen und Textübernahme ab. Screenshots werden als Testanhänge für iPhone-/iPad-Abmessungen, Deutsch/Englisch sowie Hell-/Dunkelmodus erstellt und visuell kontrolliert.

Letzter umfassender Testlauf: **198 Tests, fünf übersprungen, keine Fehler**, einschließlich **45 neuer KI-Tests**. Ausgenommen war dabei ausdrücklich der bestehende `SubscriptionManagerTests.testTrialEligibilityUpgradeExpiryAndStatusNotifications`: Dieser scheitert auf dem verwendeten iOS-27-Simulator bei der StoreKit-Ablauferkennung mit zwei Assertions. Derselbe Fehler wurde in einem separaten Checkout des unveränderten `HEAD` reproduziert. Der Abo-Manager wurde für diesen Auftrag nicht geändert. Ein früherer Gesamtlauf mit 188 Tests war ohne Fehler, wobei der StoreKit-Test wegen ausbleibender Simulator-Antwort übersprungen wurde.

Testumgebung: Xcode mit iOS-27-SDK, iPad-Air-11-Zoll-(M4)-Simulator, Debug-Konfiguration. Ergebnisbundle: `/tmp/Tammad-NativeAI-finished.xcresult`. Baseline-Vergleich: `/tmp/Tammad-AI-baseline-test.xcresult`. **Debug- und Release-Build erfolgreich**. Der Release-Build wurde für den generischen iOS-Simulator (arm64 und x86_64) durchgeführt; im abschließenden Build sind keine Compilerwarnungen oder -fehler aufgetreten. Build-Log: `/tmp/tammad-ai-release-final.log`. Die Layout-Fixtures wurden für iPhone- und iPad-Abmessungen mit echten SwiftUI-Ansichten gerendert; dies ist keine Prüfung auf physischer iPhone-/iPad-Hardware.

Ein echter Zammad-Server mit produktivem KI-Provider, physische Geräte sowie App-Store-Verarbeitung wurden nicht verwendet. Insbesondere ersetzt die Bestätigung einer getesteten Serverkonfiguration keinen End-to-End-Nachweis mit dem jeweils eingesetzten Modell.

## Geprüfte Zammad-Primärquellen

- [Versions-Endpunkt erfordert admin (7.0.0)](https://github.com/zammad/zammad/blob/7.0.0/app/policies/controllers/version_controller_policy.rb)
- [GraphQL-Liste mit Agentenrechten und Gruppen-/Ticketkontext (7.0.0)](https://github.com/zammad/zammad/blob/7.0.0/app/graphql/gql/queries/ai_assistance/text_tools/list.rb)
- [Globale IDs als rohe gid-URI (7.0.0)](https://github.com/zammad/zammad/blob/7.0.0/app/graphql/gql/zammad_schema.rb)
- [Standardkonfiguration und feste Schreibassistenten-Vorgaben](https://github.com/zammad/zammad/blob/stable/db/seeds/settings.rb)
- [Native REST-Ausführung und Ticketkontext](https://github.com/zammad/zammad/blob/stable/app/controllers/ai_assistance_controller.rb)
- [Zammad-Benutzerdokumentation zu den KI-Funktionen](https://user-docs.zammad.org/en/7.0/extras/ai-features.html)
