# Aufrufer von `FUN_08000a10` – Nachprüfung

Stand: 26.10.2026. Die Prüfung war read-only; das iPod-Gerät und seine
Speicher wurden nicht angesprochen.

## Bestätigter Aufruf im Runtime-Abbild

Der vorherige Ghidra-Xref-Lauf meldete für `FUN_08000a10` keinen Caller, weil
der Thumb-Code am Task-Einstieg `0x08010c98` in diesem Projekt nicht als Code
disassembliert war. Der dekodierte Thumb-Branch bei
`0x08010cc4` ist `BL 0x08000a10`.

Der Kontext an `0x08010c98` ist eine Zustands-/Ereignisschleife. Sie liest den
Zustand aus `[r4+0x10]` und dispatcht über `switch8_r3`. Fall 0 landet bei
`0x08010cc0`: `movs r1,#0; mov r0,r5; bl 0x08000a10`. Nach AAPCS ist der
Aufruf damit `FUN_08000a10(r5, 0)`. Der zweite Parameter wird von
`FUN_08000a10` an den Registry-Insert `FUN_0818e998` weitergegeben; dieser
Pfad beantragt also VFS-/Provider-Slot 0.

Die Funktion `0x08010c98` ist der Thumb-Einstieg des in der Task-Metadatenliste
`PCFPowerMgr` genannten Tasks (`0x08010c99` mit Thumb-Bit). Die Einträge
`DeviceDiscovery` (`0x08002151`) und `PCFPowerMgr` sind getrennte Tasks.
Constructor- und Task-Create-Aufrufe sind im separaten BootTask-Bericht
statisch belegt. Nicht dynamisch bestätigt sind, dass der externe Scheduler
den Task tatsächlich startet und dass der Dispatcherzustand 0 auf einem
normalen Gerätelauf erreicht wird.

## Gegenprüfung im vollständigen OSOS-Body

Die vollständige Datei `nano5g/osos_decrypted/osos_body.bin` enthält dieselben
256 Bytes des Tasks an Datei-/Abbildadresse `0x0803ef14`; sie stimmen mit
Runtime-Adresse `0x08010c98` überein. Für diese zwei Bereiche gilt die
Abbildung `body VA = runtime VA + 0x2e27c`.

Der Body-Gegenspieler von `FUN_08000a10` liegt daher bei `0x0802ec8c`; seine
ersten `0x100` Bytes sind identisch mit Runtime `0x08000a10`. Der entsprechende
Thumb-Aufruf steht bei Body-Adresse `0x0803ef40` und zielt auf `0x0802ec8c`.
Ghidra bestätigte nach gezielter Thumb-Disassemblierung den Xref
`0x0803ef40 -> 0x0802ec8c`. Das ist dieselbe Callsite in der vollständigen
Dateiabbildung, kein zusätzlicher unabhängiger Caller.

Ein kompletter Thumb-`BL`-Scan findet im Runtime-Abbild genau den Aufruf bei
`0x08010cc4` und im Body genau dessen abgebildete Kopie bei `0x0803ef40`.
Ein zusätzlicher 32-Bit-ARM-`BL`-Scan beider Abbilder fand keinen Aufruf auf
das jeweilige Funktionsziel.

## Indirekte und andere externe Referenzen

- In Runtime und Body gibt es keinen ausgerichteten absoluten Funktionszeiger
  auf `0x08000a10`/`0x08000a11` beziehungsweise dessen Body-Adresse
  `0x0802ec8c`/`0x0802ec8d`.
- Ein Scan ausgerichteter und halbwort-ausgerichteter signierter 32-Bit-
  Relativzeiger in beiden Abbildern fand ebenfalls keinen Eintrag auf diese
  Adressen.
- Der Scan der lokalen Firmware-/PE32-Binärdateien fand keine solchen Pointer.
  Die einzigen Bytefolgen `10 0a 00 08` außerhalb der OSOS-Abbilder liegen in
  `Firmware.MSE` und `segments/rsrc.bin` jeweils an denselben drei Offsets
  (`...da2`, `...92e`, `...6a2`, jeweils Offset modulo 4 gleich 2) in
  gepackten Resource-Daten. Sie sind keine ausgerichteten Codepointer.

