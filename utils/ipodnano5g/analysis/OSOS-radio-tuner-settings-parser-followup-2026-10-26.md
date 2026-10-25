# OSOS-Radio: TunerSettings-Datei und bedingte Startkette

Stand: 26.10.2026. Ausschließlich statische Offline-Analyse des Full-Body-
Abbilds `osos_body.bin` im read-only-Ghidra-Projekt
`nano5g/ghidra-projects/N5G_OSOS_RTOS`. Kein Gerätezugriff, USB, DFU,
Neustart oder NAND-/NOR-/Flashzugriff.

## Verifizierter Dateipfad

`FUN_081a0914` öffnet `iPod_Control/Device/Radio/TunerSettings` im
Lesemodus (`FUN_082a046c(..., 0)`) und verarbeitet die Datei als typisierte
Tagfolge. Die Funktion wird im Konstruktor `FUN_0819ab14` aufgerufen. Der
Konstruktor wird vom Lazy-Singleton `FUN_081d6680` angelegt, das über
`FUN_081769b0` aufgerufen wird.

Ein konkreter OSOS-Pfad bis zu diesem Parser ist im Abbild sichtbar:

`FUN_08066fb4` (Event-Dispatcher) → `FUN_08079fb4` → `FUN_08086ce8`
(MainApp-Setup) → `FUN_0828bd04` → `FUN_081769b0` → `FUN_081d6680` →
`FUN_0819ab14` → `FUN_081a0914`.

Der Parser läuft dabei nur, wenn die Datei vorhanden ist. Die Kette belegt
einen persistenten OSOS-Eingang im MainApp-Setup, aber keinen automatischen
Kaltstartaufruf: `FUN_08066fb4` hat im gespeicherten Body keinen direkten
Code-Xref. Seine dynamische Registrierung und der konkrete Eventzustand beim
Kaltstart bleiben ungeklärt. `FUN_081d6680` hat weitere Aufrufer; welche davon
beim normalen Einschalten ausgeführt werden, ist für diesen Befund nicht
entscheidend und wurde nicht auf dem Gerät beobachtet.

## Parsergrenzen und Auswirkung

Der sichtbare Parser liest numerische Felder über feste 4-Byte-Operationen.
Die Datei liefert Zähler für Schleifen, aber diese Zähler werden im geprüften
Code nicht als Allokationsgröße, Kopierlänge oder Adresse benutzt. Die
`FUN_0826c10c`-Tabellenabfrage prüft ihre Indizes: Der Aufrufer erzeugt die
erste Dimension in der festen Schleife 1 bis 11 und die zweite in der festen
Schleife 1 bis 2. Diese Werte liegen innerhalb der geprüften Bereiche 1 bis
11 und 1 bis 2.
Trunkierte bzw. strukturell falsche Felder beenden den Parser über
Fehler-Rückgaben. In den untersuchten Funktionen ist kein Pufferüberlauf,
dateigesteuerter Funktionszeiger oder Kontrollflussfehler erkennbar.

Dateigesteuerte Zähler können zusätzliche Parse-Iterationen verursachen; die
Schleifen lesen dabei jeweils weitere feste Felder aus dem Stream und enden
bei einem Lesefehler. Ein übermäßiger Laufzeit- oder Verfügbarkeitsfehler ist
hier nicht nachgewiesen. Die Daten werden an feste Tuner-Objekte
weitergereicht, deren VTable aus dem OSOS-Code stammt.

**Bewertung:** `TunerSettings` ist ein konkreter persistenter Dateileser,
der über das MainApp-Setup erreichbar sein kann. Der exakte automatische
Kaltstartauslöser bleibt offen; im Parser ist derzeit kein RCE-Kandidat
belegt. Dieser Pfad ermöglicht noch keinen untethered Rockbox-Start.

## Rohbelege

- `/tmp/OSOS_other_persistent_path_refs_20261026.txt`
- `/tmp/OSOS_other_persistent_reader_functions_20261026.txt`
- `/tmp/OSOS_other_persistent_reader_roots_20261026.txt`
- `/tmp/OSOS_tuner_settings_loader_context_20261026.txt`
- `/tmp/OSOS_tuner_fixed_reader_helpers_20261026.txt`
- `/tmp/OSOS_radio_pref_auto_chain_20261026.txt`
- `/tmp/OSOS_mainapp_setup_refs_20261026.txt`
- `/tmp/OSOS_mainapp_setup_dispatch_20261026.txt`
- `/tmp/OSOS_mainapp_dispatch_refs_20261026.txt`
- `/tmp/OSOS_event_dispatch_08066fb4_20261026.txt`
- `/tmp/OSOS_event_dispatch_08066fb4_refs_20261026.txt`

Alle Ghidra-Läufe nutzten `-readOnly -noanalysis`. Die Projektadressen sind
Full-Body-Adressen und dürfen nicht ohne Mapping als Runtime-Adressen
interpretiert werden.
