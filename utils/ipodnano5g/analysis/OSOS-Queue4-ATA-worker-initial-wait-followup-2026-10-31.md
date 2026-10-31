# Queue-4-Wakeup und erster ATA-Worker-Wait

Stand: 31.10.2026. Read-only-Auswertung der vorhandenen Runtime- und Body-
Ghidra-Projekte. Kein Geräte-/USB-/DFU-Zugriff und keine Firmware-, NAND-
oder NOR-Änderung.

## Ergebnis

Die beiden Warteschlangen sind getrennt: `DeviceDiscovery` wartet auf der
Kernel-Queue 4; `ATAWorkLoopTask` postet dort beim Einstieg den Typ-0-Datensatz.
Danach ruft der ATA-Worker seinen eigenen Ereignisdispatcher mit dem Objekt
aus `ATA-Objekt +8` auf. Dessen Queue wird bei der globalen ATA-Initialisierung
mit Kapazität 10 erzeugt und von `FUN_0801e078` zunächst ohne eingereihte
Datensätze initialisiert.

Der Queue-4-Post weckt einen dort wartenden Task und übergibt ihn an die
Scheduler-Freigabeliste. Eine erneute Zuordnung der Scheduler-Literale zeigt,
dass `DAT_08001650` und `DAT_08001638 + 4` beide auf `0x22009248` zeigen: Das
ist das Feld mit dem Current-TCB-Zeiger und zugleich der Anfang der nach
Priorität sortierten Liste. Fügt `FUN_08000798` einen TCB mit kleinerem
Prioritätswert als den aktuellen ein, schreibt der Einfügepfad den neuen TCB
direkt in dieses Current-Feld. Der SVC-Abschluss gibt im normalen Pfad dann den
gespeicherten Stack des TCB zurück, auf den Current jetzt zeigt; der
Kontext-Restore kann somit unmittelbar auf den geweckten Task wechseln.

Für den dokumentierten Startfall ist `DeviceDiscovery` mit Priorität `9`
höher priorisiert als der postende `ATAWorkLoopTask` mit `0x33`. Wenn
DeviceDiscovery auf Queue 4 wartet, macht der Queue-Post ihn daher zum neuen
Current-Task. Das legt den Event-0-/Slot-0-Pfad vor `MainAppTask` (`0x34`),
ohne dass der ATA-Worker erst selbst blockieren muss. Die frühere Aussage,
der Scheduler stelle sicher den bisherigen Current-TCB wieder her, war falsch:
Sie hatte übersehen, dass die Listenwurzel genau das Current-Zeigerfeld ist.
Der tatsächliche Kaltstart und ein erfolgreicher MBR-/FAT-Pfad bleiben
unbeobachtet.

Der private Receive-Pfad wiederholt die Entnahme, solange kein gültiger
Datensatz zurückkommt; bei einem leeren Ergebnis ruft er einen Wartehelper am
ATA-Eventobjekt auf. Ein IRQ-Task existiert und wartet seinerseits über einen
externen Semaphoraufruf. Aus dem statischen Befund allein ist nicht geklärt,
ob ein IRQ oder ein anderer Producer vor dem ersten Receive einen Datensatz
bereitstellt.

## Belegkette

1. `FUN_0833c118` speichert `FUN_081e2554()` bei `ATA-Objekt +8` und startet
   `ATAWorkLoopTask` sowie `ATAWorkLoopIRQTask`.
2. `FUN_081e2554` erzeugt bei Bedarf über `FUN_0833c3c2` den globalen
   Event-Endpoint. `FUN_0833cc2e(..., 10, 1)` initialisiert dessen Lazy-Queue;
   `FUN_0833ce88` erzeugt sie mit Kapazität 10. `FUN_081a5c64(10)` fordert
   dafür `10 * 0x14 + 0x48 = 0x110` Byte an.
3. `FUN_0801e078` setzt beim Queue-Aufbau Kopf/Anzahl und die Zustandsfelder
   zunächst auf null und legt die zehn freien Queue-Einträge an. Das ist eine
   leere Anfangsqueue, keine Aussage darüber, ob sie vor dem ersten
   ATA-Worker-Wait bereits befüllt wird.
