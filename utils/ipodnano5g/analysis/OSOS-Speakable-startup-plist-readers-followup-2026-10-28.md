# Speakable-PLIST-Leser im MainApp-Startpfad

Stand: 28.10.2026. Statische, read-only-Auswertung des OSOS-Runtime-Abbilds
und der lokalen Stock-RSRC-Dateien. Kein Gerätezugriff, kein Schreib-/Lösch-
oder Flashvorgang und kein Payload-Test.

## Erreichbarkeit und Dateien

`FUN_0804d42c` ist ein MainApp-VTable-Eintrag und wird von `FUN_0804fa58`
im MainApp-Initialisierungslauf aufgerufen. Die Reihenfolge in
`FUN_0804d42c` ist:

1. `FUN_0827ccfc(1)` liest zuerst
   `/iPod_Control/Speakable/CacheInfo.plist` und bedingt
   `/iPod_Control/Speakable/ConfigInfo.plist`.
2. `FUN_0805f86a` ruft `FUN_0826d5fc` auf; diese ruft später erneut
   `FUN_0827ccfc(0)` und `FUN_08312ab4` auf.
3. `FUN_08312ab4` prüft `/iPod_Control/Speakable/UISS.plist`.

Die drei benutzerseitigen Dateien gehen über Provider-Slot 0. Der Parserpfad
läuft über `FUN_0827abe8 -> FUN_0827d7aa -> FUN_0832cf24`; der Reader liest
gewöhnlich in `0x400`-Byte-Blöcken. `0x8000` in `FUN_0827ea84` ist die
Anfangsgröße des Reader-/Parserobjekts, keine hier belegte Dateigrenze.

`FUN_08312ab4` verarbeitet UISS nur, wenn das Speakable-Verzeichnis und die
Datei auffindbar sind. Vor der Nutzung vergleicht es `Version` mit `1.1`,
`Locale` mit der aktuellen System-Locale und `BuildID` mit der laufenden
Firmware. Bei fehlenden oder abweichenden Metadaten wird die Datei entfernt
und aus `/Resources/Speakable/UISS_combined.plist.gz` neu aufgebaut. Diese
Resource wird fest über Slot 4 geöffnet. Die Metadaten sind keine Signatur:
Eine Datei mit passenden Werten kann den benutzerseitigen Parsepfad erreichen.

Der Stock-FAT-Abgleich fand `Resources/Speakable/UISS_combined.plist.gz` in
`segments/rsrc.bin` (327.420 Byte, SHA-256
`d9e40e94da4b8b0b480d694bb4e191bdc4601c4a239d071f729163282ce71b7f`). Das
GZIP-Archiv ergibt 1.183.664 Byte XML; `plistlib` liest es als Dictionary mit
`Version = "1.1"`. Das bestätigt die feste Fallback-Quelle, nicht den Inhalt
der aktuellen Gerätedateien.

## Datenfelder und Speicherwirkung

`FUN_0827ccfc` parst Locale-/Statusfelder sowie `FolderBinning` und `Channels`
mit den Unterfeldern `SpokenMenus` und `VoiceOver`. Die Locale wird gegen eine
Tabelle mit 30 Einträgen verglichen. Die Wörterbuch- und Stringwerte werden in
dynamischen PLIST-/Stringobjekten verarbeitet. Für die hier verfolgten Pfade
fand sich keine feste Stackkopie der Locale oder der Wörterbuchwerte.

Vier `FolderBinning`-Werte werden über `FUN_0827782a` und
`FUN_08265800` aus Strings zu vorzeichenbehafteten Ganzzahlen konvertiert und
in `DAT_0827d138[4..7]` übernommen. In diesem Aufrufer ist keine Wertebereich-
prüfung sichtbar. Die späteren Verbraucher und deren Index-/Größennutzung sind
noch nicht vollständig verfolgt; deshalb bleibt dies ein offener Datenfluss,
aber kein belegter Speicherfehler.

Der Parser-Wrapper ruft `FUN_08252bb8(..., 0)` auf, also mit Optionswert 0.
Die früheren XML-Audits dokumentieren Schutzprüfungen für Entity-Amplifikation
und Verschachtelung im gemeinsamen Parser. Das beweist weder, dass jede
UISS-spezifische Parserkante sicher ist, noch eine Codeausführung. Für diesen
Speakable-Pfad wurde kein Speicherfehler gefunden.

## Einschränkungen und Bewertung

- Die Parseraufrufe liegen statisch im MainApp-Startablauf; die tatsächliche
  Laufzeitbedingung, dass die Verzeichnisse und Dateien auf dem Gerät vorhanden
  und über die FAT-Namensauflösung erreichbar sind, ist nicht gemessen.
- Die Pfade enthalten lange Namen. Der separate VFAT-LFN-Audit fand einen
  bedingten Out-of-bounds-Read beim LFN-Auflösen; dessen reale Auswirkung auf
  genau diese Speakable-Öffnungen bleibt offen.
- Die durch passende Metadaten erreichbare Eingabe ist potenziell
  benutzerkontrolliert. Der ursprüngliche Reader-Audit fand keinen
  Stack-/Heap-Overwrite; der Nachtrag unten dokumentiert einen separaten
  Datenfluss in einen virtuellen Aufruf. Eigene Codeausführung ist noch nicht
  nachgewiesen.
- Ergebnis für das Untethered-Ziel: ein stärkerer Kontrollflusskandidat, aber
  noch kein bestätigter Exploit und keine Persistenzumgehung.

## Belege

- `evidence/speakable-2026-10-28/OSOS_speakable_parser_and_slot4_callers_20261028.log` – UISS-Reader,
  Metadatenprüfung und Slot-4-Fallback.
- `evidence/speakable-2026-10-28/OSOS_speakable_init_and_parser_config_20261028.log` – MainApp-Init,
  Parserwrapper und Slot-0-Datei-I/O.
- `evidence/speakable-2026-10-28/OSOS_speakable_startup_owners_20261028.log` und
  `evidence/speakable-2026-10-28/OSOS_speakable_vtable_refs_20261028.log` – MainApp-Aufrufpfad.
