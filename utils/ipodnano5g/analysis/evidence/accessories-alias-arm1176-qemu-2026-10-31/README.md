# ARM1176-System-Rehost für den Alias-Handoff

Stand: 31.10.2026. Lokaler QEMU-Systemlauf mit `arm1176`; kein Gerät, USB,
DFU, Neustart oder Flashzugriff.

## Rehost mit synthetisch aufgebauter Tabelle

Der Harness baut eine ARMv6-L1-Tabelle aus den im statischen OSOS-Body
gefundenen Abschnittswerten:

- DRAM `0x08000000..0x0bffffff` identity-mapped mit `0x7c0e`.
- Alias `0x88000000..0x8bffffff` auf dasselbe DRAM mit `0x4c02`.
- Die für den Rockbox-Vektor-Relokationsschritt benötigte IRAM-Abbildung bei
  `0x22000000` sowie den Low-Vector-Alias aus dem Body-Mapper.

Der lokal gebaute, bei `0x0bf00000` gelinkte Rockbox-Zwischenloader wird als
Read-Quelle bei `0x0a000000` geladen. Der Harness führt den Accessories-Pfad
für die entscheidenden Übergabeschritte nach: Cleanup-Byte vor dem Read,
byteweises `LDRB`/`STRB` in das Aliasziel `0x8bf00000`, DSB, `bss_init` über
`0x8bf001c8` und Branch zum Loader über `0x8bf00000`. Danach läuft der echte
Loader-Startcode bis `start_loc` bei `0x0bf000e0`.

Der Harness setzt `TRE=0`, `C=0`, `I=0`, `XP=1` und `M=1`. Er prüft damit
Adressübersetzung und Kontrollfluss unter der angenommenen TRE-Attributierung;
er bildet keinen ARM1176-Cachezustand ab.

## Ergebnis

GDB hält QEMU bei `PC=0x0bf000e0`, nachdem der Loader über den Alias gestartet,
sein relocierter Startcode ausgeführt und die Vektoren nach IRAM kopiert hat.
Die am Breakpoint aus dem kanonischen Bereich und aus dem Alias exportierten
`0x10f80` Bytes sind beide bytegleich zu `bootloader-safe.bin`:

`ba355bf5771a686a07829d3df45772c2d4bc9c33ca9cf0346d17408a5f20b4b2`

Die ersten Wörter unter `0xbf00000` und `0x8bf00000` stimmen überein. Der
Beginn des vom `bss_init` geleerten Bereichs bei `0x0bf20000` ist null.
GDB liest außerdem die tatsächlich benutzten L1-Einträge zurück:
`0x2200c802` (Low-Vector-Alias), `0x08007c0e` (DRAM-Basis),
`0x0bf04c02` (Loader-Alias) und `0x22004c02` (IRAM).

Reproduktion vom Repository-Verzeichnis `rb-n5g/`:

```sh
bash utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-2026-10-31/run_alias_loader_handoff.sh
```

Der Lauf baut `alias_loader_handoff.elf`, startet `qemu-system-arm -machine
none -cpu arm1176 -m 576M`, verbindet GDB lokal auf Port `12346`, prüft den
Breakpoint und vergleicht beide Dumps mit dem Loader. `alias_loader_handoff.S`
und `.ld` enthalten das Rehost; `alias_loader_handoff.gdb` hält die GDB-Befehle
fest. `gdb_alias_handoff.log` und `qemu_alias_handoff.log` sind die Laufbelege.
`SHA256SUMS` listet Quell-, Build- und Ergebnisdateien.

## Zusatzlauf mit dem exakten OSOS-Descriptor-Writer

Ein zweiter Harness verwendet den tatsächlichen ARM-Thumb-Code des generischen
OSOS-L1-Writers aus `osos_runtime_dram_20261025.bin` bei `0x080e3e84` und
dessen Tabellenzeiger-Literal `0x086dc000`. Der Runtime-Suffix ist eine
offline Abbildung des IMG1-DRAM-Suffixes, kein Live-RAM-Dump; sein SHA-256 ist
`1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`. Der
Writer-Code liegt im byteidentischen Bereich des IMG1-Bodys. Der Harness löscht
die 4096 L1-Einträge am OSOS-Tabellenort und ruft den echten Writer mit den
statisch ermittelten Parametern für DRAM-Identity, SDRAM-Alias,
Low-Vector-Alias und IRAM-Identity auf. Danach installiert er diese Tabelle und
führt den gleichen Loader-Handoff aus.

GDB liest nach dem Handoff folgende Deskriptoren direkt aus der von OSOS
verwendeten Tabelle zurück:

- `0x086dc200 = 0x08007c0e` — DRAM-Identity.
- `0x086de200 = 0x08004c02` — erster Abschnitt des Aliasfensters.
- `0x086de2fc = 0x0bf04c02` — Aliasabschnitt für Loaderziel `0x8bf00000`.
- `0x086dc000 = 0x2200c802` — Low-Vector-Alias.
- `0x086dc880 = 0x22004c02` — IRAM-Identity.

Der Kontrollfluss hält wieder bei `PC=0x0bf000e0`; beide Loader-Dumps sind
bytegleich zu `bootloader-safe.bin` (SHA-256
`ba355bf5771a686a07829d3df45772c2d4bc9c33ca9cf0346d17408a5f20b4b2`).
Reproduktion:

```sh
bash utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-2026-10-31/run_osos_exact_mapper_handoff.sh
```

