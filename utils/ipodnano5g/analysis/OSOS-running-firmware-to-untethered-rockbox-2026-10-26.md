# Laufende iPod-Software als möglicher untethered Rockbox-Einstieg

Stand: 26.10.2026. Read-only-Prüfung lokaler Quelltexte und vorhandener
OSOS-Analysen. Keine USB-, DFU-, Boot-, NAND-/NOR- oder Geräteaktion.

## Kurzantwort

Ja, ein Fehler in der laufenden, signierten iPod-Software könnte prinzipiell
einen PC-freien Rockbox-Start ermöglichen, ohne dass eine Apple-Signatur
gefälscht oder ein Bootloader dauerhaft ins Flash geschrieben wird: Nach jedem
Kaltstart müsste eine persistente Datei automatisch einen OSOS-Fehler auslösen,
der kontrollierte Codeausführung erreicht. Dieser Code könnte den vorhandenen
Rockbox-Loader von der FAT-Partition nach RAM laden und dorthin springen. Hold
müsste vorher geprüft werden, damit der gesperrte Fall im Apple-OS bleibt.

Ein einmaliger Exploit nach manuellem Öffnen einer App reicht nicht. Auch ein
beliebiger Schreibzugriff auf Dateien auf der Datenpartition reicht allein
nicht, solange OSOS beim Kaltstart keine entsprechende Datei automatisch
ausführt.

## Verifizierte lokale Start- und Speicherpfade

- `utils/ipodnano5g/n5g-installed-boot.sh` wartet ausdrücklich auf BootROM-DFU,
  startet wInd3x/U-Boot und überträgt den Rockbox-Bootloader per YMODEM nach
  SDRAM-Adresse `0x09000000`; anschließend springt es mit `go` dorthin. Der
  Skriptkommentar und die ausgeführten Befehle bestätigen: Das ist ein
  RAM-Start, kein persistenter Bootloader-Installer.
- `firmware/export/config/ipodnano5g.h` kennzeichnet den N5G-NAND-Treiber als
  schreibgeschützt. In `firmware/target/arm/s5l8702/ipodnano4g/nand-target.h`
  wird `NAND_WRITABLE` für `IPOD_NANO5G` nicht definiert; die N5G-Implementierung
  von `nand_write_sectors()` gibt bei nichtleeren Schreibanforderungen deshalb
  `-3` zurück. Das belegt nur die Grenze des lokalen Rockbox-Treibers, nicht
  Apples eigenen NAND-Treiber oder dessen Berechtigungen.
- `bootloader/ipod-s5l87xx.c` enthält den Datei-Ladepfad für `rockbox.ipod`;
  die N5G-RAM-Bootloader-Analyse bestätigt außerdem Fallbacks zu OSOS bei
  gesperrtem Hold oder fehlender/nicht ladbarer Rockbox-Datei. Diese Pfade
  belegen den möglichen RAM-Handoff, nicht dass Apple-OSOS den Loader starten
  kann.
