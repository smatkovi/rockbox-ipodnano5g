# OSOS: Games-Ordner-Suche und `TEAppShell`-Erreichbarkeit

Stand: 26.10.2026. Untersucht wurde ausschließlich das lokale OSOS-Runtime-Abbild
in einem duplizierten Ghidra-Projekt mit `-noanalysis -readOnly`. Das Abbild ist
bei `0x08000000` gemappt. Es gab keinen Geräte-, USB-, DFU-, Boot- oder
Flashzugriff.

## Verifizierte Zuordnung

Die Daten bei `0x084f5920` beginnen mit einem Typinfozeiger auf `0x084e9f8c`;
das Typinfoobjekt verweist auf den Namen `10TEAppShell` bei `0x084ed8b3`.
Der VTable-Bereich beginnt bei `0x084f5924`. Der Eintrag bei `0x084f59cc`
enthält den Thumb-Zeiger `0x08028255`, also die Methode bei `0x08028254`.
Der Abstand zwischen VTable-Beginn und diesem Eintrag beträgt `0xa8` Byte.
Slot `+0xa4` zeigt auf den No-op `FUN_080ee9cc`; Slot `+0xac` ist ebenfalls
ein No-op (`FUN_080dc098`). Der virtuelle Aufrufpfad ist im Nachtrag
dokumentiert.

`0x08028254` initialisiert mehrere Felder des übergebenen Objekts. Dabei setzt
es das Byte bei `+0x9c` auf null, ruft `FUN_081af972` auf und anschließend
`FUN_081af8bc`. Danach folgen zwei weitere Methoden für die Teilobjekte bei
`+0x60` und `+0x7c`.

## Was der Games-Enumerator tut

`FUN_081af8bc` kehrt zurück, wenn das Byte `param+0x9c` bereits gesetzt ist;
sonst markiert es den Scan als erledigt. Es richtet zwei Verzeichniseinträge
über die Provider-Tabelle bei `DAT_081af94c` ein. Die zugehörigen Pfadreferenzen
sind `iPod_Control/games_RO/` (`0x0853c297`) und
`Resources/Games/games_RO/` (`0x0853c2ae`). Anschließend iteriert es mit
`FUN_0819cbe4` und `FUN_0819cc0a` über die Einträge.

`FUN_081965fe` verwirft leere Namen. Die anschließende Cache-Schleife ruft für
die übrigen Einträge `FUN_0804de7c` auf. Diese Funktion reserviert einen
4-Byte-Knoten und speichert darin den laufenden Integerindex; diese Schleife
kopiert weder Namen noch Dateiinhalt.

Vor dieser Index-Cache-Schleife ruft `FUN_081af8bc` jedoch zweimal
`FUN_081b343c` auf. Diese Funktion iteriert die Einträge beider Provider,
bildet für jeden passenden Unterordner den Pfad `Manifest.plist` und ruft
`FUN_08055f50` auf. Dort wird der Manifest-Pfad über `FUN_082526ca` geladen
und über `FUN_080df874` an den XML-/Property-List-Parser übergeben. Die
festen Daten bei `0x0853c2da` enthalten die Zeichenfolge `Manifest.plist`;
Referenzen darauf liegen in `FUN_081b343c` und `FUN_08055f50`.

Für diesen Katalogpfad setzt `FUN_08055f50` das zweite Parameterfeld des
Parserdeskriptors auf null. `FUN_082526ca` ruft den optionalen Prüfschritt
`FUN_08102140` nur auf, wenn dieses Feld ungleich null ist. Der automatische
Kataloglauf prüft damit in diesem Aufruf keine `.p7b`-Sidecar-Datei. Er
extrahiert Manifest-Metadaten und registriert Spieleinträge; er lädt dadurch
weder das eApp-Binary noch startet er ein Spiel. Das ist getrennt vom späteren
`FUN_080f0f18`-/`eAppMotor::loadApp`-Pfad.

