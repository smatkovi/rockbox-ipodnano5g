# OSOS-Task-SVCs und vermeintliche Prioritätsliste

Stand: 29.10.2026. Ausschließlich read-only Ghidra-Auswertung der vorhandenen
Body- und Runtime-Projekte sowie ein Rohbyteabgleich. Kein USB-/DFU-Polling,
Gerätetest, Reboot oder NAND-/NOR-/Flashzugriff.

## Ergebnis

Die Task-Erzeugung benutzt im OSOS-Prefix getrennte Kernel-Dienste: Dienst
`0x16` richtet Stack-/Kontextdaten für eine Task-ID ein; Dienst `0x15`
initialisiert den gespeicherten CPU-Kontext und verkettet den Taskblock in die
Kernel-Taskliste. Der dazu zuvor verdächtige sortierte Listenhelfer
`FUN_08353328` ist im Runtime-Projekt nicht direkt referenziert. Seine
Sortierung belegt deshalb keine Schedulerprioritäten und löst die Reihenfolge
von `PCFPowerMgr` und `MainAppTask` nicht.

## Adressräume und Aufrufkette

Gleichlautende virtuelle Adressen in den Projekten `N5G_OSOS_runtime` und
`N5G_OSOS_RTOS` dürfen nicht gleichgesetzt werden. Das Runtime-Abbild beginnt
beim Body-Dateioffset `0x2e27c`; der Prefix davor hat einen eigenen
Lade-/Aliasbereich. Im Runtime-Abbild ist `0x0820d544` ein 4-Byte-Veneer
`ldr pc,[0x0820d548]`. Der Literalwert bei `0x0820d548` ist `0x220052c4`.
Der zugehörige Prefix-Wrapper liegt im Full-Body-Projekt bei `0x080052c4`;
die dortigen Bytes sind nicht die gleichadressigen Runtime-Bytes.

Der Body-Wrapper `FUN_080052c4` richtet Stackparameter aus und ruft
`FUN_08005324` auf. Diese baut einen Dienst-Datensatz mit ID `0x16` und geht
über `FUN_08004f14` in den SVC-Dispatcher `FUN_08000b70`. `FUN_080051dc`
verwendet Dienst `0x17`; `FUN_080054fc` verwendet Dienst `0x15`. Die
BootTask-Funktion bei `0x08005058` benennt die Task `BootTask`, fordert einen
`0x800`-Byte-Stack an, konfiguriert ihn über `FUN_080052c4` und ruft danach
`FUN_080054fc` auf.

Im Dispatcher-Fall `0x16` wird die Task-ID geprüft und der Taskeintrag mit
Stack-/Kontextwerten aktualisiert. Fall `0x15` berechnet aus den gespeicherten
Stackgrenzen den initialen Registerkontext, setzt dessen Startwerte und hängt
den Taskblock über die Linkfelder an die Kernel-Liste bei `pcVar2 + 8`. Diese
Operationen vergleichen keine Taskpriorität und verwenden
`FUN_08353328` nicht.

## Einordnung der sortierten Liste

`FUN_08353328` vergleicht das vorzeichenbehaftete 32-Bit-Feld bei
`node + 8` und fügt einen neuen Knoten in eine einfach verkettete, aufsteigend
sortierte Liste ein. Bei gleichen Werten wird hinter vorhandene gleiche Werte
eingefügt. Das beschreibt nur die lokale Listenfunktion.

Ghidras Referenzsuche im Runtime-Projekt meldet null direkte Referenzen auf
`0x08353328`; im Body-Projekt ist die umgerechnete Adresse `0x083815a4`
ebenfalls ohne direkte Referenz. Ein indirekter oder dynamischer Aufruf ist
damit nicht ausgeschlossen. Es gibt aber keinen Beleg, dass diese Liste die
Task-Ready-Liste oder ihr Schlüssel eine Priorität ist. Die Prioritäts- und
Ausführungsreihenfolge der frühen Provider- und MainApp-Tasks bleibt offen.

