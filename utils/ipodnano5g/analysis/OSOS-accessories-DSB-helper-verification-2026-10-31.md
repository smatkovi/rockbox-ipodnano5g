# `accessories.reg`: DSB-Gadget-Prüfung

Stand: 31.10.2026. Read-only-Disassemblierung des OSOS-DRAM-Abbilds und
Abgleich mit den vorhandenen Parser- und ARM1176-System-Rehosts. Kein
Geräte-, USB-, DFU-, Reboot- oder Flashzugriff.

## Befund

Der im 736-Byte-Alias-Kandidaten nach dem Datei-Read aufgerufene Helper
`FUN_083531c0` ist im OSOS-Runtime-Abbild tatsächlich der Barrier-Helper:

```asm
083531c0:  e3a00000   mov r0, #0
083531c4:  ee070f9a   mcr p15, 0, r0, c7, c10, 4
083531c8:  e12fff1e   bx  lr
```

Der `MCR` ist die ARMv6-DSB-Operation. Der normale RTOS-Task-Dispatcher setzt
Task-CPSR auf `0x13` (SVC/ARM) oder `0x33` (SVC/Thumb); die Taskmethode läuft
damit im privilegierten Supervisor-Modus. Der Aufruf kann auf dem statisch
ermittelten MainApp-Taskpfad daher CP15 ausführen.

## Abgleich und integrierter Rehost

- Der Linux-User-QEMU-Rehost des 736-Byte-Kandidaten ersetzt `0x083531c0`
  durch `bx lr`. Er belegt Parser-ROP, Registerwerte, den Aufruf an dieser
  Adresse, `bss_init` und den Alias-Entry, aber nicht die Barrierwirkung.
- Der ARM1176-System-Rehost führt den echten OSOS-DSB-Helper nun im selben
  Lauf wie den Originalparser und den 736-Byte-Kandidaten aus. Er erreicht den
  Helper mit `r0=0`, `r1=0x10f80`, `r2=0x8bf10f80`, führt nach dem Breakpoint
  den `MCR` aus, erreicht `bss_init` über den Alias und hält am finalen
  Loader-Entry. Die Loaderbytes stimmen an Alias- und Identitätsabbildung
  bytegenau mit `bootloader-safe.bin` überein.
- VFS-/ATA-Open und der `/BOOT.BIN`-Read bleiben modelliert; die Tabelle wird
  vom Harness mit den ermittelten OSOS-Deskriptoren aufgebaut. Details,
  Quellcode und Reproduktion: `OSOS-accessories-alias-system-rehost-followup-
  2026-10-31.md` und `evidence/accessories-alias-system-parser-rehost-
  2026-10-31/`.

Der integrierte Lauf schließt die vorherige Rehost-Lücke, aber keinen
End-to-End-Gerätenachweis. Weiterhin unbestätigt sind erfolgreicher
MainApp-VFS-Open/Read, aktive Geräte-TLB-Abbildung und Cachezustand am
Callback, die reale freie DRAM-Region, Ausführung des Kandidaten auf dem iPod
und der Start von `/.rockbox/rockbox.ipod`.

## Belege

- Die bereinigte Disassemblierung und Hashes stehen in
  `evidence/accessories-dsb-helper-2026-10-31/README.md`.
- Taskmodus: `OSOS-task-context-privilege-handoff-2026-10-25.md`.
- Parser-/DSB-Standin: `evidence/accessories-alias-dsb-parser-rehost-2026-10-31/README.md`.
- Privilegierter ARM1176-Systemlauf: `evidence/accessories-alias-arm1176-qemu-2026-10-31/README.md`.
- Integrierter Parser-/DSB-/Alias-Rehost: `evidence/accessories-alias-system-parser-rehost-2026-10-31/README.md`.
