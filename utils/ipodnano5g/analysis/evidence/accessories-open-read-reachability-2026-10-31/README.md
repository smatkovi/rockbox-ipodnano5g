# Accessories Open-/Read-Abgleich und Voice-Reader-Grenztest

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
- `OSOS_variable_reader_*.application.log` und `OSOS_file_read_bounds_listing_20261031.application.log`:
  Voice-Datei-Stat/Allokation, Caller, Stream-Grenzprüfung und 64-KiB-Chunklimit.
- `repro_variable_voice_reader_wrap_20261031.c` und `.log`: Host-Modell mit
  Assertions für die 32-Bit-Längen-/Allocatorüberläufe und die bedingte
  Überschreibung beim vollständigen ersten 64-KiB-Read. Kein Firmwarecode und
  kein Gerätetest.
- `repro_variable_voice_reader_wrap_20261031.sanitizers.log`: zusätzlicher
  Host-Lauf mit AddressSanitizer und UndefinedBehaviorSanitizer, ohne Befund.
- `OSOS_voice_reader_stream_wrapper_max_request_20261031.S`, `.ld`,
  `.commands.txt` und `.run.log`: ARM1176-QEMU-Rehost mit Originalbytes von
  `FUN_081fd5e8`; der
  Prüf-Provider bestätigt den ungekürzten Erstrequest `0xffffffff` bei Offset
  null. Datei-Status und Provider sind Stubs; der FAT- und Allokatorpfad läuft
  in diesem Test nicht.
- `OSOS_file_copy_*.application.log`, `OSOS_fat_write_provider_boundaries_20261031.application.log`
  und `OSOS_directory_remove_helpers_20261031.application.log`: ergänzende,
  read-only-Abzüge zu den bereits untersuchten Dateioperationen.
- `OSOS_n5g_uboot_ram_console_20261031.log`: persistierter RAM-U-Boot-Konsolenausschnitt;
  kein NAND-/NOR-Schreiben oder -Löschen.
- `SHA256SUMS`: Prüfsummen dieser Ablage.

Die Abzüge ändern weder das Ghidra-Projekt noch den iPod. Interpretation,
erreichte Pfade und Grenzen stehen in
`../../OSOS-variable-voice-reader-wrap-followup-2026-10-31.md`.