Damit ist statisch ein direkter, bedingter Slot-0-Registrierungsaufruf aus
`PCFPowerMgr` gefunden. Ein weiterer unabhängiger Caller oder ein
indirekter Funktionszeiger ist in den geprüften Abbildern nicht belegt.
Allgemein zur Laufzeit konstruierte Funktionsadressen sind durch einen
Pointer-/Relativtabellenscan allein nicht ausgeschlossen.

## Nachtrag: Task-Zuordnung und Startfenster (26.10.2026)

Die Task-Zuordnung wurde anhand der Argumente der Constructor-Aufrufe in
`FUN_08013d44` korrigiert. Der Datensatz bei `0x0876019c` (Tabellenoffset
`+0xdc`, Index 11) hat Prioritätsargument 7 und Einstieg `0x08002151`, der in
der Metadatenliste `DeviceDiscovery` zugeordnet ist. Der folgende Datensatz
bei `0x087601b0` (Offset `+0xf0`, Index 12) hat Prioritätsargument 9 und
Einstieg `0x08010c99`; die zugehörige Metadatenzeichenkette bei `0x0801407c`
lautet `PCFPowerMgr`. Der Caller bei `0x08010cc4` gehört somit zu
`PCFPowerMgr`, nicht zu `DeviceDiscovery`.

`FUN_0801c684` führt zuerst den Create-Durchlauf über alle 20 Records aus und
danach den zweiten Dienstaufruf `0x2200d54c` über alle Handles. Erst im
anschließenden BootTask-Post-Init wird `MainAppTask` angefordert. Das setzt
`PCFPowerMgr` statisch vor die MainApp-Taskanforderung, beweist wegen der
fehlenden externen Scheduler-Implementierung aber weder, wann der Task läuft,
noch wann er blockiert oder ob er vor dem frühen MainApp-Parser fortgesetzt
wird. `PCFPowerMgr` ruft den Queue-Abrufwrapper `0x22005878` mit den
Argumenten `(4, 0)` auf und dispatcht ein zurückgegebenes Ereignis anhand des
Bytes bei `+0x10`; der Fall 0 registriert Slot 0. Die frühere Einstufung des
Wrappers als extern wird im Korrekturabschnitt am Ende berichtigt. Die Quelle
dieses Ereignisses und seine Erzeugung vor dem MainApp-Parser blieben in diesem
Analysestand offen.

Damit ist der Slot-0-Registrierungsversuch genauer verortet, seine für den
`accessories.reg`-ROP-Pfad nötige Erreichbarkeit beim Kaltstart aber weiterhin
nicht bewiesen. Ebenso bleibt offen, ob der registrierte Dienst das benötigte
FAT-Dateisystem bereitstellt.

## Nachtrag: Queue-Aufrufer und fehlender Ereignisproduzent (26.10.2026)

Ein Vollscan des Runtime-Abbilds nach direkten Thumb-`BLX`-Aufrufen des
Wrappers `0x08204a34` fand vier Callsites. Die Registerargumente unmittelbar
vor den Aufrufen ergeben diese IDs:

| Runtime-Callsite | ID, Flag | Kontext |
| --- | --- | --- |
| `0x080091ae` | `(3, 0)` | `FUN_080091a4` speichert das Ergebnis und gibt dem Aufrufer einen Zeiger auf `Ergebnis + 0x10`; der Aufrufer verarbeitet diesen zurückgegebenen Kontext. |
| `0x08010caa` | `(4, 0)` | `PCFPowerMgr` holt ein Ereignis, dispatcht dessen Byte bei `+0x10`; Fall 0 ruft `FUN_08000a10(r5, 0)` auf. |
| `0x08010d36` | `(2, 0)` | Warteschleife bei `0x08010d30`, danach Verarbeitung des zurückgegebenen Ereignisses. |
| `0x08017f68` | `(1, 0)` | `HoldSwitchTask`; dieser Aufruf liegt im Zweig für den Fall, dass der alternative Wartepfad kein Ereignis geliefert hat. |