## Auswirkungen auf die Exploit-Kandidaten

Dies ist kein neuer Exploitkandidat. Es entfernt lediglich die frühere
Vermutung, die sortierte Liste könne den Provideraufbau vor dem automatischen
`accessories.reg`-Open beweisen. `accessories.reg` bleibt der nächstliegende
Kontrollflusskandidat; sein echter Slot-0-VFS-Open und Dateiread sind weiterhin
nicht dynamisch bestätigt. `iPodSettings.xml` bleibt der zweite Kandidat mit
Heap-Metadatenkorruption, aber ohne belegte Kontrolle über lebende Objekte oder
den Programmzähler.

Der nächste Offline-Schritt bleibt ein gezielter Provider-Open-/Read-Rehost
mit den aufgezeichneten FAT-Verzeichnisblöcken und der bekannten
`accessories.reg`-Datei. Ein späterer Gerätetest muss danach weiterhin den
Slot-0-Zustand und den tatsächlichen Parseraufruf bestätigen.

## Rohbelege

Read-only-Auszüge und Prüfsummen liegen unter
`utils/ipodnano5g/analysis/evidence/rtos-task-order-2026-10-29/`:

- `OSOS_runtime_task_veneers_raw_20261029.txt` — Runtime-Veneers und Literalwerte.
- `OSOS_runtime_veneer_sorted_list_20261029.log` — Runtime-Veneer und sortierter Helfer.
- `OSOS_runtime_sorted_list_callers_20261029.log` — direkte Referenzsuche.
- `OSOS_body_task_wrappers_20261029.log` — Wrapper für Dienste `0x15`–`0x17`.
- `OSOS_body_task_service_callers_20261029.log` — Callerzählung im Body-Projekt.
- `OSOS_body_task_svc_dispatcher_20261029.txt` — vollständiger Dispatcherexport.
- `SHA256SUMS` — Hashes der genannten Rohbelege.

## Nachtrag: tatsächliche Kernel-Ready-Liste und Task-Rangfolge (29.10.2026)

Die vorher geprüfte Funktion `FUN_08353328` bleibt ohne belegte Schedulerrolle.
Daneben gibt es aber eine getrennte, tatsächlich vom Kernel verwendete
Ready-Task-Verwaltung: `FUN_08000798` zieht freizugebende TCBs in die
prioritätssortierte Liste ein. Der Einfügepfad vergleicht `TCB[9]`
(Byteoffset `+0x24`) und läuft weiter, solange der vorhandene Wert kleiner
oder gleich dem neuen ist. Die Liste ist somit aufsteigend sortiert; gleiche
Werte bleiben in Einfügereihenfolge. SVC-Dienst `0x16` speichert den Taskwert
an derselben Stelle `DAT_0800163c[id*0x3c + 0x24]`. Der Prioritätsvergleich in
den Kernel-Handlern bestätigt die Nutzung dieses Feldes für Reihenfolge-
änderungen.

Präzisierung vom 31.10.2026: `DAT_08001650` ist kein unabhängiger Listen-
Sentinel. Die Body-Literale zeigen `DAT_08001638 = 0x22009244` und
`DAT_08001650 = 0x22009248 = DAT_08001638 + 4`; `0x22009248` ist das
Current-TCB-Zeigerfeld und zugleich der Kopf der Ready-Liste. Wenn ein
freigegebener TCB eine kleinere Prioritätszahl als der aktuelle TCB hat,
schreibt `FUN_08000798` ihn in dieses Kopf-/Current-Feld. Im normalen
SVC-Abschluss wird anschließend der gespeicherte Stack dieses neuen Current-
TCB zurückgegeben.