`osos_exact_mapper_handoff.S` ruft den echten Writer auf; `.ld` und `.gdb`
fixieren Speicherlayout und Prüfstellen. `gdb_osos_exact_mapper_handoff.log`,
`qemu_osos_exact_mapper_handoff.log` und die beiden Loader-Dumps sind die
Laufbelege. Der Runner benötigt zusätzlich die lokale Datei
`../local-analysis/inputs/osos_runtime_dram_20261025.bin` mit dem oben genannten
SHA-256.

## Zusatzlauf mit dem echten OSOS-MMU-Initialisierer

Der dritte Harness lädt den SRAM-Prefix `osos_bootprefix_22000000_20261031.bin`
bei `0x22000000`, den offline abgebildeten DRAM-Code-Suffix bei `0x08000000`
und hält vor dem Aufruf des tatsächlichen `FUN_22005d3c` an. Diese Funktion
und ihre CP15-Helfer laufen dann unverändert im ARM1176-System-QEMU; über den
SRAM-Thunk bei `0x22003970` ruft sie den echten Descriptor-Writer bei
`0x080e3e84` auf. Der Harness setzt die L1-Tabelle zuvor am echten OSOS-Ort
`0x086dc000` auf null, entsprechend dem im normalen Layout genullten BSS.
Er führt nicht den IMG1-Relokator oder den übrigen OSOS-Startup aus.
Der DRAM-Suffix ist kein Live-Dump und weicht am Ende in 2.267 Bytes vom
IMG1-Body ab (`0x6c3768..0x6c43a7`); der ausgeführte Mappercode ist im
bytegleichen Bereich.

Nach Rückkehr aus `FUN_22005d3c` liest der Harness CP15 und die Tabelle aus:

- `SCTLR = 0x00c5187d`: `M=1`, `C=1`, `I=1`, `XP=1`, `TRE=0`.
- `ACTLR = 0x00000007`, `TTBR0 = 0x086dc000`, `TTBCR = 0`, `DACR = 1`.
- Low-Vector-Alias `0x2200c802`, DRAM-Identity `0x08007c0e`, IRAM-Identity
  `0x22004c02`, Aliasanfang `0x08004c02` und Loader-Alias
  `0x0bf04c02` bei `0x086de2fc`.
- Der zusätzliche SROM-Eintrag lautet `0x38000c02`; die IRAM-Range beginnt
  bei `0x20006c0a`.

`TRE=0` entspricht dem ARMv6-Attributmodus. Für das Aliasdescriptorwort
`0x0bf04c02` sind `TEX=100` und `C=B=0`; nach dem ARM-Attributschema ergeben
sich nicht-cachebare Inner-/Outer-Attribute für Normal Memory. Das ist für
den echten Chip aus dem Code und dem in QEMU gelesenen Zustand gestützt, aber
weiterhin keine Live-Messung. Der QEMU-Lauf stoppt bei `0x22005d3c`, führt die
Funktion aus und erreicht anschließend `PC=0x0bf000e0`. Die kanonischen und
Alias-Dumps des Loaderabbilds stimmen bytegenau mit `bootloader-safe.bin`
überein. Die ARM-Control- und TEX-Attributfelder sind im
[ARM1176JZF-S TRM](https://documentation-service.arm.com/static/5e8e294efd977155116a6ca3)
und im
[ARM Architecture Reference Manual, Abschnitt ohne TEX-Remap](https://documentation-service.arm.com/static/5f8daeb7f86e16515cdb8c4e)
beschrieben.

Reproduktion:

```sh
bash utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-2026-10-31/run_osos_startup_mapper_handoff.sh
```

Der Runner braucht außerdem
`../local-analysis/inputs/osos_bootprefix_22000000_20261031.bin` (SHA-256
`0b01c47e51b562523ddce4747529bd9f41b14840337e76ede54af60a809f54e2`) und den
bereits genannten DRAM-Suffix. Beide Eingaben sind extrahierte
Offline-Abbildungen, keine Geräte-RAM-Dumps. `gdb_osos_startup_mapper_handoff.log`
und `qemu_osos_startup_mapper_handoff.log` halten den Lauf fest.

## Aussagegrenze

Der erste Lauf belegt den Kontrollfluss mit einer **synthetisch aufgebauten**
L1-Tabelle. Der Zusatzlauf belegt, dass der echte OSOS-Descriptor-Writer die
statisch ermittelten Werte in QEMU in die Tabelle bei `0x086dc000` schreibt
und dass diese Abbildung den Loader-Handoff trägt. Er führt weder den
OSOS-Startup noch den 704-Byte-ROP-Kandidaten, den Datei-/FAT-/VFS-Pfad oder
den Callback-Stack aus. Die Parameter werden dem echten Writer vom Harness
übergeben; sie wurden nicht aus einem live beobachteten Startup übernommen.
Der dritte Lauf ruft den echten OSOS-MMU-Initialisierer und dessen CP15-Helfer
auf und liest die daraus entstandene Tabelle sowie CP15-Werte zurück. Auch
dieser Lauf überspringt den IMG1-Relokator, den tatsächlichen
Accessories-Callback und Dateisystem-Read; der Harness kopiert den Loader als
kontrollierte Eingabe. QEMU-TCG modelliert die echten separaten I-/D-Caches,
Write-Buffer, DMA und die DRAM-Belegung des Geräts nicht. Die Läufe belegen
daher weder eine live persistente Geräte-TLB-Abbildung, reale Cache-Kohärenz
noch einen Geräteboot.
