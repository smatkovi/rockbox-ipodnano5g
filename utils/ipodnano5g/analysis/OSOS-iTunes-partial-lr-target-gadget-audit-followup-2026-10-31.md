# iTunes-PLIST: Audit der partiellen LR-Ziele

Stand: 31.10.2026. Read-only-Ghidra auf dem vorhandenen OSOS-Runtime-Abbild.
Kein Geräte-, USB-, DFU-, NAND-, NOR- oder Firmwarezugriff.

## Ergebnis

Der schon dokumentierte Stack-Overwrite in `FUN_080b1904` lässt sich auf
Thumb-Ziele im Bereich `0x08000000`–`0x0800ffff` einschränken: Die zwei
kontrollierten LR-Bytes stammen aus Dateinamenoffset 116/117; das folgende
Byte wird 0 und das oberste bleibt `0x08`. Damit ist ein partiell
dateinamenkontrollierter Rücksprungwert statisch belegt, sofern der
GeniusPlaylist-Handler und sein langer LFN-Pfad erreichbar sind.

Ein Ghidra-Scan der erkannten Funktionseinträge in diesem 64-KiB-Bereich fand
59 Ziele, deren Thumb-Zeiger mit zwei druckbaren, VFAT-sicheren Zeichen
kodierbar sind. Die Filterung ist bewusst streng und schließt Leerzeichen
aus. Ein zweiter, lockerer Scan fand 509 passende Instruktionspositionen mit
kurzen Folgefenstern; diese Zahl ist **keine** Zahl verifizierter ROP-Gadgets,
weil viele Fenster nur lineare Arithmetik oder einen späteren Kontrollfluss
enthalten.

Der auffällige Zielwert `0x08006d31` ist als Zeichenpaar `1m` darstellbar und
führt an `0x08006d30` nur `bx lr` aus. Nach dem ersten Epilog von
`FUN_080b1904` enthält LR den Rücksprung `0x080b1971`. Das Gadget springt daher
zurück in dieselbe Epilogsequenz: `add sp,#0x190; pop {r4,r5,r6,pc}` läuft ein
zweites Mal. Der zweite Pop liest den PC aus dem Aufruferstack bei
`SP+0x19c`, in `FUN_08213400` aus dem oberen Wort des temporären Pfadobjekts
`auStack_48`. Die nachfolgende Pfadobjektanalyse zeigt, dass dieses Wort auf
den dynamisch allokierten Pfadtext zeigt. Dieser enthält einen
dateinamenabhängigen Namensanteil; der zweite PC ist damit indirekt
dateinamenabhängig und kein fester Codezeiger.

Ein weiteres kodierbares Beispiel ist `0x08002749` (`I'`):
`add sp,#0x64; pop {r4,r5,pc}`. Beim Eintritt ist SP der Stackpointer des
Aufrufs von `FUN_080b1904`; `FUN_08213400` legt `local_174` bei `SP+0x6c` ab.
Der PC des Gadgets wird daher aus den ersten vier Bytes von `local_174`
geladen, also aus dem festen Präfix `iPod`, und ergibt `0x646f5069` statt
eines ausführbaren Ziels. Andere gefundene Pop-PC-Fenster lesen Werte aus
Caller-Locals, deren Kontrolle durch die Playlistdatei bisher nicht belegt
ist.

## Bewertung (aktualisiert 31.10.2026)

Der partielle LR-Overwrite ist mehr als ein bloßer Längenfehler: Der gespeicherte
PC kann durch bestimmte Dateinamenbytes in einen ASCII-kompatiblen Codebereich
umgeleitet werden. Das `bx lr`-Gadget führt zum zweiten Epilog; dessen PC-Wert
ist der Zeiger auf den dynamischen String `iPod_Control\\iTunes\\` plus
Komponente. Beim Genius-Handler lautet der feste Stringanfang
`iPod_Control\\iTunes\\GeniusPlaylist`; dahinter folgt ein Eingabeanteil.
Der OSOS-MMU-Bericht weist das SDRAM-Fenster `0x08000000..0x0bffffff` als
les-/schreib- und ausführbar aus, und der verwaltete Heap liegt darin. Eine
Umleitung in ausführbaren Heap ist damit statisch plausibel.

