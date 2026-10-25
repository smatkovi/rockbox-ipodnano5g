# OSOS-Notes-Dispatch: Kaltstart-Folgeprüfung (2026-10-25)

## Fragestellung

Kann der Notes-Pfad nach dem Kaltstart automatisch in den bereits gefundenen
UTF-8-/Pfadfehler laufen und damit als wiederholbarer OSOS-Einstieg dienen?
Diese Prüfung war offline und read-only. Es gab keinen Zugriff auf USB, DFU,
Neustart, NAND oder NOR.

## Verifizierte Tabellen- und Factory-Verbindungen

- Der Funktionszeiger `0x08030da5` für `FUN_08030da4` steht bei
  `0x0853647c`. Der benachbarte Eintrag `0x08536470` enthält
  `0x08030ed1` (`FUN_08030ed0`). Beide Methoden rufen mittelbar den
  Notes-Ordner-Scanner `FUN_08240f00` auf: `FUN_08030ed0` direkt und
  `FUN_08030da4` über `FUN_08038ec8`.
- Die Methoden liegen in einer größeren Funktionszeigertabelle ab
  `0x085363c8`. `FUN_08021294` und `FUN_08042ce0` schreiben deren Adresse als
  Objekt-VTable. `FUN_08021294` richtet den Notes-Controller ein und registriert
  die Komponenten `TCNotesDispatcher`, `TCNotesLoading`, `TCNotesList` und
  `TCNotesContents`.
- Die frühe Factory-Zeile bei `0x08553a40` trägt ID `0xa980` und verweist auf
  `FUN_0801e90c`; diese Wrapperfunktion ruft `FUN_08021294` auf. Der bereits
  verifizierte MainApp-Factory-Batch verarbeitet diese Factory während der
  MainApp-Initialisierung. Damit ist eine frühe **Registrierung** des
  Notes-Controllers belegt, aber noch kein Öffnen einer Notizdatei.

## Möglicher späterer Übergang zu Notes

`FUN_080c3f28` ruft unter einer Zustandsbedingung `FUN_082544ac` auf. Bei
nichtnulligem Ergebnis erstellt sie das Ereignis `GotoNotesApp` und übergibt
es über einen virtuellen MainApp-Slot. `FUN_080ab680` ist ein direkter Aufrufer
von `FUN_080c3f28`; `FUN_080ab680` selbst liegt als Funktionszeiger bei
`0x08525a30` in einer weiteren Methodentabelle.

Der statische direkte Aufrufgraph ab `FUN_080202d8` (MainApp-Start),
`FUN_08023e90` (Factory-Batch) und `FUN_0804faa0` (Factory-Callbacks) erreichte
bei Tiefe 24 insgesamt 3.484 Funktionen, aber nicht `FUN_080ab680`,
`FUN_080c3f28`, `FUN_082544ac`, `FUN_08030da4`, `FUN_08038ec8` oder
`FUN_08030ed0`. Das schließt virtuelle Aufrufe, gespeicherte Event-Callbacks,
Scheduler- und Overlay-Dispatch ausdrücklich nicht aus. Die Methode
`FUN_080ab680` ist im statischen Image nur als Tabellenzeiger referenziert;
ein direkter Aufrufer und die Instanziierung dieser Tabelle konnten nicht
zugeordnet werden.

## Bewertung für untethered Rockbox

Eine Schwachstelle im normal signierten OSOS bleibt prinzipiell ein möglicher
Weg zu einem Rockbox-RAM-Handoff: Ein persistenter Datensatz müsste den
verwundbaren Parser automatisch bei jedem Kaltstart erreichen und der Fehler
müsste Codeausführung erlauben. Die neuen Befunde belegen einen frühen
Notes-Controller und einen späteren möglichen `GotoNotesApp`-Übergang, aber
keinen automatischen Kaltstart-Dispatch bis zum Notes-Scanner. Der vorhandene
UTF-8-Unterlauf ist weiterhin weder als Codeausführung noch als stabiler
Kontrollflussfehler bestätigt. Es wurde daher keine ausnutzbare Lücke und kein
untethered Bootpfad gefunden.

Das lokale Verzeichnis `device-backup-20261024` enthält in dieser Arbeitskopie
nur `.rockbox`-Dateien; Apple-Notes und eine Apple-Medienbibliothek stehen hier
nicht als Eingaben für eine Offline-Gegenprüfung bereit.

## Rohbelege und Wiederholung

Runtime-Image: `/tmp/osos_runtime_dram_20261025.bin`, SHA-256
`1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`.
Read-only-Ghidra-Projekt: `/tmp/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime.gpr`.

- `/tmp/OSOS_notes_vtable_methods_20261026.txt`
- `/tmp/OSOS_notes_view_factories_20261026.txt`
- `/tmp/OSOS_notes_dispatch_owner_20261026.txt`
- `/tmp/OSOS_notes_autostart_reachability_20261026.txt`
- `/home/sebastian/ipod-re/nano5g/ghidra-logs/FindOSOSReferenceBatch.java`
- `/home/sebastian/ipod-re/nano5g/ghidra-logs/AnalyzeOSOSFunctions.java`
- `/home/sebastian/ipod-re/nano5g/ghidra-logs/TraceOSOSCallGraph.java`

Die Ghidra-Läufe verwendeten `-noanalysis -readOnly`; die zusätzlichen Exporte
liegen unter `/tmp` und verändern das Projekt nicht.
