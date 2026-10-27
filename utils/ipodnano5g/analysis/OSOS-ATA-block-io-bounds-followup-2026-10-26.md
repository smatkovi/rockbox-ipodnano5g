# OSOS ATA-Block-I/O: Bereichs- und Transferlängenprüfung

Stand: 26.10.2026. Statische read-only-Auswertung der vorhandenen OSOS- und
Ghidra-Abbilder. Das angeschlossene USB-Massenspeicher-Volume wurde zusätzlich
read-only geprüft. Es gab keine DFU-, NAND-/NOR-, Schreib- oder Bootoperation.

## Zuordnung zum möglichen Slot-0-Pfad

`PCFPowerMgr` legt über `FUN_0819ae24(1)` ein Objekt an, das
`FUN_0833a5e0` konstruiert. Die Funktion setzt dessen VTable auf `0x084fd570`.
Die Einträge bei `+0x14` und `+0x1c` zeigen auf `FUN_0833a944` und
`FUN_0833a9f4`; deren Code implementiert Sektor-Lese- und Schreibpfade. Der
PCFPowerMgr-Ereignisfall 0 übergibt dieses Objekt an `FUN_08000a10` für
Registry-Slot 0. Der ATA-Block-I/O-Code ist damit für den Slot-0-Kandidaten
relevant, sofern die zuvor beschriebenen Tasks im normalen Kaltstart laufen.

## Leseweg: begrenzte Länge, aber nicht überlaufsichere LBA-Prüfung

`FUN_0833a944` delegiert an `FUN_0833a7fa`. Diese berechnet mit
`FUN_0818e65c(0x8000, sector_size)` die maximale Sektoranzahl für den internen
`0x8000`-Byte-Cache und lehnt `count > max_count` ab. Bei der üblichen
Sektorgröße von 512 Byte wären das 64 Sektoren pro Transfer. Damit ist die
Berechnung `count * sector_size` in diesem Lesepfad höchstens `0x8000` Byte;
ein übergroßer Kopierbereich ist hier nicht belegt.

Die LBA-Bereichsprüfungen verwenden dagegen 32-Bit-Additionen ohne getrennte
Carry-/Überlaufprüfung: `LBA + max_count` wird mit der Gerätesektorzahl
verglichen; später vergleicht der Cachepfad `LBA + count` mit
`cache_start + max_count`. Bei wraparound kann der Zahlenvergleich einen
ungültigen Bereich akzeptieren. Ein statisches Beispiel unter der Annahme
`sector_size = 512` ist: Nach einem gültigen Cache-Read ab LBA 0 (`cache_start
= 0`, Cache gültig) ein Read mit `LBA = 0xfffffff0` und `count = 64`. Beide
Additionen in den Prüfungen laufen modulo 2^32 und können in den Cache-Hit-
Zweig gelangen; der berechnete Cache-Offset `(LBA - cache_start) * 512` läuft
dabei ebenfalls modulo 2^32 und liegt weit außerhalb des 32-KiB-Caches.

Der anschließende Aufruf `FUN_081916cc(user_buffer, cache_address, byte_count)`
verwendet den berechneten Cachezeiger als Quelle und den Aufruferpuffer als
Ziel (Richtung aus Aufrufkontext und DMA-Deskriptor abgeleitet). Das könnte
bei erreichbarer LBA-Eingabe einen Out-of-bounds-RAM-Lesezugriff, falsche
Daten oder einen Abort auslösen. Eine RAM-Schreibprimitive oder RCE ist damit
nicht gezeigt. Nicht geklärt ist, ob ein erreichbarer Dateisystempfad aus
Partition-/FAT-Metadaten solche LBA-Werte bis zu diesem Objekt durchreicht;
die untere ATA-Funktion kann außerdem fehlerhafte Geräte-LBAs ablehnen.

## Schreibweg: keine sichtbare Transferobergrenze

`FUN_0833a9f4` verwirft `count == 0` und negative Werte, zeigt aber selbst
keine Obergrenze wie die Lesevariante. Der unaligned Pfad berechnet
`(count - 1) * sector_size`, richtet den vom Aufrufer gelieferten Puffer auf
32 Byte aus und kopiert den Präfix mit der über `0x22000274` erreichbaren
`FUN_08000274`-Memmove-Routine. Der letzte Sektor wird über einen internen
Puffer geschrieben. `FUN_081c3fa4` übergibt die Sektorzahl anschließend als
16-Bit-Wert an den unteren Blockdienst. Das kann bei sehr großen Counts zu
Trunkierung und inkonsistenten Schreibmengen führen.

Ein Speicherüberlauf folgt aus dem Ausschnitt allein nicht: Bei einem korrekt
dimensionierten Aufruferpuffer und ohne 32-Bit-Überlauf in der Größenrechnung
bleibt die Verschiebung des Präfixes innerhalb des für `count` Sektoren
vorgesehenen Bereichs; bei einem zu kleinen Puffer wäre ein
Out-of-bounds-Read/-Write möglich. Ein erreichbarer Kaltstart-Aufrufer,
der einen vom Angreifer kontrollierten Count mit kleinerem Puffer kombiniert,
ist bisher nicht gefunden. Der Schreibpfad ist deshalb ein Audit-Kandidat,
aber derzeit kein belegter Exploit.

