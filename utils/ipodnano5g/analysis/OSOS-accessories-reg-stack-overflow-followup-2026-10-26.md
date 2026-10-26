# Früher OSOS-Parser für `accessories.reg`: Stack-Überlauf

Stand: 26.10.2026. Read-only-Disassemblierung und Analyse des vorhandenen
OSOS-Runtime-Abbilds `osos_runtime_dram_20261025.bin`. Keine USB-, DFU-, Boot-,
NAND-/NOR-, Flash- oder Geräteaktion; keine Tests oder Builds.

## Ergebnis

Der Parser für `iPod_Control/Device/accessories.reg` wird im frühen
MainApp-Factory-Pfad aufgerufen. Bei seinem Token `0x44` liest er eine
dateigesteuerte 32-Bit-Länge und benutzt sie als Leselänge für einen lokalen
256-Byte-Puffer, ohne den an den Helper übergebenen Grenzwert `0x100`
anzuwenden. Damit ist ein Stackpufferüberlauf statisch belegt. Der Überlauf
kann das lokale Stringobjekt überschreiben, das anschließend über eine
VTable-Funktion verarbeitet wird. Das ist ein konkreter
Kontrollfluss-Korruptionskandidat, aber noch kein demonstrierter RCE-Exploit
oder Rockbox-Handoff.

## Kaltstartpfad

Die bestehende MainApp-Analyse weist nach, dass `FUN_0804faa0` während der
MainApp-Initialisierung die Factory-Tabelle abarbeitet. Die Zeile für ID
`0x3280` ruft `FUN_0801e8f6` auf. Dieser Callback ruft
`FUN_08020fa8(..., 0)` auf. `FUN_08020fa8` baut den Media-Controller und ruft
`FUN_08022b08` auf. In `FUN_08022b08` folgt bei `0x08022b6a` der direkte,
bedingungslose Aufruf von `FUN_0802c3c4`.

`FUN_0802c3c4` öffnet den Stream mit `FUN_082721f0(..., 0)`. Die von seinem
Pfad-Builder referenzierte Zeichenkette liegt bei Runtime-VA `0x0853d794` und
lautet `iPod_Control/Device/accessories.reg`. Der frühe Factory-Callback ist
somit ein automatischer MainApp-Startpfad zum Parser; der Nullkontext, der den
separaten ArtworkDB-Lader stoppt, verhindert diesen Parseraufruf nicht.

## Längenfluss und Überlauf

Im Parser `FUN_0802c3c4` ist der relevante Datenfluss:

1. Der lokale Puffer beginnt bei `sp+4` und ist `0x100` Byte groß.
2. Beim Token `0x44` ruft der Parser `FUN_08039048(stream, 0x100, buffer,
   &length)` auf.
3. `FUN_08039048` liest zunächst vier Bytes in `length` und ruft danach
   `FUN_08268c3a(stream, length, buffer)` auf. Sein Parameter 2 (`0x100` beim
   Parseraufruf) wird nicht gelesen und begrenzt den zweiten Read nicht.
4. `FUN_08268c3a` dispatcht über den Stream-VTable-Slot `+0x4c`. Im verwendeten
   Stream ist das `thumb_81b832e`; diese Routine reicht Zielpuffer und
   angeforderte Länge an den Read-Slot `+0x2c` weiter. Die konkrete
   Pufferstream-Routine `thumb_820cc90` kopiert verfügbare Pufferbytes und
   reicht die verbleibende angeforderte Länge an den Provider-Slot `+0x44`
   weiter. Der Stream wird mit einem Maximum von `0x8000` Byte geöffnet
   (`FUN_082721f0`); diese Grenze liegt deutlich über den `0x110` Byte, die
   zum Erreichen des Stringobjekts genügen. Sie beschränkt die Länge nicht auf
   die Größe des lokalen Zielpuffers.

