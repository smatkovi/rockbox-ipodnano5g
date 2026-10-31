# Accessories Open-/Read-Abgleich

Read-only Ghidra-Abzüge aus dem vorhandenen Runtime-Projekt, geöffnet mit
`-noanalysis -readOnly`. Eingabe: `osos_runtime_dram_20261025.bin`; sein
SHA-256 steht in `INPUT_SHA256.txt`.

- `OSOS_accessories_open_read_chain_20261031.ghidra.log`: Open-, Mount-, BPB-
  und Read-Funktionskörper von FAT-Provider und generischem VFS.
- `OSOS_accessories_open_read_instructions_20261031.ghidra.log`: exakte
  Instruktionen für `FUN_0812a870`, `FUN_081382b6`, den Aufruf von
  `FUN_0814f238` und die Registerübergabe.
- `OSOS_accessories_fat_path_scanner_and_read_20261031.ghidra.log`: Resolver-,
  Root-Handle-, LFN-Scanner-, Datei-Open- und Datei-Read-Funktionskörper.
- `SHA256SUMS`: Prüfsummen dieser Ablage.

Die Abzüge ändern weder das Ghidra-Projekt noch den iPod. Interpretation,
erreichte Pfade und Grenzen stehen in
`../../OSOS-accessories-open-read-reachability-followup-2026-10-31.md`.
