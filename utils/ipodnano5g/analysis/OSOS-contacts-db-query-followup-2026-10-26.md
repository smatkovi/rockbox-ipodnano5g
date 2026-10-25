# OSOS-Contacts-DB: Querypfade und Kaltstartrelevanz

Stand: 26.10.2026. Ausschließlich statische Offline-Analyse des Full-Body-
Abbilds `osos_body.bin` im read-only-Ghidra-Projekt
`nano5g/ghidra-projects/N5G_OSOS_RTOS`. Kein Gerätezugriff, USB, DFU,
Neustart oder NAND-/NOR-/Flashzugriff.

## Ergebnis

Die Spur zu `iPod_Control/Device/iPod_Contacts.db` führt im geprüften Code
zu Kontakt-/Fotoabfragen und DB-Wrappern, nicht zu einem automatisch belegten
Boot-Parser oder einem Rockbox-Handoff.

- `FUN_0807d740` baut die SQL-Abfrage `SELECT * FROM iPod_ContactPhotos WHERE
  person_id = %d`. Der Wert wird als formatierter numerischer Parameter
  eingebunden. Der sichtbare Funktionskörper liest keine DB-Felder selbst und
  verwendet keine dateikontrollierte Kopierlänge, Allokationsgröße oder
  Funktionsadresse.
- Der einzige direkte Aufrufer von `FUN_0807d740` ist
  `FUN_08081244`. Dieser verwaltet einen Cache und kommt aus
  `FUN_0806c740`.
- `FUN_0806c740` wird direkt von `FUN_0805aab8` aufgerufen. Der Dispatcher
  `FUN_0805aab8` leitet anhand des Anfragewerts zu verschiedenen
  Kontaktobjektmethoden weiter. Ghidra zeigt für `FUN_0805aab8` im untersuchten
  Abbild keinen direkten Code-Xref; ein zusätzlicher Rohscan fand keine
  einfachen absoluten 32-Bit-Thumb-Funktionszeiger auf `0x0805aab9` bzw.
  `0x0806c741`. Dynamische Registrierung, externe Tabellen oder anders
  kodierte Zeiger sind damit nicht ausgeschlossen.
- `FUN_0825a3a0` prüft den initialisierten DB-Zustand und einen Fehler-/Open-
  Helfer. `FUN_0825a3c8` reicht die SQL-Abfrage an `FUN_080a71f0` weiter.
  Diese beiden Wrapper zeigen in der geprüften Sequenz keinen dateigesteuerten
  Pufferzugriff.
- `FUN_080acbfc` erstellt SQL-Datensätze aus vorhandenen
  AddressBook-Kontaktobjekten. Das ist ein Objekt-zu-Datenbank-Pfad, kein
  Beleg dafür, dass die gespeicherte Datei beim Einschalten automatisch
  eingelesen wird.

Damit ist diese Spur derzeit kein bestätigter Parserfehler und kein
Kaltstarttrigger. Die generische SQLite-/DB-Implementierung wurde hier nicht
als Ganzes auditiert; der Befund beschränkt sich auf die genannten
Aufrufer und Wrapper. Auch die dynamische Registrierung von
`FUN_0805aab8` bleibt offen.

## Rohbelege

- `/tmp/OSOS_contacts_db_callers_20261026.txt`
- `/tmp/OSOS_contacts_parser_followup_20261026.txt`
- `/tmp/OSOS_contacts_db_xrefs_20261026.txt`
- `/tmp/OSOS_contacts_media_root_20261026.txt`
- `/tmp/OSOS_contacts_media_root_refs_20261026.txt`
- `/tmp/OSOS_contacts_db_wrapper_20261026.txt`
- `/tmp/OSOS_contacts_db_roots_20261026.txt`

Die Ghidra-Exports wurden mit `-readOnly -noanalysis` erstellt. Die
Projektadressen sind Full-Body-Adressen; sie dürfen nicht ohne Mapping mit
Runtime-Adressen vermischt werden.

## Bedeutung für das Ziel

Eine Schwachstelle in einer laufenden iPod-OS-Komponente könnte theoretisch
nach dem signierten OSOS-Start einen RAM-Handoff zum bestehenden
Rockbox-Bootloader ermöglichen. Für untethered Boot fehlt weiterhin ein bei
jedem Kaltstart automatisch erreichbarer, persistenter und kontrollierbarer
RCE-Trigger. Diese Contacts-DB-Spur liefert einen solchen Nachweis nicht.
