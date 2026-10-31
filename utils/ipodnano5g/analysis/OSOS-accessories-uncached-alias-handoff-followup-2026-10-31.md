# `accessories.reg`: bedingter Loader-Handoff über einen SDRAM-Alias

Stand: 31.10.2026. Offline-Analyse, ein kontrollierter OSOS-Parser-Rehost des
704-Byte-ROP-Kandidaten, ein ARM1176-System-QEMU-Rehost und der vorhandene, bei
`0x0bf00000` relinkte Rockbox-Bootloader. Kein Gerätelauf und kein Schreiben
von NAND, NOR oder Firmware.

## Befund

Der direkte Sprung zu frisch gelesenen Loaderbytes bei `0x0bf00000` hat ein
Cache-Kohärenzrisiko, falls die Basisabbildung cachebar ist: Der OSOS-Leser
schreibt den vom ROP übergebenen Puffer byteweise mit `STRB`. Der bisherige
Rehost hält vor den ersten Loaderinstruktionen an und modelliert keine Caches.
ARM1176 hat getrennte I- und D-Caches; CPU-Schreibdaten, die als Code
ausgeführt werden, benötigen passende Cache-/Prefetch-Synchronisierung.

Der scheinbare Widerspruch am Mapper-Ziel war ein **Adressierungsfehler in der
vorherigen Auswertung**. `osos_body.bin` enthält zwei unterschiedlich
abgebildete Bereiche: Der SRAM-Prefix ab Datei-Offset `0` liegt bei
`0x22000000`; der DRAM-Code beginnt erst bei Datei-Offset `0x2e27c` und liegt
bei `0x08000000`. Daher liegt `FUN_08005d3c` tatsächlich bei `0x22005d3c`,
sein Thunk bei `0x22003970` und dessen Ziel `0x080e3e84` im DRAM-Suffix. Die
Bytes an diesem Ziel stimmen exakt mit dem 36-Byte-L1-Descriptor-Schreiber im
IMG1-Body bei Datei-Offset `0x112100` (flache Body-Projektadresse
`0x08112100`) überein. Es ist kein Laufzeit-Overlay nötig, um den Zielzeiger zu
erklären.

Der Startpfad beginnt noch vor der SRAM-Abbildung. Der IMG1-Header nennt
Entry-Offset `0`; die lokale RetailOS-Dokumentation beschreibt das Laden durch
den zweiten Bootloader in DRAM bei `0x08000000`. Daher verzweigt das erste
Body-Wort zunächst von `0x08000000` nach `0x08007038`, der Stack-Stub nach
`0x08005058`. Dort liefert `FUN_08007060` aus dem Symbolunterschied
`0x22007060 - 0x08007060` das Relokationsdelta `0x1a000000`; bei einem bereits
relokatierten Lauf wäre das Delta null. `FUN_08005ec8` kopiert den SRAM-Text
von `0x08000000` nach `0x22000000`, nullt `0x2200e27c..0x2200f43f`, kopiert
den `0x20000`-Byte-Block SRAM-BSS/Daten nach `0x22030000`, wechselt für die
Fortsetzung seines eigenen Codes nach SRAM, kopiert DRAM-Textdaten aus IMG1-Dateioffset
`0x2e27c` nach `0x08000000` und die Frameworks an `0x086c3768`. Danach springt
der Relocator zum Entry `0x22000000`. Der erneute Entry-Branch führt nach
`0x22007038`, der Stack-Setup-Branch nach `0x22005058`; bei Delta null läuft
der Initialisierer weiter und ruft bei `0x220050c8` `FUN_22005d3c` auf. Diese
Funktion ruft den Mapper für sechs Bereiche auf. Beim Alias-Aufruf übergibt
sie VA `0x88000000` bis
`0x8bffffff`, PA-Basis `0x08000000` und Attribut `0x4c02`; Mapper und
Parameterblock verwenden die L1-Tabelle ab `0x086dc000`. Der generische Mapper
schreibt damit statisch 64 Abschnittsdeskriptoren, darunter für
`0x8bf00000` den Wert `0x0bf04c02` an Tabellenadresse `0x086de2fc`.

