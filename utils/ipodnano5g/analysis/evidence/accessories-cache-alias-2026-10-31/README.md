# Accessories handoff via a conditional SDRAM alias

Stand: 31.10.2026. Statische Abbildungsauswertung und pointerweise Ableitung
aus dem vorhandenen Accessories-ROP. Der 704-Byte-Kandidat wurde nachträglich
im kontrollierten Parser-Rehost verarbeitet; es gab keinen Geräte-/USB-/DFU-
Zugriff und kein Schreiben/Löschen von NAND, NOR oder Firmware.

## Ergebnis

Der korrekt auf SRAM und DRAM aufgeteilte OSOS-Startpfad richtet in
`FUN_22005d3c` eine zweite Abbildung desselben 64-MiB-SDRAM ein. Die
Abschnitts-/Thunk-Verifikation ist unter
`../accessories-alias-startup-reach-2026-10-31/README.md` dokumentiert.

| Virtueller Bereich | Physischer Anfang | Attributwort | Bedeutung |
| --- | --- | --- | --- |
| `0x08000000..0x0bffffff` | `0x08000000` | `0x7c0e` | bei `TRE=0` cachebares Normal Memory |
| `0x88000000..0x8bffffff` | `0x08000000` | `0x4c02` | Alias; Cachetyp hängt von `SCTLR.TRE` ab |

Der SRAM-Thunksprung bei `0x22003970` lädt `0x080e3e85` und erreicht damit den
generischen L1-Descriptor-Schreiber im DRAM-Suffix. Das frühere Vergleichen
gleicher Zahlenadressen im flachen IMG1-Body und im Runtime-Koordinatensystem
war falsch: Runtime-VA `0x080e3e84` entspricht IMG1-Dateioffset `0x112100`
bzw. flacher Body-Projektadresse `0x08112100`. Dort stimmen die 36 Bytes des
Writers und das TTBR-Literal `0x086dc000` exakt mit dem Offline-DRAM-Suffix
überein. Es gibt keinen Overlay-Widerspruch.

Der Setup-Pfad übergibt dem Writer VA-Bereich `0x88000000..0x8bffffff`,
physische Basis `0x08000000` und Attribut `0x4c02`. Er schreibt damit 64
Abschnittsdeskriptoren in die L1-Tabelle ab `0x086dc000`; für
`0x8bf00000` ergibt sich `0x0bf04c02` an `0x086de2fc`. Das ist eine statische
Initialisierung im normalen OSOS-Startpfad. Der Eintrag wurde nicht live am
Gerät gelesen.

Wenn `TRE=0` gilt und der Alias-Descriptor bis zum Accessories-Callback aktiv
bleibt, bezeichnet `0x8bf00000` dieselben Bytes wie `0x0bf00000`; `0x4c02` ist
dann nichtcachebares Normal Memory und `0x7c0e` cachebares Normal Memory.
`FUN_22005d3c` setzt `SCTLR.XP`, ändert aber `SCTLR.TRE` nicht. Bei `TRE=1`
werden die Attribute über PRRR/NMRR remapped. `TRE` und die aktive
Abbildung beim Accessories-Callback bleiben ungemessen.

Ein nachgelagerter CP15-c1-Scan stützt jetzt die Annahme, dass der normale
Startpfad `TRE=0` bis OSOS erhält. Das ARM1176-TRM nennt `TRE=0` als Resetwert.
Im vollständigen BootROM-Scan wurden vier SCTLR-Schreibstellen gefunden:
`0x20000278` setzt Bit 22, `0x200003cc` löscht Bit 12, `0x200003e0` löscht
Bit 2 und `0x20000448` löscht Bit 0; alle erhalten Bit 28. Der Einstieg des
lokalen N33-Bootloaders läuft statisch über
`0x22000000 -> 0x220227d0 -> 0x2202257c`. Seine beiden SCTLR-Updates löschen
Bits aus `0x04001805` und setzen später Bits 11/1 bei gleichzeitigem Löschen
von Bit 22; auch diese Masken lassen Bit 28 stehen. Die übrigen gefundenen
N33-SCTLR-Helfer schalten MMU, I-cache oder XP, ohne TRE zu ändern. Im OSOS-
DRAM-Code-Suffix wurde keine dekodierte SCTLR-Schreibstelle gefunden; das
statische SRAM-Setup erhält TRE ebenfalls. Das macht `TRE=0` zu einer starken
statischen Schlussfolgerung für den normalen Bootpfad, aber weiterhin nicht
zu einem Live-Messwert. Ein abweichender Plattform-/Startpfad oder eine
spätere, nicht erfasste Änderung ist nicht ausgeschlossen.

