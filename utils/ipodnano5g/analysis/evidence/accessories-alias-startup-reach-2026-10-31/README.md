# OSOS-Section-Mapping und frühe Alias-Initialisierung

Stand: 31.10.2026. Offline-Abgleich des IMG1-Bodys, des getrennt abgebildeten
SRAM-Prefixes und des DRAM-Code-Suffixes sowie read-only Ghidra-Abfragen. Kein
Geräte-/USB-/DFU-Zugriff und keine Änderung an NAND, NOR oder Firmware.

## Ergebnis

Die vorherige Auswertung verglich gleiche Zahlenadressen in zwei verschiedenen
Adressräumen und leitete daraus einen scheinbaren Runtime-Overlay-Widerspruch
ab. Das war falsch. `osos_body.bin` ist abschnittsweise geladen:

| IMG1-Dateioffset | Laufzeitadresse | Abschnitt |
| --- | --- | --- |
| `0x000000..0x00e27b` | `0x22000000..0x2200e27b` | SRAM-Text/Bootprefix |
| `0x02e27c..0x6f2623` | `0x08000000..0x086c43a7` | DRAM-Text/Daten |

Die Tabelle zeigt die endgültigen Laufzeitadressen. Die Abschnittszuordnung
steht in der lokalen OSOS-Speicherlayouttabelle
`/home/sebastian/ipod-re/freemyipod.org/wiki/OSOS.html` und wird durch die
Größe und Bytes der extrahierten Eingaben bestätigt. Der SRAM-Prefix ist
`0xe27c` Byte groß und stimmt bytegenau mit dem Beginn des IMG1-Bodys überein.
Die DRAM-Eingabe `osos_runtime_dram_20261025.bin` ist die Offline-Abbildung
des Body-Suffixes ab Datei-Offset `0x2e27c`, nicht ein Live-RAM-Abzug. Sie
stimmt mit dem Suffix bis auf 2.267 abweichende Bytes am Ende
`0x6c3768..0x6c43a7` überein. Die Bytes des frühen Mapperziels liegen außerhalb
dieser Differenz.

Der initiale IMG1-Entry liegt bei Offset `0`; laut lokaler RetailOS-Doku lädt
der zweite Bootloader OSOS nach DRAM. Der erste Branch läuft daher zunächst
bei `0x08000000` und führt nach `0x08007038`; der Stub verzweigt bei
`0x08007044` nach `0x08005058`. `FUN_08007060` berechnet dort aus dem
Symbolunterschied `0x22007060 - 0x08007060` das Delta `0x1a000000`, worauf
`FUN_08005ec8` die Abschnitte an ihre Zieladressen kopiert und anschließend
zum SRAM-Entry springt. Die Relokationstabelle im Body bestätigt im Detail:
SRAM-Text `0x08000000 -> 0x22000000` (`0xe27c` Byte), Nullung von
`0x2200e27c..0x2200f43f` (`0xbc4` Byte), der physisch im Body enthaltene
`0x20000`-Byte-Block SRAM-BSS/Daten `0x0800e27c -> 0x22030000`,
DRAM-Textdaten `0x0802e27c -> 0x08000000`
(`0x6c3768` Byte) sowie Frameworks `0x086f19e4 -> 0x086c3768`
(`0xc40` Byte). Im relocatierten Lauf ist das Delta null; erst dann erreicht
der Start den MMU-Setup-Aufruf.

Damit sind die relocatierten Startadressen:

1. Der IMG1-Entry bei `0x22000000` verzweigt nach `0x22007038`.
2. Das Stack-Setup bei `0x22007044` verzweigt nach `0x22005058`.
3. Der Initialisierer ruft bei `0x220050c8` `FUN_22005d3c` auf.
4. `FUN_22005d3c` ruft den SRAM-Thunk bei `0x22003970` auf.
5. Der Thunk lädt `0x080e3e85` und wechselt damit in den DRAM-Abschnitt.

Der 36-Byte-Descriptor-Schreiber an Laufzeitadresse `0x080e3e84` stammt aus
IMG1-Dateioffset `0x112100` (flache Full-Body-Ghidra-Adresse `0x08112100`).
Seine Bytes und das anschließende TTBR-Literal `0x086dc000` stimmen exakt mit
der DRAM-Suffix-Abbildung überein. Der Vergleich `Full-Body-VA 0x080e3e84`
gegen `Runtime-VA 0x080e3e84` war ungültig: Die erste Adresse bezeichnet
Dateioffset `0x0e3e84`, die zweite dagegen Dateioffset `0x112100`. Der zweite
Wert ist das Ziel des SRAM-Thunks. Es ist kein Overlay erforderlich.

Die Alias-Deskriptoren werden im normalen statischen Setup-Pfad angefordert.
Der Aufruf bei `0x22005dbc` übergibt:

- virtuelle Basis `0x88000000`, inklusive Ende `0x8bffffff`;
- physische Basis `0x08000000`;
- Attributwort `0x4c02`;
- L1-Tabelle ab `0x086dc000`.