- `evidence/speakable-2026-10-28/OSOS_plist_generic_callers_20261028.log` – CacheInfo-/ConfigInfo-
  Parser und Feldverarbeitung.
- `evidence/speakable-2026-10-28/OSOS_speakable_config_helpers_20261028.log` und
  `evidence/speakable-2026-10-28/OSOS_speakable_value_consumers_20261028.log` – Locale-, Integer- und
  Stringhelper.
- `evidence/speakable-2026-10-28/OSOS_speakable_callers_xmlcore_20261028.log` – Reader-/Push-Parser-
  Konstruktion.
- `evidence/speakable-2026-10-28/OSOS_xml_entity_expansion_guard_20261026.log`,
  `evidence/speakable-2026-10-28/OSOS_xml_entity_guard_callers_20261028.log` und
  `evidence/speakable-2026-10-28/OSOS_xml_tree_builder_followup_20261027.txt` – gemeinsame Parserguards.

## Nächste statische Schritte

1. Die vier `FolderBinning`-Integer bis zu allen Array-/Indexverbrauchern
   verfolgen und nach Wertebereichsprüfungen suchen.
2. Die zwei weiteren `FUN_0827abe8`-Aufrufer (`savedIndex` und iTunes-PLIST)
   mit ihren Event-/Dateiquellen abgrenzen. Der iTunes-Pfad hat dabei einen
   separaten Stackpufferkandidaten; er ist im Folgebericht dokumentiert.
3. Den LFN-Befund gegen die konkreten Speakable-Pfade einordnen, ohne aus dem
   statischen Read-Kandidaten einen Geräteabsturz abzuleiten.

## Nachtrag 28.10 – FolderBinning-Feld als virtueller Aufrufzeiger

Die vier `FolderBinning`-Werte sind nicht nur einfache Indexverbraucher:

- `DAT_0827d138` zeigt im Runtime-Abbild auf `0x08553cd8`. Der Parser schreibt
  die Werte für `UISS`, `PLSS`, `TASS` und `OTSS` in die Elemente `[4..7]`.
- Die Konstantentabelle bei `0x084378a8` ordnet `puVar12[3]` dem Pfad
  `/iPod_Control/Speakable/CacheInfo.plist` und `puVar12[4]` dem Pfad
  `/iPod_Control/Speakable/ConfigInfo.plist` zu. `FolderBinning` wird aus dem
  zuerst eingelesenen CacheInfo-Dictionary geholt; ConfigInfo liefert die
  Locale-Metadaten für den Vergleich. Der CacheInfo-Pfad läuft über Provider
  Slot 0.
- `DAT_0809be88` enthält `0x08553ce8`, also die Adresse von Element `[4]`.
  `FUN_0809be74` liest von dort mit `+4` das Element `[5]` (`0x08553cec`),
  behandelt den Wert als Objektzeiger, liest dessen erstes Wort als VTable-
  Zeiger und lädt den Methodenzeiger bei `VTable+0x180`. Die Thumb-Assembly
  endet mit `BX r1`; `r0` enthält dabei weiterhin den geladenen Objektzeiger.
- Derselbe Feldwert wird von `FUN_08081054`, `FUN_08080fcc`,
  `FUN_0822c588` und weiteren Routinen als Zeiger oder Objekt behandelt.
  `FUN_0802daf4` legt beim MainAppTask-Setup tatsächlich ein Heapobjekt an und
  speichert dessen Zeiger an `0x08553cec`.
- Der Integerpfad `FUN_0827782a -> FUN_08265800 -> FUN_0831601c` nimmt einen
  XML-String und liefert einen 32-Bit-Wert. Der Konverter erkennt Überläufe
  über 32 Bit, erzwingt aber keine fachliche Wertebereichsgrenze. Der
  `FolderBinning`-Parser weist den Rückgabewert direkt Element `[5]` zu.
- Die vier Werte liegen zusammenhängend. Damit kann die Parser-Eingabe
  Element `[5]` als Objektzeiger auf die Adresse von Element `[4]` setzen und
  Element `[4]` als VTable-Zeiger, dessen Slot `+0x180` auf Element `[6]`
  fällt. Element `[6]` liefert dann das `BX`-Ziel. Unter der noch offenen
  Annahme, dass die Werte bis zum Aufruf nicht überschrieben werden, ist
  damit ein frei wählbares Branchziel statisch konstruierbar. Das belegt noch
  keine Ausführung eigener Bytes; Registerzustand, ausführbarer Speicher und
  Laufzeit-Erreichbarkeit müssen separat bestätigt werden.
- Im Eventpfad `FUN_08038d38 -> FUN_0804bd38` kann `FUN_08058a6c` aufgerufen
  werden, wenn Eventtyp `0x12`, Zielobjekt und Zustandsprüfungen passen.
  `FUN_08058a6c` ruft `FUN_0827ccfc(1)` und danach `FUN_08076810` auf;
  `FUN_08076810` erreicht `FUN_0809be74`. Damit liegt der PLIST-Parse statisch
  vor diesem `BX`. `FUN_081f630c` dazwischen referenziert das globale Feld
  nicht. Für die übrigen dynamischen Aufrufe in `FUN_08076810` ist eine
  indirekte Änderung des Feldes nicht vollständig ausgeschlossen.
- `FUN_08038d38` ist als Thumb-Zeiger in der Methodentabelle ab `0x084f7558`
  bei `0x084f7594` eingetragen; der benachbarte Eventhandler
  `FUN_080377dc` steht in derselben Tabelle bei `0x084f75cc`. `FUN_0804c1b4`
  setzt den Objekt-VTable-Zeiger auf `0x084f7558`. Ein Eventzweig in
  `FUN_080377dc` ruft `FUN_0804c1a0` auf; der Nachtrag unten grenzt diesen
  Aufruf als Registry-Lookup ab, nicht als Registrierung des Eventhandlers.
  Ein vollständiger Laufzeitpfad vom MainApp-Start bis zu diesem Handler ist
  damit weiterhin nicht belegt.