Der IMG1-Header hat `entry offset=0`. Laut lokaler OSOS-Dokumentation lädt der
zweite Bootloader den Body zunächst in DRAM bei `0x08000000`. Von dort führt
der erste Branch nach `0x08007038`, der Stackstub weiter zu `0x08005058`.
`FUN_08007060` berechnet das Delta `0x1a000000`; `FUN_08005ec8` kopiert und
initialisiert die Abschnitte und springt dann zum relocatierten Entry
`0x22000000`. Erst der dortige Pfad `0x22000000 -> 0x22007038 -> 0x22005058`
ruft bei `0x220050c8` den MMU-Setup-Code `FUN_22005d3c` auf. Die Detailwerte
und reproduzierbaren Listings stehen in
`../accessories-alias-startup-reach-2026-10-31/README.md`.

Das Offline-DRAM-Suffix hat für den Mapper den Aufruferpfad
`FUN_08272474 -> FUN_0801e0d8 -> FUN_081a5d48`; er legt ein einzelnes 1-MiB-
Fenster ab VA `0x18000000` mit Attribut `0x7c0e` an. Der CP15-Scan des
DRAM-Code-Suffixes findet nur zwei `MCR p15`-Instruktionen, beide für
Cachepflege über c7, und keine dekodierte c1-/c2-Schreibinstruktion. Die
Offline-Code-Suffix reicht nur bis `0x086c43a7`; die L1-Tabelle ab
`0x086dc000` liegt im BSS außerhalb der Datei. Der frühe Descriptor-Write ist
statisch belegt; der Fortbestand des Alias bis zum Accessories-Callback ist
nicht live verifiziert. Der separate
BootROM-/N33-Scan stützt `TRE=0` als normalen Startwert, misst aber weder
Callback-Zeitpunkt noch aktive TLB-Einträge. Detailbelege stehen in
`../accessories-alias-startup-reach-2026-10-31/README.md`.

Der DRAM-Mapper `FUN_080e3e84` hat im Runtime-Koordinatensystem den statischen
Aufruferpfad `FUN_08272474 -> FUN_0801e0d8 -> FUN_081a5d48`. Dieser Pfad legt
ein einzelnes 1-MiB-Fenster ab VA `0x18000000` auf eine dynamisch berechnete
physische Basis mit Attribut `0x7c0e`. Er erzeugt nicht die Aliasrange ab
`0x88000000`. Der frühe SRAM-Thunk erreicht denselben Mapper. Der direkte
Runtime-Xref-Lauf fand nur den einen bekannten DRAM-Callsite mit dem Fenster
`0x18000000`; berechnete Aufrufe und spätere indirekte Tabellenänderungen
bleiben ungeprüft. Beleg: `../accessories-alias-startup-reach-2026-10-31/`
`OSOS_runtime_alias_writer_direct_xrefs_20261031.application.log`.

`FUN_0814346c` kopiert die Dateidaten mit CPU-`LDRB`/`STRB` in den vom
Aufrufer gelieferten Zeiger; an dieser Stelle ist keine DMA-Kopie beteiligt.

Der vorhandene Loader ist weiter bei `0x0bf00000` gelinkt. Sein CRT-Einstieg
beginnt mit einem PC-relativen Branch. `_newstart` berechnet die aktuelle
Quelladresse aus dem Laufzeit-PC und den Linksymbolen, kopiert den Loader von
der aktuellen Aliasadresse zum kanonischen Linkbereich, kopiert die Vektoren,
bereinigt/invalidiert D- und I-Cache, leert den Prefetch-Puffer und verzweigt
erst danach zur kanonischen `start_loc`-Adresse. Das macht einen Einstieg bei
`0x8bf00000` **unter der Bedingung** plausibel, dass die Aliasabbildung beim
Accessories-Callback aktiv und wegen `TRE=0` tatsächlich nichtcachebar ist. Vor dem Wechsel
zur kanonischen `0x0bf00000`-Adresse führt Rockbox die Cachepflege aus.

