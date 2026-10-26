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
- Der tatsächlich für Nano 5G verwendete gemeinsame N4G/N5G-Bootloader steht
  in `bootloader/ipodnano4g.c`. Im `IPOD_NANO5G`-Zweig prüft er den Hold-Schalter
  vor dem FAT-Mount und startet bei gesperrtem Hold das signierte OSOS über
  `launch_apple(APPLE_IMG_OSOS)`. Bei fehlendem FAT, fehlender
  `rockbox.ipod`-Datei oder fehlendem RAM-Disk-Image gibt es ebenfalls einen
  OSOS-Fallback. Bei entsperrtem Hold lädt er `rockbox.ipod` in RAM. Das ist ein
  konkreter Handoff-Kandidat für einen OSOS-Exploit, aber ein Sprung aus dem
  laufenden OSOS in diesen Bootloader ist noch nicht demonstriert.
- Der N5G-Bootloader ist laut `firmware/target/arm/s5l8702/boot.lds` bei
  `DRAM_ORIG + 16 MiB` gelinkt; der vorhandene RAM-Boot-Workflow verwendet
  dafür `0x09000000`. `crt0.S` schaltet MMU/Caches aus, leert den
  Instruktionspfad und setzt den VIC zurück. Der N5G-`system_preinit()` setzt
  voraus, dass SDRAM, Takt, GPIO und PMU bereits initialisiert sind. Ein
  Exploit müsste diese Startbedingungen beim Sprung aus OSOS berücksichtigen;
  die Quelltexte belegen noch keine sichere OSOS-zu-Bootloader-Ausführung.
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
- **Games-Katalog beim Kaltstart:** Der MainApp-Lifecycle erreicht
  `TEAppShell::FUN_08028254`. Dessen Provider-Callbacks bauen für passende
  Unterordner in `iPod_Control/games_RO/` bzw. `Resources/Games/games_RO/`
  einen `Manifest.plist`-Pfad und parsen die Metadaten automatisch. Dieser
  Katalogpfad übergibt kein `.p7b`-Sidecar an den optionalen Prüfschritt und
  startet kein eApp. Die gelesene Datei ist auf `0x20000` Byte begrenzt; in den
  geprüften Parser-Wrappern ist kein konkreter Speicherfehler gefunden. Ein
  Katalogarray wird mit `Kapazität * 0x10` Byte dynamisch alloziert; eine
  Überlaufprüfung dieser Multiplikation ist nicht sichtbar, aber aus einer
  normalen, durch die Dateigröße begrenzten XML-Liste ergibt sich kein
  erreichbarer Wrap. Entity-Amplifikation und die genaue libxml2-Version/
  Defaults bleiben ungeprüft. Auch die Beschreibbarkeit des N5G-Datenpfads auf
  diesem Gerät ist offen. Eine Community-Anleitung beschreibt manuelles
  Kopieren von Quizdaten für Nanos nach
  `iPod_Control/Games_RO/11004/UserTrivia/Packs/`; sie belegt nicht, dass das
  automatisch geparste Manifest ersetzt werden kann
  ([Anleitung](https://github.com/Olsro/ipodclickwheelgamespreservationproject/blob/main/iQuiz/README.md)).
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
einen privaten Apple-Schlüssel zu erraten. Der Games-Katalog liefert jetzt
einen belegten automatischen Manifest-Metadatenparser beim Kaltstart, aber
noch keine ausnutzbare Speicherfehlerstelle oder Kontrollflussübernahme. Die
separaten Notes- und ArtworkDB-Speicherfehlerkandidaten brauchen weiterhin
sowohl einen belegten automatischen Kaltstart-Trigger als auch eine belastbare
Kontrollflussübernahme.

Weiterhin offen sind:

1. Entity-/Ressourcenlimits und weitere mögliche Speicherfehler im automatisch
   erreichten Games-Manifestparser sowie die Schreibbarkeit der persistenten
   N5G-`games_RO`-Quelle;
2. dynamische Factory-/Overlay-Registrierungen, die den Notes- oder
   ArtworkDB-Parser beim normalen Kaltstart erreichen könnten;
3. die tatsächliche Kontrollflusswirkung der Notes-Unterlaufkopie und des
   ArtworkDB-Heap-Overflows;
4. ob OSOS einen beliebigen RAM-Handoff aus seinem normalen Taskkontext
   durchführen kann, ohne den Hold-gesperrten Apple-Pfad zu stören;
5. Apples eigener NAND-/Firmware-Schreibpfad. Die lokale Rockbox-Sperre ist
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

Der lokale Stock-Container bestätigt den Parserpfad: `Firmware.MSE` hat bei
Offset `0x100` die erwartete Signatur `]ih[` und den Resource-Tabellenoffset
`0x4000`. Mit 4096-Byte-Blöcken führt die Division in `FUN_081121f0` zum
Tabellenbereich bei `0x5000`; dort enthält der Eintrag bei `0x5118` den
Schlüssel `DNANcrsr`, Datenoffset `0x27b000` und Länge `0x07901263`. Dieser
Datenbereich ist bytegenau identisch mit dem lokalen extrahierten
`segments/rsrc.bin` (SHA-256
`d3c6ce3ffd81ffbf9547be6906167a7114fdbce2ba64075cce827a1ce8267093`). Der
`crsr`-Aufruf greift damit auf die Apple-`rsrc`-Komponente im
`APPLE_MDFW`-Firmwarebereich zu.

Die fehlende Bereichsprüfung bleibt eine strukturelle Schwäche, falls diese
Metadaten verändert werden können. Die konkrete Referenzeingabe ist jedoch
Apple-Firmwareinhalt und nicht als von der beschreibbaren FAT-Datenpartition
beeinflussbar belegt. Weder ein Speicher-Overwrite noch kontrollierter PC/LR,
Codeausführung, Signaturumgehung oder ein Rockbox-Handoff sind damit belegt.
`FUN_081da69c` wird aus
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
`/tmp/OSOS_boot_resource_root_context_20261026.txt` sowie
`/tmp/OSOS_MSE_crsr_resource_match_20261026.txt`. Ghidra-Läufe waren
`-noanalysis -readOnly`; das Gerät blieb unangetastet. Nächster Schritt ist,
die letzte Startup-Registrierung und einen OSOS-erreichbaren Schreib- oder
Updatepfad zu `APPLE_MDFW` zu klären sowie die tatsächlichen
Lower-I/O-Grenzprüfungen des Mountwrappers zu verfolgen.

## Nachtrag: Mountwrapper bis zur virtuellen Block-I/O-Schnittstelle (26.10.2026)

Die offene Lower-I/O-Spur wurde im read-only-Ghidra-Projekt weiterverfolgt.
`FUN_08243734` bezieht über `FUN_081bcbb0` den globalen Storage-Provider und
ruft `FUN_081bcc14` auf. Der Wrapper prüft dort den Volume-Slot auf `< 7`;
`FUN_0826b6e4` übernimmt danach Provider sowie Partitionsparameter in das
Volumeobjekt und richtet den Stream-/Cache-Unterbau ein. Die Blockgröße wird
über `FUN_08280b68` abgefragt: bei fehlendem Provider liefert die Funktion
`0x200`, andernfalls springt sie indirekt über den Provider-VTable-Slot
`+0x2c`.

`FUN_081bd3b0`, `FUN_081c319c` und `FUN_0828de8c` erzeugen bzw. richten den
32-Byte-ausgerichteten Streampuffer ein. Die geprüften Initialisierer
`FUN_0813f320` und `FUN_0813f0ac` richten weitere Objekt-/Cachezustände ein.
In diesen sichtbaren Funktionen ist keine Prüfung des angefragten Sektors
gegen `Partitionsstart + Partitionslänge` erkennbar; sie enthalten aber auch
nicht die tatsächlich ausgeführte Leseoperation. Der anschließende Zugriff
läuft über indirekte Provider-/Objektmethoden. Deren konkrete Implementierung
und damit eine mögliche Begrenzungsprüfung ließ sich im analysierten OSOS-Body
nicht auflösen.

Das schließt die frühere Lücke nicht zu einem bestätigten Out-of-range-Read:
Es bleibt offen, ob der konkrete Storage-Provider Anfragen außerhalb des
Volumes oder Geräts ablehnt. Selbst ein ungültiger Sektorzugriff wäre für sich
noch kein Speicherfehler oder kontrollierte Codeausführung. Der Mountpfad ist
damit als nicht abgeschlossener Kandidat dokumentiert; die nächste sinnvolle
Offline-Prüfung ist die Zuordnung des virtuellen Provider-Slots `+0x2c` zur
konkreten Laufzeitimplementierung und deren Caller.

Rohbelege: `/tmp/OSOS_volume_io_chain_20261026.txt`,
`/tmp/OSOS_lower_io_dispatch_20261026.txt`,
`/tmp/OSOS_volume_stream_helpers_20261026.txt`,
`/tmp/OSOS_device_factory_20261026.txt` und
`/tmp/OSOS_volume_provider_refs_console_20261026.log`. Alle Ghidra-Läufe
öffneten die Projektkopie mit `-readOnly -noanalysis`; es gab keinen Zugriff
auf iPod, USB, DFU oder Flash.

## Nachtrag: Games-VFS und Grenze zum eApp-Lader (26.10.2026)

Der automatische Games-Scan verwendet zwei logische VFS-Slots. `FUN_081af8bc`
ruft `FUN_081b343c` zuerst mit Slot 4 und dem Tabellenpfad
`Resources/Games/games_RO/` auf, danach mit Slot 0 und
`iPod_Control/games_RO/`. Die Pfad-/Iterator-Konstruktoren reichen diese IDs
über `FUN_082784c8` und `FUN_0827faca` an den Service-Registry-Lookup weiter;
`FUN_0826384c` akzeptiert nur IDs 0 bis 6. Der Enumerator prüft Pfade über
einen virtuellen Service-Aufruf bei `+0x50` und liest Verzeichniseinträge über
`+0x40`/`+0x44`. Das belegt die logischen Namensräume, aber weder ihre konkrete
physische Partition noch Schreibrechte des OSOS-Prozesses.

Auf Slot 0 wird beim Kaltstart für passende Unterordner automatisch
`Manifest.plist` gelesen. In diesem Metadaten-Aufruf ist das optionale
Sidecar-Feld des Parserdeskriptors null. Der Parser prüft die Datei auf
höchstens `0x20000` Byte; die XML-Initialisierung setzt explizit nur
`XML_PARSE_COMPACT`, nicht `DTDLOAD` oder `NOENT`. Das tatsächliche Verhalten
der eingebetteten libxml2-Version bleibt offen. Damit ist eine erreichbare,
potenziell hostseitig beeinflussbare Eingabe identifiziert, aber noch kein
Speicherfehler oder Codeausführung.

Der Kandidat `FUN_080f0f18` baut ebenfalls einen `Manifest.plist`-Pfad und
ruft nach dem Parsen `FUN_08102d10` sowie `FUN_08102f64` auf, bevor er eine
Callback-Methode startet. `FUN_08102f64` geht weiter über `FUN_0810872c` und
`FUN_08108448`; in den geprüften Hilfsfunktionen liegen Bereichs- und
Zählgrenzen. Ein direkter statischer Xref zu `FUN_080f0f18` fehlt, ebenso ein
Zeigerfund auf die Thumb-Adresse `0x080f0f19`. Die Verbindung vom automatisch
geladenen Katalog über die UI bis zu diesem eApp-Pfad ist deshalb weiterhin
nicht belegt. `FUN_08102140` ist in diesem Abbild lediglich ein kleiner
Deskriptor-Konstruktor; daraus folgt kein Nachweis, dass der Katalogpfad eine
DER-Signaturprüfung ausführt oder umgeht.

Bewertung: Der Slot-0-Katalogparser bleibt ein sinnvoller statischer
Einstiegspunkt für eine mögliche OSOS-Lücke. Der getrennte eApp-Pfad zeigt
zusätzliche Validierung vor dem Callback, aber deren vollständige
Kryptografie-/Ladersemantik und die dynamische UI-Verbindung sind offen. Es
gibt weiterhin keinen bestätigten Exploit und keinen belegten untethered
Rockbox-Handoff. Als Nächstes sind die dynamische `ExecuteGame`-Empfänger-
Verbindung und die konkrete Schreibbarkeit des `Manifest.plist` auf Slot 0 zu
klären; außerdem bleibt die Zuordnung des zuvor gefundenen unteren
Provider-VTable-Slots `+0x2c` offen.

Rohbelege: `/tmp/OSOS_games_vfs_constructor_followup_20261026.txt`,
`/tmp/OSOS_games_service_factory_followup_20261026.txt`,
`/tmp/OSOS_games_service_registration_callers_20261026.txt`,
`/tmp/OSOS_games_vfs_client_registrations_20261026.txt`,
`/tmp/OSOS_games_service_impl_followup_20261026.txt`,
`/tmp/OSOS_games_eapp_signature_bridge_20261026.txt`,
`/tmp/OSOS_games_eapp_signature_internal_20261026.txt` und
`/tmp/OSOS_games_eapp_cert_parser_helpers_20261026.txt`. Alle Ghidra-Läufe
verwendeten `-noanalysis -readOnly`; es gab keinen Geräte-, USB-, DFU-, Boot-
oder Flashzugriff.

## Nachtrag: Manifest-Push-Parser und Entity-Grenzen (26.10.2026)

Der automatische Manifestpfad benutzt tatsächlich den XML-Push-Parser:
`FUN_08240ac8` reicht die Datei in höchstens `0x200`-Byte-Blöcken an
`FUN_082779c8`, das jeweils `FUN_080e1310` fortsetzt. Korrektur zur früheren
Abgrenzung: Der Push-Zustandsautomat ruft bei `&` über `0x080e182c`
`FUN_08123090` auf. Für interne allgemeine Entities kann diese Funktion in
`FUN_08138c58` oder `FUN_0813980c` verzweigen; deren Parserkopien erreichen
`FUN_08216dc4` und damit bei Entity-Inhalt mit Elementen auch
`FUN_08139538`. Die rekursive Elementroutine ist also über die Entity-Route
erreichbar, nicht als direkter Aufruf jedes Start-Tags des Push-Parsers.

Im Slot-0-Manifestaufruf kommen die Zusatzoptionen als null an.
`FUN_082bf67c` ergänzt `0x10000`; `FUN_082d3914` übernimmt damit im sichtbaren
Optionspfad `XML_PARSE_COMPACT`. `NOENT` (`0x2`), `DTDLOAD` (`0x4`) und `HUGE`
(`0x80000`) werden dort nicht angefordert. Die aktuelle libxml2-Dokumentation
ordnet `COMPACT` der Speicherersparnis, `NOENT` der Entity-Ersetzung und
`HUGE` gelockerten Grenzwerten zu; das ist keine Versionsbestimmung für den
eingebetteten Parser ([Optionenreferenz](https://gnome.pages.gitlab.gnome.org/libxml2/html/parser_8h.html)).
Die genaue Wirkung globaler Defaults und des externen Entity-Loaders bleibt
offen.

Die konkreten Zielgrenzen im Abbild sind kleiner als in der ersten
Abschätzung angenommen. Der Wert bei `0x08672358` ist little-endian `0x100`
(256), nicht `0x10000`; `FUN_08139538` und `FUN_0824c628` verwenden diesen
Wert für Element-/Namenstacktiefe. `FUN_08138c58` und `FUN_0813980c` weisen
Entity-Verschachtelung über `0x28` (40) ohne `HUGE` ab; mit `HUGE` läge ihre
Grenze bei `0x400` (1024). `FUN_0820142c`, aufgerufen nach Entity-Verarbeitung
aus `FUN_08123090`, prüft außerdem das Verhältnis der geparsten Entity-Menge
zur bereits konsumierten Eingabe und setzt bei Überschreitung Fehler `0x59`.
Aus den verwendeten Faktoren ergibt sich statisch eine Schwelle von ungefähr
3,33:1; die genaue Laufzeitbilanz wurde nicht gemessen. `HUGE` würde auch
diese Prüfung umgehen, wird im Manifest-Aufruf aber nicht gesetzt.

Damit ist eine kontrollierbare XML-Eingabe und ein tiefer interner
Verarbeitungspfad belegt, aber kein Speicherfehler oder RCE. Die 256er
Elementgrenze ergibt zusammen mit den sichtbaren 72- und 24-Byte-Frames eine
grobe Obergrenze von rund 24 KiB für die gegenseitige Elementrekursion; das
liegt unter dem statisch eingerichteten `MainAppTask`-Stack von `0x20000`
Byte, ohne damit Stack-Guard oder den gesamten Aufrufstack zu beweisen. Die
40er Entity-Grenze und der Amplifikationscheck erschweren zusätzlich einen
einfachen verschachtelten-XML- oder Entity-Expansion-DoS. Übrig bleiben
ungeprüfte Parser-/Heapfehler, der nicht verifizierte physische Slot-0-Pfad
und die Schreibbarkeit des Manifests. Es gibt weiterhin keinen bestätigten
OSOS-Exploit, keinen Bootloader-Schreibpfad und keinen Rockbox-Handoff.

## Zusatzprüfung: Games-Pfadnamen und UTF-8-Normalisierer

Der automatische Games-Enumerator `FUN_081b343c` übernimmt den vom
Verzeichnisiterator gelieferten Namen, hängt ihn an den Games-Pfad an und
übergibt den so gebildeten Pfad an `FUN_08196cb8`. Dieser Wrapper löst den
VFS-Dienst für den jeweiligen logischen Slot auf und ruft dessen virtuellen
Slot `+0x50` auf. Der Verzeichnisname erreicht damit eine VFS-Pfadabfrage im
Kaltstartscan. Ob diese konkrete Implementierung `FUN_082284e0` und damit den
bekannten UTF-8-Komponenten-Splitter `FUN_08264d44` erreicht, bleibt offen:
der Empfänger von VFS-Slot `+0x50` ist in diesem Abbild nicht aufgelöst.

Der anschließende Manifest-Dateipfad ist enger abgegrenzt. `FUN_082526ca`
öffnet über `FUN_0823ff24`; diese Funktion ruft `FUN_0827f35c` mit Modus `1`
auf und speichert ihn im Streamobjekt. `FUN_08224970` ruft die fragliche
Komponenten-Normalisierung nur für Modus `0` auf. Der belegte Manifest-Read
läuft daher nicht selbst durch diesen Splitter. Eine mögliche Auslösung bei
der vorangehenden VFS-Abfrage des Verzeichnisnamens bleibt eine bedingte Spur,
keine nachgewiesene Kaltstart-Exploitation. Zusätzlich ist nicht geklärt, ob
der FAT-/VFS-Treiber fehlerhafte UTF-8-Namen überhaupt unverändert an OSOS
liefert.

Rohbelege: `/tmp/OSOS_games_path_normalizer_chain_20261026.txt`,
`/tmp/OSOS_games_vfs_path_candidates_20261026.txt`,
`/tmp/OSOS_games_vfs_method_bridge_20261026.txt` und
`/tmp/OSOS_games_vfs_service_context_20261026.txt`. Die Läufe öffneten eine
Projektkopie mit `-noanalysis -readOnly`; die Reports ändern weder das Gerät
noch Flash-Inhalte.

## Nachtrag: VFS-Registry und möglicher RAM-Handoff

Die VFS-Implementierung hinter dem Games-Scan ließ sich weiter bis zur
Registry-Grenze verfolgen. `FUN_0818e934` liefert einen Manager mit sieben
Service-Slots; `FUN_0818e998` trägt dynamisch einen Service in einen Slot ein.
`FUN_0827faca` löst die logische Slot-ID auf, und `FUN_08268cda` greift auf den
Manager zu oder verwendet den Fallback aus `FUN_0823fad4`. Der Fallback wird
beim ersten Bedarf lazy am RAM-Ziel `0x08762cb0` konstruiert; sein VTable-
Zeiger ist `0x08536a78`. Der Eintrag bei `vtable + 0x50` ist null. Er kann
deshalb die vom Games-Scan benötigte virtuelle Pfadabfrage nicht bedienen.
Beim Kaltstart-Games-Scan ruft `FUN_08196cb8` `service->vtable[0x50]` mit dem
aus dem Verzeichnisnamen gebildeten Pfad auf. Der verwendete Slot muss dafür
einen konkreten Dienst enthalten; dessen Laufzeitobjekt und VTable sind im
statisch abgebildeten OSOS-Body nicht bestimmt. Der Wrapper löst den Dienst
über `FUN_0827dce0`/`FUN_08263d14` auf; danach lädt `FUN_08196cb8` den Eintrag
`+0x50` und ruft ihn ohne Nullprüfung auf. Würde hier der generische Fallback
mit seinem leeren Eintrag verwendet, wäre das ein Absturzpfad. Ob der Fallback
für einen tatsächlich durchlaufenen Games-Eintrag ausgewählt wird, ist nicht
belegt.

Ein weiterer Startup-Trace grenzt den Zeitpunkt ein: `FUN_081ac420` ruft
`FUN_080b123c` auf. Wenn die Statusabfrage `FUN_081a8930(0)` null zurückgibt,
fordert diese Funktion über `FUN_080cbae0` den Typcode `0x72737263` (`rsrc`)
an. Schon die Statusabfrage konstruiert einen VFS-Pfad-Wrapper für Slot 0 und
ruft dort den virtuellen Slot `+0x48` auf; der anschließende Helper fragt
ebenfalls VFS-Slot 0 über `FUN_08268cda` ab. Slot 0 wird damit schon in diesem
Startup-Zweig benutzt, bevor die spätere Games-Aufzählung läuft. Der Trace
zeigt nicht, wo Slot 0 oder Slot 4 registriert werden. Die ermittelten
Registrierungs-Wrapper und die früh aufgerufenen Initialisierer führen weiter
zu dynamischen beziehungsweise nicht zugeordneten Empfängern. Damit bleibt
offen, ob der Games-Pfad den UTF-8-Komponentensplitter `FUN_082284e0` erreicht;
ein solcher Aufruf ist nicht bestätigt. Eine separate Routine `FUN_081b17ec`
im selben größeren Codebereich ruft über `FUN_08279be4` den Splitter mit
Slot 0 auf. Ihre nachweisbaren direkten Aufrufer sind jedoch `FUN_08148740`
und ein nicht als Funktion zugeordneter Call bei `0x0802ab90`; ein direkter
Kontrollfluss von `FUN_081af8bc`/`FUN_081b343c` dorthin ist nicht belegt. Dieser
Zusatz schließt die Normalisierer-Kette für den automatisch enumerierten
Verzeichnisnamen daher nicht.

Die Eintragungsroutine prüft zuerst den angeforderten Slot und erzeugt bei
freier Stelle einen Dienst über einen von zwei Konstruktorpfaden; erst danach
schreibt sie den Zeiger in den Slot. `FUN_0826384c` verwirft Slot-IDs ab 7,
bevor sie den Slotzugriff ausführt; ein einfacher Registry-Indexüberlauf ist
damit in diesem Pfad nicht gegeben. Der automatische `rsrc`-Pfad ruft diese
Routine über `FUN_082154b8` auf und belegt damit höchstens die bedingte
Erzeugung von Slot 4 aus Daten, die über Slot 0 gelesen werden. Die andere
direkte Aufrufstelle ist `FUN_08000a10`; für sie gibt es im analysierten
Programm keinen direkten Code-Xref, und die Suche nach einem absoluten
Thumb-Funktionszeiger fand keinen Treffer. Wie der physische Dateidienst für
Slot 0 beim normalen Kaltstart registriert wird, bleibt daher ungeklärt.

Für einen erfolgreichen OSOS-RCE gäbe es lokal bereits einen passenden
Rockbox-seitigen Startpfad: Der N5G-Bootloader aus
`bootloader/ipodnano4g.c` kann von `0x09000000` starten, `rockbox.ipod` und das
RAM-Disk-Image von der FAT-Partition laden und bei Hold oder Ladefehler das
signierte OSOS starten. Ein OSOS-Exploit könnte diesen Bootloader theoretisch
jedes Mal aus einer persistenten Datei in RAM laden; dafür müsste kein
Bootloader ins NAND/NOR geschrieben werden. Nicht belegt sind weiterhin ein
automatisch erreichbarer RCE, die Schreibbarkeit/physische Zuordnung des
Games-VFS-Slots auf dem Gerät und der Sprung aus dem initialisierten OSOS in
den Rockbox-Bootloader. Die vorhandenen Parsergrenzen sind keine Garantie gegen
andere Speicherfehler.

Rohbelege: `/tmp/OSOS_games_vfs_registry_deep_20261026.txt`,
`/tmp/OSOS_games_vfs_registry_clients_20261026.txt`,
`/tmp/OSOS_games_vfs_registry_refs_20261026.txt`,
`/tmp/OSOS_vfs_fallback_globals_20261026.txt`,
`/tmp/OSOS_vfs_default_vtable_entries_20261026.txt`,
`/tmp/OSOS_vfs_manager_singleton_20261026.txt`,
`/tmp/OSOS_mainapp_early_service_init_20261026.txt`,
`/tmp/OSOS_typecode_registration_helper_20261026.txt`,
`/tmp/OSOS_vfs_status_check_20261026.txt`,
`/tmp/OSOS_vfs_registration_callers_20261026.txt`,
`/tmp/OSOS_vfs_registry_insert_semantics_20261026.txt`,
`/tmp/OSOS_games_vfs_method_bridge_deep_20261026.txt`,
`/tmp/OSOS_games_vfs_provider_wrapper_semantics_20261026.txt`,
`/tmp/OSOS_utf8_splitter_callers_20261026.txt`,
`/tmp/OSOS_games_normalizer_candidate_caller_20261026.txt`,
`/tmp/OSOS_vfs_registration_orphan_refs_20261026.log` und
`/tmp/OSOS_vfs_registration_pointer_scan_20261026.log` sowie die bestehenden
Bootloader-Quellen unter `bootloader/ipodnano4g.c`,
`firmware/target/arm/s5l8702/boot.lds`,
`firmware/target/arm/s5l8702/crt0.S` und
`firmware/target/arm/s5l8702/system-s5l8702.c`. Ghidra lief mit
`-noanalysis -readOnly`; kein Build, Test, USB-, DFU-, Boot- oder
Flashvorgang.

Rohbelege: `/tmp/OSOS_xml_live_parser_refs_20261026.txt`,
`/tmp/OSOS_xml_callbacks_and_limit_20261026.txt`,
`/tmp/OSOS_xml_core_callback_paths_20261026.txt`,
`/tmp/OSOS_xml_entity_and_stack_reach_20261026.txt`,
`/tmp/OSOS_xml_entity_option_defaults_20261026.txt`,
`/tmp/OSOS_xml_entity_expansion_guard_20261026.txt` und
`/tmp/OSOS_xml_manifest_reader_construction_20261026.txt`. Die Checks liefen
im read-only-Ghidra-Projekt; es gab keine Geräte-, USB-, DFU-, Boot-, NAND-,
NOR- oder Flashaktion.