Der generische Schreiber legt 64 Einträge an. Der Abschnitt für VA
`0x8bf00000` wird zu `0x0bf04c02` und liegt bei Tabellenadresse `0x086de2fc`.
Die Tabelle befindet sich im DRAM-BSS außerhalb der Code-Suffixdatei; ihre
Einträge beim Accessories-Callback wurden nicht live gelesen.

Der DRAM-Mapper hat im Runtime-Koordinatensystem den statischen Aufruferpfad
`FUN_08272474 -> FUN_0801e0d8 -> FUN_081a5d48`. Dieser spätere Pfad richtet ein
einzelnes 1-MiB-Fenster bei VA `0x18000000` mit Attribut `0x7c0e` ein. Er ist
kein Gegenbeleg zur frühen Alias-Initialisierung. Ein zusätzlicher read-only
Xref-Lauf fand genau einen direkten Callsite zum Writer (`081a5d68 ->
080e3e84`) und einen direkten Caller des Fenster-Setters (`0801e158 ->
081a5d48`). Der Setter `FUN_0801e0d8` schreibt in seinem konfigurierten Pfad
VA `0x18000000`, Größe `0x100000` und Attribut `0x7c0e`; damit ist kein
direkter Überschreiber der Accessories-Aliasrange belegt. Indirekte Aufrufe
oder Tabellenänderungen außerhalb dieses Pfades bleiben möglich.

Für `TRE` gilt weiterhin: `FUN_22005d3c` ändert das SCTLR-Bit 28 nicht. Der
ARM1176-Resetwert ist `TRE=0`, und die geprüften BootROM-/N33-SCTLR-Updates
lassen das Bit ebenfalls unverändert. Das stützt `TRE=0` für den normalen
Pfad, misst aber nicht den Zustand vor dem Accessories-Callback. Nur unter
dieser Annahme ist `0x4c02` nichtcachebares Normal Memory. Eine reale
Aliasübersetzung und Cache-/Write-Buffer-Verhalten sind hier nicht gemessen.

## Reproduktion und Belege

- `scripts/verify_osos_section_map_alias.py` prüft Größen, SHA-256, Mapping,
  Branchziele, Thunk-Literal, Mapperbytes und TTBR-Literal.
- `scripts/verify_osos_relocation_startup.py` leitet die initialen Branchziele,
  das Relokationsdelta und die Quell-/Zielbereiche aus dem IMG1-Body ab.
- `OSOS_body_initial_to_relocated_boot_20261031.application.log` enthält die
  read-only Ghidra-Instruktionsfolge von Entry/Stackstub/Delta und Relocator.
- `OSOS_body_initial_startup_listing_20261031.application.log` hält die Branches
  vom initialen DRAM-Entry über `0x08005058` und den bedingten Relokationscall
  fest.
- `OSOS_relocation_startup_20261031.txt` ist die persistente Ausgabe des
  Relokationsskripts.
- `OSOS_runtime_alias_writer_direct_xrefs_20261031.application.log` enthält
  die read-only Xrefs zum DRAM-Writer und zu seinem Runtime-Caller.
- `OSOS_section_map_alias_target_20261031.txt` ist dessen persistente Ausgabe.
- `OSOS_prefix_correct_sram_entry_mmu_20261031.application.log` enthält den
  read-only Prefix-Listinglauf für `0x22005058` und `0x22005d3c`; der erste
  ARM-Branch ist zusätzlich aus den Rohbytes/Branchfeldern berechnet.
- `scripts/compare_img1_runtime_ranges.py` vergleicht Laufzeitadressen mit
  korrespondierenden IMG1-Dateioffsets.
- `OSOS_body_runtime_address_compare_20261031.txt` enthält den korrigierten
  Abschnittsvergleich.
- `OSOS_body_*`-Logs mit Adressen `0x08000000+` stammen vom flach importierten
  Full-Body-Projekt. Sie belegen Rohcode/-daten an Dateioffsets, nicht die
  tatsächlichen Laufzeitadressen des SRAM-Prefixes. Für reale Prefixadressen
  ist `OSOS_prefix_correct_sram_entry_mmu_20261031.application.log` maßgeblich;
  für DRAM-Codeadressen das Runtime-Projekt und der Abschnittsvergleich.

Ghidra wurde mit `/opt/ghidra/support/analyzeHeadless -readOnly -noanalysis`
auf den vorhandenen Projekten ausgeführt. Der Abschnittsvergleichsskript
ändert die Ghidra-Projekte nicht. `SHA256SUMS` sichert die Dateien dieses
Evidence-Verzeichnisses.

## Verbleibende Unsicherheiten

- Die statische Initialisierung beschreibt die Aliasrange im normalen OSOS-
  Startpfad nach der statisch belegten Abschnittsrelokation. Ein Geräte-Trace bestätigt nicht, dass sie bis zum
  Accessories-Callback bestehen bleibt.
- `TRE`, TLB-Inhalt und L1-Tabellenwerte wurden nicht live gemessen.
- Die 2.267 abweichenden Bytes am Ende des Offline-Suffixes sind nicht als
  Laufzeitänderungen identifiziert; sie betreffen den Mappercode nicht.
- `/BOOT.BIN` fehlt in der vorhandenen Volumeaufnahme. Die vollständige
  Accessories-/FAT-/VFS-Erreichbarkeit und ein Rockbox-Geräteboot bleiben offen.
