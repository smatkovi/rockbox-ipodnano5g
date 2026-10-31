# SilverImagesDB: rebasierte Slot-4-Providerkette

Stand: 29.10.2026. Read-only-Ghidra-Auswertung und Prüfung bereits lokal
vorhandener Firmwareartefakte. Kein Geräte-, USB-, DFU-, Boot- oder
Flashzugriff.

## Adressräume

Die ältere Slot-4-Analyse mischt Runtime-VA und Full-Body-VA. Das aktuelle
Runtime-Projekt lädt `osos_runtime_dram_20261025.bin` (SHA-256
`1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`) mit
Dateioffset `0x2e27c` bei VA `0x08000000`. Daher gilt:

`Full-Body-VA = Runtime-VA + 0x2e27c`.

| Frühere Full-Body-Adresse | Runtime-Adresse im aktuellen Projekt | Verifizierte Funktion |
|---|---|---|
| `0x081121f0` | `0x080e3f74` | Resource-Tabellenleser `FUN_080e3f74` |
| `0x08113178` | `0x080e4efc` | MBR/APM-Partitionssuche `FUN_080e4efc` |
| `0x081bcbb0` | `0x0818e934` | Storage-Service-Singleton `FUN_0818e934` |
| `0x081bcc14` | `0x0818e998` | Slot-Registry/Fabrik `FUN_0818e998` |
| `0x08243734` | `0x082154b8` | Service-Wrapper zur Registry |
| `0x0826b6e4` | `0x0823d468` | Provider-/Volume-Konstruktor |
| `0x08280b68` | `0x082528ec` | Blockgrößenabfrage |
| `0x08291ac8` | `0x0826384c` | Slotbereichsprüfung (`slot < 7`) |

Die Rohlogs `OSOS_silver_slot4_volume_io_writeability_thumb_20261029.log`,
`OSOS_silver_slot4_address_audit_20261029.log` und
`OSOS_silver_slot4_correct_function_entries_20261029.log` entstanden durch
erzwungene Disassemblierung der Full-Body-Zahlen im Runtime-Adressraum. Sie
zeigen dort jeweils anderen Code und sind **keine Widerlegung** der früheren
Full-Body-Funktionszuordnungen. Die rebasierte Gegenprüfung ist in
`evidence/silver-slot4-2026-10-28/OSOS_silver_slot4_rebased_provider_chain_20261029.log`
und den dortigen `partition_lookup_bounds`-/`resource_provider_trace`-Logs
festgehalten.

## Verifizierte Slot-4-Kette

Im Runtime-Abbild ruft `FUN_081ac420` zuerst `FUN_080b123c` und danach den
SilverImagesDB-Leser `FUN_080bbc1c` auf. `FUN_080b123c` sucht zunächst den
vorhandenen Servicezustand; falls der Dienst fehlt, fordert es über
`FUN_080cbae0(4, 0x72737263, 0, 2)` den Resource-Typ `crsr`, ID 0, Provider-Typ
2 für Slot 4 an. Das Literal `0x72737263` wurde bei `0x080b1264` bestätigt.

`FUN_080cbae0` bezieht den Storage-Service über `FUN_0818e934`. `FUN_080e4efc`
liest dessen Sektor 0 und unterstützt einen MBR-Zweig mit vier festen
Einträgen sowie einen Apple-Partition-Map-Zweig, der `APPLE_MDFW` sucht.
Im APM-Zweig stammt die Schleifengrenze aus dem Datenträgerkopf; eine feste
kleine Obergrenze ist im sichtbaren Code nicht vorhanden. Jeder Datensatz wird
aber als einzelner Block in einen zuvor anhand der Blockgröße reservierten
Puffer gelesen. Die Auswirkung eines manipulierten Zählers ist daher vorerst
ein möglicher überlanger Scan/DoS oder ein fehlgeschlagener Blockread, kein
belegter RAM-Overwrite.

