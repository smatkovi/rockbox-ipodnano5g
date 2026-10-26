# Früher OSOS-Parser für `accessories.reg`: Stack-Überlauf

Stand: 26.10.2026. Read-only-Disassemblierung und Analyse des vorhandenen
OSOS-Runtime-Abbilds `osos_runtime_dram_20261025.bin`. Zusätzlich wurde die
Datenpartition im Rockbox-USB-Modus read-only eingehängt und
`iPod_Control/Device/accessories.reg` gelesen. Es wurden keine Gerätedaten
geändert und keine DFU-, Boot-, NAND-/NOR- oder Flashoperation ausgeführt;
keine Tests oder Builds.

## Ergebnis

Der Parser für `iPod_Control/Device/accessories.reg` wird im frühen
MainApp-Factory-Pfad aufgerufen. Bei seinem Token `0x44` liest er eine
dateigesteuerte 32-Bit-Länge und benutzt sie als Leselänge für einen lokalen
256-Byte-Puffer, ohne den an den Helper übergebenen Grenzwert `0x100`
anzuwenden. Damit ist ein Stackpufferüberlauf statisch belegt. Er kann das
lokale Stringobjekt, den gespeicherten LR und bei längerer Eingabe den
Caller-Stack überschreiben. Die vorgeschaltete VTable-Verwendung und der
Aufräumpfad lassen sich mit gültigen Objektwerten durchlaufen. Ein vorhandenes
`pop {r0,r1,r2,r3,r4,pc}`-Gadget ermöglicht danach eine dateikontrollierte
ROP-Folge in OSOS-Code. Ein vollständiger Dateilade-/Rockbox-Handoff ist noch
nicht belegt; ein Exploit wurde nicht am Gerät ausgeführt.

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

## VTable, Aufräumpfad und Rücksprungkontrolle

Der Konstruktor `FUN_08198770` setzt die Standard-VTable `0x085354d8` und den
Stringpufferzeiger auf null. Der Token-`0x44`-Pfad prüft vor dem Read, dass
dieser Puffer leer ist. Danach berechnet `FUN_081936ec` `strlen+1` und ruft
VTable-Slot `+8` auf. Der Slot zeigt auf `FUN_080a1cc0`, die den Stringpuffer
allokiert beziehungsweise vergrößert und den Heapzeiger im Objekt speichert.
Der Destruktor `FUN_081ada60` gibt anschließend nur einen nichtnullen
Pufferzeiger frei; er dispatcht nicht über die beschädigte VTable.

Die Stackfelder relativ zum Anfang des Eingabepuffers sind:

| Offset | Bedeutung |
| --- | --- |
| `+0x10c` | Objekt-VTable; `0x085354d8` ist gültig |
| `+0x110` | Objekt-Pufferzeiger; null beendet zunächst `strlen` bei `0x110` und wird danach vom Allokator ersetzt |
| `+0x114` | Exit-Flag; ein Nichtnullwert führt nach dem Token-Read in den Aufräumpfad |
| `+0x120` | Zeiger für den Stream-Close-Aufruf; `0x084f59e0` zeigt auf ein statisches Nullwort und lässt den Close-Wrapper ohne Dispatch zurückkehren |
| `+0x128` bis `+0x138` | gespeicherte Register `r4` bis LR; LR beginnt bei `+0x138` |
| ab `+0x13c` | Caller-Stack nach der Rückkehr; bei größerer Leselänge stammen diese Wörter ebenfalls aus der Datei |

Der Parser schreibt die abschließende NUL an `buffer+length`. Bei Länge
`0x13c` reichen die gelesenen Bytes bis einschließlich des gespeicherten LR
(Offsets `+0x138` bis `+0x13b`); die NUL landet am Anfang des Caller-Stacks,
bei `buffer+0x13c`. Bei einer größeren Länge überschreibt auch der Dateikörper
Wörter dieses Caller-Stacks, und die NUL folgt dahinter. Der LR kann auf
`0x08007107` zeigen: `0x08007106` ist die Instruktion
`pop {r0,r1,r2,r3,r4,pc}`. Der Parser-Epilog stellt zuvor `sp` auf
`buffer+0x13c`; das Gadget lädt seine Register und den nächsten PC daher aus
dem dateikontrollierten Caller-Stack. Der Stack selbst muss dafür nicht
ausführbar sein.

