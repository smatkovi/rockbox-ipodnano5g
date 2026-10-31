# ARM1176-System-Rehost für den Alias-Handoff

Stand: 31.10.2026. Lokaler QEMU-Systemlauf mit `arm1176`; kein Gerät, USB,
DFU, Neustart oder Flashzugriff.

## Was der Rehost abbildet

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

## Aussagegrenze

Das ist ein positiver Kontrollflussnachweis für eine **synthetisch aufgebaute**
L1-Tabelle und den vorhandenen Loader. Der 704-Byte-ROP-Kandidat selbst, der
OSOS-Datei-/FAT-/VFS-Pfad, der Callback-Stack und die reale OSOS-Translation
Table wurden nicht ausgeführt oder beobachtet. QEMU-TCG modelliert die echten
separaten I-/D-Caches, Write-Buffer, DMA und die DRAM-Belegung des Geräts nicht.
Der Lauf bestätigt daher weder die aktive Aliasabbildung noch die Cache-
Kohärenz oder einen Geräteboot.