Das separate Runtime-Ghidra-Programm ist kein unabhängiger RAM-Dump: Seine
Eingabe ist eine Offline-Abbildung des IMG1-DRAM-Suffixes ab Datei-Offset
`0x2e27c`, auf `0x08000000` gelegt. Sie stimmt mit diesem Suffix bis auf 2.267
abweichende Bytes am Ende (`0x6c3768..0x6c43a7`) überein. Der Mappercode und
sein `0x086dc000`-Literal liegen im byteidentischen Bereich. Der DRAM-Suffix-
Mapper hat den statischen Aufruferpfad `FUN_08272474 -> FUN_0801e0d8 ->
FUN_081a5d48`, der ein einzelnes 1-MiB-Fenster bei VA `0x18000000` mit
Attribut `0x7c0e` anlegt. Ein neuer read-only Xref-Lauf findet im DRAM-Suffix
genau einen direkten Callsite zum generischen Writer `FUN_080e3e84`
(`081a5d68`) und genau einen direkten Caller von `FUN_081a5d48`
(`0801e158`). Dieser konkrete Pfad konfiguriert daher nicht die Aliasrange
`0x88000000..0x8bffffff`. Das schließt berechnete Aufrufe oder andere
Codepfade, die Tabellenwerte indirekt ändern, nicht aus.

- `FUN_22005d3c` setzt `SCTLR.XP`, lässt aber `SCTLR.TRE` unverändert. Nach
  dem ARM1176-TRM hängt die Interpretation der TEX/C/B-Attribute von `TRE` ab.
  Nur bei `TRE=0` bedeutet `0x4c02` hier Normal Memory mit nichtcachebaren
  Inner-/Outer-Attributen; `0x7c0e` für die Basisabbildung ist bei `TRE=0`
  cachebares Normal Memory. Bei `TRE=1` werden beide über PRRR/NMRR remapped.
  Ein vollständiger CP15-c1-Scan der lokalen Vorgängerabbilder schränkt den
  übernommenen Wert ein: Der ARM1176-TRM nennt `TRE=0` als Resetwert. Die vier
  gefundenen SCTLR-Schreibstellen im BootROM erhalten Bit 28: `0x20000278`
  setzt Bit 22, `0x200003cc` löscht Bit 12, `0x200003e0` löscht Bit 2 und
  `0x20000448` löscht Bit 0. Der Einstieg des lokalen N33-Bootloaders führt
  über `0x22000000 -> 0x220227d0 -> 0x2202257c`; seine beiden SCTLR-Updates
  löschen Bits aus `0x04001805` beziehungsweise ändern Bits 22, 11 und 1,
  lassen Bit 28 aber ebenfalls stehen. Auch die übrigen gefundenen N33-SCTLR-
  Helfer ändern M, I-cache oder XP, nicht TRE. Im OSOS-DRAM-Code-Suffix wurde
  keine dekodierte SCTLR-Schreibstelle gefunden; der SRAM-Setup-Code erhält TRE.
  Damit ist `TRE=0` für den normalen Startpfad durch statische Vorgängeranalyse
  und die Ausführung des echten OSOS-MMU-Initialisierers in QEMU gestützt, aber
  nicht am iPod gemessen. Ein abweichender Hardware-/Startpfad oder eine
  spätere Änderung bleibt als Restunsicherheit.
  Header-, Listing-, Xref- und Section-Bytevergleichsbelege stehen in
  `analysis/evidence/accessories-alias-startup-reach-2026-10-31/README.md`.

Die L1-Tabelle ab `0x086dc000` liegt im DRAM-BSS und ist nicht in der
code-only Suffixdatei enthalten. Das hindert den Setup-Code nicht daran, sie
beim Start zu befüllen; ihre Werte beim Accessories-Callback sind allerdings
nicht live ausgelesen.

Der Alias ist damit **statisch durch den normalen OSOS-Setup-Pfad eingerichtet**,
nach der durch IMG1-Header, Relokationstabelle und OSOS-Section-Layout
gestützten SRAM-/DRAM-Relokation. Der
auf dem iPod gemessene `TRE`-Wert, die fortbestehenden Deskriptor-/TLB-Werte am
Callback und ein Geräteaufruf des Accessories-Pfads bleiben offen. Der Alias
ist keine Gerätebestätigung des Rockbox-Handoffs.