Das beweist noch **keine Codeausführung**. `POP {pc}` lädt hier voraussichtlich
einen geraden, wortausgerichteten Heapzeiger und wechselt nach ARM-Zustand.
Die ersten Bytes des Pfadtexts dekodieren dann als ARM-Instruktionen. Der
Genius-Marker verschiebt den kontrollierbaren Suffix bis mindestens Byte 34;
der Suffix wird nicht direkt als erste Instruktion erreicht. Für den
gewöhnlichen erfolgreichen Parserpfad sind `N=0,V=0` aus dem letzten
Status-setzenden Ablauf abgeleitet. Unter diesen Flags laufen die bedingten
Instruktionen des festen Präfixes, darunter ein `LDCLPL` über `r3=0x3c`, das
wahrscheinlich vor dem kontrollierten Suffix faultet. Das Verhalten ist nicht
auf Gerät oder in einem vollständigen Rehost bestätigt. Ein Fehlerstatus mit
`N=1,V=0` könnte diese Instruktion überspringen; die Erreichbarkeit dieses
Status mit kontrolliertem Dateinamen ist offen. Außerdem stammen `r4` und `r5`
beim zweiten Pop aus Caller-Stackwörtern, deren Initialisierung in diesem Pfad
nicht sichtbar ist; das Präfix verwendet beide Register.

Die Erreichbarkeit des Registrierungs-Callbacks bleibt offen:
`FUN_08037746` ist als Slot `+0xb4` der MainApp-Controller-VTable identifiziert,
aber Ghidra zeigt keinen direkten Code-Caller. Factory- und Registry-Prüfungen
belegen Objekterzeugung und andere Lifecycle-Aufrufe, nicht aber diesen Slot.
Ein zusätzlicher Instruktionsscan fand 159 `ldr`-Instruktionen mit Offset
`0xb4`, aber keinen anschließenden `bx`/`blx` auf dasselbe Zielregister in den
jeweils folgenden acht Instruktionen. Das ist nur ein enger Pattern-Scan und
schließt indirekte, längere oder anders kompilierte Dispatchpfade nicht aus.
Die MainApp-Factory-Initialisierung wurde ebenfalls nachverfolgt: `FUN_0801e3a4`
registriert 24 Einträge und startet `MainAppTask`; dessen Factory-Schleife ruft
pro Eintrag den Factory-Callback auf und fügt das erzeugte Objekt der
Controllerverwaltung hinzu. Einer der Einträge erzeugt ein Objekt der Größe
`0x9c0`. Der transiente Thumb-Dekompilierlauf ordnet dessen Konstruktion über
`FUN_080202cc`/`FUN_08023390` der VTable `0x084fc72c` und dem Klassenmarker
`Coverflow` zu. Dieser große Eintrag belegt daher nicht, dass die separate
VTable `0x084f7558` mit `FUN_08037746` als Slot `+0xb4` den Callback-Owner
bereitstellt. Die anderen Factory-Einträge und mögliche spätere dynamische
Dispatches sind damit nicht ausgeschlossen.
Auch das Öffnen des iTunes-Verzeichnisses über den realen FAT-/LFN-Pfad vor dem
Callback ist im vollständigen Laufzeitkontext nicht bestätigt. Ein automatischer
Kaltstarttrigger oder ein Rockbox-Handoff ist nicht belegt.

## Rohbelege

Die reproduzierbaren Ghidra-Skripte, Script-Ausgaben und Prüfsummen liegen
unter `evidence/itunes-partial-lr-2026-10-31/`:

- `ScanAsciiThumbTargets.java` zählt strenge, druckbare Ziele an erkannten
  Funktionsanfängen.
- `ScanAsciiThumbGadgets.java` listet lockere Instruktionsfenster; seine
  Treffer sind manuell und kontextabhängig zu bewerten.
- `OSOS_iTunes_overflow_lr_context_20261031.script.log` enthält den
  Funktionslisting-Export von `FUN_080b1904`, `0x08006d30` und `0x08006134`.
- `OSOS_iTunes_playlist_caller_stack_20261031.script.log` enthält Listing und
  Pseudocode von `FUN_08213400`, einschließlich des `0x1e0`-Byte-Frames und
  des lokalen `local_174`-Puffers.
