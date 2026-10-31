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
`auStack_48`. Es ist kein vom Dateinamen kontrollierter Codezeiger belegt.

Ein weiteres kodierbares Beispiel ist `0x08002749` (`I'`):
`add sp,#0x64; pop {r4,r5,pc}`. Beim Eintritt ist SP der Stackpointer des
Aufrufs von `FUN_080b1904`; `FUN_08213400` legt `local_174` bei `SP+0x6c` ab.
Der PC des Gadgets wird daher aus den ersten vier Bytes von `local_174`
geladen, also aus dem festen Präfix `iPod`, und ergibt `0x646f5069` statt
eines ausführbaren Ziels. Andere gefundene Pop-PC-Fenster lesen Werte aus
Caller-Locals, deren Kontrolle durch die Playlistdatei bisher nicht belegt
ist.

## Bewertung

Der partielle LR-Overwrite ist mehr als ein bloßer Längenfehler: Der gespeicherte
PC kann durch bestimmte Dateinamenbytes in einen ASCII-kompatiblen Codebereich
umgeleitet werden. Die geprüften einfachen Rückkehr-/Stack-Gadgets liefern
jedoch keinen kontrollierten zweiten PC und keinen bestätigten Übergang zu
beliebigem Code. Es gibt weiterhin **keinen Nachweis für Codeausführung**,
einen automatischen Kaltstarttrigger oder einen Rockbox-Handoff.

Die bestehende Erreichbarkeitslücke bleibt unverändert: Der MainApp-Controller
und die Callback-Tabelle sind bekannt, aber der automatische Framework-Aufruf
von `FUN_08037746` ist nicht belegt. Auch der vorgelagerte Open von
`iPod_Control\\iTunes\\` über den realen FAT-/LFN-Pfad ist nicht bestätigt.

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

Die Ghidra-Abfragen liefen mit `-noanalysis -readOnly` auf
`N5G_OSOS_runtime`, Programm `osos_runtime_dram_20261025.bin`. Temporäre
Funktionsdekodierungen wurden nicht gespeichert.

## Nächste Schritte

1. Für `FUN_08213400` die realen Werte der an den Pop-PC-Stellen gelesenen
   Caller-Locals nach vollständiger Initialisierung statisch nachverfolgen.
2. Den automatischen VTable-Aufruf von `FUN_08037746` im MainApp-Framework
   weiter prüfen.
3. Den realen FAT-/LFN-Open des iTunes-Verzeichnisses und den Callbackstart
   im Offline-Rehost schließen. Erst danach ist ein geräteloser Trigger belegt.
4. Den getrennt priorisierten `accessories.reg`-Kandidaten weiterverfolgen;
   sein vorhandener ROP-Rehost zeigt bisher nur die Parserprimitive mit
   synthetischem VFS-/Heapzustand.