Der relevante BootTask-Record liegt bei `0x087600c0 + 0xf0 = 0x087601b0`
(Index 12, Stride `0x14`). Der Konstruktor lädt dort Prioritätsargument `9`,
den Thumb-Einstieg `0x08010c99` und den Namen `DeviceDiscovery`;
`FUN_0819dcbc` schreibt diese Werte in Recordfelder `+4`, `+0xc` und `+0x10`,
und `FUN_0801e2b4` reicht den Prioritätswert direkt an
`arm_820d544`/Dienst `0x16` weiter. Der Code bei `0x08010c98` wartet auf
Queue 4 und ruft im Ereignisfall 0 bei `0x08010cc4`
`FUN_08000a10(r5, 0)` auf. Der Slot-0-Aufruf gehört damit zum Task
`DeviceDiscovery`. Der folgende Record bei `0x087600c0 + 0x104 = 0x087601c4`
(Index 13) enthält Priorität `10`, den Thumb-Einstieg `0x0801845d` und den
Namen `PCFPowerMgr`. Die Tabelle in
`OSOS-FAT-LFN-rehost-impact-followup-2026-10-28.md` hat diese beiden
Tasknamen und Einstiege korrekt zugeordnet; die frühere Zuordnung im
`OSOS-vfs-registration-caller-followup-2026-10-26.md` war um einen Record
verschoben.

Der allgemeine Task-Wrapper bildet andere Erzeugungsargumente um:
`MainAppTask` erhält Eingabe `0x10`, daraus Kernelwert `0x34`;
`ATAWorkLoopTask` erhält `0x18`, daraus `0x33`; `ATAWorkLoopIRQTask` erhält
`0xc0`, daraus `9`. `BootTask` wird direkt mit `0x40` konfiguriert. Damit
steht `DeviceDiscovery` mit Wert `9` vor `PCFPowerMgr` (`10`), ATAWorkLoop
(`0x33`), MainApp (`0x34`) und BootTask (`0x40`), sofern sie gleichzeitig
lauffähig sind. Das korrigiert die frühere Annahme, die Prioritätsrangfolge
sei aus dem Abbild gar nicht bestimmbar.

Der statische Startpfad passt zu dieser Rangfolge: `BootTask` startet die
20 Records in einem zweiten Durchlauf, bevor sein Post-Init später
`MainAppTask` anfordert. Beim `DeviceDiscovery`-Einstieg erzeugt
`FUN_0819ae24(1)` den Gerätewrapper; dessen Wrapper-VTable `0x0853567c` führt über Slot `+0x1c`
nach `FUN_0833b000` und `FUN_0833a6e8` zur Initialisierung `FUN_0833aef0`.
Diese richtet `ATAWorkLoopTask` und `ATAWorkLoopIRQTask` ein. Der Worker
`FUN_0833c4b0` gelangt zu `FUN_0833cc58` und stellt den statischen Knoten
`DAT_0833ccd0` in Queue 4 ein. Der Resetpfad nullt den Knoten; der
Ereignistyp bei `+0x10` ist dadurch zunächst 0. Der Worker-Reset schreibt
innerhalb des Knotens die Offsets `+4`, `+0x11` und die Wörter bei `+0`,
`+4`, `+8`, `+0xc`; er schreibt `+0x10` nicht direkt. Dieses Typbyte liegt
aber innerhalb des vorherigen Löschbereichs (`0x08e51d8c`, Offset
`0x78d9e4` in `[0x086c43a8,0x08e54e4c)`). Eine gezielte read-only-Abfrage
klärt nun den sichtbaren ATA-Worker-Einstieg: `FUN_08193934` ist ein einfacher
Dezimalstring-Parser, kein Wait-/Semaphorehelper. `FUN_0833c4b0` verwirft
seinen Rückgabewert und ruft anschließend `FUN_0833cc58` auf. Die bisherige
Vermutung eines zusätzlichen Ready-Gates an dieser Stelle entfällt damit.
`FUN_0833cc58` postet den initialen Knoten vor seiner Worker-Schleife an
Queue 4; DeviceDiscovery wartet dort und kann nach dem Queue-Post den
Typ-0-Fall ausführen. Zusammen mit der Taskpriorität (DeviceDiscovery 9 vor
ATAWorkLoop 0x33) ist der statische Startablauf plausibel: DeviceDiscovery
richtet den ATA-Worker ein und wartet, danach kann der Worker den Knoten
einstellen. Beim Queue-4-Post ist `DeviceDiscovery` (`9`) höher priorisiert als
`ATAWorkLoopTask` (`0x33`); durch den beschriebenen Kopf-/Current-Einfügepfad
kann der Dispatcher unmittelbar zu `DeviceDiscovery` wechseln. Damit ist der
Slot-0-Versuch statisch vor `MainAppTask` (`0x34`) erreichbar. Der tatsächliche
Gerätelauf und ein erfolgreicher MBR-/FAT-/Datei-Open bleiben unbestätigt.