- Die MainApp-Methoden `FUN_0804fa58` und `FUN_0804d42c` liegen in einer
  anderen Methodentabelle (Einträge bei `0x084fcaf0` und `0x084fcb00`). Es
  gibt in den geprüften direkten Referenzen keinen statischen Link von dieser
  MainApp-Tabelle zur Tabelle mit `FUN_08038d38`. Die MainApp-Erreichbarkeit
  des Eventpfads bleibt deshalb offen.
- Die ursprüngliche Objektinitialisierung ist im MainAppTask-Pfad verankert:
  `arm_8354ba8 -> FUN_0801d594 -> FUN_0801e3a4` startet den Task mit Entry
  `FUN_080202d8`; dieser ruft `FUN_08023670 -> FUN_0802daf4`, das den
  Heapobjektzeiger speichert. Der Parser kann dieses Feld später überschreiben.

**Bewertung:** Verifiziert sind ein benutzerseitiger Integer-Datenfluss in ein
als Objektzeiger interpretiertes Feld und ein danach erreichbarer virtueller
Aufruf. Die benachbarten Parserwerte erlauben statisch die Konstruktion eines
kontrollierten `BX`-Ziels, sofern keine Zwischenroutine sie überschreibt.
Damit ist ein starker Kontrollflussübernahmekandidat gefunden. Offen bleiben
die tatsächliche Laufzeit-Erreichbarkeit des Eventhandlers auf dem Gerät,
die vollständige Unverändertheit der Felder bis zum `BX`, und ob sich daraus
praktische Codeausführung oder ein persistenter Flash-Schreibpfad ergibt. Die
Ghidra-Speichermarkierung `RWX` für das zusammengefasste Abbild belegt keine
MPU-/MMU-Rechte im Gerät. Es gab keinen Gerätetest, Payload-Test oder
Flashzugriff.

Neue Belege:

- `evidence/speakable-2026-10-28/OSOS_speakable_indirect_call_chain_20261028.log` – Parser, Eventpfad,
  Aufrufkette und Integerkonverter.
- `evidence/speakable-2026-10-28/OSOS_speakable_global_config_xrefs_20261028.log` und
  `evidence/speakable-2026-10-28/OSOS_speakable_field5_writer_order_20261028.log` – Feldadresse,
  Verbraucher und Initialisierer.
- `evidence/speakable-2026-10-28/OSOS_speakable_field5_initialization_chain_20261028.log`,
  `evidence/speakable-2026-10-28/OSOS_speakable_initializer_registration_20261028.log` und
  `evidence/speakable-2026-10-28/OSOS_speakable_startup_dispatcher_20261028.log` – MainAppTask-Start
  und Zeigeranlage.
- `evidence/speakable-2026-10-28/OSOS_speakable_config_source_constants_20261028.log` und
  `evidence/speakable-2026-10-28/OSOS_speakable_literal_path_mapping_20261028.log` – Zuordnung der
  CacheInfo- und ConfigInfo-Pfade.
- `evidence/speakable-2026-10-28/OSOS_speakable_event_registration_20261028.log`,
  `evidence/speakable-2026-10-28/OSOS_speakable_event_vtable_constructor_20261028.log` und
  `evidence/speakable-2026-10-28/OSOS_speakable_event_gate_details_20261028.log`,
  `evidence/speakable-2026-10-28/OSOS_speakable_vtable_registration_20261028.log` und
  `evidence/speakable-2026-10-28/OSOS_speakable_dispatch_registration_followup_20261028.log` sowie
  `evidence/speakable-2026-10-28/OSOS_speakable_mainapp_vtable_match_20261028.log` –
  Eventhandler-Tabelle, Registrierung und bedingte Zustandsübergänge.

Nächste statische Schritte: alle indirekten Aufrufe zwischen Parser und
`FUN_0809be74` auf mögliche Feldänderungen prüfen, den Eventhandler bis zum
tatsächlich registrierten MainApp-Ereignis weiterverfolgen und die
CacheInfo-Pfadauflösung über die FAT-LFN-Schicht gegen den früheren
Namensauflösungsbefund abgleichen. Danach bleibt ein Gerätetest für die
Laufzeitbestätigung erforderlich.

## Nachtrag 28.10 – Parser-Flag und Event-Registry abgegrenzt

`FUN_0827ccfc` läuft beim MainApp-Start zunächst mit Parameter `1` in
`FUN_0804d42c`. Danach ruft `FUN_0805f86a -> FUN_0826d5fc` denselben Parser
mit Parameter `0` auf. Der Test `(uVar10 & param_1) != 0` schützt nur den
frühen ConfigInfo-/Locale-Update-Zweig. Die spätere Format-/Locale-Prüfung
und der `FolderBinning`-Block liegen außerhalb dieses Zweigs. Ein gültiges
CacheInfo-Dictionary kann deshalb bei beiden Aufrufen dieselben vier
`FolderBinning`-Felder schreiben; das zweite Flag schaltet diese Zuweisungen
nicht ab.

Der CacheInfo-Pfad akzeptiert für die weitere Verarbeitung nur ein passendes
`Format`-Feld und `Locale`-Strings mit mindestens zwei Zeichen. Der Vergleich
der Locale-Einträge verwendet `FUN_0824f066` zur Zeichen-Normalisierung und
prüft nur die ersten zwei Zeichen, nicht den vollständigen Locale-String.
Die vier Integer-Zuweisungen folgen danach. Ein CacheInfo-Wert muss also die
Format- und Präfixprüfung bestehen, aber diese Prüfung bindet die
`FolderBinning`-Werte selbst nicht an einen Wertebereich.

Zwischen Parse 1 und Parse 2 ruft `FUN_0805f86a` nacheinander
`FUN_081b1218`, `FUN_0826d490`, `FUN_0826d4c8` und `FUN_0826d4dc` auf.
Keine dieser vier Funktionen hat einen direkten Referenzaufruf auf den
Getter `FUN_081a7454`, der den globalen Zeiger aus `0x08553cec` zurückgibt.
Die drei `FUN_0826...`-Funktionen dispatchen aber jeweils über
`param_1 + 0x64`; das konkrete virtuelle Ziel und dessen Seitenwirkungen sind
noch nicht rückverfolgt. Daher ist nicht ausgeschlossen, dass der erste
geparste Wert indirekt vor Parse 2 gelesen wird.

