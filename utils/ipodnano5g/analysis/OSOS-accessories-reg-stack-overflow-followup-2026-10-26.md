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
ROP-Folge in OSOS-Code. Der interne Writer und die echte 69-Byte-Datei stimmen
beim Binärformat überein; eine Feldlänge von `0x2c4` passt strukturell in
dieses Format. Die abgezählte Loaderfolge bleibt trotzdem ungetestet: Es gibt
keinen verifizierten Datei-Open, Read oder Rockbox-Handoff und keinen Lauf auf
dem Gerät.

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
   weiter. Der von `FUN_082721f0` übergebene Wert `0x8000` ist kein belegtes
   Dateilimit: `FUN_08271014` reicht ihn an `FUN_0818f134` weiter, das dafür
   `0x8020` Byte anfordert und den nutzbaren Puffer auf 32-Byte-Grenze
   ausrichtet. `FUN_08260198` setzt den separaten Restlängenzähler auf
   `0xffffffff`; `FUN_0823c9c0` füllt den Puffer bei Bedarf nach. Die
   angeforderte Leselänge kann somit über mehrere Pufferfüllungen an den
   Provider gehen. Tatsächlich gelieferte Bytes hängen weiterhin von dessen
   Rückgabewert und EOF ab. Die `0x8000` Byte sind Pufferkapazität, keine
   Obergrenze für die dateigesteuerte Leselänge.

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

### MainAppTask-Stack

`thumb_801e3a4` legt den Task `MainAppTask` mit Einstieg `0x080202d8` an. Der
in der Runtime bei `0x085512dc` gespeicherte Wert ist `0x2000`; der
Task-Setup-Code multipliziert ihn mit 16 und reicht `0x20000` an
`FUN_081a5b80` weiter. Dieser Wrapper übergibt die Größe an den Speicher-Allocator.
Das Runtime-Abbild weist damit eine angeforderte MainAppTask-Stackgröße von
128 KiB aus. Die dynamische Stackbasis und deren Laufzeit-Mapping sind aus dem
Dump nicht ersichtlich. Die ROP-Folge braucht keinen ausführbaren Stack; die
ermittelte Größe allein belegt weder den Datei-Trigger noch einen erfolgreichen
Loader-Handoff.

Die statische API-Kette besteht aus `FUN_082721f0` zum Öffnen eines
Stringobjekts als Stream und `FUN_08268c3a` zum Dispatch des Reads über
VTable-Slot `+0x4c`. `FUN_08039048` liest zunächst eine 32-Bit-Länge und reicht
diese dann als Leselänge weiter; sein Argument `0x100` wird nicht als Grenze
verwendet. Eine stackrelative Kandidatenfolge bis zum Loader-Entry ist unten
abgezählt, aber nicht dynamisch verifiziert. `FUN_0827c158` kopiert den Pfad
mit `FUN_0818eb5c` in ein eigenes
Stringobjekt des neuen Streams; `FUN_0818eb5c` kopiert die Zeichenkette über
`FUN_081936ec`. `FUN_082721f0` schreibt den Stream-Wrapper erst nach der
Konstruktion in sein Ausgabeobjekt. Damit kann die Ausgabeadresse statisch
denselben Speicher wie das Eingabe-Stringobjekt verwenden: Nach dem Kopieren
braucht der Stream die ursprüngliche Stringinstanz nicht mehr. Das verursacht
höchstens eine nicht freigegebene String-Allokation. Offen bleiben die konkrete
ROP-Ausführung auf dem Gerät, der Erfolg der Provider-Operationen und ein
kontrollierter Lauf des Loaders. Eine stackrelative Kandidatenfolge lässt sich
aus den bestätigten Gadgets aber inzwischen bis zum Entry des lokalen
Rockbox-Laders abzählen.

Der Open-Weg ist bis zum dynamischen VFS-Pfad verfolgt: `FUN_0819878c` baut
den inneren Stream auf; `FUN_08224970` durchläuft Pfad-/Providerobjekte und
übergibt die Pfadkomponenten an `FUN_082284e0`. Die konkrete Root-Mount-
Zuordnung für `/.rockbox/bootloader.bin` ist in den statischen Daten nicht
belegt. Die Datei- und Providerauflösung bleiben daher offen.

### Offline abgezählte Loader-ROP-Folge