Das belegt statisch eine erreichbare Kontrolle des Rücksprungs und eine
ROP-fähige Register-/Stackfolge in vorhandenem OSOS-Code, falls die Datei mit
einer langen Eingabe verändert werden kann. Zusätzlich ist bei `0x08030cbc`
ein indirekter Aufruf `blx r3` mit anschließendem
`pop {r3,r4,r5,pc}` bestätigt; ein direkter Einstieg an diesem Thumb-Aufruf
kann die zuvor gesetzten Argumentregister verwenden. Ein Stackzeiger-Gadget bei
`0x0800396c` übergibt `sp` in `r0`, und `0x0805b092` bildet daraus einen
stackrelativen Zeiger in `r1`. Das macht kontrollierte API-Aufrufe und
Stack-Objekte plausibel. Der vollständige Pfadobjekt-/Dateiöffnungs-/Lesepfad
bis zum Rockbox-Loader ist aber noch nicht zusammengesetzt oder verifiziert.

Die statische API-Kette besteht aus `FUN_082721f0` zum Öffnen eines
Stringobjekts als Stream und `FUN_08268c3a` zum Dispatch des Reads über
VTable-Slot `+0x4c`. `FUN_08039048` liest zunächst eine 32-Bit-Länge und reicht
diese dann als Leselänge weiter; sein Argument `0x100` wird nicht als Grenze
verwendet. Offen sind insbesondere eine zuverlässige Adresse für das
Pfad-/Stringobjekt nach Rückkehr aus dem Parser, das Wiedererlangen des
Stream-Wrappers nach dem Öffnen, die Beschränkung der Stream-Lesemengen und ein
kontrollierter Sprung zum Loader.

## Vorhandene Datei auf dem Gerät

Die read-only eingehängte Partition `/tmp/ipod-sebipod-readonly` enthält die
69 Byte große Datei `iPod_Control/Device/accessories.reg` mit SHA-256
`b7203385b92dc4b3df094d0d0889b0f48dbd6766a687f54fa874d0c5f4e48854`. Sie
enthält den normalen Token `0x8000002b`, danach `0x44`, Länge `9` und
`Pedometer`, gefolgt von normalen Terminator-Tokens. Damit ist der Trigger-Token
im echten Gerätedatensatz bestätigt, aber kein Überlaufbeispiel. Die Partition
war am Host read-only eingehängt; ob das Apple-OS diesen Pfad für normale
Host-Schreibzugriffe freigibt, bleibt offen.

## Writer/Producer

Der zweite Codeverweis auf den Pfad führt zu `FUN_0814b13c`. Diese Funktion
schreibt dieselbe Datei, aber nur wenn das Dirty-Flag bei `param_1+0x40`
gesetzt ist. Sie öffnet den Stream über `FUN_082721f0(..., 1)` und serialisiert
Datensätze mit den Tags `0x29`, `0x2a`, `0x2b`, `0x2c`, `0x44` und `0x2d`;
der Stringeintrag `0x44` wird mit Länge und Daten geschrieben. Bei erfolgreichem
Abschluss löscht der Writer das Flag. Der Parser löscht dasselbe Flag am Exit.

Der einzige direkte Caller des Writers im Runtime-Abbild ist
`FUN_0825da88`. Dessen direkte Caller sind `FUN_0835ed24`, `FUN_08058a6c` und
`FUN_08251624`; die vorhandene Analyse ordnet sie Ereignis-/Zustandspfaden zu,
nicht einem bestätigten MainApp-Kaltstartaufruf. Damit ist ein interner Writer
vorhanden, aber kein Beleg, dass er die Datei vor dem frühen Parser beim
Kaltstart neu erzeugt.