Zwei andere direkte Getter-Nutzer wurden gegen ihre Elternpfade geprüft:

- `FUN_0804db50` verwendet den zurückgegebenen Zeiger für mehrere virtuelle
  Aufrufe bei `VTable+0xf8`. Sein einziger direkter Caller ist
  `FUN_0803bdb4`; dieser wird von `FUN_0802adba` nur für Ereigniswert `0x20`
  aufgerufen. `FUN_0802adba` steht in einer zweiten Objekt-VTable bei
  `0x084fef20` (`VTable+0x3c`), ohne direkten Code-Caller oder belegten
  Kaltstartpfad.
- `FUN_0804df80` speichert den Getter-Wert als Kindobjekt und übergibt ihn an
  `FUN_0826beec`, das bei einem Wechsel virtuelle Methoden bei `+0x48` und
  `+0x44` aufruft. Der einzige direkte Caller ist `FUN_0821b70e`, und dort
  liegt der Aufruf in einem `param_5 != 0`-Zweig. Die zwei direkten Aufrufer
  von `FUN_0821b70e` (`FUN_0803c694` und `FUN_082033a0`) übergeben beide `0`.
  In den bekannten direkten Pfaden wird `FUN_0804df80` somit nicht erreicht;
  weitere dynamische Aufrufer sind damit nicht ausgeschlossen.

Die VTable von `FUN_0802adba` beginnt bei `0x084feee4`; ihr Pointer wird in
`FUN_0803be08` in das Objekt geschrieben. Diese Routine hat genau einen
direkten Caller, `FUN_0802adea`. Der steht selbst als Tabelleneintrag bei
`0x084feee8` und hat keinen direkten Code-Caller. Damit ist die Objekt-
Initialisierung zwar bis zum VTable-Schreibpunkt verfolgt, aber der
Erzeugungs-/Einbindungspfad des Objekts bleibt ohne statische Wurzel.

Die frühere Formulierung, `FUN_0804c1a0` sei Teil einer Registrierung, war zu
weitgehend. Der Code zeigt:

- `FUN_0804c1a0` holt einen Manager und ruft `FUN_081af950` mit Schlüssel
  `0xa988` auf.
- `FUN_081af950 -> FUN_081a3f86` durchläuft eine Registry-Kette über Feld
  `+0x14` und ruft deren virtuelle Methode bei `+0x74` mit Typ-Tag `"Str "`
  und dem Schlüssel auf. Das ist ein Lookup, kein Register-Aufruf.
- Dieser Lookup wird in einem Zweig von `FUN_080377dc` mit Eventwert
  `0x63` aufgerufen. `FUN_080377dc` und `FUN_08038d38` haben keine direkten
  Code-Caller; ihre Thumb-Zeiger stehen in der Tabelle ab `0x084f7558`.
  `FUN_0804c1b4` setzt diesen VTable-Zeiger und wird direkt nur aus
  `FUN_08038eb8` aufgerufen; der konkrete Objekt-Erzeugungspfad ist noch
  nicht gefunden.

Damit bleibt die entscheidende Lücke präziser benannt: Parser und
kontrollierbarer virtueller Aufruf sind statisch verbunden; die Erzeugung
des Eventobjekts und die normale Aktivierung aus dem MainApp-Kaltstart sind
es nicht. Diese Datenflussanalyse belegt weder eigene Codeausführung noch
einen persistenten Schreibpfad.

Belege für diesen Nachtrag: `evidence/speakable-2026-10-28/OSOS_speakable_flag_dispatch_reachability_20261028.log`,
`evidence/speakable-2026-10-28/OSOS_speakable_between_parses_20261028.log`,
`evidence/speakable-2026-10-28/OSOS_speakable_alternate_reader_paths_20261028.log`,
`evidence/speakable-2026-10-28/OSOS_speakable_alternate_trigger_parents_20261028.log` und
`evidence/speakable-2026-10-28/OSOS_speakable_alt_event_table_refs_20261028.log`,
`evidence/speakable-2026-10-28/OSOS_speakable_event_object_constructor_20261028.log` und
`evidence/speakable-2026-10-28/OSOS_speakable_event_object_factory_followup_20261028.log`.

## Nachtrag 28.10 – übrige globale Leser und Callback-Wurzeln

Die weiteren direkten Leser des Speakable-Zeigers wurden bis zu ihren
bekannten Aufrufern verfolgt:

- `FUN_08231082 -> FUN_0822c588` ruft eine virtuelle Methode bei
  `VTable+0x3c` des globalen Objekts auf. Bekannte direkte Aufrufer sind
  `FUN_081fbf04` und `FUN_0803cc7c`. `FUN_081fbf04` hängt an den
  direkten Aufrufstellen in `FUN_0804b8a8` (Ereignisdispatcher) und
  `FUN_08058b4c` (für diese Runde ohne statischen Caller-Root);
  `FUN_0803cc7c` hat ebenfalls keinen direkten Code-Aufrufer im
  Ghidra-XRef-Bestand. Der Pfad ist damit überwiegend ereignis-/objekt-
  getrieben; sein tatsächlicher Start- oder Laufzeit-Root ist nicht belegt.
- `FUN_08233568` ruft bei erfüllter Statusprüfung `FUN_0805eccc` auf.
  Direkte Aufrufer sind `FUN_08038d38`, zweimal `FUN_0804b9b0` und
  `FUN_081fbf04`. `FUN_08038d38` wählt `FUN_08233568` für Ereigniswert
  `0x00080009` und andere Statushandler für benachbarte Werte. Die
  Ereignisbehandlung ist im Code klar, aber die Erzeugung und Aktivierung
  des zugehörigen Dispatcherobjekts ist weiterhin nicht bis zum Kaltstart
  geschlossen.
