# iTunes-Präfix: Belege für den MMU-Data-Abort-Abgleich

Read-only-Daten für
`OSOS-iTunes-prefix-data-abort-followup-2026-10-31.md`. Der Runtime-
Ghidra-Projektstand wurde mit `-noanalysis -readOnly` geöffnet. Der Bootprefix
und das Runtime-Abbild wurden lokal disassembliert; keine Geräteoperation.

## Ergebnisse

- Der ARM Data-Abort-Vektor bei Prefixadresse `0x22000010` verzweigt nach
  `0x220038a8`. Das Literal dort ist `0x08352974`.
- Der Runtime-Handler reicht den Kontext an `FUN_08355dd8`. Wenn dessen
  JTAG-Warteflag null ist, speichert `FUN_08056dd0` den Ausnahmezustand und
  `arm_81a5608` läuft endlos. Das passt zum bereits dokumentierten OSOS-
  Ausnahmeverhalten.
- `FUN_22005d3c` setzt die L1-Tabelle nach dem Prefix-BSS-Nullen mit den im
  Hauptbericht aufgeführten Bereichen auf. Ein normaler Zeitwert mit
  resultierender Adresse `0x4bxxxxxx` liegt in keiner dieser expliziten
  Spannen. Der bekannte spätere Runtime-Mapper fügt ein 1-MiB-Fenster bei
  `0x18000000` hinzu.
- Der konkrete Zeitwert und das JTAG-Flag des Geräts sind nicht bekannt. Die
  Aussage über nicht abgebildete Adressen gilt für die untersuchten
  Initialisierungs- und Mapperpfade; indirekte spätere Tabellenänderungen
  bleiben als Restunsicherheit.

## Dateien

- `prefix_vectors_20261031.objdump.txt`: Vektortabelle.
- `prefix_mmu_setup_20261031.objdump.txt`: alle Map-Aufrufe und Literale aus
  `FUN_22005d3c`.
- `runtime_abort_handler_20261031.objdump.txt`: ARM-Handler ab `0x08352974`.
- `data_abort_handler_20261031.ghidra.log`: read-only-Decompilation von
  `FUN_08355dd8`.
- `abort_terminal_helpers_20261031.ghidra.log`: Decompilation von
  `arm_81a5608` und `FUN_08056dd0`.
- `INPUT_SHA256.txt`: Hashes der lokal verwendeten Prefix- und Runtime-Abbilder.

Der Data-Abort-Vektor und der nicht-JTAG-Hangpfad werden außerdem in
`OSOS-iAP-location-packet86-followup-2026-10-28.md` behandelt.
