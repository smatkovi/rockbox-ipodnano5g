# Alias-Kandidat im OSOS-Parser-Rehost

Stand: 31.10.2026. Der 704-Byte-Accessories-Kandidat wurde im vorhandenen
ARM-OSOS-Parser-Rehost bis zu seinem Alias-Sprungziel geführt. Der GDB-Halt
liegt auf der ersten Loaderadresse; kein Loaderbefehl wird ausgeführt und
kein Gerät/USB/DFU oder Flashspeicher wird benutzt.

## Ergebnis

QEMU hält bei `PC=0x8bf00000`. Die Register zeigen `r1=0x10f80` (Read-Länge)
und `r2=0x8bf10f80` nach der vollständigen Bytekopie. Das Statuswort
`read_called` ist 1; auch die Parser-, Open- und Datei-Read-Callbacks wurden
erreicht. Der Speicherbereich `0x8bf00000..0x8bf10f7f` ist bytegleich zum
lokalen `bootloader-safe.bin`; beide SHA-256-Werte sind
`ba355bf5771a686a07829d3df45772c2d4bc9c33ca9cf0346d17408a5f20b4b2`.
`gdb_alias_parser_rehost.log` enthält Register, den ersten Loaderwortlaut und
den Parser-/Dateizustand am Breakpoint. GDB beendet das QEMU-Inferior dort,
bevor die erste Loaderinstruktion ausgeführt wird.

Der Lauf führt den echten OSOS-Parser-/ROP-Kontrollfluss im bestehenden
Rehost aus. Der erfolgreiche `/BOOT.BIN`-Dateiread selbst bleibt ein
Harness-Callback: Er prüft die Adresse und Länge und kopiert die eingebetteten
Loaderbytes. Die ELF-Datei bildet `0x8bf00000` als separaten virtuellen
Hostbereich ab. Sie beweist daher weder, dass das Gerät dort dieselbe
physische SDRAM-Zelle abbildet, noch die tatsächliche Cache-/TRE-/TLB-Lage.
Für die synthetische MMU-Abbildung siehe den separaten System-QEMU-Rehost
`../accessories-alias-arm1176-qemu-2026-10-31/README.md`.

## Reproduktion

Im Repository-Root:

```sh
utils/ipodnano5g/analysis/evidence/accessories-alias-parser-rehost-2026-10-31/run_alias_parser_rehost.sh
```

Der Runner baut das ELF, startet `qemu-arm`, verbindet GDB, hält am Alias-Entry,
dumped den Zielbereich und beendet das Inferior mit `kill`. Der GDB-Port kann
mit `GDB_PORT` geändert werden. `loader-alias-postread.bin` ist der Dump;
`qemu_alias_parser.stderr` protokolliert, dass QEMU kontrolliert über den
GDBstub beendet wurde.

## Eingaben und Änderungen

- Eingabe in beiden OSOS-Streampositionen: `../accessories-cache-alias-2026-10-31/candidate_accessories_reg_uncached_alias_unexecuted.bin`
- Kandidat-SHA-256: `2df24b2aa0c281eb51e53418c6d8c89c9e39e301906996a07928f23f01e340a1`
- Read-Callback: erwartet Ziel `0x8bf00000`, Länge `0x10f80`; kopiert mit
  `LDRB`/`STRB`, wie der untersuchte OSOS-Dateileser.
- ELF-Linker: zusätzlicher beschreib-/ausführbarer `PT_LOAD`-Bereich bei
  `0x8bf00000..0x8bf10f7f`, damit Linux-User-QEMU den Branch und den GDB-Dump
  abbilden kann.
- Loader-Imagequelle: `../accessories-safe-loader-relocation-2026-10-30/bootloader-safe.bin`.

Der 736-Byte-Kandidat mit zusätzlichem DSB-/BSS-Init-Schritt ist in diesem
Rehost nicht ausgeführt. Ein untethered Geräteboot ist damit nicht belegt.
