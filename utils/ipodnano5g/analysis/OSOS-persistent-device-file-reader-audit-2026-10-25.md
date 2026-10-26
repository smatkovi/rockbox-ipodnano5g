# OSOS-Persistenzdateien: zusätzlicher Leser-Audit

Stand: 25.10.2026. Ausschließlich statische Offline-Analyse von
`osos_body.bin` im read-only-Ghidra-Projekt
`/tmp/N5G_OSOS_RTOS_analysis/N5G_OSOS_RTOS`. Kein Gerätezugriff, USB, DFU,
Neustart oder Flashzugriff.

## Ergebnis

Eine Schwachstelle in der laufenden, signierten OSOS-Software könnte
grundsätzlich einen PC-unabhängigen Rockbox-Start ermöglichen: Ein Exploit
müsste bei jedem Kaltstart durch eine persistente Datei automatisch ausgelöst
werden, Codeausführung erreichen und den vorhandenen Rockbox-Loader aus der
FAT-Partition in RAM starten. Das würde die Signaturprüfung der vorherigen
Bootstufen nicht umgehen. Für die bisher geprüften Kandidaten bleibt gerade
der wiederholbare automatische Trigger unbelegt.

Dieser Schritt hat zusätzliche OSOS-Dateipfade eingegrenzt:

- `iPod_Control/Device/alarms`: `FUN_0828f144` kann im Modus `param2 == 0`
  Datensätze laden. Der einzige gefundene direkte Aufrufer dieses Modus ist
  `FUN_08079610`, das von `FUN_08067588` aufgerufen wird. Für `FUN_08067588`
  wurde weder ein direkter Codeaufrufer noch ein gespeicherter Thumb-Zeiger
  `0x08067589` im OSOS-Abbild gefunden. Ein zusätzlicher Rohscan fand auch
  keine absoluten Thumb-Zeiger auf `0x08067589`, dessen Runtime-Adresse
  `0x0803930d` oder dessen Prefix-relokierte Adresse `0x2203930d` in den
  extrahierten IPSW-Segmenten und `Firmware.MSE`. Ein Scan des OSOS-Bodys nach
  einfachen 32-Bit-relativen Einträgen zu diesen Zielen blieb ebenfalls leer.
  Das schließt dynamisch erzeugte, anders kodierte oder nicht extrahierte
  Dispatches nicht aus; automatischer Kaltstart ist nicht belegt.
- `iPod_Control/Device/Users`: `FUN_0828bd04` ruft `FUN_081ddc3c` mit
  `param2 == 1` auf; dieser Modus serialisiert die interne Objektliste. Ein
  automatischer Import ist in dem damaligen Teil-Audit nicht belegt.
- `iPod_Control/Device/PlayCounts`: `FUN_0828bd04` ruft `FUN_081dde48` mit
  `param2 == 1` zum Schreiben auf. Ein separater Runtime-Pfad `FUN_081afbcc`
  liest dieselbe Datei im MainApp-Kaltstart mit `param2 == 0`; siehe Nachtrag
  unten. Die frühere Einordnung als nur beobachteter Writer war unvollständig.
- `iPod_Control/Device/iPod_Contacts.db`: `FUN_08277218` erstellt lazy einen
  kleinen Pfad-haltenden Heap-Eintrag für diese Datenbank. Die Funktion selbst
  parst keine Daten. Vier direkte Aufrufer wurden gefunden, ihre vollständige
  Erreichbarkeit und ein möglicher Parser dahinter wurden in diesem Schritt
  nicht untersucht.

Für den Alarm-Parser ist damit ein persistenter Eingabepfad belegt, aber keine
Kontrollflussübernahme. Ein bedingter Stack-OOB-Read-Kandidat ist jedoch
sichtbar: Für Feldtag `0x3c` liest `FUN_081f2dd2` über `FUN_0825ae7e` höchstens
`0x100` Byte in einen gleich großen Stackpuffer. Der Reader begrenzt zwar die
Länge, schreibt aber keinen NUL-Terminator. Danach ruft der Parser
`FUN_081c1968` auf; diese Funktion ermittelt die Länge über
`FUN_081c4d42`, eine unbeschränkte `strlen`-Schleife, und kopiert so viele
Bytes aus dem Puffer in das Stringziel. Ein 256-Byte-
Feld ohne NUL kann deshalb über das Pufferende hinaus Stackbytes lesen und
anschließend in den String übernehmen. Der sichtbare Pfad schreibt nicht über
das Zielobjekt hinaus, weil es mit der ermittelten Länge angelegt wird. Damit
ist derzeit nur ein möglicher OOB-Read/Stackdatenübertrag in ein internes
Objekt belegt, keine RCE oder Kontrollflussübernahme. Ob Tag `0x3c` in einer
realen Alarmdatei frei kontrollierbar ist, wurde nicht mit einer Fixture
geprüft. Die Gegenrichtung schreibt Tag `0x3c` mit der von
`FUN_081c4d42` berechneten Länge einschließlich NUL-Byte; damit ist das Feld
im normalen Writer ein C-String und der Importer prüft die erwartete
Terminierung nicht.

