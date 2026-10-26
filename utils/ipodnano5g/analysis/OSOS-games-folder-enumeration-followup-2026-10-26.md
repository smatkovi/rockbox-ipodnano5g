# OSOS: Games-Ordner-Suche und `TEAppShell`-Erreichbarkeit

Stand: 26.10.2026. Untersucht wurde ausschließlich das lokale OSOS-Runtime-Abbild
in einem duplizierten Ghidra-Projekt mit `-noanalysis -readOnly`. Das Abbild ist
bei `0x08000000` gemappt. Es gab keinen Geräte-, USB-, DFU-, Boot- oder
Flashzugriff.

## Verifizierte Zuordnung

Die Daten bei `0x084f5920` beginnen mit einem Typinfozeiger auf `0x084e9f8c`;
das Typinfoobjekt verweist auf den Namen `10TEAppShell` bei `0x084ed8b3`.
Der VTable-Bereich beginnt bei `0x084f5924`. Der Eintrag bei `0x084f59d0`
enthält den Thumb-Zeiger `0x08028255`, also die Methode bei `0x08028254`.
Der Abstand zwischen VTable-Beginn und diesem Eintrag beträgt `0xac` Byte.
Das verbindet die Methode belastbar mit `TEAppShell`. Der virtuelle Aufrufpfad
ist im Nachtrag weiter unten dokumentiert; seine normale Laufzeitausführung
bleibt wegen eines Nullslots widersprüchlich.

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

`FUN_081965fe` verwirft leere Namen. Für die übrigen Einträge ruft der Code
`FUN_0804de7c` auf. Diese Funktion reserviert einen 4-Byte-Knoten und speichert
darin den laufenden Integerindex; sie kopiert weder den Namen noch einen
Dateiinhalt. In der untersuchten Enumerator-Schleife gibt es keinen Zugriff auf
`Manifest.plist`, `.sinf` oder den eApp-Parser `FUN_080f0f18`.

Damit ist eine Verzeichnisaufzählung während der Ausführung dieser
`TEAppShell`-Methode bestätigt. Ein automatischer Aufruf des Manifest-Parsers
folgt daraus nicht. Der statische MainApp-Lifecycle zielt auf diese Methode;
wegen des nullen Kind-Slots `+0xa4` im vorangehenden Dispatcher bleibt aber
ungeklärt, ob die Kette im normalen Kaltstart tatsächlich bis zum Games-Scan
läuft.

## Verbindung zum Kaltstart

Die statischen Code-Xrefs zu `FUN_081af8bc` zeigen vier direkte Aufrufe, alle
aus `TEAppShell`-Methoden bei `0x080281a8`, `0x080281ce`, `0x080282f8` und
`0x08028556`. Für `FUN_08028254` gibt es keinen direkten Codeaufrufer; der
Rohzeiger ist VTable-Eintrag `0x084f59d0` (`+0xac`). Ein direkter Aufrufgraph
ab `FUN_080202d8` erreicht die Methode nicht, weil er virtuelle Aufrufe nicht
auflöst.

Die VTable-Verfolgung fand den indirekten statischen Pfad:
`FUN_080202d8` → MainApp-VTable `+0x16c` → `FUN_0804fa58`; dessen `+0x178`
ruft `FUN_082d9d38`, das den `+0xac`-Slot jedes Kinds aufruft. Factory-Zeile
16 (`0xa080`) erzeugt `TEAppShell`, sodass dieser Pfad zu `FUN_08028254`
führen würde. Im vorherigen Callback `FUN_082d9d9c` wird aber jedes Kind auch
über `+0xa4` aufgerufen, und dieser Slot ist in der `TEAppShell`-VTable null.
Weil `FUN_082d9d9c` keinen Nulltest hat, widerspricht diese Kette einem
erfolgreichen normalen OS-Start. Der virtuelle Pfad ist statisch rekonstruiert,
seine konfliktfreie Laufzeitausführung bleibt offen.

`FUN_0803b520` registriert über `FUN_0804933c` unter anderem `TCGamesMenu`,
`TCGameScreen` und `TCGameControls` bei einem UI-Factory-Dienst. Der statische
MainApp-Pfad erreicht diese Registrierung über `FUN_082d9d9c` und den Root-
VTable-Slot `+0xa4`; der frühere direkte Aufrufgraph übersah diese virtuelle
Kante. Das belegt Factory-Registrierung, nicht die Instanziierung eines Screens
oder das automatische Starten eines Games. Die separate Manifest-/eApp-Kette
ist damit weiterhin nicht verbunden.

Die Game-UI-Ereignisse zeigen ebenfalls eine indirekte Grenze: `FUN_080b60f0`
baut eine `LaunchGame`-Nachricht, während `FUN_080cdc70` und `FUN_080cde24`
`ExecuteGame`-Nachrichten bauen. Alle drei geben die Nachricht über einen
virtuellen Empfänger bei VTable-Offset `+0x15c` weiter. `FUN_080cde24` ist
zustandsabhängig: Im Zustand 1 verarbeitet sie Controls, in Zustand 2 kann sie
zuerst `GotoGameRunningLayout` anfordern, und im Zustand 3 sendet sie
`ExecuteGame`. Die konkrete Empfängerregistrierung ist nicht aufgelöst; aus
diesen Produzenten gibt es keinen statischen Aufruf zu `FUN_080f0f18` oder
`FUN_08102f64`. Das stützt einen UI-/Lifecycle-Pfad, beweist aber keine
automatische Parserausführung beim Kaltstart; zusätzlich gilt die
Nullslot-Einschränkung aus dem Nachtrag.