Der Loader-Startpfad macht die Hypothese bei erfüllten MMU-Voraussetzungen
technisch plausibel:

1. Der erste Branch von `start` nach `_newstart` ist PC-relativ.
2. `_newstart` berechnet die Quellbasis aus der aktuellen PC-Adresse und dem
   Offset des `_rtpc`-Labels. Bei Einstieg über `0x8bf00000` ist die Quelle
   daher der gelesene Aliasbereich.
3. `_movestart` und `_moveend` sind absolute Linkwerte im kanonischen Bereich
   `0x0bf00000..0x0bf10f80`; die Self-Copy legt die Bytes dorthin.
4. Danach kopiert der CRT die Vektoren, bereinigt/invalidiert D-Cache, leert den
   Write-Buffer, invalidiert I-Cache/BTB und den Prefetch-Puffer und springt
   erst dann zur kanonischen `start_loc` bei `0x0bf000e0`.

Der Read-Wrapper `FUN_0814346c` kopiert den Streaminhalt über den
caller-supplied Zielzeiger mit `LDRB`/`STRB`; der Aliaspfad benötigt keinen
separaten DMA-Buffer. Die Original-ROP-Werte sind statisch bekannt:
`r2=Ziel` beim Read und der spätere Wert in `r3` für `BLX r3`. Die dritte
Referenz ist der Parser-Cleanup-Storezeiger (`Ziel+0x40`).

## Kontrollierte Parser-Rehosts der 704- und 736-Byte-Kandidaten

Eine abgeleitete Kopie liegt unter
`analysis/evidence/accessories-cache-alias-2026-10-31/`:

- `candidate_accessories_reg_uncached_alias_unexecuted.bin` — 704 Byte.
- Drei Wörter bei `0x144`, `0x280` und `0x294` geändert von
  `0x0bf00000` auf `0x8bf00000`.
- SHA-256: `2df24b2aa0c281eb51e53418c6d8c89c9e39e301906996a07928f23f01e340a1`.
- Die vorherige Top-RAM-Kopie bleibt unverändert und hat SHA-256
  `a809112477c00685bea172c25e6dc5efb30b6e654ee74607c4b08fd0385d914e`.

Als zweite, vollständigere Offline-Variante liegt dort
`candidate_accessories_reg_alias_dsb_bssinit_unexecuted.bin` (736 Byte,
SHA-256 `b19180df8a20ef7e5496885bf227827623d6c3115adef0e4d47ed2efe2e6f78e`).
Sie stammt vom vorhandenen BSS-Init-Kandidaten, setzt Cleanup-, Read-,
`bss_init`- und Loader-Einstieg auf den Alias und fügt nach dem Read einen
Aufruf von `FUN_083531c0` (DSB) ein. Das soll ausstehende Schreibzugriffe vor
dem ersten Loader-Fetch abschließen. DSB invalidiert keine Caches und löst das
Problem nur unter der weiterhin statisch gestützten, aber nicht live gemessenen
Annahme, dass `TRE=0` gilt und der Alias-Descriptor unverändert aktiv bleibt.
Ein separater Parser-Rehost
führt den Kandidaten mit einem rückkehrenden DSB-Stub aus: der ROP erreicht
`0x083531c0`, der kopierte `bss_init` läuft bei `0x8bf001c8`, drei vorab
markierte Stellen im kanonischen BSS sind am finalen Entry null und die Folge
erreicht `PC=0x8bf00000`. Der Stub ist nur `bx lr`; das echte CP15-DSB wird
nicht ausgeführt. Reproduktion und Grenzen:
`analysis/evidence/accessories-alias-dsb-parser-rehost-2026-10-31/README.md`.

Ein separater Linux-User-QEMU-Rehost führt den 704-Byte-Kandidaten zusammen mit
dem OSOS-Parser-/ROP-Kontrollfluss aus. Er stoppt mit GDB bei
`PC=0x8bf00000`, dem finalen Branchziel vor der ersten Loaderinstruktion. Der
Read-Callback markiert `/BOOT.BIN` als gelesen und kopiert das lokale
`bootloader-safe.bin` byteweise an `0x8bf00000`. Am Entry ist `r1=0x10f80`,
`r2=0x8bf10f80`; der Speicher-Dump ist bytegleich zum Loader-Build (SHA-256
`ba355bf5771a686a07829d3df45772c2d4bc9c33ca9cf0346d17408a5f20b4b2`). Damit
ist die Parser-/ROP-Erreichbarkeit dieses Kandidaten im Rehost gezeigt.