- `FUN_081fbfbc` ruft `FUN_0827b4a2` auf dem globalen Objekt auf. Die zwei
  Verweise auf `FUN_081fbfbc` sind Tabellen-Callbacks bei `0x08508808` und
  `0x0850cf30`; die kleinen Wrapper laden jeweils den Wert `0x2c` und
  springen anschließend zurück. `FUN_0827b4a2` ändert nur ein Zustandsbyte
  bei Objekt-Offset `+0x98`, und zwar bei erlaubten Übergängen innerhalb
  der Zeichenfolge `'*'`, `'+'`, `','`, `'-'`. Das ist für sich kein
  beliebiger Schreib- oder Kontrollflussprimitive.

Die drei virtuellen Aufrufe bei `param_1+0x64` zwischen den beiden
Parserläufen lassen sich teilweise zuordnen. Im Methodentabellenbereich ab
`0x084fcaf0` liegt bei `+0x10` `FUN_0804d42c`; bei `+0x64` steht der
Thumb-Zeiger auf `0x080f81ba`. Dessen disassemblierter Körper prüft
Länge/Position bei `this+0x10` und `this+0x18`, erhöht bei verfügbarem
Byte den Positionszeiger und liest aus dem Puffer bei `this+0x0c`; am Ende
des Puffers liefert er `-1`. Das passt zu einem Byte-Lese-/Cursor-Callback
und nicht zu einem Store in die Speakable-Globalfelder. **Vorbehalt:** Die
Zuordnung dieses Tabellenbereichs zum konkreten Laufzeitobjekt von
`FUN_0805f86a` ist aus den statischen Verweisen plausibel, aber ein
eigenständiger Konstruktor-/VPtr-Store auf `0x084fcaf0` wurde nicht
gefunden. Deshalb ist dies eine starke Funktionshypothese, noch kein
vollständig bewiesener Laufzeit-Datenfluss.

Auch der alternative Eventdispatcher bleibt ohne geschlossene Wurzel:
`FUN_0804c1b4` schreibt `0x084f7558` als VTable in das Objekt; der
Dispatcher `FUN_08038d38` steht in dieser Tabelle bei `0x084f7594`.
`FUN_08038eb8` ruft den Setup-Code und anschließend `FUN_08191cdc` auf,
ist selbst aber nur ein Tabelleneintrag bei `0x084f755c` und hat keinen
direkten Code-Aufrufer. Es gibt daher weiterhin keinen statischen Beleg,
dass dieses Objekt beim normalen Kaltstart erzeugt und in den aktiven
Eventlauf eingehängt wird.

Diese Runde schließt die zuvor offenen Getter-Verwendungen weiter ein:
Die meisten nachgewiesenen Leser liegen in Ereignis-/UI-Pfaden; der
Byte-Cursor-Callback zwischen Parse 1 und Parse 2 schreibt nach der
naheliegenden Tabellenzuordnung nicht in die Speakable-Globalfelder.
Damit sinkt die Plausibilität eines unbemerkten Überschreibens durch diese
konkreten Funktionen. Die zentrale Einschränkung bleibt aber bestehen:
Die Parserwerte erreichen statisch einen indirekten Aufruf, während der
normale Kaltstart-Root des dafür nötigen Dispatcherobjekts und die
Zuordnung des MainApp-Receivers nicht vollständig belegt sind. Es wurde
weder ein eigener Payload ausgeführt noch ein Flash-Schreibpfad gezeigt.

Zusätzliche Belege dieser Runde: `evidence/speakable-2026-10-28/OSOS_speakable_remaining_global_trigger_20261028.log`,
`evidence/speakable-2026-10-28/OSOS_speakable_last_reader_owners_20261028.log`,
`evidence/speakable-2026-10-28/OSOS_speakable_dispatcher_parent_followup_20261028.log`,
`evidence/speakable-2026-10-28/OSOS_speakable_callback_veneer_windows_20261028.log`,
`evidence/speakable-2026-10-28/OSOS_speakable_callback_refs_and_event_ids_20261028.log`,
`evidence/speakable-2026-10-28/OSOS_speakable_callback_vtables_20261028.log`,
`evidence/speakable-2026-10-28/OSOS_speakable_mainapp_vtable_slot64_20261028.log`,
`evidence/speakable-2026-10-28/OSOS_speakable_mainapp_slot64_target_20261028.log`,
`evidence/speakable-2026-10-28/OSOS_speakable_mainapp_vtable_base_writes_20261028.log` und
`evidence/speakable-2026-10-28/OSOS_speakable_mainapp_vtable_code_refs_20261028.log`.

Nächster statischer Schritt: den Objekt-/Taskpfad finden, der die Tabelle
`0x084f7558` tatsächlich instanziiert und registriert, und separat die
Laufzeit-VTable des Receivers von `FUN_0805f86a` sichern. Bis dahin bleibt
der Speakable-Befund ein kontrollflussrelevanter Kandidat mit offener
Erreichbarkeit, kein bestätigter Exploit oder untethered Bootpfad.

## Nachtrag 28.10 – Prüfung des VTable-Kandidaten und Notes-Ereignistabelle

### MainApp-Startpfad zum CacheInfo-Parser

Der direkte Parseraufruf lässt sich nun bis zum MainApp-Startobjekt
zurückverfolgen. `FUN_080202d8` wird als MainApp-Task-Entry gestartet; es
ruft `FUN_08023670` auf und dispatcht danach über dessen VTable-Slot
`+0x16c`. `FUN_08023670` setzt die primäre VTable auf `0x084fc984`.
An deren Offset `+0x16c` beginnt die sekundäre Tabelle `0x084fcaf0`, deren
erster Eintrag `thumb_804fa58` ist. Diese Startmethode ruft über ihren Slot
`+0x17c` `FUN_0804d42c` auf. `FUN_0804d42c` ruft direkt
`FUN_0827ccfc(1)` auf und läuft damit im statisch belegten MainApp-
Startpfad in den CacheInfo-Parser. Danach folgen unter anderem
`FUN_0805f86a` und `FUN_0826d5fc`; Letztere ruft den Parser nochmals mit
Flag `0` auf. Der Parser ist damit nicht nur ein theoretischer Eventpfad,
sondern aus dem angelegten MainApp-Task erreichbar.

