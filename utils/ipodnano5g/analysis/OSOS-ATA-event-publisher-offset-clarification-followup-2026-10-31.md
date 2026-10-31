# ATA-Eventquelle: VTable-Offset `+0x24` ist kein Queue-Publisher

Stand: 31.10.2026. Read-only-Ghidra-Abgleich am Runtime-Abbild vom 25.10.2026
mit `-noanalysis -readOnly`. Kein Geräte-, USB-, DFU- oder Flashzugriff.

## Ergebnis

Der in `FUN_0833a430` verwendete virtuelle Aufruf bei `child->VTable+0x24`
ist nicht die zuvor gesuchte private ATA-Eventquelle. Die passende Wrapper-
VTable bei `0x0853567c` enthält an `+0x24` den Thumb-Zeiger `0x0833b7eb`
(`FUN_0833b7ea`). Der Callback liest `owner+0x10`; falls dieses Feld gesetzt
ist, gibt er das Wort `child+0x64` zurück, sonst 0. Der Eintrag bei `+0x28`
ist `0x0833b7d9` (`FUN_0833b7d8`); er liefert bei gesetztem Kindzeiger
`child+0x58 - owner+0x18`, andernfalls 0. Beide sind Getter und rufen den
Queue-Publisher nicht auf.

Davon getrennt ist der ATA-Eltern-VTable-Eintrag bei `0x084f5280+0x10`:
`0x0833bced` zeigt auf die Funktion `FUN_0833bcec`. Sie prüft
`Parent+0x54` und ruft bei gesetztem Aktivierungsbyte `FUN_0833c504` auf.
Dieser Publisher verlangt zwei nicht-null Argumente und reiht andernfalls
einen dynamisch allokierten 8-Byte-Knoten ein. In diesem Ausschnitt ist kein
fester Puffer mit ungeprüftem Arrayindex erkennbar.

Der separate Descriptor-Callback `FUN_0833c464` liegt an Slot 0 der VTable
`0x084fb4dc`. Er ruft seinerseits `underlying->VTable+0x10` auf. Der konkrete
Service-Manager-Aufrufer dieses Descriptor-Slots bleibt offen. Die neue
Offsetanalyse schließt nur die Verwechslung mit den Wrapper-Gettern aus; sie
bestimmt weder, wer den Descriptor tatsächlich aufruft, noch wann das erste
private ATA-Event eintrifft.

## Sicherheitsbewertung

Kein neuer Speicherfehler und keine neue Exploitkante. Die Queuequelle bleibt
statisch plausibel, aber der auslösende Manager-Dispatch ist nicht bis zu
einem normalen Kaltstart geschlossen. Geräteverhalten, FAT-Open, Rockbox-
Handoff und untethered Boot wurden nicht getestet oder nachgewiesen.

## Rohbelege

Die read-only-Ghidra-Exporte und ihre Prüfsummen stehen unter
`evidence/ata-event-offset-2026-10-31/`. Die zentralen Dateien sind:

- `OSOS_runtime_ata_vtable_24_even_targets_20261031.script.log` — Getter-
  Pseudocode für die normalisierten Thumb-Einstiege `0x0833b7ea` und
  `0x0833b7d8`, sowie für `FUN_0833bcec`.
- `OSOS_runtime_ata_vtable_24_manual_20261031.script.log` — Pseudocode für
  `FUN_0833c464` und dieselben getrennten Dispatches.
- `OSOS_runtime_ata_vtable_24_callbacks_20261031.script.log` —
  `FUN_0833c504` und sein einziger gefundener direkter Caller.
- `OSOS_runtime_discovery_provider_vtables_20261031.script.log` und
  `OSOS_runtime_ata_descriptor_vtable_20261031.script.log` — die beiden
  VTable-Einträge.

Die Abfragen liefen auf dem vorhandenen Projekt
`/home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime`
für `osos_runtime_dram_20261025.bin`; temporär angelegte Thumb-Funktionen
wurden beim Schließen des read-only-Laufs verworfen.

## Nächster Schritt

Die offene Kante liegt beim externen Manager, der den Descriptor-Slot 0
aufruft. Dafür sind die Root-/Registry-Laufzeitdaten außerhalb des erfassten
Runtime-Abbilds nötig oder eine weitere statische Initialisierungskette, die
den Manager und sein Dispatch zeigt. Bis dahin ist der ATA-Eventpublisher kein
bestätigter, vom Datenträger kontrollierter Trigger.
