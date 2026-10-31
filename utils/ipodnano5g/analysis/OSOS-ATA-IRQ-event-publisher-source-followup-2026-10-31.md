# ATA-IRQ-Schleife und Quelle des ersten privaten Events

Stand: 31.10.2026. Nur statische, lesende Ghidra-Auswertung des Runtime-Abbilds.
Kein Geräte-/USB-/DFU-Zugriff und keine NAND-, NOR- oder Firmwareänderung.

## Ergebnis

Die IRQ-Task ist als direkte Quelle eines Events in der privaten ATA-Queue derzeit
nicht belegt. Ihr Einstieg (`FUN_0833c4be`) führt in `FUN_0833ccd4`, eine Schleife,
die `FUN_0818f694` auf dem Kontextfeld `+4` aufruft, danach synchronisiert und
eine virtuelle Methode bei Objekt-VTable-Offset `+0x1c` ausführt. Diese Methode
(`FUN_0833be0e`) liefert bei fehlendem ATA-Kontext Status 7; andernfalls ruft sie
die Methode `+0x60` auf. Deren Statusautomat (`FUN_0833bf22`) ruft weitere
ATA-Zustands- und I/O-Methoden (`+0x58`, `+0x5c`, `+0x64` usw.) auf. In den
aufgelösten Funktionen ist kein direkter Aufruf des privaten Queue-Publishers
`FUN_0833c504` enthalten. Die tieferen virtuellen ATA-Dispatches sind nicht
vollständig aufgelöst; indirekte Seiteneffekte sind damit nicht ausgeschlossen.

Der aktuell identifizierte Queue-Publisher ist `FUN_0833c504`. Der Callback
`FUN_0833bced` an VTable-Offset `+0x10` ruft ihn auf, wenn das Byte `Objekt+0x54`
ungleich null ist. Der ATA-Konstruktor setzt dieses Byte auf 1. `FUN_0833c504`
prüft außerdem zwei nicht-null Argumente und stellt dann entweder synchron ein
Callback-Event zu oder legt einen 8-Byte-Eintrag in der Queue bei
`param_1[3]` ab. Ein Aufrufer von `FUN_0833bced` im frühen Startpfad ist bislang
nicht nachgewiesen; Ghidras statische Referenz zeigt nur den VTable-Eintrag.

Eine plausible frühe Quelle bleibt die Providerregistrierung am Ende von
`FUN_0833aef0`: Die Task-Starts in `FUN_0833c118` stehen im Code vor
`FUN_08339d3c`. Diese Registrierung ruft `FUN_0819ae68` auf; deren indirekter
Dispatch geht über `child->VTable+0x1c` zu `FUN_0833b000`. Dieser Callback
initialisiert beziehungsweise aktiviert den ATA-Singleton und ruft
`FUN_0833a430` auf. Letzteres dispatcht über ein weiteres Geräteobjekt bei
VTable-Offset `+0x24`. Der konkrete Zieltyp und die Wirkung dieses Aufrufs sind
noch nicht sicher rekonstruiert. Deshalb lässt sich aus der Quellreihenfolge
allein nicht folgern, ob vor dem ersten ATA-Worker-Wait bereits ein Queue-Event
entsteht.

Als Querprüfung wurde ein generischer Aufruf von VTable-Offset `+0x10` in
`FUN_081b2f0c` verfolgt. Seine bekannten Aufrufer laufen über
`FUN_0824c2e8` aus Content-/Textpfaden; diese Kante belegt keine Verwendung des
ATA-Singletons. Sie schließt weitere indirekte Aufrufer nicht aus.

## Einordnung für den Boot-Kandidaten

Der IRQ-Loop allein liefert bisher keinen neuen Speicherfehler und keinen
Codeausführungspfad. Die Providerregistrierung ist eine offene Startreihenfolge-
Kante, aber noch kein Exploit. Weder beliebige Codeausführung noch ein
Rockbox-Handoff oder untethered Boot sind nachgewiesen.

Die zusätzliche Descriptoranalyse unten belegt `FUN_0833c464` →
`FUN_0833bced` → `FUN_0833c504`, lässt aber den Aufrufer des Descriptor-Slots
offen. Die davon getrennte `FUN_0833a430`-Kante ist ebenfalls noch nicht
aufgelöst: Das `+0x24`-Ziel und der konkrete Typ des dort übergebenen
Geräteobjekts bleiben unbekannt. Nächster statischer Schritt ist deshalb, den
externen Service-Dispatch zur Descriptor-VTable und den Besitzer des
`FUN_0833a430`-Unterobjekts aus einer passenden Laufzeitaufnahme oder einer
weiteren Initialisierungskette zuzuordnen. Erst dann lässt sich die Reihenfolge
dieser Callbacks gegenüber dem ersten Lauf und Wait der ATA-Tasks bewerten.

