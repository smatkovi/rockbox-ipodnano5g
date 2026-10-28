# Voice-Audio-Ghidra-Belege (28.10.2026)

Dieses Verzeichnis enthält rebootfeste Analysebelege für die Voice-Audio-
Callback- und Heap-Reuse-Untersuchung.

## Inhalt

- 132 frühere Ghidra-Rohlogs als verlustfrei komprimierte `*.log.gz`-Dateien.
- Neue Ghidra-Ausgaben als `*.log` sowie die dafür verwendeten Java-Skripte unter
  `scripts/`.
- Eine synthetische 4-Byte-ARM-Instruktionsprobe und deren Disassemblierung; sie
  demonstriert nur das Dekodieren eines möglichen Teilworts und ist kein
  Geräte- oder Firmwaretest.
- `SHA256SUMS` prüft alle Dateien dieses Verzeichnisses außer sich selbst und
  außerdem die drei zugehörigen Voice-Analyseberichte.

## Speicherort und Eingaben

Die Dateien liegen im Repository unter
`utils/ipodnano5g/analysis/evidence/voice-audio-2026-10-28/` auf dem persistenten
Root-Dateisystem `/dev/nvme0n1p8` (ext4, Mountpunkt `/`). Die neuen Ghidra-Ausgaben
wurden direkt hier abgelegt; die älteren temporären Voice-Rohlogs wurden
verlustfrei hierher kopiert und die Berichtszitate auf diese Kopien umgestellt.

Read-only-Ghidra-Projekt:

`/home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis/`

Die Programmdatenbank liegt im Projektordner unter
`N5G_OSOS_runtime.rep/idata/00/~00000000.db/db.76.gbf`.

Eingabeabbild:

`/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin`

SHA-256: `1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`

## Prüfen

Vom Repository-Hauptverzeichnis:

```sh
sha256sum -c utils/ipodnano5g/analysis/evidence/voice-audio-2026-10-28/SHA256SUMS
```

Das Belegpaket stammt aus statischer, read-only-Ghidra-Analyse. Es enthält keine
Geräte-, USB-, DFU-, Boot- oder Flash-Testergebnisse.
