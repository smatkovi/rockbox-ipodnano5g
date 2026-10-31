# 736-Byte-Alias-/DSB-/BSS-Init-Parser-Rehost

Stand: 31.10.2026. Der 736-Byte-Kandidat lief durch den OSOS-Parser-/ROP-
Rehost. GDB hält am DSB-Helper, am `bss_init`-Einstieg und am finalen Loader-
Entry. Es gab keinen Geräte-/USB-/DFU-Zugriff und keine NAND-/NOR-/Firmware-
Änderung.

## Ergebnis

Der Kandidat führt den Rehost bis zum DSB-Helper bei `0x083531c0`. Dort ist
`r0=0`, `r1=0x10f80` und `r2=0x8bf10f80`. Der Helper wird im Rehost durch ein
einzelnes `bx lr` repräsentiert; der echte CP15-DSB-Befehl wird absichtlich
nicht ausgeführt. Der ROP-Kontrollfluss kehrt danach zurück und erreicht den
kopierten echten `bss_init` bei `PC=0x8bf001c8`.

GDB setzt vor `bss_init` drei Marker im kanonisch gelinkten BSS-Bereich
`0x0bf20000..0x0bfbfcff`. Am finalen Entry `PC=0x8bf00000` sind alle drei
Werte null; `r0` und `r1` stehen auf `0x0bfbfd00`, dem Ende der BSS-Schleife.
Der bei `0x8bf00000` exportierte Loaderbereich ist bytegleich zum eingebetteten
Loader-Build, SHA-256
`ba355bf5771a686a07829d3df45772c2d4bc9c33ca9cf0346d17408a5f20b4b2`.
GDB beendet das Inferior am finalen Entry vor der ersten Loaderinstruktion.

## Grenzen

Das ist ein positiver Parser-/ROP-/BSS-Kontrollflussnachweis für den
Host-Rehost, kein erfolgreicher DSB-Test. Das `bx lr`-Stub führt keine
Speicherbarriere aus. QEMU Linux-User bildet `0x8bf00000` und den kanonischen
BSS-Bereich als getrennte ELF-Segmente ab; es prüft nicht, ob beide Adressen
auf dem iPod dieselben physischen DRAM-Bytes bezeichnen. Der Lauf belegt weder
den aktiven Geräte-MMU/TLB-Zustand noch Cachekohärenz, freien DRAM oder einen
untethered Geräteboot. Der erfolgreiche `/BOOT.BIN`-Read bleibt ein Callback,
der die eingebetteten Loaderbytes kopiert.

## Reproduktion

Vom Repository-Root:

```sh
utils/ipodnano5g/analysis/evidence/accessories-alias-dsb-parser-rehost-2026-10-31/run_alias_dsb_parser_rehost.sh
```

Der Runner baut das ELF, startet `qemu-arm`, prüft die drei Breakpoints,
initialisiert BSS-Marker, exportiert den Aliasbereich, vergleicht ihn mit
`bootloader-safe.bin` und beendet das Inferior am finalen Entry. Ein anderer
GDB-Port kann über `GDB_PORT` gesetzt werden. Der Quellkandidat liegt unter
`../accessories-cache-alias-2026-10-31/candidate_accessories_reg_alias_dsb_bssinit_unexecuted.bin`
(736 Byte, SHA-256
`b19180df8a20ef7e5496885bf227827623d6c3115adef0e4d47ed2efe2e6f78e`).