Die folgenden Offsets beziehen sich auf den Parser-Stackzeiger `S` am Anfang
des Frames; die Daten des `0x44`-Felds beginnen bei `S+4`. Der Epilog lädt LR
aus `S+0x13c` und verlässt den Parser mit SP=`S+0x140`. Das erste Wort des
Gadgets `0x08007106` liegt daher bei Datenoffset `0x13c`. Die Folge ist
statisch aus Disassemblierung und ABI-Regeln abgeleitet; sie wurde weder als
fertige Datei serialisiert noch auf dem Gerät ausgeführt.

Ein direkter Pfadzeiger auf den ersten durch `mov r0,sp` erhaltenen Stackwert
würde die Pfadzeichen bei `P+0x80` mit späteren Gadget-Wörtern überlagern. Die
Kandidatenfolge verschiebt deshalb das String-/Ausgabeobjekt auf `P=S+0x40`:

1. `0x08007107` übergibt an das Stackzeigergadget `0x0800396d`; dort ist
   `r0=S+0x158`. Die nachfolgenden Gadgets `sub r0,#0xe0`, `sub r0,#0x20`
   und `sub r0,#0x18` ergeben `P=S+0x40`.
2. Der Call/Pop-Trampolin `0x08030cbd` ruft das Schreibgadget
   `0x0805b093` auf. Es setzt `r1=P+0x80=S+0xc0` und schreibt mit
   `r5=0x6f6c746f` sowie `r4=0x61` die Pfadbytes an Zeichenposition 12 bis 16.
   `FUN_08198770` (`0x08198771`) initialisiert bei `P` das Stringobjekt aus
   diesem C-String. Der Text `/.rockbox/bo` davor und `der.bin\0` danach
   belegt Datenoffset `0xbc` bis `0xd4`, also nur den Teil des Puffers vor LR.
3. Nach Konstruktion des Strings erfasst ein zweites Stackzeigergadget
   `S+0x1b0`. Die Subtraktionen `2*0x8c + 0x28 + 2*0x18` ergeben wieder
   `P=S+0x40`. Das `sub 0x28`-Pop setzt `r2=0`; über `0x0818a911` wird
   `r1=r0` hergestellt. `FUN_082721f0` (`0x082721f1`) erhält damit
   `(r0=P, r1=P, r2=0)`: derselbe Stackbereich dient als String-Eingabe und
   Ausgabeadresse. Die zuvor beschriebene Pfadkopie vor dem Schreiben des
   Stream-Wrappers macht dieses Alias statisch möglich.
4. Nach dem Open erfasst ein drittes Stackzeigergadget `S+0x250` und stellt
   `P` mit `2*0xe0 + 2*0x28` wieder her. Das letzte Pop richtet die Read-Args
   ein: `r1=0x10f80` (69.504 Byte), `r2=0x09000000` (Ziel), `r3=0x08268c3b`.
   `FUN_08268c3a` dispatcht über Slot `+0x4c`; `thumb_81b832e` ordnet die
   Register für den inneren Read als Ziel und Länge um und vergleicht die
   gelesene Bytezahl mit der Anforderung. Danach kann der Trampolin
   `0x09000000` mit `BLX` im ARM-Zustand aufrufen.

Für diese Folge muss der Inhalt des überlaufenden Datenfelds mindestens
`0x2c4` Byte lang sein, damit das letzte kontrollierte PC-Wort bei
Datenoffset `0x2c0` mitgeschrieben wird. Der interne Writer bestätigt die
Dateistruktur: Vor dem Feld stehen 32 Byte, danach folgen der 4-Byte-Endmarker
des Felds, ein 16-Byte-`0x2d`-Wert und zwei 4-Byte-Container-Endmarker. Ein
Dateikörper mit genau `0x2c4` Datenbytes wäre damit `0x300` Byte groß. Die von
`0x44` angeforderte Länge ist nicht durch `0x100` begrenzt. Der `0x8000`-Wert
des Streams ist Pufferkapazität und die Refill-Schleife kann größere Reads an
den Provider weiterreichen. Feldoffset `d` entspricht Dateioffset `0x20+d`:
Der gespeicherte LR liegt somit bei Dateioffset `0x158`, das erste ROP-Wort bei
`0x15c`, das letzte kontrollierte PC-Wort bei `0x2e0` und der Endmarker des
`0x44`-Felds bei `0x2e4`. Das sind Layoutwerte der statischen Kandidatenfolge,
kein erzeugtes oder ausgeführtes Payload.