Die vier Stellen sind direkte Aufrufer des Abruf-/Queue-Dienstes; unter ihnen
ist kein direkter Ereignis-Post-Aufruf belegt. Das ist kein Beweis, dass es
keinen Sender gibt. Die damalige Auswertung klassifizierte den bei
`0x08204a38` geladenen Alias `0x22005878` fälschlich als extern und erfasste
den separaten Post-Wrapper noch nicht; beide Punkte sind im Korrekturabschnitt
am Ende berichtigt. Auch der Forced-Thumb-Branchscan schließt indirekte
Aufrufe oder andere geladene Module nicht aus.

Folglich bleibt offen, ob ein Ereignis mit Typ 0 vor dem frühen
`accessories.reg`-Parser in `MainAppTask` an `PCFPowerMgr` geliefert wird.
Die Task-Konstruktion vor der MainApp-Anforderung und die Callsite allein
belegen diesen Zeitablauf nicht. Ein Geräte-Reachabilitytest bleibt nötig.

Eine ähnlich benannte, aber getrennte Ereignisspur wurde gegengeprüft:
`FUN_08010be8` verarbeitet Codes aus einem anderen externen Dienst und ruft
bei drei Zweigen `FUN_0819ad94` mit Werten 0, 1 oder 2 auf. Diese Funktion
leitet über `FUN_08021a74` an einen registrierten Event-Callback weiter; der
Callback-Zeiger wird durch `FUN_0804fcec` auf `0x0805e05d` gesetzt. Im
untersuchten direkten Callgraphen ist kein Aufruf des Queue-Wrappers
`0x08204a34` aus diesem Dispatcher belegt. Das ist ein vorhandener interner
Eventpfad, aber kein belegter Produzent für Queue-ID 4 oder Ereignistyp 0.
Eine indirekte Verbindung über weitere Callbacktabellen ist damit nicht
ausgeschlossen.

## Rohbelege

- Runtime-Caller: `/tmp/OSOS_08010c98_thumb_init.txt` und
  `/tmp/OSOS_08010cc4_candidate_caller.txt`
- Task-Metadaten und Constructor: `/tmp/OSOS_task_order_funcs_20261026.txt`,
  `/tmp/OSOS_task_scheduler_path_20261026.txt` und
  `/tmp/OSOS_task_table_constructor_thumb_20261026.txt`
- Task-Ereignisfunktionen: `/tmp/OSOS_PCFPowerMgr_event_services_20261026.txt`
- Queue-Aufrufer: `/tmp/OSOS_queue_wait_callsite_scan_20261026.txt`,
  `/tmp/OSOS_queue_service_user_20261026.txt` und der direkte
  ARM/Thumb-Disassembly-Scan von `/tmp/osos_runtime_dram_20261025.bin`
- Abgrenzung des anderen Eventpfads: `/tmp/OSOS_PCF_event_selector_08010be8_20261026.txt`,
  `/tmp/OSOS_PCFPowerMgr_event_sources_20261026.txt`,
  `/tmp/OSOS_event_dispatch_xrefs_20261026.txt` und
  `/tmp/OSOS_registered_event_sink_0805e05c_20261026.txt`
- Body-Task: `/tmp/OSOS_body_0803ef14_thumb_20261026.txt`
- Body-Fall-0-Caller und Ghidra-Xref:
  `/tmp/OSOS_body_case0_call_20261026.txt`
- Ghidra-Skripte: `nano5g/ghidra-logs/AnalyzeThumbFunctionAt.java` und
  `nano5g/ghidra-logs/FindOSOSReferenceBatch.java`
- Abbilddateien: `nano5g/osos_decrypted/osos_body.bin` und
  `/tmp/osos_runtime_dram_20261025.bin`

## Korrektur: interner Queue-Dienst und ATA-Worker (26.10.2026)

