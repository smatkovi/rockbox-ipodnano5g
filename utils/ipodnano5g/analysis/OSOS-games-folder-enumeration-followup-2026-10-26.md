# OSOS: Games-Ordner-Suche und `TEAppShell`-Erreichbarkeit

Stand: 26.10.2026. Untersucht wurde ausschließlich das lokale OSOS-Runtime-Abbild
in einem duplizierten Ghidra-Projekt mit `-noanalysis -readOnly`. Das Abbild ist
bei `0x08000000` gemappt. Es gab keinen Geräte-, USB-, DFU-, Boot- oder
Flashzugriff.

## Verifizierte Zuordnung

Die Daten bei `0x084f5920` beginnen mit einem Typinfozeiger auf `0x084e9f8c`;
das Typinfoobjekt verweist auf den Namen `10TEAppShell` bei `0x084ed8b3`.
Der VTable-Bereich beginnt bei `0x084f5924`. Sein Eintrag bei `0x084f59cc`
enthält den Thumb-Zeiger `0x08028255`, also die Methode bei `0x08028254`.
Der Abstand zwischen VTable-Beginn und diesem Eintrag beträgt `0xa8` Byte.
Das verbindet die Methode belastbar mit `TEAppShell`; ihre genaue
Laufzeitsemantik und ihr Aufrufer sind dadurch noch nicht bestimmt.

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
folgt daraus nicht. Die frühere offene Frage, ob der Games-Enumerator überhaupt
ausgeführt wird, ist präzisiert: Er wird ausgeführt, falls die Initialisierung
von `TEAppShell` erreicht wird; ob das im normalen Kaltstart geschieht, ist
weiterhin ungeklärt.

## Verbindung zum Kaltstart

Die statischen Code-Xrefs zu `FUN_081af8bc` zeigen vier Aufrufe, alle aus
`TEAppShell`-Methoden bei `0x080281a8`, `0x080281ce`, `0x080282f8` und
`0x08028556`. Für `FUN_08028254` gibt es keinen direkten Codeaufrufer; der
gefundene Rohzeiger ist der VTable-Eintrag `0x084f59cc`.

Ein direkter Aufrufgraph ab `FUN_080202d8` (MainApp-Initialisierung) erfasste
bei maximaler Tiefe 12 insgesamt 2.242 Funktionen. Er erreichte weder
`FUN_08028254`/`FUN_081af8bc` noch den Games-UI-Registrierer `FUN_0804933c`.
Dieser Graph folgt direkten Codeaufrufen und ist kein Beweis der
Unerreichbarkeit: virtuelle Aufrufe, Konstruktorregistrierung und externe
Laufzeit-/Overlay-Daten können die fehlende Kante erklären.

`FUN_0804933c` registriert unter anderem `TCGamesMenu`, `TCGameScreen` und
`TCGameControls` bei einem UI-Factory-Dienst. Das belegt die Factory-Registrierung,
nicht die Instanziierung des Screens beim Kaltstart. Die separate
Manifest-/eApp-Kette bleibt ohne bestätigte Verbindung zu dieser Registrierung
oder zu einem automatisch gestarteten Games-Eintrag.

Die Game-UI-Ereignisse zeigen ebenfalls eine indirekte Grenze: `FUN_080b60f0`
baut eine `LaunchGame`-Nachricht, während `FUN_080cdc70` und `FUN_080cde24`
`ExecuteGame`-Nachrichten bauen. Alle drei geben die Nachricht über einen
virtuellen Empfänger bei VTable-Offset `+0x15c` weiter. `FUN_080cde24` ist
zustandsabhängig: Im Zustand 1 verarbeitet sie Controls, in Zustand 2 kann sie
zuerst `GotoGameRunningLayout` anfordern, und im Zustand 3 sendet sie
`ExecuteGame`. Die konkrete Empfängerregistrierung ist nicht aufgelöst; aus
diesen Produzenten gibt es keinen statischen Aufruf zu `FUN_080f0f18` oder
`FUN_08102f64`. Das stützt einen UI-/Lifecycle-Pfad, beweist aber keine
Kaltstart-Erreichbarkeit und schließt einen dynamischen Callback nicht aus.

## Bewertung und nächste statische Schritte

Der neue Befund bestätigt einen persistenten Games-Verzeichnispfad und einen
Scan beim Aufruf der `TEAppShell`-Initialisierung. Er bestätigt weder einen
unsicheren Manifest-Parserlauf noch Speicherfehler, Codeausführung,
Authentifizierungs-Bypass oder Rockbox-Handoff. Ein OSOS-Laufzeitfehler, der
Rockbox nach jedem Kaltstart startet, ist damit weiterhin nicht gefunden.

Offen bleiben die Erzeugung/Registrierung des `TEAppShell`-Objekts, der
indirekte Aufruf von VTable-Slot `+0xa8`, der Empfänger von `ExecuteGame` bei
`+0x15c` und die Laufzeitverbindung zum `eAppMotor::loadApp`-Pfad. Als Nächstes
sollten die externe Konstruktor-/Factory-Registrierung und die dynamische
Empfängerregistrierung statisch verfolgt werden. Ein Live-Trace wäre erst nötig,
wenn das Gerät wieder verfügbar ist; bis dahin ist kein Gerätezugriff
erforderlich.

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