- `OSOS_iTunes_ascii_thumb_targets_20261031.script.log` und
  `OSOS_iTunes_ascii_thumb_gadgets_20261031.script.log` enthalten die
  jeweiligen Scans.
- `OSOS_iTunes_vulnerable_caller_parents_20261031.ghidra.log` und
  `OSOS_iTunes_playlist_handler_callers_20261031.ghidra.log` belegen die
  direkten Caller der Pfadverarbeitung und die Genius-/On-The-Go-Handler.
- `OSOS_iTunes_path_string_helpers_20261031.ghidra.log`,
  `OSOS_iTunes_path_vtable_entries_20261031.ghidra.log` und
  `OSOS_iTunes_path_buffer_allocator_20261031.ghidra.log` zeigen Stringlayout,
  VTable und Allokations-/Freigabepfad des dynamischen Pfads.
- `OSOS_iTunes_path_heap_manager_20261031.ghidra.log` und
  `OSOS_iTunes_runtime_mapping_20261031.ghidra.log` dokumentieren Heapgrenzen
  sowie Ghidras Runtime-Programmmodell. Die RWX-Attribute des SDRAM stammen
  aus `OSOS-voice-audio-callback-list-followup-2026-10-28.md`.
- `OSOS_iTunes_path_error_register_sources_20261031.ghidra.log`,
  `OSOS_iTunes_cleanup_type_dispatch_20261031.ghidra.log`,
  `OSOS_iTunes_cleanup_callee_register_state_20261031.script.log` und
  `OSOS_iTunes_callback_handlers_thumb_20261031.disasm.txt` enthalten die
  Flag-/Registerherleitung, Cleanup-Kette und Handler-Disassemblierung.
- `ScanVtableB4Dispatch.java` und
  `OSOS_iTunes_vtable_b4_dispatch_scan_20261031.application.log` dokumentieren
  den begrenzten Offset-`0xb4`-Dispatchscan.
- `OSOS_iTunes_factory_registry_registration_callers_20261031.application.log`,
  `OSOS_iTunes_mainapp_factory_table_20261031.application.log` und
  `OSOS_iTunes_mainapp_factory_callbacks_thumb_20261031.application.log`
  dokumentieren die 24 MainApp-Factory-Einträge und deren transiente
  Thumb-Dekompilierung.
- `OSOS_iTunes_large_controller_ctor_followup_20261031.application.log` und
  `OSOS_iTunes_large_controller_class_descriptor_20261031.application.log`
  zeigen, dass das `0x9c0`-Byte-Objekt zur `Coverflow`-VTable
  `0x084fc72c` gehört.
- `OSOS_iTunes_heap_redirect_prefix_20261031.bin` ist ein String-/Sentinel-
  Testvektor; die ARM-State-Disassemblierung steht in
  `OSOS_iTunes_heap_redirect_prefix_20261031.disasm.txt`.

Die Ghidra-Abfragen liefen mit `-noanalysis -readOnly` auf
`N5G_OSOS_runtime`, Programm `osos_runtime_dram_20261025.bin`. Temporäre
Funktionsdekodierungen wurden nicht gespeichert.

## Nächste Schritte

1. Die ARM-Präfixinstruktionen im rehosteten OSOS-Zustand ausführen und Flags
   sowie `r3/r4/r5` am zweiten Epilog beobachten; vor allem klären, ob ein
   kontrollierbarer Fehlerstatus bis zum Suffix gelangt.
2. Den automatischen Lifecycle-/VTable-Aufruf von `FUN_08037746` im
   MainApp-Framework mit längeren und dataflow-basierten Dispatchsuchen weiter
   prüfen; der Offset-Scan war nur ein einfacher Filter.
3. Den FAT-/LFN-Open des iTunes-Verzeichnisses und den Callbackstart im
   Offline-Rehost schließen. Erst danach ist ein geräteloser Trigger belegt.
4. Den getrennt priorisierten `accessories.reg`-Kandidaten weiterverfolgen;
   sein vorhandener ROP-Rehost zeigt bisher nur die Parserprimitive mit
   synthetischem VFS-/Heapzustand.