Der Slot-0-Registrierer nimmt nicht bloß ein beliebiges ATA-Objekt entgegen.
`FUN_08000a10` ruft `FUN_0800196c` auf, das LBA 0 über den Block-Read-Slot des
ATA-Objekts liest. Bei MBR-Signatur `0xaa55` wertet `FUN_0800124c` die vier
primären Partitionseinträge aus, akzeptiert Partitionstypen
`0x01/0x04/0x06/0x0b/0x0c/0x0e` und prüft Start/Länge gegen die gemeldete
Gerätegröße. Der erfolgreiche Typ-2-MBR-Pfad geht über `FUN_0818e998` und
`FUN_0823d468` in `FUN_08110e30`, den FAT-Provider-Konstruktor; der
Registry-Manager speichert den erzeugten Service im angeforderten Slot 0. Dessen
Datei-Open-Methode wird über VTable-Slot `+0x14` zu `FUN_0812a870` geführt.
Damit ist der Slot-0-Provider statisch als FAT-Dienst identifiziert, sofern
Queue-Ereignis, MBR-Prüfung und Provideranlage erfolgreich durchlaufen. Die
archivierte Volume-Prüfung hatte bereits MBR-Signatur `0xaa55` und den Typ-2-
Pfad belegt. Open-/Read-Funktionen und deren Dispatch sind inzwischen statisch
bis zum FAT-Datei-Reader verfolgt; der erfolgreiche Lauf auf Hardware bleibt
ungeprüft.

Das ist eine starke statische Erreichbarkeitskette, aber kein beobachteter
Gerätelauf: Task-Scheduling, Queuezustellung, der Zustand des externen
Speicherdienstes und ein erfolgreicher Slot-0-Registrierungserfolg bleiben
nicht dynamisch bestätigt. Ein erfolgreicher
VFS-Open/Read von `accessories.reg` auf Hardware, der kontrollierte
Parser-Handoff und eine Codeausführung sind unbewiesen. Es gab weiterhin keine Geräte-, USB-,
DFU-, Reboot- oder Flashaktion.

Neue dauerhafte Belege liegen unter
`utils/ipodnano5g/analysis/evidence/rtos-task-order-2026-10-29/`:

- `OSOS_runtime_task_priorities_and_queue4_20261029.log` — Task-Wrapper,
  DeviceDiscovery-/ATA-Aufrufer und Queue-4-Worker.
- `OSOS_runtime_pcf_constructor_slice_20261029.txt` — Recordindex,
  Prioritätsargument und Einsprungzeiger.
- `OSOS_runtime_pcf_entry_20261029.txt` — DeviceDiscovery-Queue- und
  Slot-0-Pfad.
- `OSOS_runtime_task_record_helper_20261029.txt` — Recordfeld-Schreibweise.
- `OSOS_body_kernel_scheduler_ready_list_20261029.log` — Kernel-Ready-Liste,
  BootTask-Parameter und Task-SVCs.
