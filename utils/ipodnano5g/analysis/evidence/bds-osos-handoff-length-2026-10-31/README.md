# BDS→OSOS-Handoff: Kopierlänge und Protokollpuffer

Read-only-Nachprüfung der Übergabe von BDS-Modul `05__0.pe32` an den OSOS-
Runtimecode. Sie verwirft den zuvor vermuteten Ein-Byte-Längenunterschied,
prüft die Protokollanbieter von `FUN_00000bc4` und klärt die separate
GUID-`0x14f0`-Schnittstelle. Der BDS-Stackwert bei Handoff-Offset `+0x84`
bleibt vor einem Gate stack-abgeleitet; Modul 11 liest ihn als
Plattformkennung, schreibt ihn aber nicht. Es gab keinen Geräte-, USB-, DFU-,
Reboot-, Dateisystem- oder Flashzugriff.

## Ergebnis

- BDS `FUN_00000bc4` findet die GUID
  `CA BE 81 31 A1 92 41 BA 90 34 D9 F8 E4 9A 32 3D`, ruft die Methode bei
  `interface+4` mit `(interface, 1, sp+0x18)` auf und prüft den Rückgabewert
  nicht. Danach kopiert es genau `0x138` Bytes von `sp+0x18` nach
  `0x22028cc0`.
- Modul `42__0.pe32` registriert unter GUID `0x15a0` ein Interface, dessen
  vtable bei `0x744` auf `FUN_00000294`, `FUN_000005e8` und `FUN_000004c4`
  zeigt. Der zweite Eintrag `FUN_000005e8` ist der von BDS aufgerufene Slot.
  Die Funktion kombiniert `param_2` und `param_3` zu einer Bitmaske und
  verwendet diese beim Polling; sie dereferenziert `param_3` nicht und schreibt
  nicht durch diesen Zeiger.
- Modul `11__0.pe32` installiert unter GUID `0x1570` ein Interface mit vtable
  bei `0x294`; Slot 0 ist `FUN_00000270`, Slot 1 `FUN_00000220`. BDS ruft Slot
  0 mit `*(uint32_t *)(sp+0x9c)` und `*(uint32_t *)(sp+0x1a0)` auf.
  `FUN_00000270` gibt nur dann Erfolg zurück, wenn der erste Skalar `>> 16 ==
  0x1c` und der zweite `0x1c000` ist. Sie dereferenziert und beschreibt keinen
  der Werte.
- Direkte Stores in `FUN_00000bc4` initialisieren den kopierten Bereich
  `[sp+0x18, sp+0x150)` nicht; der Nullstore liegt genau am exklusiven Ende
  `sp+0x150`. Der einzige In-Range-Zeiger, den BDS einem Provider übergibt,
  ist `sp+0x18` an den nicht schreibenden Modul-42-Slot. Das Wort bei
  `sp+0x9c` ist damit stack-abgeleitet. Der Rückgabestatus des vorherigen
  `param_1+0x24`-Aufrufs wird ignoriert; sein 0x30-Byte-Ausgabebereich ab
  `sp+0x178` umfasst zwar `sp+0x1a0`, bei Fehler könnte aber auch dieses
  Gate-Wort stale sein.
- Korrektur zur vorigen Zwischenfassung: GUID `0x14f0` gehört zum separaten
  Modul-01-Provider und wird in anderen BDS-Funktionen referenziert. Sie ist
  nicht der Anbieter, der in `FUN_00000bc4` den Wert bei `sp+0x9c` befüllt.
  Die frühere Behauptung eines Schreibers an `sp+0x9c` war falsch.
- Die Rohdaten zeigen die Modul-01-Interface-Tabelle ab `0x428` mit Slot 0
  `0x265` (`FUN_00000264`), Slot 1 `0x395` (`FUN_00000394`) und Slot 2
  `0x221` (`FUN_00000220`). BDS ruft Slot 0 mit zwei Argumenten auf.
  `FUN_00000264` enumeriert Dateisystem-Handles, fragt Info ab, vergleicht
  das UTF-16-Feld bei Pufferoffset `+0x24` mit zwei Konstanten und öffnet
  anschließend den übergebenen Pfad. Beim BDS-Aufruf bei `0x4e0` ist das
  `disk`. Damit ist der zunächst vermutete ABI-Fehler widerlegt; die
  Drei-Argument-Methode `FUN_00000394` liegt auf Slot 1. `FUN_00000f0c`
  verwendet Slot 2 zum Schließen eines Dateihandles.