`FUN_080e3f74` sucht anschließend im Resource-Verzeichnis höchstens 16
Datensätze nach FourCC/ID, bildet Start und Länge des Ressourcenbereichs und
übergibt sie an den Provider. Eine sichtbare Prüfung, dass der vollständige
Resource-Bereich innerhalb der `APPLE_MDFW`-Partition liegt, wurde nicht
gefunden. Die Slot-Registry `FUN_0818e998` lehnt Slotwerte ab 7 ab und ruft
für Provider-Typ 2 `FUN_0823d468` auf; dieser wählt `FUN_08110e30`. Dessen
VTable liegt bei `0x085056b0`. `FUN_082528ec` fragt die Blockgröße über
Provider-VTable `+0x2c` ab und liefert bei fehlendem Provider `0x200`.

`FUN_080bbc1c` öffnet den festen Pfad
`Resources/UI/SilverImagesDB.LE.bin` über `FUN_0827f35c` mit Slot 4 und liest
die BMap-Struktur über `FUN_08279bd4`/`FUN_081fd5e8`. Die Datei liegt laut
lokalem Stock-Abgleich in der eingebetteten `APPLE_MDFW`-Ressource, nicht in
der normalen beschreibbaren FAT-Datenpartition. Der Stockheader enthält
`0x474` Einträge; alle geprüften Bereiche liegen in der Datei. Der im BMap-
Parser vorhandene 32-Bit-Zählerüberlauf wird mit diesem Stockinhalt nicht
ausgelöst. Eine benutzerkontrollierte Ersetzung der `APPLE_MDFW`-Resource oder
ein OSOS-erreichbarer Update-Schreibpfad ist weiterhin nicht belegt.

Der Aufbau `FUN_081ac420 -> FUN_080b123c -> FUN_080bbc1c` ist innerhalb der
Funktion statisch geordnet. Die normale Kaltstarterreichbarkeit von
`FUN_081ac420` bleibt kontextabhängig: der Pfad über `FUN_080253f4` verlangt
einen nichtnulligen Objektkontext; der alternative Aufruf `FUN_080eb730`
prüft ein verschachteltes Feld auf Nichtnull. Der Ursprung eines beim
Kaltstart gültigen Kontextes ist in den geprüften Daten nicht bewiesen.

## Zwischenstand vor der Cache-Wrap-Prüfung

Der Slot-4-Parser ist ein echter arithmetischer Kandidat, aber der konkrete
Eingang stammt aus `APPLE_MDFW`; der Stockinhalt ist sicher bezüglich des
gefundenen Zählers. Der APM-Zähler kann einen langen Scan auslösen, aber es
gibt keinen statischen Beleg für kontrollierte Codeausführung. Damit liegt
weiterhin kein neuer untethered-Rockbox-Pfad vor.

## Nachtrag: Rohsektor-Cache-Wrap und möglicher BMap-Eingang (29.10.2026)

Die konkrete Slot-4-Rohgeräteinstanz ist `FUN_0819ae24(0)`. Ihr Wrapper hat
VTable `0x084fd570`; der Read-Eintrag `+0x14` zeigt auf den Thumb-Wrapper bei
`0x0833a944`, der `FUN_0833a7fa` aufruft. `FUN_0833a7fa` erhält seine
Rohgeräte-Readmethode aus dem Kindobjekt, begrenzt jeden Transfer auf den
`0x8000`-Byte-Cache und prüft `LBA + max_count <= device_sector_count` ohne
separate Carry-Prüfung. `FUN_081916cc` stellt anschließend einen DMA-Transfer
mit dem Aufruferpuffer als Ziel und der berechneten Cacheadresse als Quelle ein.
Der Cache wird durch den ersten Read von LBA 0 mit bis zu `max_count` Sektoren
gefüllt und als gültig markiert. Bei den für dieses Gerät zuvor read-only
gemessenen 4096-Byte-Logiksektoren ist `max_count = 8`.