Der Datei-Read bleibt ein Harness-Callback. Das ELF bildet den Aliasbereich
als separaten Host-Speicher ab und erzwingt nicht, dass `0x8bf00000` auf dem
iPod dieselbe physische SDRAM-Zelle wie `0x0bf00000` bezeichnet. Dieser Parser-
Rehost misst daher weder die Geräte-TLB/MMU noch Cache-/Write-Buffer-Verhalten.
Ein getrennter ARM1176-System-Rehost prüft den analogen Kontrollfluss zuerst
mit einer synthetischen L1-Tabelle; ein weiterer Lauf ruft den echten OSOS-
Descriptor-Writer mit den statisch gewonnenen Parametern auf. Reproduktion und
Logs:
`analysis/evidence/accessories-alias-parser-rehost-2026-10-31/README.md`.

`0x8bf00000 + 0x10f80 = 0x8bf10f80` liegt vollständig in der OSOS-Alias-
Abbildung bis `0x8bffffff`; der physische Loaderbereich bleibt
`0x0bf00000..0x0bf10f7f`. Der Cleanup-Store `0x8bf00040` wird durch den
nachfolgenden vollständigen Read überschrieben.

## ARM1176-System-QEMU-Rehost

Der erste System-Mode-Rehost baut die oben genannten Body-Deskriptoren
synthetisch in einer L1-Tabelle auf, setzt `TRE=0`, `C=0`, `I=0`, `XP=1` und
`M=1` und bildet Cleanup → byteweisen Alias-Read → DSB → `bss_init` → Loader-
Branch nach. QEMU hält bei `PC=0x0bf000e0` an, nachdem der echte Loader über
`0x8bf00000` gestartet, den Selbstrelokationspfad ausgeführt und die Vektoren
nach IRAM kopiert hat. Die Dumps sowohl des Alias- als auch des kanonischen
Bereichs sind bytegleich zum ursprünglichen `bootloader-safe.bin`:
SHA-256 `ba355bf5771a686a07829d3df45772c2d4bc9c33ca9cf0346d17408a5f20b4b2`.
Der Anfang der durch `bss_init` genullten BSS ist ebenfalls null.

Ein zusätzlicher System-Mode-Lauf führt den echten, im DRAM-Suffix enthaltenen
OSOS-Descriptor-Writer an `0x080e3e84` aus. Mit der statisch belegten
Tabellenbasis `0x086dc000` schreibt er unter anderem `0x0bf04c02` für VA
`0x8bf00000` an `0x086de2fc`. Die übrigen gelesenen Werte stimmen ebenfalls
mit den OSOS-Setup-Parametern überein: DRAM `0x08007c0e`, Aliasanfang
`0x08004c02`, Low-Vector-Alias `0x2200c802`, IRAM `0x22004c02`. Unter dieser
vom Harness gelieferten Tabelle erreicht derselbe Loader erneut
`PC=0x0bf000e0`; kanonischer und Alias-Dump stimmen bytegenau mit dem
`bootloader-safe.bin` überein. Dies bestätigt die Writer-Implementierung und
die Adressübersetzung in diesem QEMU-Rehost. Der Harness ruft den Writer mit
statisch bestimmten Argumenten auf; er führt nicht den vollständigen OSOS-
Startup aus.

Ein dritter Lauf ruft den echten, in den SRAM-Prefix relocatierten
OSOS-MMU-Initialisierer `FUN_22005d3c` auf. Seine CP15-Helfer, der SRAM-Thunk
und der DRAM-Descriptor-Writer laufen im ARM1176-System-QEMU. Nach Rückkehr
liest GDB `SCTLR=0x00c5187d` (`M=1`, `C=1`, `I=1`, `XP=1`, `TRE=0`),
`ACTLR=7`, `TTBR0=0x086dc000`, `TTBCR=0` und `DACR=1` aus. Die am echten
Tabellenort erzeugten Einträge umfassen den Aliasstart `0x08004c02`, den
Loader-Alias `0x0bf04c02` bei `0x086de2fc`, DRAM-Identity `0x08007c0e`,
IRAM-Identity `0x22004c02`, den Low-Vector-Alias `0x2200c802` und den
SROM-Eintrag `0x38000c02`. Der Lauf hält zunächst bei `PC=0x22005d3c` und
erreicht nach dem kontrollierten Loader-Read wieder `PC=0x0bf000e0`.

