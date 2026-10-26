# OSOS-Dateipfade: iTunes-Playlist-Ausgabe, Workout-XML und Device-Konfiguration

Stand: 26.10.2026. Ausschließlich statische Offline-Analyse von `osos_body.bin`
im read-only-Ghidra-Projekt `/tmp/N5G_OSOS_RTOS_analysis/N5G_OSOS_RTOS`.
Kein Gerätezugriff, USB, DFU, Neustart oder NAND-/NOR-/Flashzugriff.

## Ergebnis

Ein Fehler in der laufenden iPod-Software könnte prinzipiell einen
wiederholbaren Rockbox-Start ermöglichen, wenn eine präparierte Datei bei jedem
Kaltstart automatisch verarbeitet wird und die Verarbeitung zu kontrollierter
Codeausführung führt. Die hier nachverfolgten Zusatzpfade liefern dafür keinen
bestätigten Exploit.

## iTunesDB- und Playlist-Pfad

`FUN_082955e4` hat drei direkte Aufrufer: `FUN_0829e344`, `FUN_080fbcd8` und
`FUN_08243c08`. `FUN_0829e344` wird unter anderem aus dem MainApp-Setup
`FUN_0828bd04` aufgerufen. Der Setup-Pfad läuft über `FUN_08086ce8`, das am
Eventpfad `FUN_08066fb4`/`FUN_08079fb4` hängt. Die konkrete automatische
Kaltstartzustellung dieses Events ist im statischen Abbild weiterhin nicht
belegt.

Ein Rohscan fand bei `0x0859f93c` die drei Wörter `0x00086ce8`, `0x0b` und
`0x14a`; der erste Wert entspricht der 24-Bit-relativen Adresse von
`FUN_08086ce8`. Der Datensatz könnte zu einer Methoden-/Dispatcher-Tabelle
gehören. Ghidra findet aber keinen Verweis auf diesen Eintrag oder die
Tabellenbasis, und der Konsument sowie die Bedeutung der beiden weiteren Wörter
sind ungeklärt. Das ist ein Registrierungshinweis, kein Beleg für einen
automatischen Bootaufruf.

`FUN_082955e4` erzeugt `OnTheGoPlaylist*.plist`- beziehungsweise
`GeniusPlaylist*.plist`-Ausgaben. Es setzt feste plist-Schlüssel wie
`savedIndex`, `seedTrackPersistentID`, `playlistPersistentID`, `version`,
`DBTimestampMacOSDate` und `trackPersistentIDs`. `FUN_0829e57c`/`FUN_0829e3e0`
bereiten den festen Pfad `iPod_Control/iTunes/iTunesDB` und dessen Metadaten
vor. Der Schreibpfad `FUN_081c6b08` delegiert an `FUN_08287ad8`; dieser
vergrößert den Ausgabebereich bei Bedarf und kopiert den übergebenen Puffer in
den Stream. Im geprüften Pfad wird kein externes iTunesDB- oder plist-Dokument
als XML geparst. Vorhandene Zielpfade werden über den Datei-Provider behandelt,
bevor die neue Ausgabe geschrieben wird.

Damit ist der MainApp-Aufruf von `FUN_082955e4` kein belegter Parser für eine
vom Datenträger kontrollierte Datei. Die Routine serialisiert interne
Playlist- und Trackdaten. Der bedingte MainApp-Aufruf ist kein bestätigter
Kaltstart-Exploittrigger.

## Feste Device-Konfiguration

`FUN_0825fe3c` liest eine Datei unter `iPod_Control/Device/` in einen festen
`0x400`-Byte-Stream und übernimmt nur Dateien mit genau `4` oder `0x20` Byte.
Die Reads gehen in lokale Puffer; beim 32-Byte-Fall wird ein fixes Wort in den
Konfigurationszustand kopiert. Die Dateilänge wird nicht als Allokationsgröße
oder Schreibgrenze verwendet.

Direkte Aufrufer sind `FUN_080e9c54` und `FUN_080b2ca8`. Der erste wird von
der ARM-Funktion `0x081da69c` aufgerufen. Die frühere Ghidra-Analyse hatte
diesen Bereich irrtümlich als 2-Byte-Thumb-Funktion markiert; mit ARM-Modus
beginnt bei `0x081da69c` tatsächlich ein 1.784-Byte-Setup. Dessen sichtbare
Konstruktor-Kette lautet `FUN_0804cb72` → `FUN_0804f224` → `FUN_08050d84` →
`FUN_08053670` → `0x081da69c`. Das Setup registriert unter anderem die Pfade
`Photos/Photo Database`, `iPod_Control/Artwork/ArtworkDB` und
`iPod_Control/iTunes/iTunesDB` und ruft den begrenzten Device-Konfigurations-
Reader auf.