Damit ergibt sich für den tatsächlich im Slot-4-Aufbau erreichbaren
Ein-Sektor-Read ein konkreter bedingter Fall: `FUN_080e4efc` liest zuerst LBA 0
und findet danach den APM-Eintrag `APPLE_MDFW`; `FUN_080e3f74` liest den
zurückgegebenen Partitionsstart erneut mit Count 1. Wenn ein manipuliertes APM
als Start `0xffffffff` liefert, bestehen die sichtbaren Prüfungen in
`FUN_0833a7fa`, weil `0xffffffff + 8` zu 7 umläuft und der Cache ab 0 gültig
ist. Auch `0 + 8 < 0xffffffff + 1` ist nach 32-Bit-Arithmetik falsch, sodass
der Cache-Hit-Zweig verwendet wird. Der Quelloffset wird
`0xffffffff * 4096 mod 2^32 = -4096`; der DMA-Read kopiert damit einen Sektor
ab `cache_base - 0x1000` in den lokalen Sektorpuffer des Tabellenparsers. Das
ist ein Out-of-bounds-Read vor dem Cacheobjekt, kein RAM-Overwrite. Die
anschließende Parserfortsetzung hängt davon ab, ob die gelesenen Nachbarbytes
die erwartete Resource-Header-Magic enthalten; dies ist nicht gezeigt.

Die Arithmetik erlaubt bei `LBA = 0xfffffff8`, `Count = 8` sogar einen
`0x8000`-Byte-Transfer ab `cache_base - 0x8000`. Für genau diesen größeren
Transfer ist in der initialen `FUN_080e3f74`-Partitionssuche aber nur Count 1
belegt; ein automatisch erreichbarer Slot-4-Aufrufer mit Count 8 an dieser
LBA ist noch nicht nachgewiesen.

Ein möglicher zweiter Schritt wäre, dass eine veränderbare APM-/Resource-Map
`APPLE_MDFW` auf kontrollierbare Sektoren im normalen Datenträgerbereich
umlenkt. Der Resource-Parser prüft sichtbar nicht, dass der ganze
Resource-Bereich innerhalb der Partition liegt und authentifiziert in dieser
Funktion weder Resource-Tabelle noch Inhalt. Das könnte die zuvor bekannte
BMap-Zähler-Fehlallokation mit untrusted Bytes verbinden. **Nicht belegt**
sind jedoch, dass der relevante APM-Eintrag auf dem Gerät vom Host veränderbar
ist, dass `FUN_081ac420` im normalen Kaltstart den nötigen Kontext erhält oder
dass der kombinierte BMap-Fehler zu kontrollierter Rücksprung-/Codeausführung
führt. Die BMap-Fehlallokation bleibt ein separater Speicherbeschädigungs-
Kandidat; der Cache-Wrap allein liefert nur einen Quelllesefehler.

Damit ist die frühere Frage, ob der untere Sektorprovider einen ungültigen
LBA ablehnt, für diesen Fall nicht entscheidend: Der demonstrierte Cache-Hit
ruft den Rohgeräte-Callback gar nicht auf. Alle Aussagen bleiben statisch;
keine Partition wurde geändert, kein Gerät gelesen oder beschrieben und kein
Boot-/Flashversuch durchgeführt.

## Bewertung und nächste Schritte

Der Cache-LBA-Wrap ist ein konkreter, vom APM-Startwert bedingter
Out-of-bounds-RAM-Lesepfad im frühen `crsr`-Resource-Aufbau. Er ist noch kein
Exploit für untethered Rockbox: ein RAM-Schreibzugriff, kontrollierter
Kontrollfluss und ein verifizierter automatischer Kaltstartaufruf fehlen.
Der Stock-SilverImagesDB-Inhalt löst den BMap-Zählerüberlauf nicht aus.

Die Aufruferprüfung grenzt den Startkontext weiter ein. `FUN_080253f4` wird
statisch direkt von `FUN_08022b08` aufgerufen (`0x08022b18`). Der Caller reicht
sein zweites Eingabeargument an `FUN_08032850` weiter; diese Funktion liefert
nur bei nichtnulligem Argument und einem passenden Objekt aus ihrer Registry
einen Kontext zurück. Der erfolgreiche Pfad baut daraus ein Objekt und ruft
`FUN_081ac420` auf. Für `FUN_08022b08` selbst fand die Ghidra-Xref-Abfrage keine
eingehende Referenz; ein Byte-Scan des Runtime-Images fand auch keinen
absoluten Zeiger auf `0x08022b08` oder den Thumb-Zeiger `0x08022b09`. Das
schließt relative Tabellen-/Framework-Dispatches nicht aus.