Dieser dritte Lauf belegt den MMU-Initialisierer unter den in QEMU gelieferten
Speicherabbildern, nicht den IMG1-Relokator oder den gesamten OSOS-Startup.
Auch der Datei-Read ist weiterhin ein Harness-Kopiervorgang, kein VFS-/FAT-/ATA-
Read. Die drei System-Rehosts sind daher keine Geräte-Messungen. Sie schließen
weder die tatsächliche DRAM-Belegung noch aktive Geräte-TLB-Einträge ein;
QEMU-TCG bildet die realen ARM1176-I-/D-Caches und den Write-Buffer nicht ab.
Reproduktionsdateien und GDB-/QEMU-Logs liegen unter
`analysis/evidence/accessories-alias-arm1176-qemu-2026-10-31/README.md`.

## Grenzen

- Der Alias-Descriptor wird durch den statisch erreichbaren Setup-Code im
  üblichen SRAM-/DRAM-Layout beschrieben. Das Ende des Runtime-Suffix-Abbilds
  weicht in 2.267 Bytes vom IMG1-Body ab; diese Tail-Differenz ändert den
  byteidentischen Mappercode an `0x080e3e84` nicht. Der echte OSOS-
  Initialisierer wurde mit dem extrahierten SRAM-Prefix und DRAM-Suffix in QEMU
  ausgeführt. Das ist keine Live-Messung. Die statische DRAM-Abbildung enthält die
  L1-Tabelle ab `0x086dc000` nicht, weil sie im BSS liegt. Ob die
  Alias-Deskriptoren bis zum Accessories-Callback unverändert bleiben, ist
  nicht verifiziert.
- Der dritte QEMU-Lauf liest `TRE=0` aus dem CP15-Zustand, den der echte
  OSOS-MMU-Initialisierer unter QEMU hinterlässt; das ist weiterhin keine
  Live-Messung am iPod. Wenn derselbe Zustand dort gilt und der Alias-Descriptor
  bis zum Callback aktiv bleibt, soll der DSB-Schritt ausstehende Schreibzugriffe
  ordnen. Der dritte Rehost lässt `C=I=1`; die zwei älteren System-Rehosts
  verwenden `C=I=0`. QEMU-TCG misst weder den echten Write-Buffer-Effekt noch
  Cachekohärenz des ARM1176.
  Rockbox' frühe Self-Copy und Cachepflege beweisen den Geräteweg nicht. Wenn der
  Alias bei `TRE=1` cachebar remapped wird, reicht DSB allein nicht als
  I-Cache-/D-Cache-Synchronisierung.
- Der physische Bereich `0x0bf00000..0x0bfbfd00` ist über dem berechneten OSOS-
  Heap, aber nicht live als frei oder unreserviert belegt.
- `/BOOT.BIN` fehlt in der gesicherten Volumeaufnahme; der ROP-/FAT-/VFS-
  Kaltstartpfad und das Laden dieser Datei bleiben offen.
- Die 704- und 736-Byte-Kandidaten wurden nur in kontrollierten Parser-Rehosts
  verarbeitet; sie wurden nicht auf ein Gerät kopiert. Der DSB-Stub in einem
  Parser-Rehost war nur `bx lr` und führte keine Barriere aus. Die System-QEMU-
  Rehosts durchliefen den echten Loader-Startcode bis `start_loc=0x0bf000e0` und
  hielten dort an. Ein realer Loader- oder untethered Rockbox-Geräteboot ist
  nicht bestätigt.

Dauerbelege und Quellen: `analysis/evidence/accessories-cache-alias-2026-10-31/README.md`;
Body-/Runtime-Thunk-Abgleich: `analysis/evidence/accessories-alias-startup-reach-2026-10-31/README.md`.
