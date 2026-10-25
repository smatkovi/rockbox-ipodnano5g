# OSOS-Service-Factory und Kaltstart-Erreichbarkeit

Stand: 25.10.2026. Diese Auswertung setzt die Offline-Analyse fort. Es gab in
diesem Schritt keine DFU-, USB-, NAND-, NOR- oder Firmware-Zugriffe.

## Analysierte Datei

`/tmp/osos_runtime_dram_20261025.bin` ist ein offline erzeugtes Runtime-Mapping
des OSOS-Bodys. Der Body ist ab Dateioffset `0x2e27c` auf `0x08000000`
abgebildet; die Datei ist kein Live-RAM-Abzug des iPods. Größe: 7.095.208 Byte;
SHA-256: `1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`.

Das Extraktionsskript
[`decode_osos_runtime_tables.py`](decode_osos_runtime_tables.py) erzeugt die
beiden Tabellen im selben Verzeichnis.

## Beim Start ausgeführte Konstruktoren

Die Thumb-Funktion `0x08012a24` läuft über relative 32-Bit-Zeiger und ruft jeden
Eintrag mit `BLX` auf. Aus den Literalwerten und der Thumb-PC-Ausrichtung ergeben
sich Start `0x08550370`, Ende `0x08550774` und 257 Einträge. Ein erster
Zwischendurchlauf verwendete für das Ende `0x08550776`; dadurch wurde ein
zusätzlicher, ungültiger Eintrag erfasst. Die endgültige Graphanalyse verwendet
die korrigierte, ausgerichtete Grenze `0x08550774`.

Eintrag 66 (nullbasiert; der 67. Eintrag) enthält den relativen Zeiger auf
`0x08014601`, also den Thumb-Konstruktor `0x08014600`. Dieser Konstruktor
schreibt die Factory-ID `0x3280` in den Eintrag bei `0x08553a70`. Die zwei
folgenden Wörter des statischen Eintrags sind `0x0801e909` und `0x0801e8f7`.
Der zweite Zeiger zeigt auf `FUN_0801e8f6`, den Thumb-Callback. Dessen
Pseudocode allokiert `0x104` Byte und ruft `FUN_08020fa8` auf; dies ist die
Runtime-Adresse des zuvor untersuchten Controllers `FUN_0804f224`.

Damit ist die Startregistrierung der ID samt Callback-Zeiger belegt. Der
Callback selbst wird dadurch noch nicht beim Start ausgeführt.

## Lazy Lookup

`FUN_081a9ab8` berechnet die ID `0x3280`, fragt über `FUN_081a9af4` den
Factory-Container ab und ruft bei Erfolg die virtuelle Methode am Objekt-Offset
`+0x14` mit der ID auf. Der Lookup geht über `0x0827d69e` und `0x0825e0c6` in
einen generischen Container. Der Controller-Callback `FUN_0801e8f6` wird damit
erst durch einen solchen Lookup ausgeführt.

Die Analyse der direkten Xrefs fand 31 Funktionen, die den Lookup-Dispatcher
aufrufen. Der wichtigste zuvor bekannte Erzeugungspfad ist
`FUN_0801e8f6` → `FUN_08020fa8` → `FUN_08022b84` (`FUN_08050e00` im
Body-Pseudoadressraum); dort werden weitere Dienste angefordert. Diese Kette
erklärt die Erzeugung des Media-Controllers, aber noch nicht, wodurch die
Anforderung im normalen Startpfad ausgelöst wird.

## Erreichbarkeitsergebnis und Grenzen

Ein Ghidra-Direktaufruf-Graph über die 257 Konstruktorziele erreicht bei Tiefe
14 insgesamt 580 Funktionen. Keines der sieben geprüften Media-/ArtworkDB-Ziele
und keiner der 31 direkten Lookup-Aufrufer ist in diesem Graph direkt
erreichbar. Ein separater Graph der frühen Runtime-Wrapper erreichte 168
Funktionen; auch dort wurden diese Ziele nicht direkt erreicht. Die Starts der
OSOS-Task-/Scheduler-Helfer wurden zusätzlich mit korrektem ARM/Thumb-Modus
geprüft. `FUN_08353328` sortiert einen Eintrag in eine verkettete Liste ein;
das ist für sich kein Aufruf des Media-Parsers.

Das ist ein negativer Befund für **statisch aufgelöste direkte Aufrufe**. Er
beweist keine Nichterreichbarkeit: virtuelle Aufrufe, gespeicherte
Callbacks, Scheduler-Dispatch und Laufzeitbedingungen können im Graph fehlen.
Die Calleranalyse ordnet den bekannten Pfad dem Media-Controller zu; sie belegt
nicht, dass ArtworkDB-Daten während jedes Kaltstarts geparst werden.

Die zuvor bestätigten ArtworkDB-Heap-Schreibfehler bleiben daher ein
bedingter Kandidat. Ein Kaltstartpfad bis zum Parser und eine Kontrollfluss-
Übernahme sind nicht nachgewiesen. Auch ein BootROM-Signatur-Bypass, ein
verwendbarer privater Apple-Schlüssel und ein persistenter N5G-Flashpfad wurden
durch diese Arbeit nicht gefunden. Untethered Rockbox ist weiterhin nicht
erreicht.

## Nächste statische Schritte

1. Die Initialisierung und den späteren Dispatch des OSOS-Task-/Callback-Systems
   verfolgen, bis ein konkreter Start- oder Resume-Aufrufer für
   `FUN_081a9ab8` gefunden oder ausgeschlossen ist.
2. Für jeden tatsächlich frühen Aufrufer dessen Laufzeitbedingungen und
   Eingabequelle bis zum ArtworkDB-Parser nachweisen.
3. Erst danach die Auswirkung des Heap-Fehlers mit realistischen Allokationen
   beurteilen; bisher belegt ist kein kontrollierter PC/LR-Wert.
4. Hardwaretests, die DFU oder einen Neustart voraussetzen, bleiben ausgesetzt,
   solange Sebastian nicht vor Ort ist.