- `OSOS_body_kernel_dispatch_scheduler_20261029.log` — SVC-Dispatcher,
  Taskfeld `+0x24` und Scheduling-Aufruf.
- `OSOS_runtime_queue4_event_type_initialization_20261029.txt` — exakter
  DRAM-Nullungsbereich und Byte-Offset des Queue-4-Ereignistyps; korrigiert,
  dass der Worker selbst `+0x11` statt `+0x10` zurücksetzt.
- `OSOS_runtime_ata_worker_queue4_startup_followup_20261030.txt` und die
  `ghidra_ata_*_20261030.application.log`-Dateien — neuer Nachweis, dass der
  Worker-Einstieg keinen sichtbaren Wait-Gate enthält und der initiale
  Queue-Post auf den Typ-0-Slot-0-Pfad führt.
- `OSOS_runtime_slot0_provider_provenance_20261029.txt` — MBR-Erkennung,
  Partitionsprüfung, FAT-Provider-Aufbau und Eintragung in Registry-Slot 0.
- `OSOS_runtime_slot0_provider_chain_20261029.log` und
  `OSOS_runtime_slot0_type_discriminator_20261029.log` — Registrierer,
  MBR-Erkennung und Servicekonstruktoren.
- `OSOS_runtime_slot0_mbr_type_paths_20261029.log` — MBR-Partitionspfad und
  unterstützte Partitionstypen.
- `OSOS_runtime_accessories_stream_open_read_20261029.log` — Stream-
  Readdispatch, FAT-Provider-VTable, Open- und Dateireadfunktionen.
- `OSOS_runtime_fat_open_read_entries_20261029.log` und
  `OSOS_runtime_fat_read_vtable_verification_20261029.txt` — eindeutiger
  Read-Methodenexport; dokumentiert einen wiederholten Zieladressblock im
  breiteren Batchlog.

## Nachtrag: Open-/Read-Pfad statisch bis zum FAT-Datei-Reader (29.10.2026)

Der automatische Parser-Open `FUN_0802c3c4 -> FUN_082721f0` führt über
`FUN_0827ea84`, `FUN_0819878c` und `FUN_08224970` zum Provider-VTable-Slot
`+0x14`. Die Typ-2-FAT-VTable bei `0x085056b0` bindet diesen Slot an
`FUN_0812a870`; Slot `+0x1c` ist `FUN_0812ac00`, der Datei-Read.

Der Tokenread `FUN_0826dd26` dispatcht über `FUN_08268c3a` zu
`FUN_081b832e`. Der Streamwrapper verlangt die vollständige angeforderte
Länge; dessen gepufferter Pfad `FUN_0820cc90 -> FUN_082a2c48 ->
FUN_0819887c -> FUN_081fd5e8` erreicht den Provider-Read. `FUN_0812ac00`
ordnet den Dateieintrag/Cluster zu und delegiert an `FUN_0814346c`, dessen
Code FAT-/Clusterzustand und Sektorcache für den Read verwendet. Damit ist der
statische Datei-Readpfad geschlossen, nicht aber sein erfolgreicher
Gerätelauf.

Der read-only BPB-/Directory-Snapshot weist für `accessories.reg` Cluster
179788, 69 Byte Dateigröße und 8192 Byte Clustergröße aus. Der 704-Byte-
Kandidat passt in einen einzelnen Cluster; Dateigröße/Verzeichniseintrag
müssten beim Ersetzen angepasst werden. Der Snapshot ist kein vollständiges
Rohabbild des Volumes. Der vorherige QEMU-Wire-Rehost ersetzt Open, Read und
Loader weiterhin durch Stubs und führt keine echten FAT-Sektoren aus.

Details und Grenzen: `OSOS-accessories-fat-read-chain-followup-2026-10-29.md`;
Ghidra-Rohbeleg: `evidence/rtos-task-order-2026-10-29/OSOS_runtime_accessories_stream_open_read_20261029.log`.