4. `FUN_0833cc58` postet den statischen Typ-0-Datensatz in Kernel-Queue 4 und
   ruft danach `FUN_0833ce02(param_1[2])` auf. `FUN_0833cec0` leitet an
   `FUN_082772dc` weiter. Der Receive-Pfad versucht wiederholt eine Entnahme;
   bei Rückgabewert 0 ruft er `FUN_081ad3a8` am Feld `ATA-Eventobjekt +0x34`
   auf. `FUN_082785f4` liefert ebenfalls 0, wenn das Ereignis-Valid-Byte bei
   `+0x10` nicht gesetzt ist.
5. Im Kernel-SVC-Dispatcher `FUN_08000b70`, Dienst 4 (QueuePost), wird ein
   vorhandener Queue-4-Waiter aus der Warteliste gelöst, sein Wartebit `0x20`
   gelöscht und der Task in die Scheduler-Freigabeliste gestellt. Der
   gemeinsame Abschluss ruft bei wartenden Freigaben `FUN_08000798` auf.
   Die Literalwerte im Body-Projekt zeigen `DAT_08001638 = 0x22009244` und
   `DAT_08001650 = 0x22009248 = DAT_08001638 + 4`. Damit ist der Listenanfang
   das Current-TCB-Zeigerfeld. Wird der geweckte TCB vor dem bisherigen
   Current eingefügt, ändert der Einfügepfad den Current-Zeiger und der
   normale SVC-Abschluss gibt dessen Stack für den Kontext-Restore zurück.
   `DeviceDiscovery` (`9`) liegt vor dem ATA-Worker (`0x33`) und kann so beim
   Queue-4-Post unmittelbar laufen.
6. `FUN_08000b1c` liest beim Blockieren den `TCB->next`-Zeiger des aktuellen
   Tasks, schreibt diesen als neuen Scheduler-Current und fügt den alten
   Current-Task prioritätssortiert in die angegebene Warteliste ein. Damit
   hängt die nächste Ausführung von der tatsächlichen Verkettung am
   Blockierzeitpunkt ab.
7. `ATAWorkLoopIRQTask` ruft `FUN_0833ccd4` auf. Die Schleife wartet zuerst
   mit `FUN_0818f694` auf den Semaphor bei `param_1 + 4`, nimmt danach den
   Mutex bei `param_1 + 5`, ruft den Handler an Vtable-Offset `+0x1c` auf und
   gibt den Mutex frei. `FUN_0818f694` ist ein Wrapper um
   `EXT_FUN_220030d8`; Anfangszähler und externe Semaphorsemantik sind aus dem
   vorliegenden Body-Dump nicht ableitbar.

## Grenzen und Bedeutung für den Rockbox-Kandidaten

- Der Queue-4-Post kann `DeviceDiscovery` (`9`) zum Current-Task machen,
  während `ATAWorkLoopTask` (`0x33`) der aktuelle Task ist. Damit ist der
  Slot-0-MBR-/Providerpfad statisch vor `MainAppTask` (`0x34`) erreichbar,
  falls der erwartete Queue-Wait und der erfolgreiche ATA-Aufbau vorliegen.
- Der ATA-Eventqueue-Initializer setzt die Queue zunächst leer. Ein IRQ-Task
  wartet auf einen externen Semaphor; ob dessen Signalzustand beim Start null
  ist oder vor dem ersten Worker-Receive signalisiert wird, ist offen.
- Auch eine erfolgreiche MBR-/FAT-Registrierung, der automatische
  `accessories.reg`-Open, ein kontrollierter Rücksprung und der Rockbox-Handoff
  bleiben unbeobachtet. Der bekannte Kandidat ist damit weiterhin kein
  bestätigter Exploit und kein untethered Boot.

## Rohbelege

Alle Dateien liegen reboot-überlebend im Repository unter
`utils/ipodnano5g/analysis/evidence/rtos-task-order-2026-10-29/`:

- `OSOS_runtime_ata_worker_event_source_constructor_20261031.application.log`
  — globale Endpoint-Konstruktion und Taskstart.
- `OSOS_runtime_ata_task_entrypoints_20261031.application.log` — ATA-Objekt-
  Konstruktor und beide Task-Entry-Wrapper.
