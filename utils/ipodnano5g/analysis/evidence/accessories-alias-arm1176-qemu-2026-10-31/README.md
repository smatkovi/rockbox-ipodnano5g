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

## Aussagegrenze

Der erste Lauf belegt den Kontrollfluss mit einer **synthetisch aufgebauten**
L1-Tabelle. Der Zusatzlauf belegt, dass der echte OSOS-Descriptor-Writer die
statisch ermittelten Werte in QEMU in die Tabelle bei `0x086dc000` schreibt
und dass diese Abbildung den Loader-Handoff trägt. Er führt weder den
OSOS-Startup noch den 704-Byte-ROP-Kandidaten, den Datei-/FAT-/VFS-Pfad oder
den Callback-Stack aus. Die Parameter werden dem echten Writer vom Harness
übergeben; sie wurden nicht aus einem live beobachteten Startup übernommen.
QEMU-TCG modelliert die echten separaten I-/D-Caches, Write-Buffer, DMA und die
DRAM-Belegung des Geräts nicht. Die Läufe belegen daher weder eine persistente
Geräte-TLB-Abbildung noch Cache-Kohärenz oder einen Geräteboot.