Die obige Aussage, `0x22005878` sei ein externer Queue-Dienst ohne sichtbare
Implementierung, war falsch. Der Bootprefix-Alias `0x22005878` entspricht dem
OSOS-Bodencode `FUN_08005878`. Dieser setzt Dienstnummer 5 und ruft über
`FUN_08004f14` den Dispatcher `FUN_08000b70` auf; dessen Fall 5 ist der
Warteschlangenabruf. Auch der bisher nicht gefundene Senderwrapper ist intern:
`0x220058b4` entspricht `FUN_080058b4`, der Dienstnummer 4 an denselben
Dispatcher übergibt. Der Fall 4 reiht den angegebenen Datensatz in eine Queue
ein.

Der neue direkte Caller-Audit fand zwei Aufrufer dieses Senders: `FUN_0818e190`
stellt einen Datensatz in Queue 2 ein; `FUN_0833cc58` stellt einen Datensatz
in Queue 4 ein. `FUN_0833cc58` wird als Einstieg von `ATAWorkLoopTask`
verwendet. `FUN_0833c118` richtet diesen Task und `ATAWorkLoopIRQTask` ein;
`FUN_0833aef0` ruft diesen Einrichter während der ATA-Objektinitialisierung
auf. Der Getter `FUN_0833a6e8`, der diese Initialisierung auslöst, hat einen
direkten Aufruf aus `FUN_0801f74a` bei `0x0801f796` und einen Aufruf aus
`FUN_0833b000`. Das belegt einen möglichen Queue-4-Produzenten und dessen
ATA-Aufrufpfad, aber nicht, dass dieser Pfad vor dem `accessories.reg`-Parser
im Kaltstart ausgeführt wird.

Der von `FUN_0833cc58` verwendete Queue-Datensatz stammt aus dem Literal bei
`0x0833ccd0`; der Little-Endian-Wert ist `0x08e51d7c` (Bytes `7c 1d e5 08`).
Er liegt außerhalb des file-backed Runtime-Abbilds, aber innerhalb des frühen
OSOS-Nullungsbereichs `0x086c43a8..0x08e54e4b`. `FUN_08005058` ruft
`FUN_08005fec` bei `0x080050bc` auf. Die vierte Bereichsbeschreibung der
Nullroutine steht bei `osos_body.bin+0x6050`: Start `0x086c43a8`, Länge
`0x790aa4`; deren Ende exklusiv ist `0x08e54e4c`. Der Queue-Knoten liegt
`0x30d0` Byte unterhalb dieses Endes.

Damit wird der Knoten im statischen Resetpfad zunächst genullt. `FUN_0833cc58`
setzt das Ereignisbyte `+0x10` im bedingten Zweig ausdrücklich auf 0; auf dem
anderen Zweig schreibt die Funktion dieses Byte vor dem Post nicht. Unter der
statisch gestützten Annahme, dass kein anderer Laufzeitpfad den Knoten vorher
ändert, stellt `ATAWorkLoopTask` daher ein Ereignis vom Typ 0 in Queue 4 ein.
Der Pointer-Scan des file-backed Runtime-Abbilds fand den Knotenpointer nur als
Literal bei `0x0833ccd0` mit den zwei erwarteten Lesezugriffen in
`FUN_0833cc58`; berechnete oder externe Schreiber sind dadurch nicht
ausgeschlossen.

Das erhöht die Reachability-Evidenz für den `PCFPowerMgr`-Fall 0: Der Task
wartet auf Queue 4 und kann über diesen Fall `FUN_08000a10(r5, 0)` ausführen.
Die BootTask-Konstruktion legt die `PCFPowerMgr`-Tasks vor der späteren
`MainAppTask`-Anforderung an; `ATAWorkLoopTask` wird beim ATA-Objektaufbau
angelegt. Statisch bleibt aber offen, ob beide Worker im normalen Kaltstart
tatsächlich laufen und ob das Ereignis vor dem `accessories.reg`-Parser
verarbeitet wird. Ebenso unbewiesen bleiben der konkrete Slot-0-Provider, sein
FAT-Verhalten und eine daraus erreichbare kontrollierte Codeausführung.

Es wurde kein zusätzlicher Parserfehler, keine Kontrollflussübernahme und
keine RCE bestätigt. Die Auswertung blieb offline und read-only; es gab weder
Geräte-/USB-/DFU-Zugriffe noch Schreib-, Lösch-, Boot- oder Flashaktionen.