- `OSOS_runtime_ata_internal_queue_ctor_20261031.log` und
  `OSOS_runtime_ata_event_publisher_object_init_20261031.application.log` —
  Initialisierung der privaten Queue und des IRQ-Eventobjekts.
- `OSOS_runtime_ata_worker_event_queue_init_helper_20261031.application.log`
  — Lazy-Queue-Konstruktion.
- `OSOS_runtime_ata_worker_event_init_followup_20261031.application.log` und
  `OSOS_runtime_ata_worker_event_status_20261031.application.log` — Event-
  Receive, Entnahme, Validbyte und Wait-Helfer.
- `OSOS_queue4_scheduler_reachability_20261031.application.log` und
  `OSOS_body_scheduler_dispatch_followup_20261030.log` — QueuePost-
  Wakeupzweig sowie die Listenoperation `FUN_08000b1c`.
- `OSOS_body_queue4_current_tcb_successor_followup_20261031.application.log`
  — QueuePost-SVC, Ready-Listen-Einfügepfad und Stack-Rückgabe des neuen
  Current-TCB.
- `OSOS_body_scheduler_global_list_fields_20261031.application.log` — die
  Body-Literale für `DAT_08001638` und `DAT_08001650` und ihr gemeinsames
  Current-TCB-Feld bei `0x22009248`.
- `OSOS_body_task_create_scheduler_enqueue_followup_20261030.log` —
  Ready-Listen-Sortierung und Scheduler-Restore.
- `OSOS_runtime_ata_irq_loop_followup_20261031.application.log` und
  `OSOS_runtime_ata_irq_wait_semaphore_semantics_20261031.application.log` —
  IRQ-Task-Schleife und Wrapper des externen Semaphor-Waits.

SHA-256 der neuen Runtime- und Scheduler-Exports:

```text
44b0967f4ffd2f574c7e2f7119f4476cd780733bc70ccfa4085f92f23e560214  OSOS_runtime_ata_worker_event_queue_init_helper_20261031.application.log
3cda2b2e72b11a3aa897433ff8016507877efecf2c969ca36cc29ea4f4e9cbee  OSOS_runtime_ata_worker_event_source_constructor_20261031.application.log
962db86481312b13f72242a334c7b0402c13e10195100cc968d69abae98258f6  OSOS_runtime_ata_worker_event_init_followup_20261031.application.log
502c0d8cf20df764207039cc8728006ea8ddf4957a979fdd765ffc2f2a12f90d  OSOS_queue4_scheduler_reachability_20261031.application.log
191a690294d190d43d350ab0c53d4f2cdeac0f08078f7cabbf917e39e0a47da6  OSOS_runtime_ata_internal_queue_ctor_20261031.log
8087aeb9f2f23c1a1d18729a2bc047b63cee2597468a991dc6acf326cd83d3f5  OSOS_runtime_ata_worker_event_status_20261031.application.log
0f275985895968bbf4acac7fdf9f867bcc777e718cdf16e80d849b7492775eae  OSOS_runtime_ata_irq_loop_followup_20261031.application.log
e2dd64cad94bda95f81826b3bbeb23f9b72403b51ea9f79e46c9a213fd03f5ef  OSOS_runtime_ata_irq_wait_semaphore_semantics_20261031.application.log
ffef6417e18c04cfed519dc31a9c47cacabc85a39d4b78c9fc6899702ad798a3  OSOS_runtime_ata_event_publisher_object_init_20261031.application.log
51183274091650f28936f8335413b07927931a4892dd54a1ed2b1be3b0c3d689  OSOS_runtime_ata_task_entrypoints_20261031.application.log
```

## Nächster Schritt

Als nächstes sind die Gerätebedingungen für den Slot-0-MBR-/FAT-Pfad und der
automatische `accessories.reg`-Open weiterzuprüfen. Die Scheduler-Reihenfolge
ist statisch so weit geschlossen, dass der geweckte `DeviceDiscovery`-Task
den ATA-Worker beim Queue-4-Post überholen kann. Ungeprüft bleiben ein
erfolgreicher Hardware-Read, die konkrete FAT-Dateiöffnung und der spätere
Parser-Handoff.

Die Schedulerkorrektur und die aktualisierten Folgeberichte sind mit
`SHA256SUMS_queue4-priority-preemption-20261031.txt` gehasht.
