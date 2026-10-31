# Read-only-Prüfung des OSOS-DSB-Helpers

Quelle: `/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin`

SHA-256 der vollständigen Runtime-Eingabe:
`1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`.

Der Eintrag bei Runtime-VA `0x083531c0` wurde mit
`arm-none-eabi-objdump -D -b binary -marm --adjust-vma=0x08000000`
disassembliert:

```asm
083531c0: e3a00000  mov r0, #0
083531c4: ee070f9a  mcr 15, 0, r0, cr7, cr10, {4}
083531c8: e12fff1e  bx lr
083531cc: ea000008  b 0x083531f4
```

Damit ist die Implementierung am Ziel des Kandidatenaufrufs ein CP15-DSB plus
Rückkehr. Ein späterer integrierter ARM1176-System-QEMU-Rehost führt diesen
Originalhelper nach dem 736-Byte-Parser-ROP aus; Details stehen unter
`../accessories-alias-system-parser-rehost-2026-10-31/README.md`. Der
integrierte Rehost modelliert weiterhin den VFS-/ATA-Open und den
`BOOT.BIN`-Read.