## Belege

- `/tmp/OSOS_device_persistent_file_handlers_20261026.txt` – Alarm-, Users-,
  PlayCounts- und Contacts-Routinen.
- `/tmp/OSOS_device_alarms_context_20261026.txt` – direkte Alarm-Leser und
  Parserhelfer.
- `/tmp/OSOS_alarm_string_import_helper_20261026.txt` – `strlen`- und
  Stringkopierpfad für Alarmfeld `0x3c`.
- `/tmp/OSOS_device_file_service_roots_20261026.txt` – Aufrufer von
  `FUN_0828bd04`, einschließlich MainApp-Setup `FUN_08086ce8`.
- Read-only-Ghidra-Referenzläufe: direkte Referenzen auf
  `FUN_08079610`, `FUN_0828bd04` und die Datei-Wrapper; Rohresultate wurden
  während dieser Analyse über die Headless-Konsole ausgegeben.

Der separate, bereits bekannte ArtworkDB-Heap-Schreibfehler bleibt der
stärkste statische Speicherkorruptionskandidat. Seine automatische
Kaltstarterreichbarkeit und eine Kontrollflussübernahme sind weiterhin nicht
nachgewiesen. Das angeschlossene Gerät blieb unberührt und im bisherigen
U-Boot-Zustand; es wurden keine Boot-, Reset-, NAND-/NOR-Schreib- oder
-Löschaktionen ausgeführt.

## Nächste Offline-Schritte

1. Prüfen, ob Alarmfeld `0x3c` laut Format NUL-terminiert oder binär ist und
   welche Stackbytes bei maximaler Länge in das Stringobjekt gelangen.
2. Indirekte Registrierung bzw. externe Dispatch-Wurzel von
   `FUN_08067588` untersuchen.
3. Die vier Aufrufer von `FUN_08277218` bis zu einem möglichen
   Contacts-DB-Parser und dessen Startbedingungen verfolgen.
4. Den vorhandenen ArtworkDB- und Music-Loading-Task-Pfad weiter auf einen
   automatischen Kaltstarttrigger eingrenzen.

## Nachtrag: AlarmTask im Starttask-Table (26.10.2026)

Der relative Constructor `FUN_08013d44` enthält tatsächlich einen Task-Eintrag
mit Namen `AlarmTask`. Sein Thumb-Einstieg ist `0x08010be8` (`0x08010be9` als
Funktionszeiger). Der Einstieg wurde im Runtime-Projekt read-only exportiert.
Er richtet einen 20-Byte-Ereigniskontext ein und wartet in einer Endlosschleife
auf Ereignisse. Die sichtbaren Fälle `9`, `10`, `11` und `0x11` konfigurieren
Alarm-/Timer-Dienste oder ändern den Zustand der Taskinstanz; der Fall `0x11`
setzt unter anderem über `FUN_0800a6f0` ein Flagbyte. Im Taskkörper gibt es
keinen Aufruf des persistenten Alarmdatei-Parsers `FUN_0828f144` und keinen
Dateizugriff.

Die Alarmdatei wird im MainApp-Setup `FUN_08086ce8` über
`FUN_0828bd04` → `FUN_081769ca` mit `param2 == 1` verarbeitet. Dieser Modus
schreibt den internen Alarmzustand; er importiert die Datei nicht. Der
Importmodus `param2 == 0` wird im untersuchten Abbild nur über
`FUN_08079610` → `FUN_0828f144` erreicht, wobei der einzige direkte Aufrufer
von `FUN_08079610` weiterhin `FUN_08067588` ist. Für `FUN_08067588` wurde
keine Referenz aus dem `AlarmTask` oder dem statischen Starttask-Table
gefunden; eine externe/dynamische Registrierung ist nicht ausgeschlossen.

Der Eintrag zeigt, dass `AlarmTask` für den OSOS-Task-Dispatcher vorgesehen
ist; die tatsächliche Kaltstarterreichbarkeit des externen Constructor-Runners
bleibt offen. Auch der Taskkörper belegt keinen Alarmdatei-Import. Der
bereits dokumentierte Feld-`0x3c`-Pfad bleibt ein bedingter Stack-OOB-Read,
aber weder der automatische Import noch Kontrollflussübernahme oder RCE sind
belegt.

Read-only-Rohbelege:

- `/tmp/OSOS_AlarmTask_entry_20261026.txt`
- `/tmp/OSOS_AlarmTask_event11_callback_20261026_ARM.txt`
- `/tmp/OSOS_device_alarms_context_20261026.txt`
- `/tmp/OSOS_device_file_service_roots_20261026.txt`
- `/tmp/OSOS_task_table_init_thumb.txt`