Die durch den Überlauf vor dem Rücksprung beschädigten Parserfelder müssen
weiterhin gültig gesetzt werden: Datenoffset `0x10c` erhält die bestätigte
VTable `0x085354d8`, `0x110` zunächst null, `0x114` das Exit-Flag `1` und
`0x120` den Close-Zeiger `0x084f59e0`. Damit kann der Parser den String über
die gültige VTable neu aufbauen und anschließend den harmlosen Close-Pfad
nehmen. Diese Werte und die ROP-Wörter liegen im selben vom Datei-Read
gefüllten Stackbereich.

Das ist noch kein bestätigter Exploit: Die Registry-Serialisierung ist anhand
des internen Writers und der echten Datei abgeglichen, aber eine vollständige
ROP-Datei wurde nicht erzeugt. Pfadauflösung für `/.rockbox/bootloader.bin`,
Open-Erfolg und exakte Provider-Rückgabe sind nicht nachgewiesen; die Folge
prüft ihre Statuswerte nicht. Der Loader liegt mit seinem Ziel `0x09000000` im
OSOS-Heapbereich und initialisiert zusätzlich BSS ab `0x09100000`. Ob diese
Bereiche die laufende MainAppTask-Stackbelegung oder benötigte OSOS-Allokationen
treffen, bleibt offen. Auch die Ausführbarkeit des RAM-Bereichs und der
CPU-/MMU-Kontext beim ersten `BLX` sind nur aus dem Loader-Startupcode, nicht im
OSOS-Kontext, abgeleitet.

## Vorhandene Datei auf dem Gerät

Die read-only eingehängte Partition `/tmp/ipod-sebipod-readonly` enthält die
69 Byte große Datei `iPod_Control/Device/accessories.reg` mit SHA-256
`b7203385b92dc4b3df094d0d0889b0f48dbd6766a687f54fa874d0c5f4e48854`. Ihre
Writer-konforme Struktur ist bytegenau nachvollzogen:

| Dateioffset | Inhalt |
| --- | --- |
| `0x00` | Containerstart `0x40000029` |
| `0x04` | Containerstart `0x4000002a` |
| `0x08` | Feld `0x2b`, Länge `4`, Wert `3`, Feldende `0x8000002b` |
| `0x18` | Feld `0x44`, Länge `9`, Bytes `Pedometer`, Feldende `0x80000044` |
| `0x2d` | Feld `0x2d`, Länge `4`, Wert `0x691272bb`, Feldende `0x8000002d` |
| `0x3d` | Containerenden `0xc000002a`, `0xc0000029` |

Die Tokenwörter sind little-endian; das Feldende von `0x44` liegt wegen der
neun Nutzbytes unaligned bei Dateioffset `0x29`. Die Datei ist ein normales,
nicht übergroßes Beispiel und löst keinen Überlauf aus. Der Host hatte das
Volume read-only eingehängt; ob es sich im normalen Apple-USB-/OSOS-Dateipfad
ersetzen lässt, bleibt offen.

## Writer/Producer

Der zweite Codeverweis auf den Pfad führt zu `FUN_0814b13c`. Diese Funktion
schreibt dieselbe Datei, aber nur wenn das Dirty-Flag bei `param_1+0x40`
gesetzt ist. Sie öffnet den Stream über `FUN_082721f0(..., 1)`. Die
Serialisierung ist jetzt aus den Aufrufen und den Bytes des echten Beispiels
bestätigt:

- `FUN_08254c00` schreibt einen Containerstart als `tag | 0x40000000`;
  `FUN_08254cc8` schreibt das Containerende als `tag | 0xc0000000`.
- `FUN_082350fc` schreibt einen 4-Byte-Feldtag, danach `Länge=4` und den
  4-Byte-Wert, dann `tag | 0x80000000` als Feldende.
- `FUN_08250be0` schreibt für `0x44` denselben Feldtag, die 32-Bit-Länge, genau
  diese Zahl an Nutzbytes und das Feldende `tag | 0x80000000`.