## Rohbelege

Die Exporte liegen reboot-überlebend unter
`utils/ipodnano5g/analysis/evidence/rtos-task-order-2026-10-29/`:

- `OSOS_runtime_ata_task_entrypoint_words_20261031.application.log` — Task-
  Funktionszeiger: `0x0833c4b1` und `0x0833c4bf`.
- `OSOS_runtime_ata_task_entrypoints_20261031.application.log` — Task-Einstiege,
  ATA-Worker und Event-Publisher.
- `OSOS_runtime_ata_irq_loop_followup_20261031.application.log` — IRQ-Task-
  Schleife und `FUN_0833c504`.
- `OSOS_runtime_ata_irq_vtable_decompile_20261031.application.log` und
  `OSOS_runtime_ata_irq_slot60_followup_20261031.application.log` — Slot `+0x1c`,
  Slot `+0x60` und Zustandsautomat.
- `OSOS_runtime_ata_irq_state_methods_20261031.application.log` — aufgelöste
  Status- und ATA-I/O-Helfer.
- `OSOS_runtime_ata_registration_callsite_listing_20261031.application.log` —
  Reihenfolge von Taskstart und Providerregistrierung.
- `OSOS_runtime_ata_provider_registration_callees_20261031.application.log`,
  `OSOS_runtime_ata_provider_callbacks_20261031.application.log` und
  `OSOS_runtime_ata_backend_factory_followup_20261031.application.log` —
  Registrierung, vier Callback-Einträge und Backend-VTable.
- `OSOS_runtime_ata_attached_device_dispatch_20261031.application.log` und
  `OSOS_runtime_ata_attached_device_vtable_20261031.application.log` — noch
  offene Geräteobjekt-Dispatchkante.
- `OSOS_runtime_ata_method10_crossclass_callers_20261031.application.log` und
  `OSOS_runtime_ata_method10_caller_reach_20261031.application.log` — bekannte
  generische `+0x10`-Kante und ihre Aufrufer.
- Das Analysehilfsskript `evidence/rtos-task-order-2026-10-29/scripts/CreateAndDecompileFunctions.java`
  erzeugt fehlende Thumb-Funktionen nur im lesenden Ghidra-Lauf; die Änderungen
  am Programm wurden verworfen.

SHA-256 der zentralen Exporte:

```text
497c9660e44c6e430101cc628bb528fc6e5a833568571606bdc96e759fcb758b  OSOS_runtime_ata_task_entrypoint_words_20261031.application.log
51183274091650f28936f8335413b07927931a4892dd54a1ed2b1be3b0c3d689  OSOS_runtime_ata_task_entrypoints_20261031.application.log
0f275985895968bbf4acac7fdf9f867bcc777e718cdf16e80d849b7492775eae  OSOS_runtime_ata_irq_loop_followup_20261031.application.log
b7a62fd4c1c8b983f886062b4e8c0f30be67a2849b9d731f33321fd88d81784b  OSOS_runtime_ata_irq_vtable_decompile_20261031.application.log
29e0023f54bbdd19b77aa4995ba12a1c0245c75c2ed79347710331364c474ea8  OSOS_runtime_ata_irq_slot60_followup_20261031.application.log
836512b4d2def96cef25659e4ab04d1e0655be76c9fcdc4d3ea7d901e6e0e768  OSOS_runtime_ata_registration_callsite_listing_20261031.application.log
d502c54279e5170df8656d771935349c4f2951ebf1e31111308c758ad9755f0d  OSOS_runtime_ata_provider_callbacks_20261031.application.log
45593e6bbfdf24841f318d9f724feb3703d37fb3c6a6ae15370ab77070a797b1  OSOS_runtime_ata_method10_crossclass_callers_20261031.application.log
```

## Nachtrag: Descriptor-Callback und Block-I/O-Kandidat, 31.10.2026

Die fehlende lokale Kante vom ATA-Descriptor zum privaten Queue-Publisher ist
jetzt aufgelöst. `FUN_0833a6e8` erhält einen Zeiger auf eine globale Root-
Struktur. Bei leerem Feld `[0]` legt die Funktion dort das ATA-Elternobjekt ab,
schreibt es zusätzlich bei `root+0x10` und gibt anschließend `root[0]`
zurück. Sie gibt nicht das separate Descriptorobjekt zurück. Die Root-Adresse
`0x08e5170c` liegt außerhalb des aufgenommenen Runtime-Abbilds.