## Grenzen der Aussage

- Das echte Dateibeispiel ist normal und nicht übergroß. Ob `accessories.reg`
  über die Apple-USB-Datenpartition gezielt ersetzt werden kann, bleibt offen;
  aktuell ist nur die Rockbox-USB-Partition read-only verifiziert.
- Rücksprungkontrolle und ein geeignetes Pop-Gadget sind statisch belegt. Ein
  vollständiger ROP-Aufruf für Dateilesen und Loader-Handoff sowie die konkrete
  Laufzeitlage des MainAppTask-Stacks sind noch offen.
- Die RAM-/MMU-Eigenschaften und der Hold-gesperrte Apple-Fallback bleiben
  ungeprüft.
- Die Hold-Prüfung und der Fallback zum signierten iPod-OS sind damit nicht
  gelöst.

## Nächste statische Schritte

1. Klären, ob `accessories.reg` im normalen Apple-USB-Modus vom Host ersetzt
   werden kann; den internen Writer und sein Dirty-Flag sind identifiziert.
2. Die ROP-Kette vom vorhandenen Streamobjekt oder über einen neuen Stream bis
   zum Lesen von `bootloader.bin` nach `0x09000000` ausarbeiten. `rockbox.ipod`
   und `n5g-ramdisk.img` liegen bereits unter `/.rockbox/`; `bootloader.bin`
   liegt derzeit nur im lokalen Build.
3. MainAppTask-Stack und nötige Kontextobjekte aus Task-/Heap-Aufbau bestimmen;
   der ROP-Pfad braucht keinen ausführbaren Stack.
4. Den Einweg-Handoff und den Hold-gesperrten Apple-Fallback statisch prüfen.

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
- `/tmp/OSOS_runtime_parser_20261026.txt` – Parser-Stacklayout und LR-Offset.
- `/tmp/OSOS_runtime_string_ctor_20261026.txt`,
  `/tmp/OSOS_runtime_string_setter_20261026.txt`,
  `/tmp/OSOS_runtime_string_length_20261026.txt` und
  `/tmp/OSOS_runtime_close_and_allocator_20261026.txt` – String-VTable,
  Allokation, Kopie und Cleanup.
- `/tmp/OSOS_runtime_pop_pc_gadgets_20261026.txt` und
  `/tmp/OSOS_runtime_rop_pop_context_20261026.txt` – Pop-Gadgets und das
  verwendete `0x08007106`-Gadget.
- `/tmp/OSOS_runtime_call_pop_sequences_20261026.txt` und
  `/tmp/OSOS_global_service_callers_20261026.txt` – indirekter Aufruf bei
  `0x08030cbc` mit folgendem Pop-Chain-Gadget.
- `/tmp/OSOS_runtime_stack_pointer_gadgets_20261026.txt` und
  `/tmp/OSOS_runtime_stack_to_register_pop_20261026.txt` – Stackzeiger- und
  Registerübergabe-Gadgets.
- `/tmp/OSOS_function_082721f0_20261026.txt`,
  `/tmp/OSOS_function_08268c3a_20261026.txt` und
  `/tmp/OSOS_function_0827ea84_20261026.txt` – Öffnen und Lesen von Streams.
- `/tmp/OSOS_runtime_accessories_second_caller_20261026.txt` – bedingter
  Writer von `accessories.reg`.
- `/tmp/OSOS_function_0825da88_20261026.txt` – Writer-Aufrufer und umgebender
  Ereignis-/Zustandspfad.
- `/tmp/OSOS_runtime_stack_address_ops_20261026.txt` – Stackbezogene
  Instruktionssuche.
- `/tmp/ipod-sebipod-readonly/iPod_Control/Device/accessories.reg` –
  read-only extrahierte 69-Byte-Gerätedatei.
