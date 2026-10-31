# PowerMgmt-Task und Hold-Status, 31.10.2026

Read-only-Ghidra-Abfragen auf den vorhandenen OSOS-Bootprefix und das
OSOS-Runtime-Abbild. Die Projektdateien wurden mit `-readOnly -noanalysis`
geöffnet. `DumpThumbRange.java` dekodiert den Entry bei `0x22004fc0` im
erzwungenen Thumb-Modus; Ghidra hat an dieser Adresse zuvor keine Funktion
erkannt. Die temporären Änderungen an der Programmliste wurden verworfen.

## Ergebnis

Der BootTask-Einstieg `0x22004fc1` gehört zu Code im separaten Prefix-Abbild,
nicht zum Runtime-DRAM-Abbild. Der Thumb-Task bei `0x22004fc0` führt einen
Ereignis-/Statusloop aus. Im sichtbaren Übergangspfad ruft er über einen
Prefix-Veneer `FUN_081b2854` im Runtime-Abbild auf. Diese Funktion liest
Statusfelder aus einem globalen Objekt und initialisiert dieses bei einem
Sonderwert. Die Initialisierung ist bis `FUN_081abab0` verfolgt: Sie liest
PMU-Register `0x0a` und `0x33`, nicht das Hold-Register `0x05`. Der
identifizierte Hold-Reader `FUN_082062c0` liest separat Register `0x05` und gibt
Bit 0 über einen Ausgabezeiger zurück.

Damit ist der zuvor externe Taskcode teilweise aufgelöst, aber kein früher
Hold-Gate nachgewiesen. Weitere externe Dienstaufrufe und die tatsächliche
Taskausführungsreihenfolge bleiben offen. Insbesondere belegt die Reihenfolge
der Task-Erzeugung nicht, dass der Hold-Status vor dem `accessories.reg`-Parser
abgefragt wird.

## Rohbelege

- `powermgmt_entry_20261031.application.log`: normale Funktionssuche für
  `0x22004fc0`/`0x22004fc1`; dort war keine Funktion definiert.
- `powermgmt_thumb_20261031.application.log`: Thumb-Pseudocode und Listing
  des Tasks `0x22004fc0..0x2200504b`.
- `powermgmt_helpers_20261031.application.log`: ausgewählte Status-, Event-
  und Import-Veneer-Helfer.
- `powermgmt_globals_20261031.application.log`: globale Pointer und
  Tabellenwerte des Prefix-Tasks.
- `powermgmt_external_veneers_20261031.application.log`: Pointerwörter der
  ARM-Veneers; insbesondere `0x22003a58 -> 0x081b2855`.
- `runtime_status_bridge_20261031.application.log`: Decompilierung von
  `FUN_081b2854`, `FUN_082062c0` und deren erkannten Runtime-Xrefs.
- `runtime_status_initializer_20261031.application.log`: Initialisierung
  über `FUN_081a87fc` und `FUN_0802529c`.
- `runtime_status_input_20261031.application.log`: PMU-Registerzugriffe in
  `FUN_081abab0` sowie die Status-Caller.

Projekte:

- `/home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_prefix_20261031/N5G_OSOS_prefix_20261031`
- `/home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime`

Keine Geräte-, USB-, DFU-, NAND-, NOR- oder Firmwareoperation wurde ausgeführt.