`FUN_081da550` gehört nicht zu diesem Pfad: Sie ist ein UTF-16-Konverter,
aufgerufen aus `FUN_081e2e70` bei `0x081e2ecc`. `FUN_080b2ca8` wird von
`FUN_08099c48` aufgerufen. Für `FUN_0804cb72`, `FUN_08099c48` und den zweiten
Konfigurationspfad ist kein automatischer Kaltstart-Aufrufer belegt; indirekte
Factory-/Overlay-Aufrufe bleiben möglich. Der geprüfte Reader ergibt weiterhin
keinen Speicherfehler.

## Workout-XML-Pfad

`FUN_081a3704` enumeriert `Trainer_Workouts_Empeds` und sucht darin nach
`preferences.xml` sowie `lastWorkout.xml`. Bei Treffern werden Datei-/Objekte
über generische Parser- und Registrierungshelfer weitergereicht. Für
`FUN_081a3704` gibt es im Ghidra-Projekt keinen direkten Code-Xref und im
OSOS-Body keinen exakten absoluten oder 24-Bit-relativen Funktionszeiger.
Eine UI- oder Overlay-Registrierung bleibt möglich. Ein automatischer
Kaltstartpfad wurde nicht gefunden.

Der XML-Parser selbst und die dynamische Registrierung sind noch nicht
vollständig untersucht. Dieser Pfad ist daher ein offener, bedingter
Parserkandidat, aber kein bestätigter Speicherfehler oder Boottrigger.

## Einordnung und nächste Schritte

Eine persistent ausgelöste OSOS-Schwachstelle bleibt als Konzept möglich. In
dieser Untersuchung wurden jedoch nur Serializer, begrenzte Konfigurationsreads
und ein nicht zurückverfolgter Workout-Parser gefunden. Die zuvor dokumentierten
Notes-UTF-8-Pfadunterlauf- und ArtworkDB-Überlaufkandidaten haben weiterhin
keinen belegten automatischen Kaltstarttrigger und keine nachgewiesene
Kontrollflussübernahme.

Nächste Offline-Schritte:

1. Den Workout-XML-Parser und seine externe beziehungsweise tabellenbasierte
   Registrierung nachvollziehen.
2. Die Eventzustellung an `FUN_08086ce8` vom MainApp-Kaltstart bis zur konkreten
   Eventquelle zurückverfolgen.
3. Die dynamische Registrierung und Startkette zu `FUN_0804cb72` sowie den
   Kontext des Media-Setups `0x081da69c` weiterverfolgen. Die aktuelle direkte
   Callgraph-Prüfung aus `MainAppTask` löst diesen Factory-/Overlay-Übergang
   nicht auf.

## Nachtrag: Media-Setup und ARM/Thumb-Korrektur

Die Nachprüfung mit erzwungenem ARM-Modus korrigiert die vorherige Zuordnung:
`0x081da69c` ist der Beginn einer ARM-Funktion, keine Thumb-Funktion. Sie ruft
bei `0x081da7e4` `FUN_080e9c54` auf; diese initialisiert mehrere Device-Dienste
und ruft den Reader `FUN_0825fe3c` auf. Der zweite Aufrufer des Media-Setups,
`thumb_81199ac`, ruft es nur auf, wenn das globale Objekt bei
`DAT_081199c0 + 0x14` an Offset `0x48` einen nichtnulligen Wert enthält. Für
diese kleine Callback-Funktion und für `FUN_0804cb72` fand sich kein direkter
Code-Xref. Ein Rohscan des OSOS-Bodys fand außerdem weder absolute noch
24-Bit-relative Pointerwörter auf `0x081199ac` oder `0x0804cb72`.

Damit ist die interne Konstruktor-Kette zum Media-Setup belegt, aber kein Weg
von einem normalen Kaltstart bis zu diesem Konstruktor. Die frühere Aussage,
Ghidras direkter MainApp-Graph schließe die Media-Initialisierung aus, war zu
stark: indirekte Factory-, VTable- und Overlay-Wege werden von diesem Graphen
nicht vollständig modelliert. Ein automatischer Dateieingang oder Exploit ist
weiterhin nicht nachgewiesen.

## Rohbelege

- `/tmp/OSOS_candidate_functions_followup_20261026.txt`
- `/tmp/OSOS_media_config_and_playlist_helpers_20261026.txt`
- `/tmp/OSOS_device_config_reader_callchain_20261026.txt`
- `/tmp/OSOS_media_config_caller_arm_20261026.txt`
- `/tmp/OSOS_media_setup_callers_20261026.txt`
- `/tmp/OSOS_media_root_constructor_20261026.txt`
- `/tmp/OSOS_utf16_caller_region_20261026.txt`
- `/tmp/OSOS_workout_root_and_parser_20261026.txt`
- `/tmp/OSOS_playlist_io_helpers_20261026.txt`
- `/tmp/OSOS_playlist_io_helpers_followup_20261026.txt`
- `/tmp/OSOS_workout_xml_helpers_20261026.txt`
- `/tmp/OSOS_other_path_reader_refs_20261026.txt`
- `/tmp/OSOS_app_event_table_refs_20261026.txt`
- `/tmp/OSOS_event_tables_immediate_refs_20261026.txt`
- `/tmp/OSOS_mainapp_parser_reach_20261026.txt`