Der alternative direkte Caller `FUN_080eb730` lädt einen Kontext aus dem
statischen Objekt bei `0x08550acc` und prüft Feld `+0x48`. Der dort abgelegte
Pointer bei `0x08550ae0` ist im Runtime-Image null. Die Abfrage direkter
Referenzen auf die benachbarte Struktur fand keinen direkten Write auf dieses
Pointerfeld, aber viele Leseverwendungen; indirekte Initialisierung ist damit
nicht ausgeschlossen. Beide Aufrufpfade lassen den automatischen
Kaltstartaufruf weiterhin unbewiesen.

Nächste Offline-Schritte: (1) den möglichen Pfad von APM und `APPLE_MDFW` zu
host-kontrollierbaren Sektoren anhand vorhandener Images und des OSOS-Write-/
Updatecodes prüfen; (2) den nichtnulligen Startkontext von `FUN_081ac420`
über Task-/Frameworkregistrierung weiterverfolgen; (3) bei bestätigter
BMap-Quelle die Fehlallokation und deren Folge für benachbarte Heapobjekte
erneut bewerten. Kein NAND-/NOR-Schreiben und keine Flash-Experimente.

## Rohbelege

Die reproduzierbaren Ghidra-Exporte, das Adressprüfskript und Prüfsummen liegen
unter `evidence/silver-slot4-2026-10-28/`. `README.md` dort erklärt die Rolle
jedes Logs und kennzeichnet die unrebasierten Diagnoseausgaben.

## Nachtrag: Scheduler- und Storage-Schreibpfad (29.10.2026)

Die Schedulerprüfung korrigiert eine offene Hypothese: `FUN_081a8320` schreibt
bei `+0x20` den Little-Endian-Wert `0x72756e20` (ASCII `" run"`) in den
Eintrag und reiht ihn über `FUN_081966b4` in die Timerliste ein. Das Feld ist
kein Callback-Funktionszeiger. Der Export zeigt damit eine Queue-Registrierung,
aber noch keinen Ablauf-Dispatch bis `FUN_080eb730` oder `FUN_081ac420`.
`TMusicLoadingTask` wird weiterhin nur über die status-/eventabhängige Kette
`FUN_08038d38 -> FUN_0804b900 -> FUN_08228ac0 -> FUN_08076996 ->
FUN_080945fc` angelegt; ein automatischer Kaltstarttrigger ist nicht belegt.

Der Rohgerätewrapper hat getrennte VTable-Einträge: `+0x14` zeigt auf den
Read-Wrapper `0x0833a944`, `+0x1c` auf `0x0833a9f4`. Der Read-Zweig prüft die
Sektoranzahl mit einer 32-Bit-Summe ohne Carry-Prüfung. Der Schreibzweig
invalidiert zuerst den Cache und delegiert dann an `FUN_081c3fa4`; im sichtbaren
Wrapper ist keine entsprechende Prüfung gegen die Gesamtsektorzahl vorhanden.
Das ist ein zusätzlicher Grenzprüfungs-Kandidat, aber noch kein belegter
Speicherfehler: die untere Hardware-/Storage-Routine und ihre Fehlerbehandlung
müssen separat eingeordnet werden, und ein OSOS-erreichbarer Aufruf mit
kontrollierbarem LBA wurde nicht gefunden.