Der direkte Start bei `0x0bf00000` ist bei `TRE=0` cachekritisch: Der
OSOS-Dateiread schreibt dann in die cachebare Basisregion, während ARM1176
getrennte I- und D-Caches ohne gegenseitige Kohärenz hat. Falls `TRE=1` gilt,
ist auch deren Attributierung von PRRR/NMRR abhängig. Die Cachepflege im
Rockbox-CRT liegt nach den ersten Loaderinstruktionen. Die Architekturquellen
beschreiben die Notwendigkeit der expliziten Synchronisierung:

- ARM1176JZF-S Technical Reference Manual, Abschnitte zu `SCTLR.TRE`,
  TEX/C/B-Attributen und I-/D-Caches:
  <https://documentation-service.arm.com/static/5e8e294efd977155116a6ca3>
- Arm, *Caches and Self-Modifying Code*:
  <https://developer.arm.com/community/arm-community-blogs/b/architectures-and-processors-blog/posts/caches-and-self-modifying-code>

## Verfeinerte Variante mit DSB und BSS-Init

`candidate_accessories_reg_alias_dsb_bssinit_unexecuted.bin` ist eine
736-Byte-Kopie des vorhandenen BSS-Init-Kandidaten. Sie ergänzt nach dem
Datei-Read einen vierwortigen BLX-/Pop-Schritt zu `FUN_083531c0` bei
`0x083531c0`. Die Runtime-Instruktionen lauten `mov r0,#0; mcr p15,0,r0,c7,c10,4; bx lr`;
der CP15-Aufruf ist ein DSB. Der Schritt soll ausstehende CPU-Schreibzugriffe
des Reads abschließen, bevor der Loader erstmals über den Alias ausgeführt
wird. Danach ruft die Folge `bss_init` bei `0x8bf001c8` auf und startet bei
`0x8bf00000`. Die drei Adresswörter für Cleanup, Read-Ziel und Einstieg sowie
das BSS-Init-Ziel verwenden damit denselben Alias.

Das DSB ist **keine** I-/D-Cache-Invalidierung. Es hilft nur, wenn `TRE=0`
gilt und der Alias-Descriptor noch aktiv ist; bei einer durch `TRE=1` remapped
Cache-Attributierung bleibt der alte I-Cache-Fehler offen. Die Adresse des
DSB-Helfers stammt aus dem Offline-DRAM-Code-Suffix.
Der direkte statische Caller des Helpers wurde nicht gefunden; die Variante
ruft ihn kontrolliert über den ROP-Trampolin auf. Die ROP-Datei wurde in einem
separaten Linux-User-Parser-Rehost verarbeitet. Der CP15-DSB-Helfer ist dort
durch einen `bx lr`-Stub ersetzt. Der Lauf erreicht den echten kopierten
`bss_init`-Code bei `0x8bf001c8`, leert drei vorab markierte BSS-Stellen und
kommt am finalen Loader-Entry `0x8bf00000` an. Der Loader selbst wird dort
angehalten. Das beweist keinen DSB-Effekt; siehe
`../accessories-alias-dsb-parser-rehost-2026-10-31/README.md`. Ein separates
ARM1176-System-Rehost führt die entsprechenden Schritte mit einer
synthetischen Tabelle und echter QEMU-DSB-Instruktion aus, führt die ROP-Datei
aber nicht aus und modelliert keine realen Caches (siehe unten).

- Ausgangsdatei: `../accessories-rop-2026-10-29/candidate_accessories_reg_bssinit_unexecuted.bin`
- Ausgangs-SHA-256: `d9973abc3b223baceaf378a582e2b7acd3fd96b82ef548f40a8f31a4a957ecfa`
- Neues Feld: `0x2a4` Byte; Dateigröße: `0x2e0` Byte.
- SHA-256: `b19180df8a20ef7e5496885bf227827623d6c3115adef0e4d47ed2efe2e6f78e`.
- Builder und Wort-/Längenprüfungen: `build_candidate_accessories_reg_alias_dsb_bssinit.py`.

## Abgeleitete Kandidatenkopie

`candidate_accessories_reg_uncached_alias_unexecuted.bin` ist eine isolierte
704-Byte-Kopie des bereits relinkten Top-RAM-Kandidaten. Genau die drei
Little-Endian-Wörter bei Datei-Offsets `0x144`, `0x280` und `0x294` wurden von
`0x0bf00000` auf `0x8bf00000` geändert. Sie bestimmen im bekannten ROP-Ledger
den Parser-Cleanup-Zeiger, das Ziel des `/BOOT.BIN`-Reads und das abschließende
ARM-Sprungziel. Beim Cleanup liegt der Byte-Store dann auf `0x8bf00040`; der
folgende vollständige Loader-Read überschreibt den Bereich.