Die Funktion `FUN_0802c3c4` reserviert mit `push {r0,r4,r5,r6,r7,lr}` und
`sub sp,#0x128` einen Stackframe. Das lokale Stringobjekt beginnt bei
`sp+0x110`; sein Puffer beginnt bei `sp+4`. Eine erfolgreiche Eingabe mit
Länge mindestens `0x110` überschreibt daher bereits das erste Wort des
Stringobjekts. Direkt danach ruft der Parser `FUN_081936ec(sp+0x110, buffer)`
auf. Diese Funktion liest den VTable-Zeiger aus dem lokalen Objekt und ruft
den Eintrag bei VTable-Offset `+8` indirekt auf. Der Überlauf erreicht somit
vor dem regulären Funktionsende ein kontrollflussrelevantes Objekt.

Aus demselben Stacklayout ergibt sich, dass der gespeicherte LR bei `sp+0x13c`
liegt; die ersten Bytes des LR liegen `0x138` Bytes ab dem Pufferanfang.
Dieser Weg ist für die Bewertung relevant, aber die frühere virtuelle
Verwendung des lokalen Stringobjekts tritt bereits vor einer Rückkehr aus dem
Parser ein.

## Grenzen der Aussage

- Die Analyse belegt den Überlauf und die spätere indirekte Verwendung des
  beschädigten Objekts statisch. Sie belegt nicht, dass ein bestimmtes
  `accessories.reg`-Exemplar den gewünschten Funktionsaufruf auslöst.
- Ein Beispiel der Datei fehlt sowohl im lokalen Gerätebackup als auch in den
  vorliegenden Extraktionen. Ob sie auf diesem Gerät vorhanden ist und über
  die normale Datenpartition ersetzt oder angelegt werden kann, ist offen.
- Die absolute Lage des MainAppTask-Stacks, ein brauchbarer indirekter
  Aufrufwert, die Speicherrechte des Zielbereichs und ein Übergang in den
  Rockbox-Bootloader wurden nicht ermittelt.
- Die Hold-Prüfung und der Fallback zum signierten iPod-OS sind damit nicht
  gelöst.

## Nächste statische Schritte

1. Den vollständigen Writer/Producer von `accessories.reg` und die konkrete
   Token-/Längen-Codierung finden.
2. Den Datei-Provider bis zur Datenpartition verfolgen und anhand vorhandener
   Firmware-/Dateisystemartefakte prüfen, ob der feste Pfad für den Nutzer
   schreibbar ist.
3. Stacklage und VTable-Aufrufkontext des MainAppTask bestimmen und prüfen,
   welche kontrollierten Ziele erreichbar sind.
4. Erst nach einer statisch tragfähigen Kontrollflusskette untersuchen, wie
   OSOS Rockbox von FAT nach RAM lädt und wie der Hold-gesperrte Apple-Pfad
   erhalten bleibt.

## Rohbelege

- `/tmp/OSOS_recursive_skip_direct_callers_20261026.txt` – Parser und Aufruf
  von `FUN_08039048`.
- `/tmp/OSOS_factory_runtime_decomp_2026-10-25.txt` – früher Factory-Callback
  und `FUN_08022b08`.
- `/tmp/OSOS_mainapp_factory_batch_init_2026-10-25.txt` – MainApp-Factory-
  Dispatch.
- `/tmp/OSOS_function_0827ea84_20261026.txt` und
  `/tmp/OSOS_timer_stream_functions_20261026.txt` – Stream-Setup und
  `thumb_81b832e`.
- `/tmp/OSOS_timer_wrapper_read_0820cc90_20261026.txt` – buffered file-read
  forwarding.
- `/tmp/OSOS_playcounts_stream_bounds_20261026.txt` – Öffnung des Streams mit
  `0x8000`-Byte-Maximum in `FUN_082721f0`.
- `/tmp/OSOS_mainapp_registry_singleton_data_20261025.txt` – String bei
  `0x0853d794`.