Rohbelege: `/tmp/OSOS_runtime_service4_queue_senders_20261026.txt`,
`/tmp/OSOS_service4_queue_post_wrapper_20261026.txt`,
`/tmp/OSOS_FUN_0833c118_20261026.txt`,
`/tmp/OSOS_ata_init_parent_20261026.txt`,
`/tmp/OSOS_ata_factory_20261026.txt`,
`/tmp/OSOS_ata_workloop_literals_20261026.txt`,
`/tmp/OSOS_08000b70.txt` und
`/tmp/OSOS_body_08005878_followup_20261026.txt`. Der Nullungsbereich ist in
`nano5g/ghidra-logs/OSOS_mmu_preinit_2026-10-25.txt` dokumentiert; die vier
Start-/Längenwörter stehen in `nano5g/osos_decrypted/osos_body.bin` bei Offset
`0x6038`. Der read-only Pointer- und Xref-Abgleich steht in
`/tmp/OSOS_ata_startup_refs_20261026.txt`; `FindOSOSWordRefs.java` fand für
`0x08e51d7c` nur das Literal und die zwei Lesezugriffe in `FUN_0833cc58`;
der Konsolenexport liegt in `/tmp/OSOS_queue_node_literal_refs_20261026.txt`.

## Nachtrag: Slot-0-Wrapper aus MBR und FAT-Partition (26.10.2026)

Der Registrierungsaufruf `FUN_08000a10(r5, 0)` ist der Runtime-Alias des
Bodencodes `FUN_0802ec8c`. Dieser liest über den übergebenen Sektordienst
LBA 0 und erkennt im MBR-Zweig die Signatur `0xaa55` (Bytes `55 aa`).
`FUN_0802f4c8` wählt
anschließend den ersten Eintrag mit Status 0 oder `0x80` und einem der
Partitionstypen `0x01`, `0x04`, `0x06`, `0x0b`, `0x0c` oder `0x0e`; das sind
DOS-FAT-Partitionstypen. Start und Länge müssen ungleich null sein und die
Länge darf die Gesamtsektorzahl des Geräts nicht überschreiten.

Für den MBR-Zweig gibt `FUN_0802fbe8` Typwert 2 zurück. `FUN_0802ec8c`
übergibt diesen an `FUN_081bcc14` mit Slot-ID 0. Der Registry-Wrapper baut
daraufhin über `FUN_0826b6e4` das Volumeobjekt und ruft für Typ 2 den
Initialisierer `FUN_0813f0ac` auf. Damit ist der Slot-0-Pfad statisch an einen
MBR-Volumehandler gebunden, der nur klassische FAT-Partitionstypen akzeptiert;
die frühere Aussage, der Dateisystemtyp des Kandidaten sei völlig unbekannt,
war zu weit gefasst.

Das schließt die Reachability-Lücke nicht: Es ist weiterhin nicht belegt,
dass der ATA-Objektaufbau den Queue-4-Worker im normalen Kaltstart vor dem
frühen `accessories.reg`-Leser ausführt. Auch die konkrete Laufzeit-Pfadauflösung
und ein erfolgreicher Datei-Read wurden nicht getestet. Außerdem prüft
`FUN_0802f4c8` sichtbar nicht `Start + Länge <= Gerätesektorzahl`; eine
manipulierte Partition könnte daher einen ungültigen Blockbereich an den
Volume-Wrapper geben. Die nachgelagerte Wirkung hängt von den noch nicht
aufgelösten Provider-/ATA-Grenzprüfungen ab und ist kein belegter
Speicherfehler oder RCE.

Rohbelege: `/tmp/OSOS_body_FUN_0802fbe8_20261026.txt`,
`/tmp/OSOS_body_FUN_0802f4c8_20261026.txt`,
`/tmp/OSOS_body_FUN_0802ec8c_recheck_20261026.txt`,
`/tmp/OSOS_body_vfs_registry_insert_20261026.txt`,
`/tmp/OSOS_partition_volume_objects_20261026.txt` und
`/tmp/OSOS_partition_volume_io_20261026.txt`. Ghidra wurde mit
`-noanalysis -readOnly` ausgeführt.