- Das lokale Projekt beschreibt wInd3x als temporären DFU-/RAM-Pfad. Die
  Upstream-Dokumentation sagt ebenfalls, dass haxed DFU bis zum nächsten
  Neustart gilt und den persistenten Gerätezustand nicht verändert
  ([wInd3x README](https://github.com/freemyipod/wInd3x)).

## OSOS-Eingabepfade und Exploitstatus

Die vorhandenen Analysen belegen persistente Eingaben, aber bisher keine
vollständige Kombination aus automatischem Kaltstart-Trigger und
Kontrollflussübernahme:

- **Notes:** Der UTF-8-Pfadtrim kann bei einer unvollständigen Drei-Byte-Sequenz
  eine Kopierlänge von `0xffffffff` erzeugen. Das ist ein ernstzunehmender
  Out-of-bounds-Schreibkandidat. Der Notes-/VFS-Übergang, ein automatischer
  Start des verwundbaren Pfads und kontrollierte Codeausführung sind nicht
  belegt.
- **ArtworkDB:** `mhia_count << 2` kann eine zu kleine Allokation verursachen.
  Die bisherigen Heapmodelle zeigen Korruption, aber keinen kontrollierten
  PC/LR-Wert. Der automatische Kaltstartaufruf des Parsers ist offen.
- **eApp/Games:** `_skipgamedrm` kann unter den untersuchten Bedingungen die
  optionale `Manifest.plist.p7b`-Prüfung umgehen. `.sinf`- und
  Metadatenverarbeitung folgen weiter; ein beliebiges ausführbares eApp oder
  ein automatischer Spielstart beim Einschalten ist nicht nachgewiesen.
- **TunerSettings:** Ein persistenter Leser ist über das MainApp-Setup
  erreichbar, verarbeitet im geprüften Pfad aber feste typisierte Felder.
  Kein Speicherfehler oder RCE ist belegt.
- **Alarmdatei:** Der Starttask-Plan enthält einen `AlarmTask`, dessen
  Ereignisschleife den Dateiparser nicht aufruft. Das MainApp-Setup schreibt
  den Alarmzustand; der Importpfad hat weiterhin keinen belegten automatischen
  Startaufrufer. Das geprüfte Feld `0x3c` liefert nur einen bedingten
  Stack-OOB-Read, keine bestätigte Kontrollflussübernahme.
- **ArtworkDB-Start:** Der von `TMusicLoadingTask` benötigte Kontextslot ist im
  gespeicherten Runtime- und Full-Body-Abbild null. Im OSOS-Code wurde kein
  Schreiber gefunden; ein zusätzlicher Literal-Scan der verfügbaren Firmware-
  und PE32-Module fand keine direkten Referenzen auf diesen Slot. Berechnete
  oder nicht extrahierte Laufzeitverweise bleiben offen.
- **Play Counts, Contacts, Device-Konfiguration, Workout-XML und weitere
  geprüfte Pfade:** bislang kein bestätigter Speicherfehler mit
  Kontrollflusswirkung und kein vollständiger automatischer Bootpfad.

Quellen im Arbeitsbaum: `OSOS-runtime-exploit-boot-feasibility-2026-10-25.md`,
`OSOS-persistent-device-file-reader-audit-2026-10-25.md`,
`OSOS-additional-persistent-paths-followup-2026-10-26.md`,
`OSOS-play-counts-input-followup-2026-10-26.md`,
`OSOS-radio-tuner-settings-parser-followup-2026-10-26.md` und
`OSOS-workout-parser-and-ramboot-audit-2026-10-26.md` sowie
`OSOS-DiskMgrTask-startup-followup-2026-10-26.md`.

## Schlussfolgerung und nächste Schritte

Der laufende OSOS-Pfad ist als Konzept ein realistischerer Weg als der Versuch,
einen privaten Apple-Schlüssel zu erraten. Im geprüften Material wurde jedoch
noch keine Lücke gefunden, die sich bereits als wiederholbarer untethered
Start verwenden lässt. Die zwei stärksten Speicherfehlerkandidaten (Notes und
ArtworkDB) brauchen weiterhin sowohl einen belegten automatischen
Kaltstart-Trigger als auch eine belastbare Kontrollflussübernahme.

Weiterhin offen sind:

1. dynamische Factory-/Overlay-Registrierungen, die den Notes- oder
   ArtworkDB-Parser beim normalen Kaltstart erreichen könnten;
2. die tatsächliche Kontrollflusswirkung der Notes-Unterlaufkopie und des
   ArtworkDB-Heap-Overflows;
3. ob OSOS einen beliebigen RAM-Handoff aus seinem normalen Taskkontext
   durchführen kann, ohne den Hold-gesperrten Apple-Pfad zu stören;
4. Apples eigener NAND-/Firmware-Schreibpfad. Die lokale Rockbox-Sperre ist
   kein Beleg dafür, dass Apple-OSOS keine Flashoperation ausführen kann; ein
   solcher Schreibpfad würde außerdem die Signaturprüfung beim nächsten Start
   nicht automatisch umgehen.

Das Gerät blieb unangetastet. Es wurden keine Tests oder Builds ausgeführt.

## Nachtrag: MainApp-Media-Setup hängt an bedingtem Event (26.10.2026)

Der zuvor offene Aufruf des MainApp-Setups `FUN_08086ce8` wurde eine Ebene
weiter zurückverfolgt. Der direkte Aufrufer ist `FUN_08079fb4`; diese Routine
wird im gespeicherten OSOS-Code nur aus dem Eventdispatcher `FUN_08066fb4`
aufgerufen. Der Dispatcher akzeptiert hier Eventtyp `0x12` und verlangt, dass
der Nutzdatenzeiger aus Feld `0xd00` genau auf `MainApp + 0x818` zeigt.

Vor dem Setup prüft `FUN_08079fb4` über `FUN_08280452` das Byte
`MainApp + 0x8e1`. Bei Wert `0x2c` (ASCII-Komma) setzt der Helper ein
separates Statusbyte und die Setup-Routine wird übersprungen. Bei anderen
Werten kann `FUN_08086ce8` folgen, sofern der zusätzliche globale
Zustandstest ebenfalls den Setup-Zweig auswählt. `FUN_08086ce8` führt
anschließend MainApp-/Device-Service-Initialisierung aus, darunter
`FUN_0828bd04`; dieser Aufruf allein belegt keinen automatischen Lauf eines
verwundbaren Dateiparsers.

Für `FUN_08066fb4` gibt es im Ghidra-Projekt keinen direkten Code-Xref. Ein
Rohscan des Full-Body-Binaries fand weder das absolute noch das 24-/32-Bit-
relative Funktionsoffset für ARM- oder Thumb-Einstieg als gespeicherten
Funktionszeiger. Damit ist die Eventquelle bzw. dynamische Registrierung
weiterhin unbekannt. Die MainApp startet zwar ihren Eventloop, aber in den
gespeicherten Daten ist kein Kaltstart-Sender für genau dieses Event
nachgewiesen. Dies ist eine bedingte Runtime-Spur und kein bestätigter
Kaltstart-Trigger oder Exploit.

Rohbelege: `/tmp/OSOS_event_dispatch_08066fb4_20261026.txt`,
`/tmp/OSOS_mainapp_setup_dispatch_20261026.txt`,
`/tmp/OSOS_event_object_helpers_20261026.txt` und
`/tmp/OSOS_mainapp_setup_refs_20261026.txt`. Ghidra wurde mit
`-readOnly -noanalysis` auf dem Full-Body-Abbild verwendet; keine
Geräte-/USB-/DFU-/Boot-/Flashaktion. Der Rohscan auf absolute und
base-relative Funktionszeiger ist in
`/tmp/OSOS_mainapp_event_pointer_scan_20261026.txt` festgehalten.

## Nachtrag: FAT32-Spuren im OSOS-Body eingegrenzt (26.10.2026)

Ein erster read-only-Suchlauf nach `FAT32`, `FAT12` und `FAT16` im lokalen
dechiffrierten OSOS-Body (`nano5g/osos_decrypted/osos_body.bin`) fand vier
Codeverwendungen der FAT32-Zeichenketten. Die Ghidra-Xrefs ordnen sie
Format-/Volume-Verwaltung zu:

- `FUN_08034df4` schreibt `FAT32` in einen erzeugten Volume-Sektor und reicht
  den Sektor über den Blockgeräte-VTable-Slot `+8` zum Schreiben weiter.
- `FUN_08037f18` erzeugt bzw. aktualisiert Volume-/Bootsektor-Metadaten; die
  Funktion verarbeitet Geometrie und schreibt vorbereitete Sektordaten.
- `FUN_080365c8` setzt ein Formatlabel (`HFSPLUS`, `FAT32` oder `Unknown`) in
  einem Volume-Statusobjekt.
- `FUN_08058658` serialisiert Volumeformat- und Unterstützungsfelder in einen
  Ausgabedatensatz.

Diese Verwendungen zeigen keinen FAT-Verzeichnis- oder Datei-Mountparser und
keine beim OSOS-Kaltstart automatisch gelesene FAT-Metadaten-Eingabe. Das ist
kein Beweis, dass der Parser fehlt: Der eigentliche Dateisystemtreiber kann
über einen externen Kernel-/Providerdienst, eine nicht extrahierte Komponente
oder einen dynamischen Dispatch eingebunden sein. Die vorhandene Spur ist
deshalb eine Eingrenzung, kein Ausschluss eines FAT-Angriffs.

Read-only-Rohbeleg: `/tmp/OSOS_fat_mount_funcs_20261026.txt`; Ghidra-Projekt
`nano5g/ghidra-projects/N5G_OSOS_RTOS.gpr`, Programm `osos_body.bin`, mit
`-noanalysis -readOnly`. Es wurden keine Geräte-, USB-, DFU-, Boot- oder
Flashoperationen ausgeführt.

Nächster sinnvoller Offline-Schritt: den Blockgeräte-/Filesystem-Provider,
der beim Start den Datenvolume-Mount bereitstellt, über seine registrierten
VTables und Dienst-IDs identifizieren. Erst wenn dessen Mountpfad als
Kaltstart-erreichbar belegt ist, lohnt sich eine gezielte Prüfung von
FAT-Verzeichnis- und Clustergrenzen.

## Nachtrag: OSOS-Abbild-Provenienz und Music-Event-VTable (26.10.2026)

Der Adressversatz des Offline-Abbilds ließ sich bytegenau gegen die Quelldatei
prüfen. `/tmp/osos_runtime_dram_20261025.bin` (7.095.208 Byte) entspricht
dem Suffix von `osos_body.bin` ab Dateioffset `0x2e27c` (gleiche Länge) bis
auf 2.267 abweichende Bytes im letzten Bereich `0x6c3768..0x6c43a7`.
`/tmp/n5g-osos-md.txt` enthält nach dem Parsen aller Adresszeilen exakt die
7.284.260 Bytes von `osos_body.bin` (keine Abweichung). Diese Dateien sind
somit keine unabhängigen Belege für veränderliche Zustände eines bereits
laufenden OSOS. Insbesondere bedeutet der Nullwert bei `0x08550ae0` nur, dass
der statische Offline-Abbildwert null ist; der echte Wert nach Initialisierung
bleibt unbekannt.

Der Tabellenhinweis wurde im korrekten Adressraum erneut eingeordnet:
Runtime-Tabelle `0x084f7590` entspricht Full-Body-Adresse `0x0852580c`.
Ihre ersten zehn Einträge sind bis auf Slot 1 mit dem Teil der
`TMusicLoadingTask`-VTable ab `0x08504b74` identisch. Der abweichende Slot
zeigt in der Tabelle `0x084f7590` auf `FUN_08038d38`; die von
`FUN_080bb0c0` für `TMusicLoadingTask` gesetzte VTable enthält dort dagegen
`FUN_08271b7c`. Diese Routine ist ein allgemeiner Event-Fallback, während
`FUN_08038d38` Ereignistypen und objektinterne Zeiger speziell dispatcht.
Das spricht für eine verwandte Interface-/Klassenmethode, identifiziert aber
weder den Besitzer der ersten Tabelle noch einen Aufrufer beim Kaltstart.
Für die Tabellenbasis gibt es weiterhin keinen statischen Verweis; der
Callback-Zeiger `0x08038d39` steht im Offline-Abbild nur als Tabelleneintrag.

Bewertung: Der Eventtabellenfund ist kein neuer OSOS-Einstieg. Er grenzt die
Music-Task-Hypothese ein: `FUN_08038d38` ist nicht der in der bekannten
`TMusicLoadingTask`-VTable eingetragene Eventhandler. Eine Verbindung zu
`FUN_081ac420`, zu persistenten Benutzerdaten oder zu einem Kaltstart-Trigger
ist weiterhin nicht nachgewiesen. Die VTable-Zuordnung und alle daraus
gezogenen Aussagen bleiben statische Image-Analyse, keine Laufzeitmessung.

Belege: `/tmp/OSOS_runtime_event_vtable_20261025.txt`,
`/tmp/OSOS_runtime_music_task_vtable_20261025.txt`,
`/tmp/OSOS_runtime_music_task_vtable_literal_20261025.txt` und
`/tmp/OSOS_runtime_music_dispatch_callback_20261025.txt`. Keine Geräteaktion,
kein Build und keine Tests.

## Nachtrag: XML-Reader-Aufrufpfade und Speakable-PLIST-Spuren (26.10.2026)

Die direkten Referenzen des XML-Textreaders wurden im read-only Full-Body-
Projekt erneut verfolgt. `FUN_08330614` hat dort genau einen direkten Aufrufer,
den Wrapper `FUN_0829e15c`. Dieser Wrapper wird direkt aus `FUN_0810daf0` und
`FUN_08163bb4` aufgerufen. `FUN_0810daf0` wird von `FUN_08280946` benutzt;
`FUN_08280946` wiederum wird aus dem eApp-Manifestpfad `FUN_0811f194` und dem
generischen Objektpfad `FUN_080841cc` aufgerufen. Dieser läuft
über `FUN_081e16b8`, das in `FUN_081ddb38` zweimal mit unterschiedlichen
Parsermodi aufgerufen wird. Für `FUN_081ddb38` fand sich im untersuchten
Projekt kein direkter Code-Xref; ein indirekter Callback-/Factory-Aufruf bleibt
möglich.

Damit bestätigt der XML-Reader-Xrefgraph keinen allgemeinen automatischen
Kaltstartparser für beliebige Dateien. Die sichtbaren Pfade führen zur
eApp-Manifestverarbeitung und zu generischer Objekt-/Datenverarbeitung; deren
Trigger- und Speicherfehlerbewertung bleibt durch die vorherigen Abschnitte
begrenzt. Der zuvor separat untersuchte Workout-Scanner bleibt ein eigener
Parserpfad. Für
`/iPod_Control/Speakable/UISS.plist`, `CacheInfo.plist`, `ConfigInfo.plist` und
`UISS_combined.plist.gz` sind die Strings im OSOS-Body vorhanden, aber die
durchgeführten Ghidra-Xref-/Immediate-Suchen und Scans nach absoluten sowie
base-relativen 24-/32-Bit-Zeigern fanden keine direkte Verbindung zu einem
Leser. Das schließt dynamische Registrierungen, indirekte Referenzen oder
nicht enthaltene Overlays nicht aus und macht diese Dateien derzeit nicht zu
bestätigten Boot-Eingaben.

Rohbelege: `/tmp/OSOS_xml_libxml_context_20261026.txt`,
`/tmp/OSOS_xml_other_parser_context_20261026.txt`,
`/tmp/OSOS_xml_dispatch_root_20261026.txt` und
`/tmp/OSOS_speakable_immediate_refs_20261026.txt`. Alle Ghidra-Läufe nutzten
`-noanalysis -readOnly`; das Gerät blieb unangetastet. Kein Build und keine
Tests.

## Nachtrag: Accessories/Tags ist ein Schreibpfad (26.10.2026)

Die direkten Referenzen auf `iPod_Control/Device/Accessories/Tags/` führen zu
`FUN_0832eedc`. Diese Funktion erstellt aus festen PLIST-Feldern wie
`MajorVersion`, `ManufacturerID`, `ManufacturerName` und `DeviceName` einen
zeitgestempelten Dateinamen und serialisiert anschließend die Daten über den
Stream-Schreibpfad `FUN_081c6b08`. Der Code öffnet oder parst keine vorhandene
Datei aus diesem Verzeichnis. Sein einziger direkter Aufrufer ist
`FUN_08297668`; dieser hat im analysierten OSOS-Body vier direkte Aufrufer,
darunter Zustands-/Ereignisfunktionen `FUN_081b9f7c`, `FUN_082a6efc` und
`FUN_08200b14`. Die genaue Laufzeitregistrierung bleibt offen, aber der
Accessories/Tags-Pfad ist nach dem sichtbaren Datenfluss kein persistenter
Datei-Exploit-Trigger.

Rohbelege: `/tmp/OSOS_accessory_tags_reader_20261026.txt`,
`/tmp/OSOS_accessory_tags_caller_20261026.txt` und
`/tmp/OSOS_accessory_tags_callers_20261026.txt`. Ausschließlich read-only-
Ghidra-Analyse; keine Geräteaktion, kein Build und keine Tests.

## Nachtrag: Update-Statusfelder und interner FTL-Schreibpfad (26.10.2026)

Die Update-bezogenen Strings `UpdaterFamilyID`, `WillFlash`, `UpdateMethod`,
`AutoRebootAfterFirmwareUpdate` und `UpdateRetriesSupported` wurden bis zu
ihren Aufrufern verfolgt. `FUN_08058100`, `FUN_080585e4` und `FUN_080587b4`
fügen diese Felder über die Objekt-/PLIST-Schreibhelfer `FUN_081c21f8`,
`FUN_081c22cc` und `FUN_081c23b4` in Ausgabedatensätze ein. Die Funktionen
werden aus `FUN_0803650c` und `FUN_08036b98` aufgerufen. Die sichtbaren Pfade
lesen keinen Update-Payload ein und starten keinen Image-Installer; die
Feldnamen allein belegen daher keine vom laufenden OSOS erreichbare
Installationsschnittstelle.

OSOS enthält zugleich einen internen FTL-Wartungspfad: `FUN_08062bf0` wählt
bei Bedarf eine freie FTL-Section, verschiebt Daten über `FUN_08078f60` und
aktualisiert Mapping-Zustand; sein Fehlerpfad nennt `VFL_Erase`. Das bestätigt
NAND-Schreib-/Löschfähigkeit für die normale FTL-Verwaltung, aber keinen
beliebigen Bootbereichsschreiber. Im Body sind außerdem Fehlermeldungen zu
`VFL_Write2ndBootLoader` enthalten. Die geprüfte Ghidra-Xrefsuche zu diesen
Meldungen (`0x084c1414`, `0x084c1458`, `0x084c149c`, `0x084c14e0`,
`0x084c1524`) ergab keine Referenzen; ein zusätzlicher ausgerichteter
32-Bit-Pointer-Scan auf `0x084c1414` ebenfalls keine. Das beweist weder, dass
der Writer unerreichbar ist, noch dass er fehlt: unanalysierter Code,
berechnete Aufrufe und externe Module bleiben außerhalb dieser Aussage.

Damit ist belegt, dass der Retail-OSOS-Code FTL-Wartung ausführt und
Update-Metadaten serialisiert. Nicht belegt ist eine Verbindung dieser
Metadaten oder eines bisher untersuchten persistenten Eingabepfads zu einem
Bootloader-/OS-Installer; auch ein Fehler, der so einen Pfad ausnutzt, ist
nicht gefunden. Die bereits dokumentierten Notes- und ArtworkDB-Kandidaten
brauchen weiterhin einen automatischen Kaltstart-Trigger und kontrollierte
Codeausführung.

Rohbelege: `/tmp/OSOS_nand_signed_driver_loader_20261026.txt`,
`/tmp/OSOS_nand_readblock_api_20261026.txt`,
`/tmp/OSOS_ftl_flash_ops_20261026.txt`,
`/tmp/OSOS_updater_config_helpers_20261026.txt`,
`/tmp/OSOS_fw_status_serializers_20261026.txt` und
`nano5g/ghidra-logs/OSOS_strings_refs.tsv`. Alle Ghidra-Läufe verwendeten
`-noanalysis -readOnly`; es gab keine Geräte-, USB-, DFU-, Boot- oder
Flashaktion.

## Nachtrag: Partitions- und früher Resource-Mountpfad (26.10.2026)

Die zunächst gefundene MBR-Auswahl `FUN_0802f4c8` prüft bei akzeptierten
Partitionstypen den Bootstatus, nichtleeren Start und nichtleere Länge. Sie
vergleicht die Länge mit der Gesamtsektorzahl des Geräts, prüft aber im
sichtbaren Code nicht `Start + Länge <= Gesamtsektorzahl`. Das allein belegt
einen möglichen ungültigen Blockgerätebereich, keinen Speicherfehler.

Der zugehörige Einstieg `FUN_0802ec8c` ruft `FUN_0802fbe8` und anschließend
`FUN_081bcc14` auf. Im read-only Ghidra-Xrefgraph hat `FUN_0802ec8c` keinen
statischen Aufrufer; `FUN_0802fbe8` wird nur von diesem Einstieg referenziert.
Zwei Rohbytesuchen nach `8c ec 02` waren Scheintreffer: Die Instruktionen bei
`0x082f3748` und `0x08368cea` sind `BLX` zu `0x08231064` bzw. `0x0823c604`,
nicht Aufrufe von `FUN_0802ec8c`. Eine indirekte Registrierung bleibt möglich,
ist aber nicht gefunden.

Daneben gibt es einen tatsächlich referenzierten Mountwrapper:
`FUN_08243734` ruft `FUN_081bcc14` auf und hat vier direkte Aufrufstellen in
`FUN_080f9d5c`, `FUN_080e307c` und `FUN_080fcb2c`. Vor dem Eintrag in die
Volumes-Tabelle prüft `FUN_081bcc14` über `FUN_08291ac8`, dass der Slotindex
kleiner als 7 ist. `FUN_0826b6e4` übernimmt Start und Länge in das
Volumeobjekt; ob dessen spätere Lese-/Schreibmethoden die Grenzen des
übergeordneten Geräts prüfen, ist noch offen.

Ein früherer Resourcepfad ist zusätzlich sichtbar: `FUN_081da69c` ruft
`FUN_080df4b8` auf. Bei erfolgreichem Status von `FUN_081d6bac(0)` fordert
dieser über `FUN_080f9d5c` den FourCC `crsr` (Rohwort `0x72737263`), ID 0,
Typ 2 an. `FUN_080f9d5c` verwendet `FUN_08113178`, das Sektor 0 nach
Partitionsmetadaten durchsucht und bei einem Apple-Partitionsdatensatz den
Eintrag `APPLE_MDFW` auswählt. `FUN_081121f0` sucht dann in dessen
Resource-Tabelle mit höchstens 16 Einträgen nach dem Schlüssel und gibt den
gefundenen Start-/Längenbereich an `FUN_08243734` weiter. Die
64-Bit-Multiplikationen werden auf einen nichtnulligen oberen Wortteil
geprüft; eine sichtbare Prüfung, dass der resultierende Bereich vollständig
innerhalb der `APPLE_MDFW`-Partition liegt, fehlt in `FUN_081121f0`.

Das ist der bisher klarste Kandidat für einen frühen fehlerhaften
Storagebereich. Die Daten stammen laut sichtbarem Pfad aus `APPLE_MDFW`,
nicht nachweislich aus der beschreibbaren FAT-Datenpartition. Weder ein
Speicher-Overwrite noch kontrollierter PC/LR, Codeausführung, Signaturumgehung
oder ein Rockbox-Handoff sind damit belegt. `FUN_081da69c` wird aus
`FUN_08053670` und einem bedingten Callback aufgerufen; `FUN_08053670` wird
von `FUN_08050d84` aufgerufen. Für `FUN_08050d84` fand sich kein direkter
Code-Xref, deshalb bleibt die letzte Registrierung bzw. automatische
Kaltstart-Erreichbarkeit dieser Kette unaufgelöst.

Rohbelege: `/tmp/OSOS_partition_mount_depth_20261026.txt`,
`/tmp/OSOS_partition_mount_refs_20261026.log`,
`/tmp/OSOS_partition_false_call_1_20261026.txt`,
`/tmp/OSOS_partition_false_call_2_20261026.txt`,
`/tmp/OSOS_partition_alternate_mount_path_20261026.txt`,
`/tmp/OSOS_partition_mount_wrapper_callers_20261026.txt`,
`/tmp/OSOS_partition_mount_parent_context_20261026.txt`,
`/tmp/OSOS_boot_resource_mount_parser_20261026.txt`,
`/tmp/OSOS_boot_resource_volume_provider_20261026.txt`,
`/tmp/OSOS_boot_resource_initializer_refs_20261026.log` und
`/tmp/OSOS_boot_resource_root_context_20261026.txt`. Ghidra-Läufe waren
`-noanalysis -readOnly`; das Gerät blieb unangetastet. Nächster Schritt ist,
die letzte Startup-Registrierung und die Herkunft/Schreibbarkeit von
`APPLE_MDFW` zu klären und die tatsächlichen Lower-I/O-Grenzprüfungen des
Mountwrappers zu verfolgen.