Das Runtime-Abbild ist ein statisches Mapping, kein Live-RAM-Dump. Es gab
keinen Geräte-, USB-, DFU-, Boot- oder Flashzugriff.

## Nachtrag: Device/PlayCounts wird im MainApp-Kaltstart importiert (26.10.2026)

Die Datei `iPod_Control/Device/PlayCounts` ist von der separaten Datei
`iPod_Control/iTunes/Play Counts` zu unterscheiden. Der `TEAppShell`-VTable-
Eintrag `+0xa8` zeigt auf `FUN_08028254`; der dokumentierte MainApp-Factory-
und Child-Lifecycle ruft diese Methode beim Kaltstart auf. Sie ruft
`FUN_081afbcc(param + 0x7c, 0)` auf. Dieser Modus öffnet den festen
`Device/PlayCounts`-Pfad im Lesemodus und parst Tokens `0x3d`, `0x3e` und
`0x3f`; andere Tags gehen an `FUN_0826dca0`.

Der `0x3e`-Feldleser (`FUN_0822cc02`) begrenzt die gelesene Länge auf `0x40`,
während der Caller nur einen 56-Byte-Stackpuffer bereitstellt. Ein maximaler
Read kann deshalb acht Bytes in die lokalen Slots bei `sp+0x3c` und `sp+0x40`
schreiben. Im Importzweig werden diese Slots nicht als Parserzustand benutzt;
der gespeicherte LR liegt weiter oben und wird von diesem begrenzten Write
nicht direkt erreicht. `FUN_081936ec` ermittelt anschließend mit einer
NUL-Suche die Stringlänge und legt ein entsprechend großes Zielobjekt an. Ein
fehlendes NUL kann über das Feldende hinaus Stackbytes lesen; eine
Kontrollflusswirkung oder verwertbare Offenlegung ist damit noch nicht
nachgewiesen.

Der allgemeine Skip-Parser `FUN_0826dca0` behandelt Tags mit Oberbyte `0x40`
rekursiv und kehrt erst bei einem passenden `0xc0`-Endtag zurück. Ein
Rekursionstiefenzähler ist im Funktionskörper nicht sichtbar; pro Ebene sichert
er sechs Register (24 Byte). Der MainApp-Task wird mit einem
Stackgrößenargument `0x20000` angelegt: Das Wort an Runtime-VA `0x085512dc`
ist `0x2000`, und `FUN_0801e3a4` verschiebt es vor dem Aufruf von
`FUN_08193984` um vier Bits nach links. Tief verschachtelte gültig gepaarte
Container sind deshalb ein plausibler Task-Stack-Absturzpfad. Der normale
Writer erzeugt nur die bekannten Tags `0x3d`, `0x3e` und `0x3f`; die
verschachtelten unbekannten Tags erfordern daher eine geänderte Eingabedatei.
Die tatsächliche Stackgrenze, ein möglicher Guard und der angrenzende Speicher
gehören zum importierten Taskdienst und sind im Abbild nicht aufgelöst. Das
belegt weder kontrollierte Return-Adress-Korruption noch RCE.

Der vorhandene Streampfad übergibt `0x8000` als Puffergröße; der Streamzustand
startet mit Restlänge `0xffffffff` und lädt weitere Blöcke nach. In diesem
Wrapper wurde kein Gesamtdateilimit gefunden. Ein echtes Device/PlayCounts-
Dateibeispiel fehlt im lokalen Backup; auch die Host-Schreibbarkeit genau
dieses Pfads ist offline nicht verifiziert.

Rohbelege: `/tmp/OSOS_TAppShell_method_08028254_20261026.txt`,
`/tmp/OSOS_TAppShell_corrected_vtable_and_second_lifecycle_20261026.txt`,
`/tmp/OSOS_recursive_skip_direct_callers_20261026.txt`,
`/tmp/OSOS_function_0826dca0_20261026.txt`,
`/tmp/OSOS_playcounts_helpers_20261026.txt`,
`/tmp/OSOS_playcounts_stream_bounds_20261026.txt`,
`/tmp/OSOS_function_08271014_20261026.txt`,
`/tmp/OSOS_function_0818f134_20261026.txt`,
`/tmp/OSOS_timer_reader_state_20261026.txt`,
`/tmp/OSOS_task_create_MainAppTask_helper_20261026.txt`,
`/tmp/OSOS_boot_mainapp_task_setup_20261026.txt`,
`/tmp/OSOS_playcounts_callers_20261026.txt` und
`/tmp/OSOS_device_persistent_file_handlers_20261026.txt`. Alle Ghidra-Läufe
waren `-noanalysis -readOnly`; keine Geräte-, USB-, DFU-, Boot- oder
Flashaktion.