`FUN_0819ae24(0)` wird sowohl vom Slot-4-Aufbau `FUN_080cbae0` als auch vom
Storage-Initialisierer `FUN_08339d3c` bezogen. `FUN_08339d3c` wird unter anderem
von `FUN_081f1f18` und `FUN_0833aef0` aufgerufen. Das zeigt die interne
Existenz des Rohgeräteobjekts und seiner Schreibmethode, aber nicht, dass ein
Host oder ein normaler Dateipfad die APM-Sektoren beschreiben kann. Im konkret
verfolgten SilverImagesDB-Aufbau werden Resource-Bytes über
`FUN_08279bd4 -> FUN_081fd5e8 -> Provider-VTable +0x1c` gelesen. Die Semantik
der Open-Modusparameter von `FUN_0827f35c` ist in dieser Runde nicht vollständig
aufgelöst; daher wird der Pfad nicht als garantiert read-only klassifiziert.

Der Cache-Wrap bleibt somit an eine manipulierte APM gebunden. Ein Rohschreiber
existiert, aber die Verbindung `fremdgesteuerte Eingabe -> erreichbarer
Schreibaufruf -> APM/APPLE_MDFW` ist offen. Ebenso fehlen ein bestätigter
RAM-Schreibfehler, kontrollierter Kontrollfluss und ein nachgewiesener
Kaltstartpfad. Kein untethered-Rockbox-Boot ist belegt.

Neue Rohbelege zu dieser Runde: `OSOS_silver_scheduler_dispatch_followup_20261029.log`,
`OSOS_silver_scheduler_callback_pointer_xrefs_20261029.log`,
`OSOS_silver_raw_storage_write_api_20261029.log`,
`OSOS_silver_storage_vtable_wrapper_followup_20261029.log`,
`OSOS_silver_storage_vtable_thumb_entries_20261029.log`,
`OSOS_silver_storage_write_helpers_thumb_20261029.log`,
`OSOS_silver_storage_raw_write_reachability_20261029.log`,
`OSOS_silver_storage_secondary_factory_20261029.log`,
`OSOS_silver_storage_write_method_xrefs_20261029.log`,
`OSOS_silver_storage_init_callers_20261029.log`,
`OSOS_silver_resource_provider_read_write_methods_20261029.log`,
`OSOS_silver_resource_slice_write_path_20261029.log` und
`OSOS_silver_resource_backing_io_thumb_20261029.log`.

Nächste Offline-Schritte: (1) die untere `FUN_081c3fa4`-/Storage-Fehler- und
Bereichsbehandlung nachvollziehen; (2) den tatsächlichen Caller des
Rohschreib-VTable-Eintrags und alle Rechte-/Slotprüfungen eingrenzen; (3) den
Schedulerablauf von Queue-Expiration bis virtueller Taskmethode verfolgen.
Danach den Cache-Wrap nur dann als nutzbaren Eingang werten, wenn ein
OSOS-erreichbarer Schreibpfad die benötigten APM-/Resource-Metadaten tatsächlich
ändern kann.

## Nachtrag: BMap-Überlauf erreicht den Element-Initializer (29.10.2026)

Die ABI-Prüfung bestätigt jetzt die Reihenfolge und den Funktionszeiger des
BMap-Allocators: `FUN_080bbc1c` liest den 32-Bit-Eintragzähler und ruft
`FUN_082741a0(0x18, count, DAT_080bbdf0)` auf. `FUN_082741a0` reicht Zähler,
Elementgröße und Initializer über `FUN_082bdc64` an `FUN_081586fa` weiter.
Der Thumb-Code von `FUN_081586fa` berechnet `count * element_size` mit einer
32-Bit-Multiplikation ohne sichtbare Überlaufprüfung. Bei der Slot-4-Variante
ist der optionale Allokator null; der Pfad verwendet deshalb die normale
Heap-/Pool-Allokation. Wenn diese fehlschlägt, ruft `FUN_08194f20` den fatalen
Fehlerpfad `FUN_081940f0` auf, statt den übergroßen Zähler sauber zurückzuweisen.

