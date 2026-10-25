# OSOS-Resume-Handler und Kaltstart-Erreichbarkeit

Stand: 25.10.2026. Nur Offline-Analyse des Runtime-Abbilds
`/tmp/osos_runtime_dram_20261025.bin` (Body-Offset `0x2e27c` auf VA
`0x08000000` abgebildet). Kein USB-, DFU-, Neustart-, NAND- oder NOR-Zugriff.

## Ergebnis

Eine Laufzeitlücke im signierten OSOS könnte prinzipiell Rockbox starten, wenn
sie beim normalen Kaltstart automatisch erneut ausgelöst wird und genügend
Kontrolle über den Ausführungspfad erhält. Der bestehende Rockbox-Loader kann
danach aus persistenten FAT-Dateien laden; ein solcher automatischer OSOS-RCE-
Trigger ist weiterhin nicht belegt.

Die neu geprüften Resume-Bezeichner schließen diese Lücke nicht:

- Der Dispatcher ab `0x0804c3e4` vergleicht den übergebenen Namen mit
  `HandleExit`, `HandleLap`, `HandleResume` und `HandleStartStop`. Beim Namen
  `HandleResume` ruft er `FUN_0804c494` nur auf, wenn das zweite Argument nicht
  dem Sentinel `0xdeadbeef` entspricht. Der Handler prüft ein Objektfeld bei
  `param+0xdc`, ruft abhängig vom Zustand weitere Dienste auf und plant über
  `FUN_08270208(param, 500)` eine spätere Verarbeitung ein. Das ist ein
  namebasierter Aktionspfad; ein Datei- oder Kaltstarttrigger ist daran nicht
  nachgewiesen.
- Der Dispatcher ab `0x080b4114` behandelt Namen wie `HandlePlayPause`,
  `HandleAddChapterMark`, `ResumeRecord`, `BeginSave` und `FinishSave`. Für
  `ResumeRecord` verzweigt er bei einem gültigen zweiten Argument nach
  `FUN_080ce0f4`. Auch hier belegen die Strings nur eine Dispatch-Option, keine
  automatische Verarbeitung persistenter Benutzerdaten.
- Ghidra findet den Aufruf von `FUN_0804c494` aus dem Resume-Zweig bei
  `0x0804c442`. Die Dispatcher selbst erscheinen in statischen
  Funktionszeigertabellen (`0x084f94b4`, `0x085160e8` für `0x0804c3e4`;
  `0x084f9624`, `0x0851625c`, `0x085163e4` für `0x080b4114`). Eingehende
  direkte Codeverweise auf diese Tabellen oder einen normalen
  Kaltstart-Aufrufpfad wurden nicht gefunden. Dynamische Registrierung,
  Laufzeitdaten und nicht enthaltene Overlays bleiben offen.

## Bedeutung für den Rockbox-Start

Ein einmaliger Fehler nach dem Start von OSOS kann eine PC-freie
Rockbox-Übergabe ermöglichen, ohne eine Apple-Signatur zu erzeugen: Das
unveränderte OSOS startet regulär, der Fehler lädt anschließend den Rockbox-
Loader aus einer persistenten Datei in RAM und übergibt die CPU-Kontrolle.
Für den gewünschten automatischen Start fehlt weiterhin eine bei jedem
Kaltstart erreichte Eingabe bis zu Codeausführung. Der gesperrte Hold-Fall muss
vor einer möglichen erneuten Exploit-Ausführung in den Apple-OS-Pfad gelangen.

Die vorhandenen Kandidaten erfüllen diese Kette noch nicht: Notes hat einen
bedingten UTF-8-/Speicherfehler ohne bestätigte Kontrollflussübernahme;
ArtworkDB hat einen Heap-Schreibfehler ohne nachgewiesenen automatischen
Parseraufruf; beim Task-Argumentparser fehlt ein persistenter kontrollierbarer
Eingabepfad. Der Resume-Dispatcher ergänzt derzeit keinen belegten Einstieg.

## Belege

- `/tmp/OSOS_handle_resume_dispatch_20261025.txt`
- `/tmp/OSOS_resume_record_dispatch_20261025.txt`
- `/tmp/OSOS_resume_handler_refs_20261025.txt`
- Runtime-Projekt: `/tmp/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime.gpr`
- Vorherige Bewertung: [`OSOS-runtime-exploit-boot-feasibility-2026-10-25.md`](OSOS-runtime-exploit-boot-feasibility-2026-10-25.md)

Die Ghidra-Referenzsuche lief mit `-noanalysis -readOnly`; die
Thumb-Disassemblierung erfolgte lokal mit `arm-none-eabi-objdump`.