Verwandte Analyse: [OSOS-runtime-exploit-boot-feasibility-2026-10-25.md](OSOS-runtime-exploit-boot-feasibility-2026-10-25.md).

## Nachtrag: libxml2-Reader und Workout-Dateisuche getrennt (26.10.2026)

Im OSOS-Body ist libxml2-Code enthalten. `FUN_0829e15c` ist ein XML-Reader-
Loop; es ruft unter anderem `FUN_08270b8c` zur Reader-/TextReader-Verarbeitung
und `FUN_08330614` für Elementereignisse auf. Die SAX-Textfunktion
`FUN_08167ff0` prüft vor dem Anhängen von Text die Längen-/Kapazitätsgrenzen,
verwendet einen realloc-Pfad und meldet überlange Textknoten bzw. Überlauf als
Parserfehler. In dieser Funktion ist kein unmittelbarer Out-of-bounds-Schreib-
oder Kontrollflussfehler erkennbar. Das ist keine vollständige Prüfung der
gesamten libxml2-Implementierung.

Der konkrete Einstieg in diesen Reader ist `FUN_08163bb4` → `FUN_0829e15c`.
`FUN_08163bb4` wird direkt aus `FUN_0815c47c` aufgerufen; dieser Pfad hängt an
`FUN_0814a988` und dessen bedingter Objekt-/Statusverarbeitung. Der Reader
besitzt im geprüften Callgraph keinen direkten Bezug zur Workout-Dateisuche.
`FUN_081a3704` sucht zwar `Trainer/Workouts/Empeds/preferences.xml` und
`lastWorkout.xml` und reicht gefundene Objekte an `FUN_0827af50` weiter, doch
`FUN_0827af50` geht hier über `FUN_082d83c4`/`FUN_0826a418`. Ein direkter Aufruf
oder Funktionszeiger von diesem Workout-Pfad auf `FUN_08163bb4` bzw.
`FUN_0829e15c` wurde nicht gefunden. Die bloße Existenz von libxml2 belegt daher
keinen XML-Parserzugriff auf diese persistenten Workout-Dateien.

Der nachgelagerte Objektmapper `FUN_0826a418` verwendet dynamische Arrays.
Im Typ-1-Zweig wird die Zahl der Einträge bei 1200 gedeckelt; im Typ-2-Zweig
leitet sie sich aus der Länge eines 32-Byte-Elementvektors ab und die Routine
schreibt genau einen 32-Bit-Wert pro Element. Für konsistente Vektorgrenzen
zeigt der geprüfte Pfad keinen festen Pufferüberlauf. Fehler in den nicht
vollständig aufgelösten virtuellen Methoden oder im vorgeschalteten Erzeuger
sind damit nicht ausgeschlossen.

Für die beiden Workout-Einstiege `FUN_081a3704` und `FUN_081a3970` gibt es im
Full-Body-Ghidra-Projekt keine direkten Code-Xrefs. `FUN_081a3970` liest
`Trainer/Workouts/Empeds/Trainer/historysummary` als Binärformat und begrenzt
die geprüften Tabellen auf höchstens 12 bzw. 13 Einträge mit festen
Datensatzbreiten; dieser Nachbarpfad ist kein XML-Reader. Die separaten Funktionen
`FUN_08163bb4` und `FUN_08163d50` haben dagegen direkte Aufrufer
(`FUN_0815c47c` bzw. `FUN_08155978`); diese bilden keinen direkten Pfad von der
Workout-Dateisuche zu libxml2. Ein Rohscan fand für `FUN_081a3704`,
`FUN_08163bb4` und `FUN_08163d50` keine exakten absoluten Thumb-Zeiger im Body;
das schließt berechnete oder zur Laufzeit erzeugte Verweise nicht aus. Die
geprüften Spuren ergeben somit weder einen automatischen Workout-Parserlauf
beim Kaltstart noch eine bestätigte RCE oder einen Rockbox-Handoff.

Neue Read-only-Ghidra-Auszüge: `/tmp/OSOS_workout_parser_chain_20261026.txt`,
`/tmp/OSOS_workout_config_factory_20261026.txt`,
`/tmp/OSOS_xml_textreader_callers_20261026.txt`,
`/tmp/OSOS_xml_app_callers_20261026.txt`,
`/tmp/OSOS_workout_xml_feature_callers_20261026.txt`,
`/tmp/OSOS_workout_xml_owner_context_20261026.txt` und
`/tmp/OSOS_workout_count_buffer_bounds_20261026.txt`. Alle Läufe verwendeten
`-readOnly -noanalysis`; keine Geräte-, USB-, DFU-, Boot- oder Flashaktion.