Auch die Reihenfolge der globalen Feldschreiber ist jetzt genauer:
`DAT_08020a84` ist `0x08553ce8`; `FUN_08020a7c` initialisiert die Elemente
`[6]` und `[7]` bei `0x08553cf0` und `0x08553cf4`. Der einzige direkte
Aufrufer in der XRef-Datenbank ist `FUN_0801e3a4`, der vor dem Start des
Tasks `MainAppTask` läuft. Seine Task-Entry-Konstante bei `0x0801e3dc` ist
`0x080202d9` (Thumb-Zeiger auf `FUN_080202d8`). `FUN_080202d8` ruft
anschließend `FUN_08023e90` auf; diese Funktion liest `[6]` als Tabelle
`0x08553a04`, `[7]` als Anzahl `24` und iteriert über die
Registrierungs-Callbacks. Das geschieht vor dem MainApp-Startmethodenpfad
und vor dem CacheInfo-Parse. Für `[6]`/`[7]` wurde nach diesem Parse kein
weiterer direkter statischer Schreiber gefunden; indirekte Schreibeffekte
der übrigen Aufrufe sind damit nicht ausgeschlossen.

Das schließt noch nicht den gefährlichen indirekten Sprung: `FUN_0809be74`
liegt im anderen Pfad `FUN_08058a6c -> FUN_08076810`. Der MainApp-Start
ruft `FUN_0805f86a`, nicht `FUN_08076810`; die Frage ist daher, ob der
MainApp-Start die manipulierten globalen Werte erhält und ob der
Dispatcherpfad später regulär ausgelöst wird. Diese beiden Punkte bleiben
offen.

Eine frühere Abfrage hatte bei `0x08022b84` Thumb-Code erzwungen und daraus
einen langen Konstruktor abgeleitet. Die unveränderte Ghidra-Datenbank
markiert diesen Einstieg im voreingestellten ARM-Modus zwar als fehlerhafte
Instruktion (`halt_baddata`), doch ein Rohscan nach relativen Branches fand
bei `0x08021010` einen Thumb-`BL` direkt auf `0x08022b84`. Thumb-Dekodierung
ab `0x08020fa8` ergibt außerdem einen zusammenhängenden Factory-Pfad mit
passenden `TMediaNowPlayingCntlr`-Klassennamen und konsistenter
Objektinitialisierung. Darin wird `FUN_08022b84` aufgerufen und sein
Rückgabewert bei Objektoffset `+0x38` gespeichert. Das stützt stark, dass
der Kandidat echter Thumb-Code ist, obwohl die gespeicherte Datenbank die
Instruktionsart nicht korrekt abbildet.

Die erzwungene Thumb-Dekodierung von `0x08022b84` zeigt den VTable-Store
`0x084f7558` und den Aufruf des zweiten Parameters als Callback. Das
Literal liegt bei `0x08022ef0`; zusätzlich übergibt die Factory den
Thumb-Zeiger `0x0802389d` auf `FUN_0802389c`, das 0x28 Byte reserviert und
`FUN_0802e060` aufruft. Der rohe Funktionszeiger `0x08022b85` selbst kommt
im Abbild nicht vor; der nachgewiesene direkte `BL` erreicht den Code ohne
solchen Tabellenzeiger.

Die damalige Bewertung zum fehlenden Start-/Laufzeit-Root war ein
Zwischenstand und wird durch den Nachtrag am Ende dieses Berichts korrigiert.
Der rohe Branchscan hatte den direkten Aufruf von `FUN_08020fa8` aus dem
Wrapper bei `0x0801e8f6` gefunden (`BL` bei `0x0801e902`), aber die
Registry-Referenz auf den Thumb-Zeiger `0x0801e8f7` und den MainApp-Aufruf
über die virtuelle Methode `FUN_0804faa0` noch nicht verbunden. Die Suche
nach `0x0801e900/0x0801e901` war für diesen registrierten Einstieg nicht
aussagekräftig: der Tabellenzeiger zeigt auf `0x0801e8f7`, nicht auf den
inneren Block `0x0801e900`.

Der Tabellen-Dump zeigt für den VTable-Slot `+0x180` an Adresse
`0x084f76d8` den Thumb-Zeiger `0x0816a463`. Erzwungene Thumb-Dekodierung
bei `0x0816a462` ergibt einen kleinen Getter:
`return *(uint32_t *)(*(uint32_t *)(this + 0x0c) + 4)`. Damit ist der Slot
für ein reguläres Objekt dieser Klasse konkret belegt; das ist für sich
kein gefährlicher Callback. Beim im vorigen Nachtrag beschriebenen
überlappenden `FolderBinning`-Layout kann der Parser den Slotinhalt jedoch
aus Element `[6]` beziehen. Ob dieser manipulierte Pfad im Gerät bis zum
`BX r1` erhalten bleibt, ist weiterhin offen.

Bestätigt bleibt außerdem der separate kürzere Initialisierungspfad:
`FUN_0804c1b4` schreibt `0x084f7558` in das Objekt und wird von
`FUN_08038eb8` direkt aufgerufen. `FUN_08038eb8` selbst hat im gespeicherten
XRef-Bestand keinen direkten Codeaufrufer; seine Adresse steht als
Tabelleneintrag bei `0x084f755c`. Das belegt die Verknüpfung innerhalb der
Tabelle, aber noch keine Aktivierung aus dem Startpfad.

Ein zunächst vielversprechender Verweis in der Notes-Umgebung führt zu
einer anderen Struktur: `FUN_08014600` initialisiert Ereigniscodes in
12-Byte-Datensätzen ab `0x08553a00`. Der Datensatz bei `0x08553a48` ordnet
dem Code `0x8700` den Callback `FUN_0801e90c` zu; dieser öffnet den Notes-
Dispatcher über `FUN_08021294`. Die Notes-Registrierung setzt jedoch die
VTable `0x085363c8`, nicht `0x084f7558`. Diese konkrete Ereignisroute
schließt daher die fehlende Erreichbarkeit des verdächtigen VTable-
Konstruktors nicht.