`FUN_0833aef0` erstellt neben dem ATA-Elternobjekt ein 0x6c-Byte-
Descriptorobjekt. `FUN_0833c098` speichert den Elternzeiger bei `Descriptor+4`
und den Namen `NAND_FLASH_DRIVE` im Descriptor. Die erste Methode der VTable
bei `0x084fb4dc` ist `FUN_0833c464`. Sie ruft über `Parent+0x10` den
Callback `FUN_0833bced` auf. Dessen Aktivierungsbyte `Parent+0x54` wird vom
Konstruktor auf 1 gesetzt; der Callback leitet das Event an
`FUN_0833c504` weiter. Dieser publiziert es entweder direkt oder durch einen
dynamisch angelegten 8-Byte-Queueknoten. In diesem Ausschnitt ist kein
fester Queuepuffer mit ungeprüftem Arrayindex zu sehen.

`FUN_0833aef0` hängt das Descriptorobjekt außerdem an die externe Root-Liste
an (mit einer sichtbaren Grenze von vier Einträgen) und registriert den
Provider. Damit ist die statische Objekt- und Funktionskette bis zum Publisher
belegt. Die Stelle, an der der externe Service-Manager die Descriptor-Methode
aufruft, bleibt im Runtime-Snapshot offen. Die Queue-Eventquelle ist daher
weiterhin nicht als ATA-IRQ-Aufruf oder als datenträgerkontrollierter Aufruf
nachgewiesen; die frühere IRQ-Einordnung ändert sich dadurch nicht.

Ein separater Schreibpfad führt von `FUN_0833bd10` zu
`FUN_0833ca2c`. `FUN_0833bd10` steht als VTable-Eintrag bei
`0x084f5338` (Eltern-VTable `+0xc8`); die statische Referenzabfrage fand
keinen direkten Codeaufrufer, und der vorhandene `+0xc8`-Aufrufscan fand keine
konventionelle indirekte Aufrufstelle. Die Geometrie bezieht `FUN_0833ca2c`
über `FUN_081a3fc6` aus einer Laufzeitstruktur bei `0x0866cc80`; deren
Geometriefelder sind im statischen Snapshot null und werden zur Laufzeit
gesetzt. Der Schreibhelper zeigt am Einstieg keine eigene LBA-/Count-
Obergrenze. Seine Mittelblock-Multiplikationen und LBA-Additionen sind
32-bittig; ein kontrollierter Aufrufer mit übergroßem Count ist jedoch nicht
gefunden. Im Teilblockpfad gilt `Rest < local_30 = geometry >> 12` und damit
`Rest << 12 <= 0xffffe000`; der sichtbare Schiebevorgang allein belegt also
keinen 32-Bit-Längenüberlauf. Dieser Schreibpfad ist derzeit kein erreichbarer
Exploitkandidat.

Neue beziehungsweise maßgebliche Rohbelege liegen unter
`evidence/rtos-task-order-2026-10-29/`:

- `OSOS_runtime_ata_singleton_register_dataflow_20261031.application.log` und
  `OSOS_runtime_ata_singleton_global_objects_20261031.application.log` —
  Root-Zeiger und Rückgabewert von `FUN_0833a6e8`.
- `OSOS_runtime_ata_publisher_object_fields_20261031.application.log`,
  `OSOS_runtime_ata_slot10_targets_retry_20261031.application.log`,
  `OSOS_runtime_ata_forwarder_guards_20261031.application.log` und
  `OSOS_runtime_ata_parent_vtable_extended_20261031.application.log` —
  Descriptorkonstruktor, Callback, Publisher und Eltern-VTable.
- `OSOS_runtime_ata_io_listing_windows_20261031.application.log`,
  `OSOS_runtime_ata_io_helpers_decompile_20261031.application.log`,
  `OSOS_runtime_ata_io_geometry_values_20261031.application.log`,
  `OSOS_runtime_ata_io_geometry_xrefs_20261031.application.log`,
  `OSOS_runtime_ata_io_geometry_table_xrefs_20261031.application.log` und
  `OSOS_runtime_ata_io_geometry_setters_20261031.application.log` —
  Block-I/O-Listing, Laufzeitgeometrie und Setter.

Alle Ghidra-Abfragen waren `-readOnly -noanalysis`. Kein Gerät oder USB wurde
abgefragt; es gab keine Boot-, NAND-/NOR-, Lösch- oder Schreiboperation.