`DAT_080bbdf0` enthält den Thumb-Zeiger `0x080dc219`. Der Code bei
`0x080dc218` setzt sechs 32-Bit-Wörter, also 24 Byte pro Element, auf null.
`FUN_081586fa` führt diesen Callback in einer Schleife von `i = 0` bis
`i < count` aus und erhöht den Zielzeiger jeweils nur um die angeforderte
Elementgröße. Damit erreicht die Initialisierung den Zähler direkt nach der
Fehlmultiplikation; sie ist nicht durch die späteren Datei-Leseprüfungen
geschützt.

Ein rechnerischer Kandidat ist `count = 0x15555556` (357.913.942):
`count * 24 mod 2^32 = 0x10`, während `count * 12 mod 2^32 = 0x8`. Der Zähler
bleibt für die vorzeichenbehaftete Initializer-Schleife positiv. Die erste
Allokation fordert somit nominal nur 16 Byte an, die zweite nur 8 Byte; der
Initializer läuft danach dennoch mit dem ursprünglichen Zähler weiter und
schreibt je Aufruf 24 Byte. Das belegt einen bedingten Objektgrenzenfehler
bereits während der Initialisierung, sofern die kleine Allokation gelingt.
Der Heap-/Pool-Dispatcher versucht einen Größenklassenpool und kann auf den
allgemeinen Heap zurückfallen; dessen sichtbare Rundung macht aus der
16-Byte-Anforderung keine zählerabhängig große Allokation. Der genaue
Nachbarobjekt-Effekt, ein kontrollierbarer Rücksprung und Codeausführung sind
nicht belegt. Ein tatsächlicher Fehler kann auch früh durch einen ungültigen
Speicherzugriff abbrechen.

Der anschließende 8-Byte-Tabellenread ist ebenfalls nicht gleichbedeutend mit
einem akzeptierten Parse: der Streamreader prüft Offset/Dateilänge und die
exakte zurückgegebene Länge. Diese Prüfungen verhindern hier aber nicht den
zuvor ausgeführten Initializer. Für eine Ausnutzung fehlen weiterhin eine
host-kontrollierbare BMap-Quelle (die Stockdatei liegt in `APPLE_MDFW`), ein
belegter Kaltstart-Kontext für `FUN_081ac420` und ein Weg von der
Speicherbeschädigung zu kontrolliertem Codefluss. Dies ist ein stärkerer
bedingter Heap-Schreib-/DoS-Kandidat, kein bestätigter Bootrom-Bypass oder
untethered-Rockbox-Pfad.

Die sechs neuen Rohbelege `OSOS_silver_bmap_allocator_semantics_20261029.log`,
`OSOS_silver_bmap_pool_allocator_followup_20261029.log`,
`OSOS_silver_bmap_heap_manager_dispatch_20261029.log`,
`OSOS_silver_bmap_allocator_impl_followup_20261029.log`,
`OSOS_silver_bmap_pool_allocator_fallback_20261029.log` und
`OSOS_silver_bmap_heap_manager_constants_20261029.log` liegen neben dem
vorherigen `OSOS_silver_bmap_allocator_abi_followup_20261029.log` im
Evidence-Verzeichnis. Sie stammen aus `-noanalysis -readOnly`-Läufen.

Nächster sinnvoller Offline-Schritt: klären, ob irgendein normaler
OSOS-/USB-/Updatepfad die APM- oder `APPLE_MDFW`-Bytes ändern kann, und den
Ursprung des nichtnulligen `FUN_081ac420`-Kontexts weiterverfolgen. Bis dahin
bleibt der Befund bedingt und wird nicht am Gerät getestet.

## Nachtrag: Raw-Write erreicht den Controller, aber kein Eingabepfad (29.10.2026)

