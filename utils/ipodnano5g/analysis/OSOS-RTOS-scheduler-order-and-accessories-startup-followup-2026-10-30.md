# RTOS-Startreihenfolge und Accessories-Open (30.10.2026)

Stand: 30.10.2026. Ausschließlich read-only Ghidra- und Binärbildanalyse.
Kein Geräte-/USB-/DFU-Zugriff, Neustart oder Flashzugriff.

## Neue Einordnung des Kernel-Trampolins

`FUN_080039b0` wurde zunächst als möglicher Scheduler-/Taskwechselpfad
untersucht. Die ARM-Instruktion bei `0x080039b0` ist jedoch nur ein
`ldr pc,[pc,#-4]`-Trampolin; sein Literal bei `0x080039b4` enthält
`0x08365104`. Der Runtime-Dump vom 25.10. enthält an diesem Ziel ARM-Code:

```asm
mrc   p15, 0, r2, cr1, cr0, {2}
cmp   r0, #0
biceq r2, r2, #0x00f00000
orrne r2, r2, #0x00f00000
mcr   p15, 0, r2, cr1, cr0, {2}
bx    lr
```

Das Zielregister ist CP15 c1,c0,2, der Coprocessor Access Control Register
(CPACR), nicht der Domain Access Control Register. Bits 20–23 sind die
Zugriffsrechte für CP10 und CP11. Mit Argument `0` löscht der Helper diese
Bits; bei einem Argument ungleich null setzt er sie. Er wählt keinen TCB und
führt selbst keinen Taskwechsel aus. Die ARM1176-Dokumentation ordnet
`MRC/MCR p15,0,Rd,c1,c0,2` dem CPACR zu und beschreibt diese beiden Felder
als Coprozessor-Zugriffsrechte ([ARM1176JZF-S Technical Reference Manual,
Abschnitt 3.2.9](https://documentation-service.arm.com/static/5e8e294efd977155116a6ca3)). Das statische
`osos_body.bin` enthält an derselben virtuellen Adresse andere Bytes. Body-
und Runtime-Abbild dürfen hier nicht vermischt werden. Der volle Runtime-
Dump/Hash und der unabhängige ARM-Disassembly-Auszug liegen bei den
Rohbelegen unten.

Der eigentliche Kontext-Restore liegt in `FUN_08004f44`: Er setzt `sp` auf
den übergebenen Kontext, restauriert `SPSR` und Register und lädt anschließend
`pc` via `ldmia ... {r0-r12,lr,pc}^`. `FUN_08000b70` ist der SVC-Dispatcher;
sein Dienst `0x15` initialisiert einen Task-Kontext und verkettet den Task in
die Kernelverwaltung. `FUN_08000798` übernimmt freizugebende Tasks in die
Ready-Liste. Diese wird anhand `TCB+0x24` aufsteigend sortiert. Das belegt die
Sortierreihenfolge, aber die Rohbilder allein belegen keinen vollständigen
Kaltstart-Trace der jeweils zuerst restaurierten Task.

Ein zweiter Body-Veneer trennt die Prioritätsverwaltung klarer vom
Kontextwechsel: `0x08003990` lädt über sein Literal bei `0x08003994` das
Runtime-Ziel `0x083531f8`. Dieses Ziel schreibt den übergebenen Wert nach
`[TCB+0x24]` und entfernt/verkettet den TCB abhängig von seinem Listenstatus
neu. Der bedingte Pfad bei gesetzten Statusbits `0xaa` verzweigt zu
`0x08354cb0`; dessen Folgeroutine vergleicht ebenfalls Prioritätsfelder bei
`TCB+0x24` und sortiert einen weiteren doppelt verketteten Pfad um. Das passt
zu Prioritäts-/Wartelistenpflege. Der Helper restauriert selbst keinen
Registerkontext; ein dynamischer Beleg, dass diese Operation unmittelbar
`MainAppTask` verdrängt, liegt nicht vor. Body-Literal, Ghidra-Veneerexport
und Runtime-Disassembly sind als Rohbelege gespeichert.

Die Queue-Übergabe ist jetzt ebenfalls konkreter: `ATAWorkLoopTask` ruft den
QueuePost-Alias `0x220058b4` mit Dienst 4, Queue-ID 4 und dem statischen
Typ-0-Record auf. `DeviceDiscovery` verwendet den QueueGet-Dienst 5 für
Queue 4. Ist die Queue leer und ein Wait angefordert, trägt der Dispatcher den
Empfänger als wartend ein (Status 5/Flag `0x20`). Der Dienst-4-Pfad nimmt beim
Post einen vorhandenen Waiter aus der Queue-Warteliste und entfernt dessen
Warteflag; der freigegebene TCB wird anschließend vom Scheduler in die
prioritätssortierte Ready-Liste übernommen. Der gemeinsame SVC-Abschluss
verarbeitet diese Freigaben und ruft danach den Kontext-Restore auf. Damit ist
der statische Queue-4-Übergang von „wartet“ zu „bereit“ nachvollziehbar.
Offen bleibt, ob und wann dieser konkrete Dispatcher nach dem Post den Kopf
der Ready-Liste statt des aktuellen ATA-Tasks restauriert; ein dynamischer
Kaltstart-Trace fehlt weiterhin. Zusätzlich ist `FUN_0800073c` kein
Taskselektor, sondern fügt zeitbegrenzte Warteobjekte anhand ihrer Frist in
eine separate Timerliste ein.

## Bedeutung für Slot 0 und `accessories.reg`

Die bekannten TCB-Werte sind:

- `DeviceDiscovery`: statischer BootTask-Record mit Wert `9`; sein Queue-4-
  Event-0-Zweig ruft den Slot-0-MBR-/Providerpfad auf.
- `ATAWorkLoopTask`: allgemeiner Taskhelper-Eingabewert `0x18`, Kernelwert
  `0x33`; beim Einstieg wird der Queue-4-Record mit Typ 0 gepostet.
- `MainAppTask`: Taskhelper-Eingabewert `0x10`, Kernelwert `0x34`; sein
  Initialisierungspfad ruft den `accessories.reg`-Parser.
- `BootTask`: wird mit Wert `0x40` gestartet.

Die Ready-Liste sortiert kleineres `TCB+0x24` vor größerem. Unter der
zusätzlichen Annahme, dass der Kernel bei einem Block/Yield den Kopf dieser
Liste zuerst restauriert, passt die Folge zum gewünschten Providerzustand:
DeviceDiscovery wartet auf Queue 4; der ATA-Worker postet den initialen
Typ-0-Record; DeviceDiscovery wird aufgeweckt und registriert nach erfolgreichem
MBR/FAT-Pfad Slot 0. `MainAppTask` mit `0x34` würde danach laufen. Das ist eine
starke statische Plausibilität, keine dynamisch bestätigte Ausführungsfolge.
Besonders die unmittelbare Dispatch-/Preemptionssemantik der Start-, Wait- und
Queue-Dienste ist mit dem aktuellen Nachweis nicht vollständig geklärt.

Der Fehlerfall ist relevant: `FUN_0802c3c4` prüft direkt nach dem Open
`FUN_082721f0` den Rückgabewert. Bei Open-Fehler schließt der Parser den
Stream und kehrt vor dem Tokenread zurück. Der sichtbare Startup-Caller
`FUN_08022b08` ruft den Parser synchron auf. Ist Slot 0 zu diesem Zeitpunkt
noch unregistriert, reicht die spätere Providerregistrierung für genau diesen
Parseraufruf nicht aus. Ein automatischer Wiederholungsaufruf nach erfolgreichem
Mount ist bislang nicht belegt.

## Verifizierter Stand und Grenzen

- Der `FUN_080039b0`-Pfad ist ein CP15-Registerhelper und kein Taskselektor.
- Die Ready-Liste vergleicht `TCB+0x24` und ist aufsteigend sortiert.
- Queue-4-Record, DeviceDiscovery-Event-0 und der Slot-0-Registrierer sind
  statisch verbunden.
- MainAppTask-Open und unmittelbarer Fehler-Return sind statisch belegt.
- Eine tatsächliche Kaltstart-Reihenfolge, erfolgreiches MBR-/FAT-Mount,
  VFS-Open/Read, Parserausführung oder Rockbox-Handoff wurde nicht beobachtet.
- Die gespeicherten Dateiaufnahmen belegen weder den heutigen Gerätestand noch
  einen installierten Kandidaten.

## Rohbelege

Unter `analysis/evidence/rtos-task-order-2026-10-29/`:

- `OSOS_runtime_scheduler_domain_helper_ARM_20261030.disasm.txt` — Runtime-
  Instruktionen des CP15-Helpers an `0x08365104`.
- `OSOS_body_priority_vector_literals_20261030.txt`,
  `OSOS_body_priority_preemption_helper_20261030.log` und
  `OSOS_runtime_priority_list_helper_083531f8_20261030.disasm.txt` — getrennte
  Priority-Veneer-Literalauflösung, Ghidra-Export und Runtime-Zielcode.
- `OSOS_runtime_scheduler_vector_xrefs_20261030.log` — Body-Trampolin,
  Literalziel und direkte Aufrufer.
- `OSOS_runtime_scheduler_selected_task_followup_20261030.log` — read-only
  Ghidra-Abfrage zum Bodyziel; dokumentiert, dass dort in diesem Projekt
  keine Funktion angelegt ist.
- `OSOS_runtime_scheduler_target_runtime_snapshot_20261030.log` — read-only
  Ghidra-Abfrage des Runtime-Snapshots.
- `OSOS_body_scheduler_dispatch_followup_20261030.log` — SVC-Dispatcher,
  Kontext-Restore und Tasklistenoperationen.
- `OSOS_body_task_create_scheduler_enqueue_followup_20261030.log` — Task-
  Create-/Ready-List-Code.
- `OSOS_runtime_task_create_dispatch_entry_20261030.log` — Runtime-Veneer
  für den Starttaskdienst.
- `OSOS_body_boot_task_start_order_followup_20261030.log` und
  `OSOS_body_boot_task_entry_and_mainapp_handoff_20261030.log` — BootTask-
  Erzeugung, Dienstnummern und Einstieg.
- `OSOS_runtime_boot_task_postwait_path_20261030.log` — Runtime-Auswertung
  des relocierten BootTask-Folgepfads.
- `OSOS_runtime_task_priorities_and_queue4_20261029.log`,
  `OSOS_runtime_ata_worker_queue4_startup_followup_20261030.txt`,
  `OSOS_runtime_queue4_event_type_initialization_20261029.txt` und
  `OSOS_runtime_slot0_provider_provenance_20261029.txt` — Taskwerte,
  Queue-4-Ereignis und Slot-0-FAT-Aufbau.
- `OSOS_body_queue_post_wakeup_dispatch_followup_20261030.log` — Timerlisten-
  Helper `FUN_0800073c`, QueueGet-Wrapper und zugehöriger Dispatchkontext.
- `../lfn-resolution-2026-10-28/OSOS_accessories_open_chain_20261029.log` —
  Open-Fehlerpfad des automatischen Parsers.

## Nächste Analyse

Als Nächstes sollte der normale Task-Dispatch vom BootTask-Start über
DeviceDiscovery/ATAWorkLoop bis zum MainApp-Aufruf im Offline-Rehost mit den
realen Kontextstrukturen nachgebildet werden. Danach bleibt der wertvollste
unabhängige Schritt ein VFS-Open-/Read-Rehost ohne vorausgefüllten Stream oder
Handle. Bis dahin ist `accessories.reg` ein dateibasierter Kandidat mit
statischem Parser-/Providerpfad, aber kein nachgewiesener untethered Boot.