## Bewertung und nächste statische Schritte

Der neue Befund bestätigt einen persistenten Games-Verzeichnispfad und einen
Scan beim Aufruf der `TEAppShell`-Initialisierung. Er bestätigt weder einen
unsicheren Manifest-Parserlauf noch Speicherfehler, Codeausführung,
Authentifizierungs-Bypass oder Rockbox-Handoff. Ein OSOS-Laufzeitfehler, der
Rockbox nach jedem Kaltstart startet, ist damit weiterhin nicht gefunden.

Die Factory-Erzeugung und virtuelle Dispatchkette sind statisch aufgefunden;
offen bleiben die Ursache der Nullslot-Diskrepanz, der Empfänger von
`ExecuteGame` bei `+0x15c` und die Laufzeitverbindung zum
`eAppMotor::loadApp`-Pfad. Als Nächstes ist die Abbildidentität gegen die auf
dem Gerät verwendete OSOS-Version zu prüfen. Ein Live-Trace zur Bestätigung der
Laufzeitkante ist erst möglich, wenn das Gerät wieder verfügbar ist.

Rohbelege (temporäre Exporte):

- `/tmp/OSOS_TAppShell_method_08028254_20261026.txt`
- `/tmp/OSOS_games_path_helpers_20261026.txt`
- `/tmp/OSOS_games_eapp_dispatch_xrefs_20261026.log`
- `/tmp/OSOS_TAppShell_mainapp_reach_20261026.txt`
- `/tmp/OSOS_TAppShell_creator_08028614_20261026.txt`
- `/tmp/OSOS_games_typeinfo_20261026.txt`
- `/tmp/OSOS_games_class_vtable_words_20261026.txt`
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
`0x084f5924` von `TEAppShell` an den Objektanfang. Deren Eintrag `+0xa4` ist
null, `+0xa8` zeigt auf den `bx lr`-No-op `FUN_080ee9cc`, und `+0xac` zeigt auf
`FUN_08028254`.

Slot `+0x174` ist `FUN_082d9d9c`. Er ruft auf dem MainApp-Objekt zuerst
`+0xa8`, dann `+0xa4` auf; der zweite Aufruf landet bei `FUN_0803b520`, die
Controller und über `FUN_0804933c` auch UI-/Games-Fabriken registriert. Danach
iteriert dieselbe Funktion die Elemente bei `MainApp+0x34` und ruft auf jedem
Kind unbedingte virtuelle Slots `+0xa4` und `+0xa8` auf. Slot `+0x178` ist
`FUN_082d9d38`; der zweite Durchlauf ruft auf Root und Kindern Slot `+0xac`
auf. Für ein `TEAppShell`-Kind wäre das `FUN_08028254`, also der oben
beschriebene Games-Ordnerscan.

Damit ist der statische virtuelle Aufrufpfad zur UI-/Games-Registrierung
belegt; die frühere Aussage, diese Registrierung sei im MainApp-Startpfad
nicht erreicht, war falsch. Auch die statische Kante zum `TEAppShell`-Scan ist
jetzt gefunden. Es gibt jedoch einen ungelösten Widerspruch: Das `TEAppShell`-
Kind wird laut Factory- und Containerpfad in `MainApp+0x34` eingefügt, aber der
vorherige Durchlauf `FUN_082d9d9c` würde auf seinem nullen Slot `+0xa4`
unbedingt `blx 0` ausführen. Das passt nicht zu einem normalen, erfolgreich
startenden iPod-OS. In der Offline-Referenzsuche wurde kein direkter Verweis auf
die Speicheradresse des nullen VTable-Eintrags gefunden; das schließt eine
indirekte Laufzeitänderung oder ein abweichendes Runtime-Abbild nicht aus.

Folglich ist der statische Dispatchpfad belegt, seine tatsächliche Ausführung
im normalen Kaltstart aber nicht widerspruchsfrei bestätigt. Weiterhin nicht
belegt sind ein automatischer Manifest-/eApp-Parserlauf, eine RCE, ein
Signatur-Bypass oder ein Rockbox-Handoff. Als Nächstes muss die Nullslot-
Diskrepanz durch Prüfung der Runtime-Abbildidentität bzw. einen späteren
Laufzeittrace aufgelöst werden; bis das Gerät wieder verfügbar ist, erfolgt
keine Geräteaktion.

Rohbelege: `/tmp/OSOS_mainapp_bootstrap_verification_20261026.txt`,
`/tmp/OSOS_mainapp_init_callbacks_20261026.txt`,
`/tmp/OSOS_factory_a080_callback_0801e230_20261026.txt`,
`/tmp/OSOS_TAppShell_constructor_return_20261026.txt`,
`/tmp/OSOS_TAppShell_nested_ctor_return_20261026.txt`,
`/tmp/OSOS_TAppShell_a4_slot_writes_20261026.txt`,
`/tmp/OSOS_TMPSystemApp_followup_callbacks_20261026.txt` und
`/tmp/OSOS_mainapp_plus_a8_and_related_20261026.txt`. Ghidra lief mit
`-noanalysis -readOnly` auf der Offline-Kopie; keine Geräte-, USB-, DFU-, Boot-
oder Flashaktion.