- Ein Byte-Scan der extrahierten `bl-efi`- und `diags-efi`-PE32-Module findet
  die GUID-Bytes `d2 68 88 50 1d 0a af 44 8f f7 50 74 06 41 69 8d` nur in
  `bl-efi/01__0.pe32` bei Offset `0x470` und `bl-efi/05__0.pe32` bei Offset
  `0x14f0`. Das stützt die Zuordnung des Providers zur BDS-Abfrage, beweist
  aber keinen erfolgreichen Laufzeit-Open.
- OSOS `FUN_0801b32c` prüft den Übergabemarker `0x53797349`, lädt den
  Quellzeiger aus dem Übergabeblock und kopiert in `0x086c7404`.
- Die Thumb-Schleife setzt `r2=0xff`, addiert `0x39` (`r2=0x138`) und
  dekrementiert vor jedem Byte. Sie kopiert für die Werte `0x137..0` genau
  `0x138` Bytes; der nächste Dekrement-Schritt erzeugt Borrow und beendet die
  Schleife. BDS- und OSOS-Längen stimmen daher überein. `sp+0x150` liegt
  außerhalb dieses Bereichs.
- Die Kopierlängen stimmen überein; ein Ein-Byte-Überlauf liegt nicht vor.
  OSOS `FUN_08006e34` liest `+0x84 >> 16` als Plattformkennung und ordnet
  `0x1c` dem Metadatenwert 5 für `GamesPlatformID` zu. Das Feld ist damit als
  Datenwert, nicht als Kontrollflusszeiger, belegt. Der Leser liegt auf einem
  Runtime-Metadatenpfad; Kaltstart-Erreichbarkeit ist offen.
- Weitere OSOS-Leser verwenden Offsets `+0x92`, `+0x94`, `+0x98`,
  `+0xe0..+0xe8` und `+0x104`. Ihre Verwendung sieht nach Geräte-, Versions-,
  Flag-, Text- und Grenzwerten aus. Arbiträre Codeausführung ist nicht belegt.

## Eingaben

| Datei | SHA-256 |
|---|---|
| `nano5g/bl-efi/05__0.pe32` | `c20fc49960ebc8efdf3b1c05755f9ddab496e214a5ab7dfd7ed4cc15dc576826` |
| `nano5g/bl-efi/01__0.pe32` | `19ab708c06f465a890438d2562698409cd750b81c36717c0921b401fcddf981a` |
| `nano5g/bl-efi/09__0.pe32` | `a53f62248f14f008ead721245c48b80770e452f820fedcf58b1bd871347cad96` |
| `nano5g/bl-efi/42__0.pe32` | `0b0cdfe9233b7f4203fdae3f4f40ace8db55337f4cd65b90f99640467d6f1a62` |
| `nano5g/bl-efi/11__0.pe32` | `46f5dc8130a61bfb1a22c611a82295147734ef1ef28d8760d9e76f70bad8d258` |
| `local-analysis/inputs/osos_runtime_dram_20261025.bin` | `1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03` |

Die Module 01, 09 und 42 wurden im bestehenden Projekt
`N5G_BDS_Providers_Thumb` read-only mit `-noanalysis` abgefragt. Modul 11 wurde
isoliert in `N5G_BDS_Provider11_20261031` mit `PeLoader` und Sprache
`ARM:LE:32:v6` importiert und anschließend read-only abgefragt. Der BDS-Export
stammt aus `N5G_Bds_Thumb`, ebenfalls read-only. Das Slot-`+4`-Listing stammt
aus einer transienten Thumb-Dekompilierung im read-only Projekt. Der OSOS-Loop
wurde zusätzlich direkt mit `arm-none-eabi-objdump` als Thumb disassembliert;
das zugehörige Listing steht in `OSOS_bds_handoff_copy_thumb_20261031.txt`.

Die Konfigurationsstruktur am OSOS-Ziel `0x086c7404` ist nur teilweise
nachverfolgt. Der Leser für `+0x84` liegt auf einem Runtime-Metadatenpfad:
`FUN_08006e34` wird von `FUN_08008290` aufgerufen; deren gefundener direkter
Aufrufer ist `FUN_0804d748`, aufgerufen von `FUN_080054a0`. Das belegt keinen
Kaltstartpfad. Herkunft des Stackwerts auf dem Gerät und Angreiferkontrolle
sind offen; weitere kopierte Felder brauchen noch eine Produzenten-/Nutzerkarte.

## Zentrale Ausgaben

- `BDS_handoff_callers_20261031.application.log` — Aufrufpfade und
  Stack-/CopyMem-Parameter in `05__0.pe32`.
- `module42_entry_and_registration_20261031.application.log` und
  `module42_protocol_interface_words_20261031.application.log` — Registrierung
  der GUID und Interface-/vtable-Pointer in `42__0.pe32`.