## Ergebnis und nächste statische Schritte

- Neuer konkreter Fehlerkandidat: wraparound in den LBA-Cachebereichsprüfungen
  des Lesepfads; ein falscher LBA könnte bei Cache-Hit einen Zeiger außerhalb
  des internen Puffers erzeugen.
- Separater Kandidat: fehlende sichtbare Count-Obergrenze und 16-Bit-Trunkierung
  im Schreibpfad; keine kontrollierte kleine Zielpuffergröße nachgewiesen.
- Weder der LBA-Wraparound noch der Schreibpfad sind als beliebige
  Codeausführung belegt. Der `accessories.reg`-Kandidat bleibt der klarere
  Kontrollflussfehler, aber seine Kaltstart-Erreichbarkeit und sein FAT-Provider
  sind offen.
- Nächster Offline-Schritt: den Weg von Partitionseinträgen und FAT-Clusterwerten
  in die LBA-Argumente von `FUN_0833a944` prüfen; parallel nach direkten
  Schreibaufrufern suchen, deren Count aus Dateiinhalten oder Dateigrößen stammt.

Rohbelege: `/tmp/OSOS_pcf_provider_ctor_20261026.txt`,
`/tmp/OSOS_pcf_provider_methods_20261026.txt`,
`/tmp/OSOS_ata_io_bounds_helpers_20261026.txt`,
`/tmp/OSOS_ata_io_arith_helpers_20261026.txt`,
`/tmp/OSOS_ata_write_lock_20261026.txt`,
`/tmp/OSOS_ata_write_helper_20261026.txt`,
`/tmp/OSOS_ata_write_align_allocator_20261026.txt`,
`/tmp/OSOS_ata_write_copy_helpers_20261026.txt`,
`/tmp/OSOS_body_08000274_20261026.txt`.

## Nachtrag: MBR-Partitionsgrenze als Eingabe zum LBA-Pfad (26.10.2026)

Der an Slot 0 übergebene Dienst wird durch `FUN_0802ec8c` aus Sektor 0
aufgebaut. Im MBR-Zweig akzeptiert `FUN_0802f4c8` DOS-FAT-Partitionstypen
`0x01`, `0x04`, `0x06`, `0x0b`, `0x0c` und `0x0e`; es prüft
`start != 0`, `length != 0` und `length <= device_sector_count`, aber sichtbar
nicht `start + length <= device_sector_count`. Der ungeprüfte Startwert wird
in den Volumehandler übernommen, der spätere LBA-Anfragen an den Provider
weiterleitet.

Das liefert einen konkreten Eingabepfad zu ungültigen LBA-Werten, aber noch
keine nachgewiesene Speicherbeschädigung. Die ATA-Cacheprüfung addiert LBA und
Bereichslänge ebenfalls ohne explizite Carry-Prüfung; die Hardware-/FTL-
Implementierung des darunterliegenden Sektorzugriffs kann den Wert jedoch
ablehnen. Ein Zusammenspiel, das den Cachezeiger außerhalb des 32-KiB-Puffers
erreicht, ist deshalb weiter ein Kandidat. Es gibt keinen belegten
Schreibzugriff auf RAM oder RCE.

Rohbelege: `/tmp/OSOS_body_FUN_0802fbe8_20261026.txt`,
`/tmp/OSOS_body_FUN_0802f4c8_20261026.txt`,
`/tmp/OSOS_body_FUN_0802ec8c_recheck_20261026.txt` und
`/tmp/OSOS_partition_volume_objects_20261026.txt`.

## Nachtrag: reale Sektorgröße und Leseauswirkung (26.10.2026)

Das aktuelle Gerät meldet über USB-Massenspeicher 4096-Byte-Logiksektoren.
Auch das FAT32-BPB gibt 4096 Byte pro Sektor an. Für den Cache von `0x8000`
Byte folgt in `FUN_0833a7fa` daher `max_count = 8` Sektoren; die zuvor
angeführte Zahl 64 gilt nur für das dort ausdrücklich hypothetische
512-Byte-Beispiel. Der aktuelle MBR meldet 3.901.376 Gerätesektoren; seine
Partition beginnt bei 63 und hat Länge 3.901.312, sodass `Start + Länge` hier
innerhalb des Geräts liegt.

Die Überlaufstelle bleibt statisch sichtbar: `FUN_0833a7fa` vergleicht
`LBA + max_count` und `cache_start + max_count` ohne getrennte Carry-Prüfung.
Bei einem Cache-Hit kann ein umgebrochener LBA damit einen Quellzeiger außerhalb
des 32-KiB-Caches erzeugen. Der untersuchte Transfer ruft
`FUN_081916cc(user_buffer, cache_source, count * sector_size)` auf; die
Kontrolle über MBR-/FAT-Metadaten erreicht in diesem Ausschnitt die Quelladresse,
nicht den Kopier-PC oder einen beliebigen RAM-Zielzeiger. Das ist ein möglicher
Fehler-/Datenlesepfad, aber keine belegte RAM-Schreibprimitive oder RCE. Ob ein
konkreter FAT-Clusterwert bis zu dieser Cache-Hit-Bedingung gelangt und welche
Fehlerantwort der untere Sektor-Dienst für eine missende Cacheline liefert,
bleibt statisch offen. Der aktuelle MBR testet diesen Randfall nicht.

