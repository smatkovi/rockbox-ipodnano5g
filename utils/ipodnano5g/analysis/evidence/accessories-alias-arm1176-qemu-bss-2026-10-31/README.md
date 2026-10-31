# OSOS DRAM-BSS-Nullung vor dem MMU-Setup

Stand: 31.10.2026. Statische Prüfung des SRAM-Prefixes plus ARM1176-System-
QEMU-Lauf mit den extrahierten OSOS-Abbildern. Kein USB-, DFU- oder
Gerätezugriff; kein NAND-, NOR- oder Firmware-Schreiben.

## Ergebnis

Die Sorge, die L1-Tabelle bei `0x086dc000` könne beim normalen Start uninitialisiert
sein, ist für den statischen OSOS-Startpfad ausgeräumt:

- Der Startup-Code bei `0x22005058` ruft bei `0x220050bc` die BSS-Nullroutine
  `0x22005fec` auf.
- Danach folgen weitere Setup-Aufrufe; der Startup-Code ruft bei `0x220050c8`
  den MMU-Initialisierer `0x22005d3c` auf.
- `0x22005fec` ruft für den DRAM-BSS-Bereich die Nullhilfe `0x22000074` mit
  Start `0x086c43a8` und Länge `0x790aa4` auf. Der resultierende Bereich ist
  `[0x086c43a8, 0x08e54e4c)`.
- Die L1-Tabelle belegt `[0x086dc000, 0x086e0000)` und liegt damit vollständig
  in diesem DRAM-BSS-Bereich. Die Funktion löscht also die Tabelle, bevor der
  spätere MMU-Initialisierer ihre Deskriptoren schreibt.

Der QEMU-Harness setzt zunächst `0xdeadbeef` in L1-Eintrag 0x500 bei
`0x086dd400`. Am Breakpoint am Eintritt der unveränderten BSS-Nullroutine ist
der Marker vorhanden. Am nächsten Breakpoint, am Eintritt des echten
`FUN_22005d3c`, ist derselbe Eintrag null. Nach dem echten MMU-Initialisierer
stehen die bekannten Deskriptoren an den erwarteten Tabellenadressen; der
unberührte Eintrag bleibt null. Der Kontrollfluss erreicht danach wie in den
vorherigen Rehosts `PC=0x0bf000e0`, und die Kopien des Loaderabbilds sind
bytegleich zu `bootloader-safe.bin`.

## Reproduktion und Dateien

Vom Repository-Verzeichnis `rb-n5g/`:

```sh
python3 utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-bss-2026-10-31/verify_osos_dram_bss_startup.py
bash utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-bss-2026-10-31/run_osos_startup_bss_mapper_handoff.sh
```

- `verify_osos_dram_bss_startup.py` prüft die Branchziele der beiden
  Startup-Aufrufe, die BSS-Literale, Dateigrenzen und Tabellenüberdeckung.
- `OSOS_prefix_dram_bss_zero_routine_20261031.objdump.txt` enthält den
  Disassembly-Ausschnitt der Nullroutine und ihrer Literale.
- `osos_startup_bss_mapper_handoff.S`, `.ld` und `.gdb` bilden den Rehost ab.
  Der Harness setzt den Marker und ruft exakt `0x22005fec` und `0x22005d3c`
  auf; der L1-Nullbereich wird nicht vom Harness selbst hergestellt.
- `gdb_osos_startup_bss_mapper_handoff.log` enthält die Marker- und
  Deskriptorlesungen. `qemu_osos_startup_bss_mapper_handoff.log` hält die
  QEMU-Ausgabe fest.
- Die `.bin`-Dateien enthalten die beiden Loader-Dumps bei `start_loc`.
- `verify_osos_dram_bss_startup.txt` ist die Ausgabe des statischen Prüfers.

Der Harness benötigt die lokalen Offline-Eingaben
`../local-analysis/inputs/osos_bootprefix_22000000_20261031.bin` und
`../local-analysis/inputs/osos_runtime_dram_20261025.bin`; ihre SHA-256-Werte
werden vom Runner geprüft. Der DRAM-Suffix ist kein Live-RAM-Abzug.

## Grenzen

Die Branches in `FUN_22005058` belegen statisch die Reihenfolge im Startup.
Der QEMU-Harness springt für die kontrollierte Prüfung direkt in die exakte
BSS-Nullroutine und danach in den MMU-Initialisierer; er führt nicht alle
vorherigen MMIO-Zugriffe und RTOS-Setup-Aufrufe des vollständigen Starts aus.
Ebenso bleiben Accessories-Callback, FAT/VFS/ATA-Leseweg und Geräte-TLB-Zustand
außerhalb des Laufs. QEMU-TCG bildet ARM1176-Caches, Write-Buffer und reale
DRAM-Belegung nicht vollständig nach. Damit ist die BSS-Initialisierung
statisch und im QEMU-Rehost belegt, aber nicht live am iPod gemessen.