- `module42_method_5e8_thumb_20261031.application.log` — Thumb-Listing von
  `FUN_000005e8`, einschließlich der Verwendung des dritten Arguments als
  Maskenwert.
- `module11_protocol_1570_methods_20261031.application.log` — Modul-11-
  Registrierung, Slot-/GUID-Abgleich, Methoden und Metadaten des Imports.
- `BDS_handoff_guid_provider_call_map_20261031.application.log` — BDS-GUIDs,
  Xrefs und die Aufrufpfade in `FUN_00000bc4`.
- `BDS_guid14f0_exact_callers_20261031.application.log` — exakte BDS-Thumb-
  Instruktionen am GUID-`0x14f0`-Lookup und den Slot-0-Aufrufen.
- `module01_guid14f0_vtable_20261031.application.log` — Interface-Adresse,
  Vtable-Wörter und GUID-Zuordnung in Modul 01.
- `module01_guid14f0_all_slots_20261031.application.log` — Pseudocode der
  drei Methoden `FUN_00000264`, `FUN_00000394` und `FUN_00000220`.
- `module01_guid14f0_image_scan_20261031.txt` — Bytefundstellen der GUID in
  den extrahierten `bl-efi`- und `diags-efi`-PE32-Dateien.
- `OSOS_platform_id_consumer_20261031.application.log` — OSOS-Leser des Felds
  `+0x84` sowie direkte Aufrufkette.
- `OSOS_config_getter_and_setter_20261031.application.log` und
  `OSOS_config_consumers_20261031.application.log` — exemplarische
  Konfigurationsfelder und Leser im OSOS-Runtimecode.

## Ghidra-Abfragen

Die gespeicherten `.application.log`-Dateien enthalten die vollständigen
Ausgaben. Beispiele der verwendeten Abfragen:

```sh
/opt/ghidra/support/analyzeHeadless /home/sebastian/ipod-re/nano5g/ghidra-projects N5G_Bds_Thumb -readOnly -noanalysis -scriptPath /home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/accessories-alias-startup-reach-2026-10-31/scripts -process -postScript DumpContainingFunctions.java 0x258 0x9e8 0xbc4 0x332 0x37c 0x3f2 0x478
/opt/ghidra/support/analyzeHeadless /home/sebastian/ipod-re/nano5g/ghidra-projects N5G_BDS_Providers_Thumb -readOnly -noanalysis -scriptPath /home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/accessories-alias-startup-reach-2026-10-31/scripts -process -postScript FindIncomingReferencesInRange.java 0x78c 0x79b
/opt/ghidra/support/analyzeHeadless /home/sebastian/ipod-re/nano5g/ghidra-projects N5G_BDS_Providers_Thumb -readOnly -noanalysis -scriptPath /home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/accessories-alias-startup-reach-2026-10-31/scripts -process 42__0.pe32 -postScript DumpContainingFunctions.java 0x220 0x280 0x294 0x330 0x360 0x400
/opt/ghidra/support/analyzeHeadless /home/sebastian/ipod-re/nano5g/ghidra-projects N5G_BDS_Providers_Thumb -readOnly -noanalysis -scriptPath /home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/accessories-alias-startup-reach-2026-10-31/scripts -process 09__0.pe32 -postScript DumpContainingFunctions.java 0x220 0x230 0x240 0x250
/opt/ghidra/support/analyzeHeadless /home/sebastian/ipod-re/nano5g/ghidra-projects N5G_BDS_Providers_Thumb -readOnly -noanalysis -scriptPath /home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/rtos-task-order-2026-10-29/scripts -process 01__0.pe32 -postScript CreateAndDecompileFunctions.java 0x264 0x394 0x220
/opt/ghidra/support/analyzeHeadless /home/sebastian/ipod-re/nano5g/ghidra-projects N5G_Bds_Thumb -readOnly -noanalysis -scriptPath /home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/accessories-cache-alias-2026-10-31/scripts -process -postScript DumpFunctionListing.java 0x258 0x9e8 0xabc 0xd34 0xf0c
```

`SHA256SUMS` deckt die gespeicherten Listings und Ghidra-Ausgaben in diesem
Verzeichnis ab. Der Kopierlängenfehler und der GUID-`0x14f0`-ABI-Verdacht
sind geschlossen. Stackwert und Gate sind statisch verifiziert, aber
Laufzeitwerte und Kaltstart-Erreichbarkeit bleiben offen. Der OSOS-Accessory-
VFS-/FAT-Open-Pfad ist in den separaten Berichten bereits statisch
eingegrenzt; offen bleibt dessen tatsächliche Erreichbarkeit und der
Laufzeit-Provider-/Handle-/Speicherzustand. Beliebige Codeausführung oder
untethered Rockbox-Boot ist nicht nachgewiesen.