Der statische MainApp-Lifecycle erreicht `TEAppShell::FUN_08028254` im ersten
Child-Dispatch über Slot `+0xa8`: Der vorangehende Kind-Slot `+0xa4` zeigt auf
einen `bx lr`-No-op. Damit sind sowohl Verzeichnisaufzählung als auch
Manifest-Metadatenparser Teil des statischen Kaltstartpfads.

## Parseroptionen und Katalogobjekt

`FUN_080df874` startet den XML-Reader über `FUN_081d7254`; dieser richtet ihn
über `FUN_082bf67c` ein. Im untersuchten Manifest-Aufruf werden keine
zusätzlichen Parserflags übergeben; `FUN_082bf67c` ergänzt intern stets
`0x10000`. Die aktuelle libxml2-Dokumentation ordnet diesen Wert
`XML_PARSE_COMPACT` zu ([Optionsreferenz](https://gnome.pages.gitlab.gnome.org/libxml2/html/parser_8h.html)). Das ist eine Referenz zum Flag, aber kein Nachweis der
eingebetteten libxml2-Version oder ihrer globalen Defaults. In diesem Aufruf
sind keine expliziten Optionen zum Laden von DTDs oder zur Entity-Substitution
gesetzt; das tatsächliche Verhalten der eingebetteten Bibliothek ist nicht
vollständig aufgelöst.

`FUN_080597b2` baut aus den geparsten Feldern ein dynamisches Katalogobjekt.
`FUN_0825e954` ermittelt die Elementzahl `n` eines 16-Byte-Arrays aus
`(Ende - Anfang) >> 4`. Der Caller ruft `FUN_08252762(0)` auf; das liefert eine
Mindestkapazität von 32. Danach reserviert er `max(n, 32) * 0x10` Byte und
`FUN_082528c0` kopiert die `n` Elemente. Für die Multiplikation ist keine
separate Überlaufprüfung sichtbar. Die Quelldatei ist jedoch auf `0x20000` Byte
begrenzt; ein Überlauf ist aus einer normalen, direkt serialisierten Liste
nicht hergeleitet. Entity-Amplifikation und die exakten Limits der
eingebetteten XML-Bibliothek sind offen. Das ist ein Prüfpunkt, kein bestätigter
Speicherfehler.

## Verbindung zum Kaltstart

Die statischen Code-Xrefs zu `FUN_081af8bc` zeigen vier direkte Aufrufe, alle
aus `TEAppShell`-Methoden bei `0x080281a8`, `0x080281ce`, `0x080282f8` und
`0x08028556`. Für `FUN_08028254` gibt es keinen direkten Codeaufrufer; der
Rohzeiger ist VTable-Eintrag `0x084f59cc` (`+0xa8`). Ein direkter Aufrufgraph
ab `FUN_080202d8` erreicht die Methode nicht, weil er virtuelle Aufrufe nicht
auflöst.

Die VTable-Verfolgung fand den indirekten statischen Pfad:
`FUN_080202d8` → MainApp-VTable `+0x16c` → `FUN_0804fa58`; dessen `+0x178`
ruft `FUN_082d9d38`, das den `+0xac`-Slot jedes Kinds aufruft. Der Games-Scan
liegt eine Phase früher: `+0x174` dispatcht `FUN_082d9d9c`, das auf jedem Kind
`+0xa4` und danach `+0xa8` aufruft. Factory-Zeile 16 (`0xa080`) erzeugt
`TEAppShell`; sein `+0xa4`-Slot ist der No-op `FUN_080ee9cc`, gefolgt von
`FUN_08028254` an `+0xa8`. Damit ist die statische Kaltstarterreichbarkeit des
Games-Scans belegt. Der zweite Dispatcher nutzt `+0xac` (`FUN_080dc098`, No-op).

`FUN_0803b520` registriert über `FUN_0804933c` unter anderem `TCGamesMenu`,
`TCGameScreen` und `TCGameControls` bei einem UI-Factory-Dienst. Der statische
MainApp-Pfad erreicht diese Registrierung über `FUN_082d9d9c` und den Root-
VTable-Slot `+0xa4`; der frühere direkte Aufrufgraph übersah diese virtuelle
Kante. Das belegt Factory-Registrierung, nicht die Instanziierung eines Screens
oder das automatische Starten eines Games. Der Manifest-Metadatenparser ist
über den statischen `TEAppShell`-Lifecyclepfad erreichbar; die separate
`eAppMotor::loadApp`-Kette ist damit weiterhin nicht erreicht.

Die Game-UI-Ereignisse zeigen ebenfalls eine indirekte Grenze: `FUN_080b60f0`
baut eine `LaunchGame`-Nachricht, während `FUN_080cdc70` und `FUN_080cde24`
`ExecuteGame`-Nachrichten bauen. Alle drei geben die Nachricht über einen
virtuellen Empfänger bei VTable-Offset `+0x15c` weiter. `FUN_080cde24` ist
zustandsabhängig: Im Zustand 1 verarbeitet sie Controls, in Zustand 2 kann sie
zuerst `GotoGameRunningLayout` anfordern, und im Zustand 3 sendet sie
`ExecuteGame`. Die konkrete Empfängerregistrierung ist nicht aufgelöst; aus
diesen Produzenten gibt es keinen statischen Aufruf zu `FUN_080f0f18` oder
`FUN_08102f64`. Der automatische Kataloglauf parst zwar Manifest-Metadaten,
belegt aber weder eApp-Laden noch Spielstart.

## Bewertung und nächste statische Schritte

Der neue Befund bestätigt einen persistenten Games-Verzeichnispfad und einen
automatischen `Manifest.plist`-Metadatenparser beim Aufruf der
`TEAppShell`-Initialisierung. Er bestätigt weder einen Speicherfehler in
diesem Parser noch Codeausführung, Authentifizierungs-Bypass oder Rockbox-
Handoff. Ein OSOS-Laufzeitfehler, der Rockbox nach jedem Kaltstart startet,
ist damit weiterhin nicht gefunden.

Die Factory-Erzeugung und virtuelle Dispatchkette bis zum
Manifest-Metadatenparser sind statisch belegt. Offen bleiben Speicherfehler
oder Parser-Exploits im XML-Pfad, die konkrete Schreibbarkeit der N5G-
`iPod_Control/games_RO`-Quelle auf diesem Gerät, der Empfänger von
`ExecuteGame` bei `+0x15c` und die Laufzeitverbindung zum
`eAppMotor::loadApp`-Pfad. Als Nächstes sind Parsergrenzen,
Callback-/Containerwachstum und Mount-/Schreibpfad von `games_RO` zu prüfen.

Ein öffentliches Preservation-Projekt beschreibt für Nanos das manuelle
Kopieren von Quizdaten nach `iPod_Control/Games_RO/11004/UserTrivia/Packs/`.
Das stützt, dass zumindest Spiele-Daten auf dem persistenten Volume hostseitig
verändert werden können. Es belegt weder das Ersetzen des automatisch
geparsten `Manifest.plist` noch die Schreibbarkeit dieses konkreten Geräts
([Installationshinweise](https://github.com/Olsro/ipodclickwheelgamespreservationproject/blob/main/iQuiz/README.md)).

Rohbelege (temporäre Exporte):

- `/tmp/OSOS_TAppShell_method_08028254_20261026.txt`
- `/tmp/OSOS_games_path_helpers_20261026.txt`
- `/tmp/OSOS_games_eapp_dispatch_xrefs_20261026.log`
- `/tmp/OSOS_TAppShell_mainapp_reach_20261026.txt`
- `/tmp/OSOS_TAppShell_creator_08028614_20261026.txt`
- `/tmp/OSOS_games_typeinfo_20261026.txt`
- `/tmp/OSOS_games_class_vtable_words_20261026.txt`
- `/tmp/OSOS_games_provider_boundary_20261026.txt`
- `/tmp/OSOS_games_manifest_startup_parser_20261026.txt`
- `/tmp/OSOS_games_manifest_parser_helpers_20261026.txt`
- `/tmp/OSOS_games_plist_xml_engine_20261026.txt`
- `/tmp/OSOS_games_xml_event_callbacks_20261026.txt`
- `/tmp/OSOS_games_plist_tree_builder_20261026.txt`
- `/tmp/OSOS_games_parser_setup_20261026.txt`
- `/tmp/OSOS_games_parser_option_wrappers_20261026.txt`
- `/tmp/OSOS_games_parser_option_setter_20261026.txt`
- `/tmp/OSOS_games_manifest_alloc_followup_20261026.txt`
- `/tmp/OSOS_games_registration_function_20261026.txt`
- `/tmp/OSOS_games_launch_callbacks_20261026.txt`
- `/tmp/OSOS_game_action_string_callers_20261026.txt`

## Korrektur/Nachtrag: MainApp-VTable und `TEAppShell`-Dispatch (26.10.2026)

Die frühere Zuordnung von `FUN_080202d8` zu einem No-op bei `+0x16c` war ein
VTable-Offsetfehler. Der Konstruktor `FUN_08023670` setzt die VTable-Adresse
`0x084fc984`; deren Eintrag bei `+0x16c` ist `0x0804fa59`, also
`FUN_0804fa58`. Der No-op `FUN_0816c896` steht an einer anderen Tabellenposition
und wird hier nicht aufgerufen.

`FUN_0804fa58` ruft der Reihe nach Slots `+0x170`, `+0x174`, `+0x178`,
`+0x17c` und `+0x180` auf. Slot `+0x170` ist `FUN_0804faa0`: Die Funktion
iteriert die 24 Factory-Zeilen bei `0x08553a04`, ruft jede Callback-Adresse bei
Zeilenoffset `+8` auf und fügt den Rückgabewert in `MainApp+0x34` ein.
Zeile 16 (`0x08553ac4`, ID `0xa080`) ruft `FUN_0801e230` auf; diese allokiert
600 Byte und ruft `FUN_0801fca4` auf. Der Konstruktor schreibt die VTable
`0x084f5924` von `TEAppShell` an den Objektanfang. Deren Eintrag `+0xa4` zeigt
auf den `bx lr`-No-op `FUN_080ee9cc`, `+0xa8` auf `FUN_08028254` und `+0xac`
auf den `bx lr`-No-op `FUN_080dc098`.

Slot `+0x174` ist `FUN_082d9d9c`. Er ruft auf dem MainApp-Objekt zuerst
`+0xa8`, dann `+0xa4` auf; der zweite Aufruf landet bei `FUN_0803b520`, die
Controller und über `FUN_0804933c` auch UI-/Games-Fabriken registriert. Danach
iteriert dieselbe Funktion die Elemente bei `MainApp+0x34` und ruft auf jedem
Kind unbedingte virtuelle Slots `+0xa4` und `+0xa8` auf. Beim
`TEAppShell`-Kind ist `+0xa4` der No-op; `+0xa8` ruft `FUN_08028254` auf und
scannt die Games-Verzeichnisse. Slot `+0x178` ist `FUN_082d9d38`; der zweite
Durchlauf ruft auf Root und Kindern `+0xac` auf, hier jeweils einen No-op.

Damit ist der statische virtuelle Aufrufpfad zur UI-/Games-Registrierung
belegt; die frühere Aussage, diese Registrierung sei im MainApp-Startpfad
nicht erreicht, war falsch. Der Games-Ordnerscan liegt im ersten Lifecycle-
Durchlauf und ist über `TEAppShell::FUN_08028254` an Slot `+0xa8` gebunden. Die
Index-Cache-Schleife liest keine Manifeste; die davorliegenden Provider-
Callbacks parsen für passende Unterordner aber automatisch `Manifest.plist`
als Metadaten. In den bisher geprüften Pfad- und Callback-Wrappern ist kein
konkreter Out-of-bounds-Fehler erkennbar. Nicht geprüft ist der vollständige
libxml2-interne Code; dessen exakte Version und Parser-Defaults bleiben offen.
Weiterhin nicht belegt sind RCE, eApp-Ausführung, Signatur-Bypass oder
Rockbox-Handoff. Als Nächstes sind Parserlimits/Callbacks und die Schreibbarkeit
der persistenten N5G-Quelle zu untersuchen.

Rohbelege: `/tmp/OSOS_mainapp_bootstrap_verification_20261026.txt`,
`/tmp/OSOS_mainapp_init_callbacks_20261026.txt`,
`/tmp/OSOS_factory_a080_callback_0801e230_20261026.txt`,
`/tmp/OSOS_TAppShell_constructor_return_20261026.txt`,
`/tmp/OSOS_TAppShell_nested_ctor_return_20261026.txt`,
`/tmp/OSOS_TAppShell_a4_slot_writes_20261026.txt`,
`/tmp/OSOS_TAppShell_corrected_vtable_and_second_lifecycle_20261026.txt`,
`/tmp/OSOS_games_provider_boundary_20261026.txt`,
`/tmp/OSOS_games_manifest_startup_parser_20261026.txt`,
`/tmp/OSOS_games_xml_event_callbacks_20261026.txt`,
`/tmp/OSOS_TMPSystemApp_followup_callbacks_20261026.txt` und
`/tmp/OSOS_mainapp_plus_a8_and_related_20261026.txt`. Ghidra lief mit
`-noanalysis -readOnly` auf der Offline-Kopie; keine Geräte-, USB-, DFU-, Boot-
oder Flashaktion.

## Nachtrag: dateinamensabhängiger Manifest-Pfadaufbau (26.10.2026)

Der Kaltstart-Enumerator `FUN_081b343c` übernimmt Namen passender
Games-Unterordner aus dem Verzeichnisiterator und baut daraus Pfadobjekte für
`Manifest.plist`. Die zunächst auffälligen Stackobjekte sind String- und
Iteratorobjekte, keine festen C-Zielpuffer für den kompletten Pfad. Der
Formatierer `FUN_08196c00` verwendet einen 512-Byte-Stackpuffer und ruft
`FUN_08273378(dest, 0x200, format, args)` auf. Dieser begrenzt die Ausgabe auf
`0x1ff` Zeichen, bevor er den NUL-Terminator setzt. Der Ausgabe-Callback
`FUN_081ae28e` prüft den Zähler gegen diese Kapazität, bevor er ein Zeichen
schreibt. Der Formatstring wird aus statischen Daten gewählt; der
Verzeichnisname ist nur ein `%s`-Wert und kann keine Formatdirektiven
einschleusen.

Damit ergibt sich aus einem langen, datenträgerkontrollierten Unterordnernamen
kein Überlauf des 512-Byte-Stackpuffers. Der dynamische String wird über
`FUN_081936ec` in ein Stringobjekt kopiert. Das schließt Fehler in der
separaten XML-Bibliothek oder im FAT-LFN-Iterator nicht aus, bestätigt aber
keinen neuen RCE-Pfad im automatischen Manifest-Pfadaufbau. Der reale aktuelle
Volume-Root enthält kein `iPod_Control/games_RO`-Verzeichnis; dieser Befund
belegt nur den Ist-Zustand und nicht die Schreibbarkeit eines solchen Ordners.

Read-only-Ghidra-Ausgabe: `/tmp/OSOS_games_manifest_path_builder_followup_20261026.txt`.
Das bestehende Projekt wurde mit `-noanalysis -readOnly` abgefragt.

## Nachtrag: Materialisierung der Manifestfelder (26.10.2026)

Die automatische Manifestverarbeitung wurde vom XML-Ergebnis bis zu den
Katalogfeldern weiter geprüft. `FUN_08055f50` erhält den Feldkatalog aus
`FUN_08259b78`: Die Funktion wählt anhand der Hardwarekennung eine statische
Tabelle mit drei oder vier Einträgen. `FUN_08259bac` gleicht diese festen
Einträge mit den XML-Schlüsseln ab; die äußere Schleife läuft über diese
hardwareabhängige Anzahl und verwendet sie nicht als dateigesteuerten Index.

Die passenden Werte werden in Stringobjekte kopiert. Die Listen für
Manifestfelder und Katalogeinträge werden als dynamische 16-Byte- bzw.
40-Byte-Elemente geführt. `FUN_080597b2` reserviert die 16-Byte-Liste anhand
der geparsten Elementzahl und kopiert sie mit `FUN_082528c0`; der spätere
Merge `FUN_082570de` aktualisiert die gleiche dynamische Vektorstruktur.
`FUN_08255bc2` durchsucht die 40-Byte-Einträge vom Anfang bis zum gespeicherten
Endzeiger. In diesem Materialisierungspfad fand sich kein festes Stackziel,
das mit einem Manifestwert beschrieben wird, und kein dateikontrollierter
Schleifenindex in die hardwarefeste Feldtabelle.

Das schließt Fehler in libxml2, ungewöhnliche Parserzustände oder
Ressourcenerschöpfung nicht aus. Es bestätigt in den geprüften
Manifest-Callbacks aber keinen neuen festen Pufferüberlauf oder
Kontrollflussfehler. Die automatische Erreichbarkeit des Parsers bleibt
statisch belegt; ein Geräte-/Parserlauf wurde nicht ausgeführt.

Rohbelege: `/tmp/OSOS_games_vfs_method_bridge_20261026.txt`,
`/tmp/OSOS_games_manifest_startup_parser_20261026.txt`,
`/tmp/OSOS_games_manifest_parser_helpers_20261026.txt`,
`/tmp/OSOS_games_manifest_alloc_followup_20261026.txt` und
`/tmp/OSOS_games_provider_boundary_20261026.txt`. Ghidra-Abfragen liefen
read-only.

## Nachtrag: Manifest-Parseroptionen und Versionshinweis (27.10.2026)

Die Parseroptionen wurden im passenden Runtime-Ghidra-Projekt
`/tmp/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime` nachgeprüft. Der
Manifest-Pfad erreicht `FUN_082526ca` aus `FUN_08055f50`; bei diesem Aufruf ist
der optionale Sidecar-/Prüfpfadparameter null. `FUN_082526ca` übergibt die
Manifestdaten an `FUN_080df874`, das den Reader über `FUN_0826fee0` anlegt.
Der Reader-Aufruf übergibt keine zusätzlichen Optionsbits. `FUN_082bf67c`
ergänzt intern `0x10000` und leitet die Optionen an `FUN_082d3914` weiter.
Damit ist im untersuchten Aufruf kein explizites DTD-Laden oder Ersetzen von
Entities angefordert; die globalen Defaults und das Verhalten der konkreten
eingebetteten libxml2-Version bleiben offen.

Ein druckbarer Versionshinweis ließ sich im OSOS-Body nicht finden. Die
Strings `libxml2 built without HTML support` und ein Quellpfad zu
`LIBXML/xpath.c` belegen die Bibliothekszuordnung, aber keine Versionsnummer.
Eine vorherige Adressabfrage im Full-Body-Projekt wurde für diese Parserkette
nicht herangezogen: Die hier verifizierten Adressen stammen aus dem
Runtime-Projekt `osos_runtime_dram_20261025.bin`.

Das grenzt die Optionen dieses Manifest-Aufrufs ein, bestätigt aber weder
einen Speicherfehler in libxml2 noch sichere globale Parser-Defaults. Es gab
keinen XML-Lauf und keinen Gerätezugriff; ein RCE- oder Rockbox-Handoff ist
weiterhin nicht belegt.

Rohbelege:

- `/tmp/OSOS_manifest_xml_xref_runtime_20261027.txt`
- `/tmp/OSOS_manifest_xml_runtime_functions_20261027.txt`
- `/tmp/OSOS_games_parser_option_setter_20261026.txt`
- `/tmp/OSOS_games_plist_xml_engine_20261026.txt`
- `strings -a -n 5 /home/sebastian/ipod-re/nano5g/osos_decrypted/osos_body.bin`

Alle Ghidra-Abfragen nutzten `-readOnly -noanalysis`; es gab keinen
Geräte-, USB-, DFU-, Boot- oder Flashzugriff.