- Ausgangskandidat: `../accessories-safe-loader-relocation-2026-10-30/candidate_accessories_reg_topram_unexecuted.bin`
- Ausgangs-SHA-256: `a809112477c00685bea172c25e6dc5efb30b6e654ee74607c4b08fd0385d914e`
- Alias-Kandidat-SHA-256: `2df24b2aa0c281eb51e53418c6d8c89c9e39e301906996a07928f23f01e340a1`

Die Kopie wurde auf Länge, drei Ersetzungspositionen und Prüfsumme geprüft und
anschließend im kontrollierten Parser-Rehost verarbeitet. Der Rehost erreicht
`PC=0x8bf00000` und hält vor der ersten Loaderinstruktion an. Er bildet den
Alias als separaten Hostbereich ab und beweist deshalb weder die reale Geräte-
MMU zum Readzeitpunkt noch Cache-/Write-Buffer-Verhalten am Gerät. Details und
Logs: `../accessories-alias-parser-rehost-2026-10-31/README.md`.

## Quellen im Arbeitsbaum

- `../../../../../../nano5g/ghidra-logs/OSOS_mmu_init_2026-10-25.txt` —
  statische Body-Abbildung, Basis-/Aliasargumente und Attributkonstanten.
- `../../../../../../nano5g/ghidra-logs/OSOS_mmu_preinit_2026-10-25.txt` —
  Werte `DAT_08005e30=0x4c02` und `DAT_08005e3c=0x7c0e`.
- `OSOS_body_mmu_helpers_20261031.application.log` and
  `OSOS_body_mmu_controls_20261031.application.log` — CP15-Helfer und
  Descriptor-Aufbau aus dem flach importierten Body-Projekt; die Prefix-VA ist
  `0x22005d3c`, und der Code setzt XP und erhält TRE.
- `OSOS_body_mmu_xrefs_20261031.application.log` and
  `OSOS_body_mmu_startup_window_20261031.application.log` — statischer
  Body-Aufruf des MMU-Setups; kein Runtime-Beleg.
- `OSOS_body_cp15_c1_writes_20261031.application.log` — alle gefundenen
  CP15-c1-Schreibinstruktionen im statischen Body-Abbild; `TRE` wird in den
  erkannten Read/Modify/Write-Sequenzen nicht gezielt verändert.
- `OSOS_body_mmu_range_and_attributes_20261031.application.log` — konstante
  Attribut-/Grenzwerte für die zusätzlichen 0x22000000-IRAM- und
  Low-Vector-Mappings.
- `OSOS_runtime_mmu_metadata_and_c1_20261031.application.log` — Größe des
  Offline-DRAM-Suffixes, Mappingvergleich und DRAM-Mapper
  bei `0x080e3e84` und keine gefundenen CP15-c1-Schreibinstruktionen in diesem
  Codeabschnitt.
- `OSOS_runtime_body_address_comparison_20261031.application.log` — bestätigt,
  die flache Full-Body-Adresse ist keine gültige Runtime-VA für den SRAM-Prefix;
  verwende stattdessen das korrekt rebased Prefix-Listing.
- `OSOS_runtime_section_mapper_xrefs_20261031.application.log`,
  `OSOS_runtime_section_mapper_caller_20261031.application.log`,
  `OSOS_runtime_mapper_owner_table_20261031.application.log`,
  `OSOS_runtime_mapper_initializer_20261031.application.log`,
  `OSOS_runtime_mapper_window_owner_20261031.application.log` und
  `OSOS_runtime_translation_table_base_xrefs_20261031.application.log` —
  Mapper-Xrefs und Argumente; der bekannte Runtime-Aufruf setzt nur das
  1-MiB-Fenster ab `0x18000000`, nicht den Alias ab `0x88000000`.
- `../accessories-alias-arm1176-qemu-2026-10-31/README.md` — erfolgreicher
  System-QEMU-Kontrollflusslauf mit synthetischer ARM1176-L1-Tabelle; der
  704-Byte-ROP-Kandidat und reale Cache-/OSOS-Zustände wurden dabei nicht
  ausgeführt.
- `../accessories-alias-parser-rehost-2026-10-31/README.md` — 704-Byte-Kandidat
  erreicht im Parser-Rehost den Alias-Loader-Entry; Loader-Read bleibt ein
  Callback und der Loader wird am Entry angehalten.
