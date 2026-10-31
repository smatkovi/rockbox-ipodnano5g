# Hold-Status-Rückgabe und bedingte Stack-Fortsetzungen

Stand: 31.10.2026. Ausschließlich statische Analyse eines lokalen OSOS-Runtime-
Abbilds. Kein Gerätezugriff, kein Reboot und keine NAND-/NOR-/Flashoperation.

## Ergebnis

Der Hold-Status ist in der OSOS-Runtime als Rückgabewert in `r0` verfügbar:
`1` bedeutet verriegelt, `0` entriegelt. Der Wrapper bei `0x0824dc22` erhält
diesen Rückgabewert. Eine read-only-Ghidra-Suche fand jedoch keinen einfachen
bedingten Stack-Return, bei dem die zwei Zweige verschieden viel Stack
verbrauchen und damit zwei ROP-Fortsetzungen auswählen. Das löst den
Hold-Fallback des `accessories.reg`-Kandidaten daher noch nicht.

## PMU-Rückgabepfad

Untersucht wurde
`/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin`,
SHA-256 `1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`.

- `FUN_082062c0` liest PMU-Register `0x05`, extrahiert Bit 0 und schreibt den
  Wert an den Ausgabezeiger.
- `FUN_081988fc` initialisiert `r0` mit `1`; falls das gelesene Bit gesetzt
  ist, setzt es `r0` auf `0`. Bei Bit 0 gleich null (Hold verriegelt) kehrt es
  somit mit `1` zurück.
- `FUN_0824dc22` besteht aus `push {r4,lr}; bl FUN_081988fc; pop {r4,pc}`.
  Es überschreibt `r0` nicht und gibt den booleschen Status weiter.
- Der erste Aufruf von `FUN_081988fc` hat beobachtbare Nebenwirkungen: Er setzt
  den Initialisierungszustand `DAT_08198948` und sendet Hold-Ereignisse `0x57`
  und `0x59`. Der Aufruf ist daher kein reiner, nebenwirkungsfreier PMU-Leser.
- `FUN_0818ebd8` ruft den Wrapper auf und kehrt bei nichtnull `r0` früh zurück,
  bevor der sichtbare Pfad `FUN_083522bc` aufruft. Das ist ein nativer
  Hold-Guard für den Eingabepfad. In der untersuchten Funktion ist kein
  beliebiger Callback-Parameter erkennbar, den dieser Guard bedingt ausführen
  könnte.

Die Instruktionsfenster stammen aus `arm-none-eabi-objdump` mit ARM-Modus für
`FUN_0818ebd8` und Thumb-Modus für die Thumb-Wrapper. Der vollständige PMU-
und Eingabehandler-Kontext ist in den bereits abgelegten Ghidra-Logs
`analysis/evidence/hold-power-mgmt-2026-10-31/runtime_status_bridge_20261031.application.log`
und
`analysis/evidence/hold-power-mgmt-2026-10-31/runtime_power_mgmt_pmu_bridge_20261031.application.log`
enthalten.

## Suche nach ROP-Fortsetzungen

Das reproduzierbare Ghidra-Skript
`analysis/evidence/hold-gadget-scan-2026-10-31/ScanHoldBranchGadgets.java`
läuft mit `-readOnly -noanalysis` über die definierten Funktionen. Es sucht
nach `cmp r0,#0` beziehungsweise `cbz/cbnz r0`, verfolgt beide unmittelbaren
bedingten Zweige höchstens fünf Instruktionen bis zu einem `pop`/`ldm` mit
`pc` und vergleicht den Stackverbrauch. Calls und nicht sicher auswertbare
Stack-Änderungen werden für den Vergleich ausgeschlossen.

Der Lauf über 1.375.826 definierte Instruktionen meldete:

- 34.917 Vergleiche `r0` gegen null; kein als `cbz/cbnz r0` erkanntes Muster;
- 1.965 Zweigpaare, bei denen beide Wege innerhalb des Suchfensters einen
  Stack-Return erreichen;
- 663 Paare ohne Calls oder nicht auflösbare Stack-Operationen;
- davon 0 Paare mit unterschiedlichem Netto-Stackverbrauch.

Die Ghidra-Ausgabe mit diesen Zählern liegt in
`analysis/evidence/hold-gadget-scan-2026-10-31/OSOS_runtime_hold_conditional_netsp_final_20261031.application.log`.
Der Lauf wurde mit Ghidra `12.1.2_DEV` gegen das bestehende Projekt
`N5G_OSOS_runtime` ausgeführt; das Projekt wurde nicht verändert.

## Aussagegrenzen und nächste Schritte

Der Scan widerlegt keine beliebigen ROP-Ketten: Er umfasst die von Ghidra
definierten Funktionen, direkte `r0 == 0`-Tests, Zweige mit Stack-Return in
einem Fenster von fünf Instruktionen und nur eindeutig auswertbare
Stackbewegungen. Er analysiert keine vollständigen Kontrollflussgraphen,
berechneten Branches, fremde Module oder Laufzeit-Schedulerreihenfolge. Ein
anderer nativer Dispatcher oder eine längere Gadget-Kette bleibt möglich.

Der Hold-Wert ist verfügbar, aber die hier gesuchte einfache bedingte
Stack-Verzweigung ist nicht belegt. Der nächste sinnvolle Schritt ist, die
außerhalb des Runtime-Abbilds liegende `PowerMgmt`-Registrierung im
Bootprefix (`0x22004fc1`) weiter auf ihren Aufrufzeitpunkt relativ zum
automatischen `MainAppTask`-/`accessories.reg`-Pfad zu verfolgen. Parallel
muss ein anderer bedingter Dispatcher gesucht werden, der einen
Rockbox-Handoff bei entriegeltem Hold und den unveränderten Apple-Start bei
verriegeltem Hold erlaubt.

Reproduzierbarer Ghidra-Aufruf:

```sh
/opt/ghidra/support/analyzeHeadless \
  /home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis \
  N5G_OSOS_runtime \
  -process osos_runtime_dram_20261025.bin -noanalysis -readOnly \
  -scriptPath /home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/hold-gadget-scan-2026-10-31 \
  -postScript ScanHoldBranchGadgets.java
```