Rohprüfung des Gerätes: `lsusb`, `fdisk -l /dev/sda`,
`blockdev --getss /dev/sda`, `blockdev --getsz /dev/sda` und die read-only
BPB-Ausgabe aus `/dev/sda1`. Es wurde kein Sektor verändert.

## Nachtrag: FAT-Clusterwert kann die LBA-Berechnung umlaufen (27.10.2026)

Der offene Datenfluss von FAT-Metadaten zur Sektoradresse ist jetzt teilweise
geschlossen. `FUN_0822fbbc` liest einen FAT-Eintrag über `FUN_081e0e10` und
`FUN_082015bc`. Für den Dateisystemtyp 8 behält `FUN_08235b00` den unteren
28-Bit-Wert bei, solange er nicht exakt `0x0fffffff` ist. Der daraus gelesene
Clusterwert erreicht unter anderem `FUN_0822641e` über
`FUN_081608f8`.

`FUN_0822641e` berechnet die Sektoradresse als
`first_data_lba + ((cluster - 2) << cluster_shift)`. Die Addition und
Linksverschiebung sind 32-bittig; eine Carry-Prüfung fehlt. Anschließend wird
nur geprüft, ob das Ergebnis kleiner als `end_data_lba` ist. Eine untere
Grenze gegen `first_data_lba` fehlt ebenfalls. Für `cluster_shift = 7` ergibt
der FAT-Wert `0x02000002` rechnerisch einen um `2^32` umlaufenden Offset und
damit wieder `first_data_lba`. Andere passende Clusterwerte können die
Ergebnisadresse unter den Beginn des Datenbereichs umlaufen lassen. Das setzt
voraus, dass der BPB-Pfad diesen Cluster-Shift akzeptiert; dessen vollständige
Initialisierung und Grenzprüfung ist noch nicht lokalisiert.

Der Clusterlauf wird beim Durchlaufen von Verzeichnissen verwendet:
`FUN_081f83c8` ruft `FUN_081608f8` auf; die FAT-Pfadauflösung erreicht diesen
Pfad über `FUN_0814f238` beziehungsweise `FUN_08158b64`. Damit ist ein
datenträgerkontrollierter Weg bis zur fehlerhaften LBA-Abbildung belegt,
sobald ein solcher VFS-Pfad ausgeführt wird. Der konkrete Effekt ist bisher
eine fehlgeleitete Sektor-Leseadresse, etwa ein Zugriff auf reservierte
Sektoren oder auf Sektoren vor dem Datenbereich. Ein RAM-Schreibzugriff,
eine Rücksprungkontrolle oder Codeausführung folgt daraus nicht.

Die zuvor dokumentierte ATA-Cache-Quellüberlesung ist damit noch nicht als
erreichbar belegt: Für sie wäre eine hohe LBA nötig, die zugleich durch
`end_data_lba` zugelassen wird und den Cache-Hit-Wraparound trifft. Ob
manipulierte BPB-/Partitionsgeometrie diese Kombination nach erfolgreichem
Mount ermöglicht, bleibt offen. Es gab keinen Laufzeit- oder Gerätetest.

Ein zweiter arithmetischer Kandidat liegt im Dateileser `FUN_08143298`: Die
Prüfung `file_size <= offset + count` verwendet eine 32-Bit-Summe ohne
Carry-Prüfung. Ein Offset nahe `0xffffffff` kann deshalb eine Kürzung auf die
Restlänge der Datei umgehen. Die Bytes werden weiterhin nur in den vom
Aufrufer angeforderten Puffer kopiert; ein kleiner Zielpuffer zusammen mit
einem größeren Count oder eine Speicherbeschädigung ist aus diesem Pfad nicht
belegt. Dieser Befund ist vorerst ein mögliches Lesen über das Dateiende.

Rohbelege: `/tmp/OSOS_LBA_cluster_core_20261027.txt`,
`/tmp/OSOS_LBA_cluster_reader_20261027.txt`,
`/tmp/OSOS_LBA_fat_core_20261027.txt`,
`/tmp/OSOS_LBA_runtime_fat_callbacks_20261027.txt` und
`/tmp/OSOS_runtime_provider_disk_io_20261026.txt`. Ghidra-Projekt:
`/tmp/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime`, geöffnet mit
`-readOnly -noanalysis`.

Nächste statische Schritte: den BPB-Geometrieparser und alle Schreibstellen
für `cluster_shift`, `first_data_lba` und `end_data_lba` lokalisieren; danach
die resultierende LBA gegen den darunterliegenden Provider und den Aufrufer-
Puffer des Dateilesers verfolgen. Bis dahin sind beide Befunde Kandidaten für
Fehlzugriffe beziehungsweise Datenlesen, nicht für bestätigte Codeausführung.