Damit ist ein überlanges `0x44`-Feld im beobachteten Wire-Format darstellbar;
die Schreibbarkeit der Datei auf dem iPod ist davon unabhängig und ungeklärt.
Bei erfolgreichem Abschluss löscht der Writer das Dirty-Flag. Der Parser löscht
dasselbe Flag am Exit.

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
- Rücksprungkontrolle und ein geeignetes Pop-Gadget sind statisch belegt. Die
  ROP-Folge bis zum Loader-Entry ist abgezählt, aber nicht serialisiert oder
  ausgeführt. Provider-Erfolg, RAM-/Stack-Überlappung und die konkrete
  dynamische Basis des mit `0x20000` Byte angeforderten MainAppTask-Stacks sind
  noch offen.
- Die RAM-/MMU-Eigenschaften und der Hold-gesperrte Apple-Fallback bleiben
  ungeprüft.
- Die Hold-Prüfung und der Fallback zum signierten iPod-OS sind damit nicht
  gelöst.

## Nächste statische Schritte

1. Prüfen, ob der Host `accessories.reg` über den normalen USB-Datenpfad
   ersetzen kann; das Wire-Format ist mit Writer und echtem Beispiel
   abgeglichen.
2. Die abgezählte ROP-Folge vollständig in das bestätigte Format einordnen und
   die Pfadauflösung für `/.rockbox/bootloader.bin` offline prüfen.
   `rockbox.ipod` und `n5g-ramdisk.img` liegen bereits unter `/.rockbox/`;
   `bootloader.bin` liegt derzeit nur im lokalen Build.
3. Die angeforderte MainAppTask-Stackgröße ist im Runtime-Dump mit `0x20000`
   Byte ermittelt; dynamische Stackbasis, Mapping und nötige Kontextobjekte
   bleiben offen. Der ROP-Pfad braucht keinen ausführbaren Stack.
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
- `/tmp/OSOS_playcounts_stream_bounds_20261026.txt` – disassemblierter Aufruf
  von `FUN_082721f0`; die dort sichtbaren `0x8000` sind nach Prüfung der
  Wrapper-Initialisierung als Puffergröße einzuordnen, nicht als Dateilimit.
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
  `/tmp/OSOS_function_0827ea84_20261026.txt`,
  `/tmp/OSOS_function_08271014_20261026.txt` und
  `/tmp/OSOS_function_0818f134_20261026.txt` – Öffnen, Pufferaufbau und Lesen
  von Streams.
- `/tmp/OSOS_timer_reader_state_20261026.txt`,
  `/tmp/OSOS_timer_wrapper_read_0820cc90_20261026.txt` und
  `/tmp/OSOS_timer_stream_functions_20261026.txt` – Restlängenzähler,
  Puffer-Refill und Provider-Weitergabe.
- `/tmp/OSOS_function_0818eb5c_20261026_followup.txt` und
  `/tmp/OSOS_runtime_cleanup_20261026.txt` – String-Kopie im Streamobjekt und
  Zuweisung der kopierten Zeichenkette.
- `/tmp/OSOS_runtime_accessories_second_caller_20261026.txt` – bedingter
  Writer von `accessories.reg`.
- `/tmp/OSOS_accessories_writer_helpers_runtime_20261026.txt` und
  `/tmp/OSOS_accessories_registry_helpers_20261026.txt` – read-only-Ghidra-
  Auszüge zu Feld-/Container-Tags und Längen-/Byte-Schreibreihenfolge.
- `/tmp/OSOS_accessories_open_path_helpers_20261026.txt` und
  `/tmp/OSOS_accessories_vfs_open_followup_20261026.txt` – Stringkopie beim
  Streamaufbau und dynamischer VFS-/Providerpfad.
- `/tmp/OSOS_function_0825da88_20261026.txt` – Writer-Aufrufer und umgebender
  Ereignis-/Zustandspfad.
- `/tmp/OSOS_runtime_stack_address_ops_20261026.txt` – Stackbezogene
  Instruktionssuche.
- `/tmp/OSOS_boot_mainapp_task_setup_20261026.txt`,
  `/tmp/OSOS_task_create_MainAppTask_helper_20261026.txt`,
  `/tmp/OSOS_task_api_0801d518_20261026.txt`,
  `/tmp/OSOS_task_create_0801de7c_20261026.txt` und
  `/tmp/OSOS_runtime_alloc_081a5b80_20261026.txt` – MainAppTask-Setup und
  Stackallokation.
- `/tmp/ipod-sebipod-readonly/iPod_Control/Device/accessories.reg` –
  read-only extrahierte 69-Byte-Gerätedatei.