Zum damaligen Zeitpunkt war nur der Factory-internen Aufruf belegt. Die
Folgeanalyse unten schließt den Factory-Pfad vom MainApp-Task bis zur
Instanziierung des Controllers; der äußere Verweis auf die ARM-Startfunktion
und der konkrete Laufzeit-Dispatch bleiben gesonderte offene Punkte. Es wurde
kein Payload getestet und kein Gerät oder Flash angesprochen.

Belege dieser Runde liegen dauerhaft unter
`evidence/speakable-2026-10-28/`:
`OSOS_speakable_vtable_constructor_candidate_20261028.log`,
`OSOS_speakable_vtable_constructor_raw_refs_20261028.log`,
`OSOS_speakable_vtable_constructor_incoming_range_20261028.log`,
`OSOS_speakable_constructor_saved_functions_20261028.log`,
`OSOS_speakable_constructor_allocator_refs_20261028.log`,
`OSOS_speakable_candidate_raw_branch_scan_20261028.log`,
`OSOS_speakable_candidate_branch_thumb_decode_20261028.log`,
`OSOS_speakable_firewire_factory_thumb_decode_20261028.log`,
`OSOS_speakable_factory_raw_branch_scan_20261028.log`,
`OSOS_speakable_firewire_entry_raw_branch_scan_20261028.log`,
`OSOS_speakable_firewire_entry_raw_pointer_refs_20261028.log`,
`OSOS_speakable_factory_and_wrapper_bytewise_pointer_scan_20261028.log`,
`OSOS_speakable_factory_root_refs_20261028.log`,
`OSOS_speakable_factory_literal_values_20261028.log`,
`OSOS_speakable_factory_callback_0802389c_20261028.log`,
`OSOS_speakable_vtable_084f7558_full_20261028.log`,
`OSOS_speakable_vtable_slot180_target_decode_20261028.log`,
`OSOS_speakable_mainapp_parser_roots_20261028.log`,
`OSOS_speakable_mainapp_parser_callers_20261028.log`,
`OSOS_speakable_mainapp_vtable_full_20261028.log`,
`OSOS_speakable_mainapp_constructor_vtable_literals_20261028.log`,
`OSOS_speakable_mainapp_start_methods_20261028.log`,
`OSOS_speakable_mainapp_start_slot16c_thumb_decode_20261028.log`,
`OSOS_speakable_mainapp_launch_helpers_20261028.log`,
`OSOS_speakable_global_field_write_functions_20261028.log`,
`OSOS_speakable_global_writer_roots_20261028.log`,
`OSOS_speakable_task_and_startup_writers_20261028.log`,
`OSOS_speakable_early_field_writer_context_20261028.log`,
`OSOS_speakable_event_table_base_literal_20261028.log`,
`OSOS_speakable_notes_table_root_20261028.log`,
`OSOS_speakable_notes_table_consumer_20261028.log`,
`OSOS_speakable_notes_factory_vtable_link_20261028.log` und die zugehörigen
Skripte im Unterordner `scripts/`. Die Rohscanner
`scripts/scan_arm_branch_targets.py` und `scripts/scan_raw_pointer_bytes.py`
markieren Branch-Treffer ausdrücklich als zu prüfende Rohmuster; die
Bestätigung des Aufrufs stammt aus der zusätzlichen Thumb-Dekodierung. Der
Bericht enthält keine `/tmp`-Pfade.
Die wiederöffnungsfähige Ghidra-Projektablage liegt unter
`/home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis/`;
das Eingabeabbild liegt unter
`/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin`
und hat SHA-256
`1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`.

Nächster statischer Schritt: die indirekten Methoden in `FUN_08076810` auf
Schreibzugriffe auf `FolderBinning[5..7]` prüfen, die Sender-/Zustandswerte
für den internen Eventtyp `0x12` weiter eingrenzen und nach einem vorhandenen
OSOS-Dateilader suchen, der einen erreichbaren Kontrollfluss-Sprung für
einen Rockbox-Start nutzbar machen könnte. Der `BX r1`-Pfad ist noch kein
End-to-End-Nachweis und kein bestätigter Untethered-Bootpfad.

## Nachtrag 28.10 – MainApp-Factory-Root und Event-Gate

### Korrektur der zuvor offenen Factory-Erreichbarkeit

Die MainApp-Kette erreicht die Factory-Tabelle statisch:

- `arm_83534e8 -> arm_8354ba8 -> FUN_0801d594 -> FUN_0801e3a4` startet
  `MainAppTask` mit Entry `0x080202d9` (`FUN_080202d8`, Thumb).
- `FUN_080202d8` ruft `thumb_804fa58` über den MainApp-VTable-Slot `+0x16c`
  auf. `thumb_804fa58` ruft unmittelbar danach Slot `+0x170`, dessen Eintrag
  bei `0x084fcaf4` der Thumb-Zeiger `0x0804faa1` auf `FUN_0804faa0` ist.
- `FUN_0804faa0` durchläuft die 24 Einträge ab `0x08553a04` mit Stride
  `0x0c` und ruft pro Eintrag den dritten 32-Bit-Wert bei `+8` auf. Der
  Eintrag 9 beginnt bei `0x08553a70`; sein drittes Wort bei `0x08553a78`
  ist `0x0801e8f7`, der Thumb-Zeiger auf `FUN_0801e8f6`.
- `FUN_0801e8f6` reserviert `0x104` Byte und ruft `FUN_08020fa8` auf.
  Diese Factory baut `TMediaNowPlayingCntlr`; ihr `BL` bei `0x08021010`
  erreicht `FUN_08022b84`, das die VTable `0x084f7558` in das Kindobjekt bei
  Parent-Offset `+0x38` schreibt. `FUN_0804faa0` hängt das Factory-Ergebnis
  an die MainApp-Objektliste und übergibt es an die Registry-Helfer.