- `../accessories-alias-dsb-parser-rehost-2026-10-31/README.md` — 736-Byte-
  Kandidat erreicht mit rückkehrendem DSB-Stub zusätzlich den BSS-Init-Pfad
  und den finalen Loader-Entry.
- `OSOS_body_cp15_mcr_20261031.application.log` und
  `OSOS_runtime_cp15_mcr_20261031.application.log` — CP15-MCR-Instruktionen
  aus Prefix und offline gemapptem DRAM-Suffix; im DRAM-Suffix stehen DSB und WFI,
  keine Cache-Clean-/Invalidate-Instruktion.
- `OSOS_runtime_cp15_cache_helper_xrefs_20261031.application.log` — DSB-
  Helferlisting; kein statischer Caller für `FUN_083531c0` gefunden.
- `BootROM_cp15_writes_20261031.application.log`,
  `BootROM_sctlr_early_window_20261031.application.log` und
  `BootROM_reset_to_sctlr_followup_20261031.application.log` — CP15-c1-Scan
  und früher BootROM-Kontrollfluss; die vier SCTLR-Schreibstellen verändern
  Bit 28 nicht.
- `BootROM_sctlr_functions_20261031.application.log` — Pseudocode der drei
  als Funktionen erkannten BootROM-SCTLR-Helfer.
- `N33_bootloader_cp15_writes_20261031.application.log`,
  `N33_bootloader_cp15_functions_20261031.application.log`,
  `N33_bootloader_cp15_constants_20261031.application.log`,
  `N33_bootloader_raw_sctlr_window_20261031.application.log` und
  `N33_bootloader_entry_c1_chain_20261031.application.log` — SCTLR-Schreibscan,
  Startpfad und Masken des lokalen N33-Bootloaders.
- ARM1176JZF-S Technical Reference Manual, Resetwert von `SCTLR.TRE` und
  TEX/C/B-Attributinterpretation:
  <https://documentation-service.arm.com/static/5e8e294efd977155116a6ca3>
- `scripts/ScanCp15C1Writes.java`, `scripts/ScanCp15Mcr.java` und
  `build_candidate_accessories_reg_alias_dsb_bssinit.py` — reproduzierbare
  statische Such-/Erzeugungsskripte.
- `SHA256SUMS` — Prüfsummen der beiden lokalen Alias-Kandidaten, des Builders
  und der ausgewählten neuen BootROM-/N33-/Body-/Runtime-Listingbelege.
- `../accessories-safe-loader-relocation-2026-10-30/bootloader_safe_entry_20261030.txt`
  — Loader-Einstieg, Alias-unabhängiger Quelladressaufbau und Cache-Sequenz.
- `../rtos-task-order-2026-10-29/OSOS_runtime_accessories_stream_open_read_20261029.log`
  — OSOS-FAT-Read-Kopie in den caller-supplied Zielpuffer.
- `../accessories-rop-2026-10-29/OSOS_accessories_open_read_stack_accounting_20261029.txt`
  — ROP-Registerwerte und letzter `BLX`-Sprung.

## Nächste Offline-Schritte

1. Aktive L1-/TLB-Einträge und `TRE` zum Accessories-Callback klären; der
   frühe SRAM-Setup-Pfad richtet die Aliasrange statisch ein, aber spätere
   Änderungen und der Zustand am Callback sind nicht live verifiziert.
2. Den vollständigen 704-Byte-ROP-Stack-Ledger gegen den neuen System-Rehost
   abgleichen und prüfen, ob sich der echte Gadgetpfad mit dem statischen
   Runtime-Abbild einspielen lässt. QEMU kann den realen Cachezustand des
   Siliziums nicht belegen.
3. Erst bei Gelegenheit und mit dem Gerät verfügbar: kontrolliert den
   Dateiread und Einstieg testen, getrennt von jedem NAND-/NOR-Schreib- oder
   Firmware-Flash-Schritt.

Der obere DRAM-Bereich `0x0bf00000..` ist weiterhin nicht live als frei
gemessen. `BOOT.BIN` fehlte in der gespeicherten Volumeaufnahme. Beide Alias-
Kandidaten sind bedingt; der 704-Byte-Kandidat wurde bis zum Loader-Entry
verarbeitet. Die 736-Byte-Variante erreichte zusätzlich den BSS-Init-Pfad mit
DSB-Stub. Keiner wurde auf dem Gerät getestet, und ein untethered Rockbox-Boot
ist nicht erreicht.