Die VTable-Kette des Raw-Storageobjekts ist nun bis zum Controller-Dispatcher
aufgelöst. `FUN_08193eec` setzt die Child-VTable auf `0x0853567c`; deren Slot
`+4` zeigt auf `FUN_0833b078` (Write) und `+8` auf `FUN_0833b7f4` (Read).
Der äußere Cache-Write-Wrapper `FUN_0833a9f4` invalidiert zuerst den Cache und
delegiert ausgerichtete Writes an `FUN_081c3fa4`. Diese Routine berechnet die
zu flushende Bytezahl, reicht LBA und auf 16 Bit gekürzte Sektorzahl an die
Child-VTable weiter und enthält im sichtbaren Code keine Prüfung gegen die
Gesamtsektorzahl. `FUN_0833b078` teilt Transfers in höchstens `0x100`-Sektor-
Schritte und dispatcht an controllerinterne Methoden; auch in diesem Wrapper
ist keine Gerätegrenzenprüfung sichtbar. Die konkreten Controller-Callbacks
und deren vollständige Fehler-/Bereichsbehandlung werden im folgenden
Nachtrag weiter eingegrenzt.

Das bestätigt eine interne Raw-Write-Fähigkeit, aber keine vom Host
kontrollierbare LBA-Eingabe. Der SilverImagesDB-Pfad ruft über
`FUN_08279bd4 -> FUN_081fd5e8` die Read-Methode des Resource-Providers auf.
Der zugehörige Open-Aufruf `FUN_080bbc1c -> FUN_0827f35c` setzt den Moduswert
`1`; seine exakte Schreibberechtigungssemantik ist anhand der gemeinsamen
Factory noch nicht abschließend bewiesen. Der Xref-Scan fand 31 direkte
Aufrufer von `FUN_0827f35c`; diese breite generische Verwendung ist für sich
kein Beleg, dass `APPLE_MDFW` beschreibbar ist. Weder ein Hostpfad zu den
APM-Sektoren noch ein Schreibaufruf für die SilverImagesDB wurde gefunden.

Neue Rohbelege: `OSOS_silver_raw_write_backend_followup_20261029.log`,
`OSOS_silver_raw_write_vtable_targets_20261029.log`,
`OSOS_silver_vfs_open_factory_callers_20261029.log`,
`OSOS_silver_vfs_open_callsite_windows_20261029.log`,
`OSOS_silver_slot4_open_mode_semantics_followup_20261029.log`,
`OSOS_silver_vfs_open_mode_dispatch_20261029.log`,
`OSOS_silver_vfs_open_object_vtables_20261029.log`,
`OSOS_silver_vfs_open_object_vtable_entries_20261029.log` und
`OSOS_silver_vfs_file_object_methods_20261029.log`. Alle erfolgreichen
Abfragen liefen in Ghidra mit `-noanalysis -readOnly`.

Zwischenstand dieser Runde: ein ungeprüfter Low-Level-LBA-Pfad existiert,
aber die Kette `hostkontrollierte Metadaten -> beschreibbarer APPLE_MDFW/APM-
Bereich -> früher BMap-Parser` ist weiterhin unterbrochen. Nächste Offline-
Schritte sind die Controller-Callbacks für die VTable-Slots sowie die
Schreibrechte und Caller der resource-backed Write-Methode einzugrenzen.

Die nachgelagerte Controllerprüfung grenzt die Aussage ein: `FUN_0833b2d8`
prüft nicht-nullige Puffer/Controller und `count <= 0x100`; danach übergibt es
die LBA an `FUN_081ab45a`. Diese Hilfsroutine lehnt LBA-Werte ab, bei denen
eines der oberen vier Bits gesetzt ist (`LBA < 0x10000000`), prüft aber keine
konkrete Gerätesektorzahl. Der alternative Controllerpfad `FUN_0833b628`
übergibt die LBA an `FUN_081ab41c`, der sie in Registerfelder zerlegt und
keine Softwaregrenze prüft. Die 0x100-Sektorgrenze stammt dort vom
Batchwrapper `FUN_0833b078`, nicht von einer Prüfung der Gerätekapazität.
Damit ist die unmittelbare Controllerkette für bestimmte Hardwaremodi nur
gegen LBA-Werte ab 2^28 begrenzt; ein Zugriff außerhalb der echten Kapazität
ist statisch möglich, wenn ein Aufrufer so eine LBA liefert. Ein Hostpfad,
der dies für APM/`APPLE_MDFW` tut, bleibt aber weiterhin unbewiesen.
