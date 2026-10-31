# ARM1176-System-Rehost: Accessories-ROP bis Rockbox-Loader-Einstieg

Der Rehost kombiniert den 736-Byte-Accessories-Kandidaten, den Originalparser,
den echten OSOS-DSB-Helper, eine synthetische ARMv6-L1-Tabelle mit den
ermittelten OSOS-Deskriptoren und den echten lokalen Rockbox-Zwischenloader.
Der ARM1176-System-QEMU-Lauf hält vor der ersten Loaderinstruktion an.

## Ergebnis

- Der Kandidat erreicht `0x083531c0` mit `r0=0`, `r1=0x10f80` und
  `r2=0x8bf10f80`.
- `0x083531c0` wird als Originalbytes aus dem Runtime-Dump eingebunden; der
  ARM1176-Systemlauf führt den DSB-Befehl aus.
- Der echte Loadercode wird über Alias `0x8bf00000` geladen; sein
  `bss_init`-Einstieg `0x8bf001c8` löscht die dort gesetzten BSS-Marker.
- Am Alias-Loader-Einstieg und an der DRAM-Identitätsabbildung sind beide
  `0x10f80` Byte bytegleich zu `bootloader-safe.bin`.
- Die synthetische L1-Tabelle liegt bei `0x0bfd0000`. Ein früher Versuch bei
  `0x08004000` überschrieb OSOS-Gadgets und ist kein gültiger Negativbefund.

## Reproduktion

Vom Repository-Root:

```sh
utils/ipodnano5g/analysis/evidence/accessories-alias-system-parser-rehost-2026-10-31/run_alias_system_parser_rehost.sh
```

Der Runner baut das ELF, startet `qemu-system-arm -machine none -cpu arm1176`,
verbindet GDB, prüft die drei Übergabepunkte und BSS-Marker und vergleicht
beide Loader-Dumps mit `bootloader-safe.bin`.

## Dateien

- `OSOS_accessories_parser_alias_system_20261031.S` — Parser-Rehost,
  ROP-/FAT-Teil, MMU-Tabellenaufbau und echter DSB-Include.
- `OSOS_accessories_parser_alias_system_20261031.ld` — Adresslayout und
  Program-Header; der Loader-Alias wird erst durch die L1-Tabelle abgebildet.
- `OSOS_accessories_parser_alias_system_20261031.gdb` — Breakpoints,
  Marker und Speicherexporte.
- `run_alias_system_parser_rehost.sh` — Build, System-QEMU-Lauf und
  Assertions.
- `gdb_alias_system_parser.log` — Register, Deskriptoren und Breakpoints.
- `qemu_alias_system_parser.log` — QEMU-Ausgabe.
- `loader-alias-at-entry.bin`, `loader-canonical-at-entry.bin` — Loader-Dumps
  am Halt vor der ersten Loaderinstruktion.
- `SHA256SUMS` — Prüfsummen der Artefakte.

## Grenzen

Die Parser-Open-/FAT-Handle-/Streamzustände werden teilweise gesetzt. Der
`BOOT.BIN`-Open und Dateiread bleiben im Harness modelliert; der Callback
kopiert den eingebetteten Loader. Die L1-Tabelle enthält die ermittelten
OSOS-Werte, wird aber vom Harness aufgebaut. Der Lauf beweist weder reale
Providerregistrierung und Datei-Erreichbarkeit auf dem iPod noch Cache-/TLB-
Zustand, Rockbox-Ausführung oder untethered Boot. Es gibt keinen Geräte-, USB-,
DFU- oder Flashzugriff.
