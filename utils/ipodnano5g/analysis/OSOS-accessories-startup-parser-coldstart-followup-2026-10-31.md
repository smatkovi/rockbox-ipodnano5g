# `accessories.reg`-Parser im MainApp-Kaltstartpfad

Stand: 31.10.2026. Statische read-only-Verknüpfung der vorhandenen
OSOS-Runtime- und Ghidra-Belege. Kein Gerät, USB, DFU, Reboot, Emulator,
Dateisystem- oder Flashzugriff.

## Ergebnis

Der automatische MainApp-Fabriklauf ruft statisch `FUN_08022b08` auf.
Diese Funktion ruft `FUN_0802c3c4` direkt und ohne Prüfung des vorherigen
Rückgabewerts auf. Damit ist der **Parseraufruf** für
`iPod_Control/Device/accessories.reg` im MainApp-Kaltstartpfad belegt.

Das schließt nicht den Datei-Open und Read: `FUN_0802c3c4` muss den
VFS-Service-Slot 0 erfolgreich öffnen und die überlange Tokenlänge tatsächlich
aus dem Dateistream erhalten, bevor der bekannte Stackpufferfehler ausgelöst
wird. Der gespeicherte Volume-/Providerzustand auf Hardware ist weiterhin
unbekannt.

## Statische Aufrufkette

1. Der Bootpfad richtet `MainAppTask` mit Entry `FUN_080202d8` ein. MainApp
   ruft über VTable-Slot `+0x16c` `FUN_0804fa58` auf; dessen Slot `+0x170`
   ruft `FUN_0804faa0` auf. Der Batch-Callback läuft über die 24 MainApp-
   Factory-Zeilen und ruft den Funktionszeiger bei Zeilenoffset `+8` auf.
2. Der Boot-Constructor `FUN_08014600` schreibt Factory-ID `0x3280` in die
   erste Zelle der Zeile bei `0x08553a70`. Das dritte Wort der Zeile bei
   `0x08553a78` ist der Callback `0x0801e8f7` (`FUN_0801e8f6`). Dieser
   reserviert `0x104` Byte und ruft `FUN_08020fa8(pointer, 0)` auf.
3. Ghidras Pseudocode für `FUN_08020fa8` bricht wegen eines nicht erkannten
   Konstruktor-/Instruktionskontexts ab. Das vorhandene rohe Thumb-Listing
   zeigt den tatsächlichen Kontrollfluss: Die Funktion setzt ihr Feld bei
   `r4+0xf8` auf null und ruft bei `0x08021018` `FUN_08022b08(r4, 0)` auf.
4. `FUN_08022b08` ruft zunächst `FUN_080253f4(0, object+0x48)` auf. Der
   Nullkontext kann diesen anderen Media-/ArtworkDB-Pfad vor
   `FUN_081ac420` beenden. `FUN_08022b08` prüft den Rückgabewert jedoch nicht;
   nach weiteren Initialisierungsschritten folgt bei `0x08022b6a` der direkte
   Aufruf `BL FUN_0802c3c4`.
5. `FUN_0802c3c4` öffnet den festen Pfad
   `iPod_Control/Device/accessories.reg` über `FUN_082721f0` und fragt dabei
   Service-Slot 0 ab. Der Pfad enthält kein Laufwerkspräfix; der zuvor
   dokumentierte neue Taskkontext verwendet Volumeindex 0.

Damit korrigiert sich eine mögliche Überdehnung des älteren Befunds: Der
Nullkontext verhindert den ArtworkDB-Aufruf über `FUN_081ac420`, aber nicht
den nachfolgenden separaten `accessories.reg`-Parseraufruf in
`FUN_08022b08`.

## Auswirkung und Grenzen

- Der Parseraufruf ist statisch im MainApp-Startpfad erreichbar. Das erhöht
  die Relevanz des dateigesteuerten `0x44`-Längenfehlers als persistenter
  Boottrigger.
- Der Open-/Read-Pfad bleibt bedingt. Die vorhandene Analyse zeigt, dass der
  Parser einen fehlgeschlagenen Open vor dem Tokenloop abfängt. Ein
  fehlender/unregistrierter Slot 0 oder ein nicht erfolgreicher Dateiread
  verhindert den Overflow.
- Die letzte read-only-Dateiaufnahme dokumentiert eine normale
  69-Byte-`accessories.reg` mit `Pedometer`; sie stammt nicht vom heutigen
  Gerätezustand. Ein präparierter Dateiinhalt wurde in dieser Runde weder
  geschrieben noch ausgeführt.
- Das belegt weder Codeausführung auf dem iPod noch einen Rockbox-Start. Der
  nächste technische Engpass ist ein gemeinsamer Lauf, der MainApp-Aufruf,
  Slot-0-Provider, echten VFS-Open und Dateiread zusammenführt. Erst danach
  lässt sich der persistente Boottrigger bewerten.

## Vorhandene Rohbelege

- `evidence/speakable-2026-10-28/OSOS_speakable_factory_route_and_event_sink_20261028.log` —
  MainApp-Lifecycle- und 24-Zeilen-Batchcallback.
- `evidence/speakable-2026-10-28/OSOS_speakable_registry_registration_initializer_followup_20261028.log` —
  Konstruktor für Factory-ID `0x3280`, Zeile `0x08553a70` und
  Callback-Referenz.
- `evidence/speakable-2026-10-28/OSOS_speakable_registry_callback_0801e8f6_20261028.log` —
  Factorycallback und `FUN_08020fa8(pointer, 0)`.
- `evidence/speakable-2026-10-28/OSOS_speakable_factory_08020fa8_full_thumb_20261028.log` —
  rohe Thumb-Instruktionen einschließlich `0x08021018 BL 0x08022b08`.
- `evidence/speakable-2026-10-28/OSOS_speakable_child_controller_registration_helpers_20261028.log` —
  Pseudocode und Thumb-Listing von `FUN_08022b08`, einschließlich des
  unbedingten `BL 0x0802c3c4` bei `0x08022b6a`.
- `OSOS-accessories-full-path-reachability-followup-2026-10-29.md` und
  `OSOS-accessories-file-chain-untethered-assessment-2026-10-30.md` — fester
  Dateipfad, Slot-0-Open, Statusprüfung und Grenzen des Stream-/FAT-Nachweises.

Alle genannten Quellbelege sind bereits im Repository versioniert. Die
Rohdisassemblierung von `FUN_08020fa8` ist maßgeblich für diesen Schritt, weil
Ghidras Decompiler an dieser Funktion einen Pcode-/Konstruktorfehler meldet.
