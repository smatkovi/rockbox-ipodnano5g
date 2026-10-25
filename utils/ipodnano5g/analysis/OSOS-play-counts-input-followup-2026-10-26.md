# OSOS-Play-Counts-Datei als persistente Eingabe

Stand: 26.10.2026. Ausschließlich statische Offline-Analyse des Full-Body-
OSOS-Abbilds `osos_body.bin` im read-only-Ghidra-Projekt
`/tmp/N5G_OSOS_RTOS_analysis/N5G_OSOS_RTOS`. Kein Gerätezugriff, USB, DFU,
Neustart oder NAND-/NOR-/Flashzugriff.

## Befund

OSOS enthält zwei Funktionen für `iPod_Control\\iTunes\\Play Counts`:

- `FUN_080df9c8` liest und übernimmt Play-Count-Einträge. Der einzige direkte
  Aufruf im untersuchten Abbild liegt bei `0x081dac7c` in `FUN_081da69c`.
- `FUN_080dfc5c` erzeugt/aktualisiert die Datei. Der gefundene direkte Aufruf
  liegt bei `0x0838d07c` in `FUN_0838cfa0`.

Der Leser wird erst nach dem erfolgreichen Aufbau der Trackliste und nur bei
einem normalisierten Datenbankwert größer 1 aufgerufen. Er öffnet den fest
codierten Pfad, liest einen festen Header von `0x60` Byte in einen entsprechend
großen Stackpuffer und vergleicht dessen Kennung sowie ein Feld mit dem Wert aus
der bereits aufgebauten Trackdatenbank. Danach iteriert er über deren interne
verkettete Liste und liest pro Track genau `0x1c` Byte in einen lokalen
28-Byte-Datensatz. Ein kurzer oder fehlgeschlagener Read beendet die Schleife.

Die gelesenen Felder aktualisieren Zähler, Zeit-/Metadatenfelder und ein
Flagbyte des jeweiligen Trackobjekts. In diesem Pfad wird keine Länge aus der
Datei für eine Allokation, Schleifengrenze, Kopierlänge oder Zieladresse
verwendet; auch werden keine dateigesteuerten Zeiger oder Funktionszeiger
übernommen. Die Addition eines dateigesteuerten Zählers kann numerisch
überlaufen, führt im sichtbaren Code aber nicht zu einer Speicheradresse oder
Kontrollflussentscheidung.

`FUN_080dfc5c` schreibt feste `0x1c`-Byte-Datensätze aus bereits vorhandenen
Trackobjekten. Der sichtbare Writer liefert keinen zusätzlichen
dateigesteuerten Parserpfad.

## Erreichbarkeit und Auswirkung

Die Datei ist ein persistenter OSOS-Eingabepfad, wenn der Media-/iTunesDB-Lader
ausgeführt wird. Die bisherige Startup-Analyse weist jedoch keinen automatischen
Kaltstartaufruf dieses Laders nach. `FUN_081da69c` wird statisch aus
`FUN_08053670` und dem alternativen Einstieg `FUN_081199ac` aufgerufen;
für die vorgeschalteten Loaderwurzel `FUN_0804cb72` und `FUN_081199ac` fehlt
weiterhin ein direkter statischer Startup-Aufrufer. Die bekannte
`TMusicLoadingTask`-Kette ist kontext- und statusabhängig. Dynamische
Task-/Overlay-Aufrufe bleiben möglich, sind aber nicht belegt.

Damit ist Play Counts eine plausible persistente Testeingabe für den
Media-Lader, aber kein bestätigter Speicherfehler, keine RCE und kein
Untethered-Bootpfad. Ein OSOS-RCE, der nach dem verifizierten OSOS-Start bei
jeder Kaltstartverarbeitung einer persistenten Datei automatisch ausgelöst
wird, könnte grundsätzlich den vorhandenen Rockbox-Code aus dem FAT-Dateisystem
in RAM laden. Genau dieser wiederholbare Trigger samt kontrollierter
Codeausführung fehlt weiterhin.

## Belege

- `/tmp/OSOS_playcount_functions_20261026.txt` – Instruktionen und Pseudocode
  für beide Funktionen.
- `/tmp/OSOS_playcount_xrefs_20261026.txt` – direkte Funktions- und String-
  Xrefs; die Rohdatei enthält auch alle extrahierten OSOS-Strings.
- `OSOS-runtime-exploit-boot-feasibility-2026-10-25.md` – bisheriger Stand zu
  ArtworkDB-, Music-Task- und Kaltstart-Erreichbarkeit.

Die Adressen beziehen sich auf den Full-Body-Adressraum. Das Runtime-Abbild
verwendet für diese Funktionen eine andere Basis; Adressen aus beiden Ansichten
dürfen nicht ohne Umrechnung vermischt werden.

## Nächster sinnvoller Offline-Schritt

Die bedingte Music-Task-/Overlay-Kette weiterverfolgen und den Erzeuger des
nichtnulligen Media-Kontexts suchen. Falls diese Kette einen automatischen
Dateilader belegt, dessen Eingaben anhand ihrer festen Reads und
dateigesteuerten Speicherzugriffe priorisieren. Bis dahin ist keine
Geräteaktion nötig.
