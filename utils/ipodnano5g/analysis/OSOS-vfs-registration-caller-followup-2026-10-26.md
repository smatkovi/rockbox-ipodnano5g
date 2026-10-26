# Aufrufer von `FUN_08000a10` – Nachprüfung

Stand: 26.10.2026. Die Prüfung war read-only; das iPod-Gerät und seine
Speicher wurden nicht angesprochen.

## Bestätigter Aufruf im Runtime-Abbild

Der vorherige Ghidra-Xref-Lauf meldete für `FUN_08000a10` keinen Caller, weil
der Thumb-Teil des `DeviceDiscovery`-Tasks an `0x08010c98` in diesem Projekt
nicht als Code disassembliert war. Der dekodierte Thumb-Branch bei
`0x08010cc4` ist `BL 0x08000a10`.

Der Kontext an `0x08010c98` ist eine Zustands-/Ereignisschleife. Sie liest den
Zustand aus `[r4+0x10]` und dispatcht über `switch8_r3`. Fall 0 landet bei
`0x08010cc0`: `movs r1,#0; mov r0,r5; bl 0x08000a10`. Nach AAPCS ist der
Aufruf damit `FUN_08000a10(r5, 0)`. Der zweite Parameter wird von
`FUN_08000a10` an den Registry-Insert `FUN_0818e998` weitergegeben; dieser
Pfad beantragt also VFS-/Provider-Slot 0.

Die Funktion `0x08010c98` ist als Task-Einstieg `DeviceDiscovery` in der
OSOS-Tasktabelle eingetragen. Constructor- und Task-Create-Aufrufe sind im
separaten BootTask-Bericht statisch belegt. Nicht dynamisch bestätigt sind,
dass der externe Scheduler den Task tatsächlich startet und dass der
Dispatcherzustand 0 auf einem normalen Gerätelauf erreicht wird.

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
`DeviceDiscovery` gefunden. Ein weiterer unabhängiger Caller oder ein
indirekter Funktionszeiger ist in den geprüften Abbildern nicht belegt.
Allgemein zur Laufzeit konstruierte Funktionsadressen sind durch einen
Pointer-/Relativtabellenscan allein nicht ausgeschlossen.

## Rohbelege

- Runtime-Caller: `/tmp/OSOS_08010c98_thumb_init.txt` und
  `/tmp/OSOS_08010cc4_candidate_caller.txt`
- Body-Task: `/tmp/OSOS_body_0803ef14_thumb_20261026.txt`
- Body-Fall-0-Caller und Ghidra-Xref:
  `/tmp/OSOS_body_case0_call_20261026.txt`
- Ghidra-Skripte: `nano5g/ghidra-logs/AnalyzeThumbFunctionAt.java` und
  `nano5g/ghidra-logs/FindOSOSReferenceBatch.java`
- Abbilddateien: `nano5g/osos_decrypted/osos_body.bin` und
  `/tmp/osos_runtime_dram_20261025.bin`