- Der zweite Tabellenwert bei `0x08553a74` ist `0x0801e909` und dekodiert
  als `BX LR`. Dieser No-op wird von `FUN_08023e90` als Callback an `+4`
  aufgerufen; er ist nicht die Factory. Die Factory steht getrennt im dritten
  Wort `+8` und wird später von `FUN_0804faa0` aufgerufen.

Damit ist die statische Instanziierung des Controllers im MainApp-Task
belegt. Die übergeordnete ARM-Funktion `arm_83534e8` hat im Runtime-Dump
keinen internen Ghidra-XRef, rohen Funktionszeiger oder direkten Branch als
Caller. Der Übergang vom externen OSOS-Startmechanismus zu dieser Funktion
bleibt deshalb offen. Ebenso ist die konkrete Laufzeit-Auslösung des
Controller-Eventhandlers nicht durch Gerätedaten bestätigt.

### Erreichbarer Eventzweig und verbleibende Bedingungen

`FUN_08038d38` ist als Methode in der VTable `0x084f7558` enthalten. Bei
Eventtyp `0x12` vergleicht es den Sender mit `this + 0x794 + 0x84` und ruft
bei Übereinstimmung `FUN_0804bd38` auf. `FUN_0804bd38` überspringt den
Speakable-Zweig, falls das Byte bei `this+0x8e1` den Wert `','` hat. Andernfalls
ruft es `FUN_08058a6c`, wenn der globale Zeiger bei `0x08550adc` null ist
oder das Byte bei `*(0x08550adc)+0x20` gesetzt ist. Der statische Dump zeigt
für `0x08550adc` zunächst null; zwei Codepfade können den Wert setzen bzw.
löschen. Der tatsächliche Wert und das Vorliegen eines Eventtyps `0x12` im
Gerät bleiben Laufzeitfragen.

Der Speakable-Zweig ruft `FUN_0827ccfc(1)` und danach
`FUN_08076810 -> FUN_0809be74` auf. `FUN_0809be74` prüft nur, ob der Wert
`FolderBinning[5]` ungleich null ist, und dispatcht dann über den VTable-Slot
`+0x180`. Weil `[5]`, `[6]` und `[7]` benachbarte 32-Bit-Werte sind, ergibt
sich bei unveränderten Parserwerten die statische Alias-Konstellation:

1. `[5] = 0x08553cf0` zeigt auf das globale Element `[6]`.
2. `[6] = 0x08553b74` wird als VTable-Zeiger gelesen; `0x08553b74 + 0x180`
   ist die Adresse von `[7]` (`0x08553cf4`).
3. Der Wert `[7]` wird als indirektes Sprungziel geladen und mit `BX r1`
   angesprungen.

Das ist ein kontrollierter indirekter Sprung, falls der `CacheInfo.plist`-
Parser diese Werte annimmt, sie bis zum Eventpfad erhält und der Eventzweig
ausgeführt wird. Es ist noch kein Gerätetest und kein Beleg, dass ein
geeigneter Rockbox-Lader oder eine lauffähige Payload erreichbar ist.

Eine weitere statische Gegenprüfung grenzt den unmittelbaren Nachlauf ein:
Die direkten Referenzen auf `[6]`/`[7]` bei `0x08553cf0/0x08553cf4` stammen
aus der Tabelleninitialisierung und den beiden 24-Zeilen-Loops vor dem
CacheInfo-Parse. Die direkt nach dem Parser aufgerufene Methode
`FUN_08291556` liest diese Felder nicht. Für `[5]` ist neben dem frühen
Defaultschreiber `FUN_0802daf4` kein späterer direkter statischer Schreiber
gefunden; Parser- und virtuelle Nebenwirkungen sind damit nicht
ausgeschlossen. Der Integer-Konverter liefert gültige 32-Bit-Ergebnisse,
auch für negative Eingaben. Bei positivem Überlauf liefert der innere
Konverter `0xffffffff`; ein negatives Vorzeichen wird in der umgebenden
Routine anschließend angewendet. Eine `FolderBinning`-fachliche
Adressbereichsprüfung ist im Parser nicht sichtbar.

Die neue Beleggruppe liegt persistent unter
`evidence/speakable-2026-10-28/`:

- `README.md` (persistenter Ablageort, Eingabeabbild und Prüfbefehl)
- `SHA256SUMS` (Manifest für die Belege, Skripte, diese README und diesen
  Bericht)
- `OSOS_speakable_startup_child_factory_and_dispatch_roots_20261028.log`
- `OSOS_speakable_child_registry_event_dispatch_helpers_20261028.log`
- `OSOS_speakable_event_gate_and_state_flow_followup_20261028.log`
- `OSOS_speakable_mainapp_entry_and_state_global_xrefs_20261028.log`
- `OSOS_speakable_mainapp_task_bootstrap_and_gate_writers_20261028.log`
- `OSOS_speakable_boot_entry_and_folderbinning_runtime_path_20261028.log`
- `OSOS_speakable_mainapp_coldstart_root_chain_20261028.log`
- `OSOS_speakable_bootstrap_raw_pointer_scan_20261028.log`
- `OSOS_speakable_bootstrap_raw_branch_scan_20261028.log`
- `OSOS_speakable_registry_registration_initializer_followup_20261028.log`
- `OSOS_speakable_registry_actual_callback_decode_20261028.log`
- `OSOS_speakable_controlled_global_fields_and_integer_parser_20261028.log`
- `OSOS_speakable_postparse_global_readers_context_20261028.log`
- `OSOS_speakable_event_sender_offset_scalar_scan_20261028.log`

Die fehlerhafte erste Sammelausgabe wurde nicht verworfen: Sie ist als
`OSOS_speakable_factory_registry_mainapp_loop_followup_20261028.log.gz`
komprimiert archiviert und mit einer Warnnotiz in der gleichnamigen `.log`
gekennzeichnet; die gezielten, gültigen Folgeabfragen stehen in der oben
genannten Beleggruppe. Alle neuen Belege und Skripte liegen auf dem
persistenten Dateisystem im Repository; `/tmp` wurde dafür nicht verwendet.
