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

Ein zweiter read-only-Schritt hat die ersten sichtbaren Aufrufe des Tasks
weiter aufgelöst: `FUN_0824dec4` wartet auf einen globalen Bereitschaftswert;
danach führt der Prefix über `FUN_08009094` eine Listen-/Array-Operation mit
dem Callback `0x2200607c` aus. Der Callback aktualisiert Prefix-Statusdaten
und kann `FUN_081b2854` erreichen. Die verfolgte Runtime-Initialisierung liest
PMU-Register `0x0a` und `0x33`, nicht das Hold-Register `0x05`. Für die
Bereitschaftsvariable wurde im Runtime-Abbild kein Setzer gefunden; die
Ausführungsreihenfolge gegenüber dem Parser bleibt ungeklärt.

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
- `runtime_power_mgmt_pmu_bridge_20261031.application.log`: Pseudocode von
  `FUN_0824dec4`, `FUN_0824dc22` und erkannte Caller.
- `runtime_power_mgmt_readiness_xrefs_20261031.application.log`: Referenzen
  auf die Bereitschaftszelle `DAT_0824ded8` und den Runtime-Caller.
- `runtime_power_mgmt_registration_bridge_20261031.application.log`:
  erzwungene Thumb-Dekodierung und Pseudocode des Runtime-Listen-Helpers bei
  `0x08009094`.
- `runtime_power_mgmt_wait_semantics_20261031.application.log`: Wrapper
  `FUN_08190a9c`/`FUN_080253de` und deren Caller-Kontexte; der vollständige
  Schedulerdienst liegt außerhalb der Runtime-Abbildung.
- `powermgmt_scheduler_delay_semantics_20261031.application.log`: Prefix-
  Fortsetzung des Warte-Helpers über den externen Einstieg `0x2240a228`.
- `powermgmt_registered_callback_20261031.application.log`: Callback
  `0x2200607c` aus dem Prefix-Task.
- `powermgmt_callback_state_update_20261031.application.log`: Statusupdate
  über `FUN_22005bec` und dessen Aufruf von `FUN_220061a4`.
- `OSOS_HoldSwitch_raw_wrapper_call_scan_20261031.txt`: Rohscan nach
  eingehenden Thumb-`BL`-Instruktionen der beiden nicht aufgelösten Hold-
  Wrapper; die vier `FUN_0824dc22`-Treffer dienen als Dekodierkontrolle.
- `OSOS_HoldSwitch_bootprefix_pointer_scan_20261031.txt`: exakte
  Absolutzeiger-Suche im 57.980-Byte-Prefix für Wakeup-, Hold- und bekannte
  Status-Einstiege; relative/berechnete Referenzen bleiben außerhalb der
  Scan-Aussage.

Projekte:

- `/home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_prefix_20261031/N5G_OSOS_prefix_20261031`
- `/home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime`

Keine Geräte-, USB-, DFU-, NAND-, NOR- oder Firmwareoperation wurde ausgeführt.
