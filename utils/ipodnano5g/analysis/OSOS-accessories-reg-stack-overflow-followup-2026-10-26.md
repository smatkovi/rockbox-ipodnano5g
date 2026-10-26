# Früher OSOS-Parser für `accessories.reg`: Stack-Überlauf

Stand: 26.10.2026. Read-only-Disassemblierung und Analyse des vorhandenen
OSOS-Runtime-Abbilds `osos_runtime_dram_20261025.bin`. Zusätzlich wurde die
Datenpartition im Rockbox-USB-Modus read-only eingehängt und
`iPod_Control/Device/accessories.reg` gelesen. Es wurden keine Gerätedaten
geändert und keine DFU-, Boot-, NAND-/NOR- oder Flashoperation ausgeführt;
keine Tests oder Builds.

## Ergebnis

Der Parser für `iPod_Control/Device/accessories.reg` wird im frühen
MainApp-Factory-Pfad aufgerufen. Wenn sein Datei-Open gelingt und ein Token
`0x44` gelesen wird, benutzt er eine dateigesteuerte 32-Bit-Länge als Leselänge
für einen lokalen 256-Byte-Puffer, ohne den an den Helper übergebenen
Grenzwert `0x100` anzuwenden. Der Stackpufferüberlauf ist in diesem Parser
statisch belegt: Er kann das lokale Stringobjekt, den gespeicherten LR und bei
längerer Eingabe den Caller-Stack überschreiben. Die vorgeschaltete
VTable-Verwendung und der Aufräumpfad lassen sich mit gültigen Objektwerten
durchlaufen. Ein vorhandenes `pop {r0,r1,r2,r3,r4,pc}`-Gadget ermöglicht
danach eine dateikontrollierte ROP-Folge in OSOS-Code. Der interne Writer und
die echte 69-Byte-Datei stimmen beim Binärformat überein; eine Feldlänge von
`0x2c4` passt strukturell in dieses Format. Die abgezählte Loaderfolge bleibt
ungetestet: Datei-Open, Read und Rockbox-Handoff sind nicht verifiziert; ein
neuer LFN-Befund im generischen FAT-Pfadauflöser kann den Read vorher
unterbrechen.

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

Das belegt statisch, dass ein erfolgreicher langer Datei-Read eine Kontrolle
des Rücksprungs und eine ROP-fähige Register-/Stackfolge in vorhandenem
OSOS-Code ermöglichen kann. Der automatische Factory-Aufruf des Parsers ist
belegt, nicht jedoch ein erfolgreicher Open/Read bis zu diesem Feld. Zusätzlich
ist bei `0x08030cbc`
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

Der Stream-Wrapper `FUN_0819878c` baut den inneren Stream auf. `FUN_08224970`
kann für Streammodus 0 Pfadkomponenten an `FUN_082284e0` übergeben. Der unten
beschriebene Kandidat nutzt `FUN_082721f0(..., mode=0)`, das den Modus vor dem
Aufruf von `FUN_0827ea84` invertiert; der resultierende Streammodus ist 1 und
überspringt diese spezielle Komponenten-Schleife. Die konkrete Root-Mount-
Zuordnung für `/.rockbox/bootloader.bin` ist in den statischen Daten weiterhin
nicht belegt.

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
treffen, bleibt offen. Die Ausführbarkeit des Zielbereichs ist im
MMU-Nachtrag unten statisch belegt; der erste `BLX`-Übergang und die
Weiterverwendung des OSOS-Zustands sind nicht dynamisch verifiziert.

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
Volume read-only eingehängt. Der aktuelle Rockbox-USB-Modus exportiert drei
SCSI-LUNs:

| Hostgerät | SCSI-Produkt | Größe | Schreibstatus | Zuordnung |
| --- | --- | ---: | --- | --- |
| `/dev/sda` | `Rockbox Ramdisk` | 8 MiB | schreibbar | RAM-Dateisystem, nicht persistent |
| `/dev/sdb` | `Apple iPod Nano 5G` | 14,9 GiB | geschützt | Datenpartition mit `SEBIPOD` |
| `/dev/sdc` | `Apple iPod Nano 5G FTL` | 15,1 GiB | geschützt | vollständige logische FTL-Sicht |

Die Zuordnung ist durch SCSI-Inquiry-Namen, Größen und die Linux-Meldungen vom
26.10.2026 belegt. Der Quellcode erklärt den Status: Die N5G-Konfiguration
ordnet die RAM-Disk zuerst ein; danach meldet der NAND-Treiber die Daten-
partition und die vollständige FTL-Sicht als zwei weitere Drives. Für
`IPOD_NANO5G` wird `NAND_WRITABLE` nicht definiert, daher liefert
`nand_readonly()` für beide NAND-Drives `true`. `usb_storage.c` setzt damit im
SCSI-MODE-SENSE das Write-Protect-Bit und beantwortet SCSI-WRITE-Befehle mit
`DATA_PROTECT`/`WRITE_PROTECTED`. Linux meldete für `/dev/sdb` und `/dev/sdc`
entsprechend `Write Protect is on`; die RAM-Disk `/dev/sda` meldete
Schreibschutz aus. Ein Remount der Datenpartition als RW scheiterte; auch
`blockdev --setrw` änderte den vom Gerät gemeldeten Schutz nicht. In dieser
Sitzung wurden keine Sektoren geschrieben. Die RAM-Disk ist laut
`ramdisk_write_sectors()` nur ein Speicherbereich bei `RAMDISK_ADDR`; ihre
Änderungen wären flüchtig und würden den benötigten persistenten Trigger nicht
ersetzen. Ob Apples eigener USB-Disk-Modus die Datenpartition beschreibbar
exportiert, bleibt für dieses Gerät noch ungetestet. Apples Anleitung beschreibt
für iPod nano die Verwendung als Festplatte und das Kopieren beliebiger Dateien
zum Gerät; das macht einen schreibbaren Hostpfad plausibel, belegt aber nicht,
dass genau `iPod_Control/Device/accessories.reg` dort ersetzt werden kann:
[Apple Support: iPod als Festplatte verwenden](https://support.apple.com/en-my/guide/itunes/itns3114/windows).

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
  über Apples USB-/OSOS-Dateipfad gezielt ersetzt werden kann, bleibt offen.
  Im aktuellen Rockbox-Modus ist die NAND-Datenpartition durch das Gerät
  schreibgeschützt; nur die flüchtige RAM-Disk ist schreibbar.
- Der FAT-Open-Callback `FUN_0812a870` und sein Fallback erreichen beide
  `FUN_081382c2`. Dessen LFN-Pfadauflöser speichert einen Stackpufferzeiger als
  Verzeichniseintragsindex und kann dadurch den Datei-Open für LFN-Pfade
  unterbrechen. Die statische Factory-Kette belegt daher nicht, dass die
  tatsächliche `accessories.reg`-Nutzlast den überlaufenden Read erreicht.
- Rücksprungkontrolle und ein geeignetes Pop-Gadget sind statisch belegt. Die
  ROP-Folge bis zum Loader-Entry ist abgezählt, aber nicht serialisiert oder
  ausgeführt. Provider-Erfolg, RAM-/Stack-Überlappung und die konkrete
  dynamische Basis des mit `0x20000` Byte angeforderten MainAppTask-Stacks sind
  noch offen.
- Die statische MMU-Analyse bestätigt ausführbaren, privilegiert
  schreibbaren DRAM bei `0x09000000`. Stack-/Heap-Überschneidung, der
  tatsächliche Loader-Handoff und der Hold-gesperrte Apple-Fallback bleiben
  ungeprüft.
- Die Hold-Prüfung und der Fallback zum signierten iPod-OS sind damit nicht
  gelöst.

## Nächste statische Schritte

Der vorhandene Devloop bietet einen Rückweg von Rockbox zur U-Boot-USB-Konsole
ohne DFU: `n5g-cycle.sh` wirft alle drei LUNs aus; `devloop_tick()` erkennt
`devloop_usb_ejected` und kehrt mit `devloop_return_to_uboot()` zur Konsole
zurück. `n5g-shellboot.sh` kann von dort Rockbox erneut aus RAM laden. Das ist
ein wiederholbarer Rockbox-Testzyklus, aber kein Rückweg aus dem Apple-OS.
Laut README beendet ein OSOS-Handoff die U-Boot-Sitzung; ohne physisches DFU
ist die Rückkehr nicht belegt. Deshalb wurde der Apple-USB-Modus hier nicht
gestartet.

1. Statisch weiterverfolgen, ob Apples eigener USB-Disk-Modus oder ein OSOS-
   Dateipfad `accessories.reg` persistent verändern kann. Apples Anleitung
   bestätigt allgemeines Dateikopieren im Disk-Modus, der Zugriff auf genau
   diese Systemdatei bleibt zu prüfen. Der Rockbox-USB-Modus erlaubt auf dem
   iPod nur RAM-Disk-Schreibzugriffe.
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
- `firmware/export/config/ipodnano5g.h`,
  `firmware/target/arm/s5l8702/ipodnano4g/nand-target.h`,
  `firmware/target/arm/s5l8702/ipodnano4g/nand-nano4g.c` und
  `firmware/storage.c` – Drive-Reihenfolge, fehlendes `NAND_WRITABLE` und
  `storage_readonly()`-Zuordnung.
- `firmware/usbstack/usb_storage.c` und `firmware/drivers/ramdisk.c` – SCSI-
  Write-Protect-Antworten sowie RAM-Disk-Schreibpfad.
- `lsblk -o NAME,TRAN,HCTL,RO,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS`, SCSI-Inquiry
  aus `dmesg --ctime` und `lsusb -d 05ac:1265 -v` vom 26.10.2026 – drei
  exportierte LUNs und deren Schreibstatus im angeschlossenen Rockbox-Modus.
- `/tmp/ipod-sebipod-readonly/iPod_Control/Device/accessories.reg` –
  read-only extrahierte 69-Byte-Gerätedatei.

## Nachtrag: Service-Slot 0 und Dateizugriff des Loader-Kandidaten

Der Loader-Kandidat öffnet `/.rockbox/bootloader.bin` mit
`FUN_082721f0(..., mode=0)`. Der disassemblierte Helper übergibt an
`FUN_0827ea84` als Service-ID ausdrücklich `0`; `FUN_0827ea84` reicht Pfad,
Modus und Service-ID an `FUN_0819878c` weiter. Damit hängt dieser Kandidat
konkret von einem nutzbaren Dienst in Registry-Slot 0 ab.

`FUN_0827faca` holt den Dienst über `FUN_0818e934` und `FUN_08268cda`. Ist der
Slot leer, liefert die Lookup-Routine `FUN_0823fad4` als Fallback. Dessen
Konstruktor `FUN_08289208` setzt VTable `0x08536a78` und initialisiert unter
anderem die Felder `+0x04` und `+0x0c` auf null. Der Pfad-Komponenten-Callback
bei VTable-Offset `+0x58` ist `FUN_0813749c`; er gibt immer null zurück und
liefert damit selbst keinen Dateizugriff. Entscheidend ist der abschließende
virtuelle Aufruf bei `FUN_08224970`: Im Fallback zeigt VTable-Offset `+0x14`
auf `FUN_081c6996`, das bei einem Nullfeld `+0x0c` oder fehlendem Objekt bei
`+0x04` sofort Fehlercode `2` zurückgibt. `FUN_082721f0` verwirft daraufhin
den Stream. Wenn Slot 0 beim betreffenden Aufruf leer ist, kann der Kandidat
die Loader-Datei somit nicht lesen.

Die Kaltstart-Registrierung von Slot 0 bleibt offen. Der Manager wird von
`FUN_08020448` mit sieben leeren Slots angelegt. Die registrierten Dienste
werden über `FUN_0818e998` eingetragen. Dessen direkter Wrapper
`FUN_082154b8` wird im analysierten Code für Slots 4, 5 und 6 benutzt; der
`rsrc`-Zweig registriert Slot 4, nachdem er bereits Slot 0 abgefragt hat.
Der weitere direkte Wrapper `FUN_08000a10` kann eine Partition als Dienst
eintragen. Eine spätere Thumb-Nachprüfung fand den Caller in `PCFPowerMgr`,
Fall 0: `0x08010cc4` ruft `FUN_08000a10(r5, 0)` auf. Damit ist ein bedingter
Registrierungsversuch für Slot 0 statisch belegt. Ob der Task im normalen
Gerätelauf startet und Fall 0 vor dem frühen MainApp-Parser erreicht, sowie ob
Slot 0 dabei tatsächlich auf das FAT-Dateisystem zeigt, ist nicht dynamisch
bestätigt. Die frühere Zuordnung des Callers zu `DeviceDiscovery` war falsch;
Details und Task-Datensatz stehen in
`OSOS-vfs-registration-caller-followup-2026-10-26.md`.

Eine erweiterte Xref-Prüfung aller Aufrufer von `FUN_0818e934` bestätigt diese
Lücke: Die Startup-Funktion `FUN_080202d8` ruft `FUN_08021d08` auf; dieser holt
den Registry-Manager und ruft danach nur `FUN_08029e80` auf, einen einzelnen
`bx lr`-Stub. Der weitere Registry-Mutator `FUN_080e7e70` setzt einen
vorhandenen Slot auf null und wird über `FUN_0821545a` zum Entfernen benutzt.
Die anderen direkten Manager-Aufrufer sind Lookups, Synchronisation oder
Statusabfragen. Die beiden gefundenen direkten Insert-Wrapper sind
`FUN_082154b8` und `FUN_08000a10`; der zuvor übersehene Caller von
`FUN_08000a10` ist der Thumb-Aufruf bei `0x08010cc4`. Im Runtime-Abbild gibt es
keinen absoluten Pointer auf `0x08000a10`/`0x08000a11`; die Caller-Nachprüfung
fand auch keinen weiteren indirekten Pointer-Verweis. Die alte Aussage, für
`FUN_08000a10` gebe es keinen Code-Xref, ist überholt.

Der komplette Xref-Auszug liegt unter
`/tmp/OSOS_vfs_manager_all_xrefs_20261026.txt`; die untersuchten Startup-,
Insert-, Remove- und Statusfunktionen sind in den übrigen Rohbelegen unten
aufgeführt.

Damit ist eine konkrete Schranke des aktuellen Exploit-Kandidaten verifiziert:
Die ROP-Folge kann nicht allein aufgrund eines erfolgreichen Stream-Objekt-
Aufbaus als lauffähig gelten. Sie benötigt einen aktiven Slot-0-Provider,
erfolgreiche Pfadauflösung und lesbare Bytes der Loader-Datei. Keine dieser
drei Eigenschaften wurde hier auf dem Gerät getestet; es gab keine USB-,
NAND- oder NOR-Schreiboperation.

Rohbelege: `/tmp/OSOS_vfs_candidate_open_helper_20261026.txt`,
`/tmp/OSOS_vfs_stream_factory_20261026.txt`,
`/tmp/OSOS_vfs_service_handle_20261026.txt`,
`/tmp/OSOS_vfs_service_lookup_20261026.txt`,
`/tmp/OSOS_eapp_vfs_normalization_20261026.txt`,
`/tmp/OSOS_vfs_fallback_vtable_20261026.txt`,
`/tmp/OSOS_vfs_fallback_open_method_20261026.txt`,
`/tmp/OSOS_vfs_fallback_blockop_20261026.txt`,
`/tmp/OSOS_vfs_manager_getter_20261026.txt`,
`/tmp/OSOS_runtime_service_registry_setters_20261026.txt`,
`/tmp/OSOS_runtime_provider_reg_callers_20261026.txt`,
`/tmp/OSOS_disk_provider_parser_a_20261026.txt`,
`/tmp/OSOS_disk_provider_parser_b_20261026.txt` und
`/tmp/OSOS_disk_provider_parser_c_20261026.txt`.

## Nachtrag: Queue-4-Produzent und mögliche Slot-0-Erreichbarkeit (26.10.2026)

Der zuvor offene Queue-Produzent wurde im ATA-Worker eingegrenzt. `PCFPowerMgr`
wartet auf Queue 4; `ATAWorkLoopTask` stellt beim Einstieg aus
`FUN_0833cc58` einen statischen Queue-Datensatz ein. Der Pointer bei
`0x0833ccd0` ist little-endian `0x08e51d7c`. Der frühe Resetpfad ruft
`FUN_08005fec` auf und nullt den Bereich `0x086c43a8..0x08e54e4b`, der diesen
Knoten enthält. Der Sender setzt Ereignisbyte `+0x10` im bedingten Zweig auf
0; im anderen Zweig schreibt er es vor dem Post nicht. Unter der Annahme,
dass kein anderer Pfad den Knoten vorher verändert, ist deshalb ein Ereignis
Typ 0 plausibel.

Der Fall 0 in `PCFPowerMgr` ruft `FUN_08000a10(r5, 0)` auf. `r5` stammt aus
`FUN_0819ae24(1)`, das für diesen Modus ein Objekt über `FUN_0833a5e0`
erzeugt. Damit gibt es jetzt einen konkreten statischen Produzenten und einen
passenden Empfänger für den Slot-0-Registrierungsversuch. Noch offen bleibt,
ob der ATA-Objektaufbau und beide Tasks im normalen Kaltstart vor dem frühen
`accessories.reg`-Parser tatsächlich laufen. Für den ATA-Aufbau führen die
gefundenen direkten Getter-Aufrufe über `FUN_0801f74a` und `FUN_0833b000`;
deren Verbindung zu einem automatisch vorher ausgeführten Startpfad ist
weiterhin nicht belegt.

Der Slot-0-Inhalt ist ebenfalls nicht identifiziert. `FUN_0833a5e0` richtet
einen internen Provider-/Pufferkontext ein, aber die vorliegende statische
Analyse beweist nicht, dass dieser Provider FAT-Dateien über
`/.rockbox/bootloader.bin` lesen kann. Es gibt weiterhin keinen Nachweis,
dass der `accessories.reg`-Überlauf beim Kaltstart erreicht wird, den
Rücksprung kontrolliert oder beliebigen Code ausführt. Der Loader-Handoff
bleibt ein bedingter Kandidat.

Rohbelege zum Nachtrag: `utils/ipodnano5g/analysis/OSOS-vfs-registration-caller-followup-2026-10-26.md`,
`/tmp/OSOS_runtime_service4_queue_senders_20261026.txt`,
`/tmp/OSOS_queue_node_literal_refs_20261026.txt`,
`/tmp/OSOS_PCFPowerMgr_event_services_20261026.txt`,
`/tmp/OSOS_pcf_provider_ctor_20261026.txt`,
`/tmp/OSOS_pcf_creation_xrefs_20261026.txt` und
`nano5g/ghidra-logs/OSOS_mmu_preinit_2026-10-25.txt`.

## Korrektur: MBR-Registrierung erzeugt einen FAT-kompatiblen Volumehandler (26.10.2026)

Eine gezielte Nachverfolgung der `FUN_08000a10`-Implementierung präzisiert
den Slot-0-Kandidaten: Der Runtime-Alias führt zum Bodencode `FUN_0802ec8c`,
der Sektor 0 liest, im MBR-Fall die erste passende Partition aus den FAT-
Partitionstypen `0x01`, `0x04`, `0x06`, `0x0b`, `0x0c` und `0x0e` auswählt und
den MBR-Handler über `FUN_081bcc14` unter Slot 0 einträgt. Der Typ-2-Zweig
erstellt über `FUN_0826b6e4` den MBR-Volumehandler und initialisiert dessen
Dateisystemkontext mit `FUN_0813f0ac`. Der frühere Satz, der
Slot-0-Provider sei nicht als FAT-fähig belegt, ist damit korrigiert: Die
statische Konstruktion passt grundsätzlich zum Zugriff auf
`iPod_Control/Device`; einen erfolgreichen Datei-Open belegt sie nicht.

Offen bleiben die Ausführung des ATA-Initialisierers und des Queue-4-Ereignisses
vor dem MainApp-Parser, die erfolgreiche Laufzeit-Pfadauflösung und die
Ersetzbarkeit von `accessories.reg`. ROP-Bytes wurden nicht ausgeführt; ein
Loader-Handoff oder beliebige Codeausführung ist weiterhin nicht verifiziert.

Rohbelege: `/tmp/OSOS_body_FUN_0802fbe8_20261026.txt`,
`/tmp/OSOS_body_FUN_0802f4c8_20261026.txt`,
`/tmp/OSOS_body_FUN_0802ec8c_recheck_20261026.txt` und
`/tmp/OSOS_body_vfs_registry_insert_20261026.txt`.

## Nachtrag: FAT-Volume-VTable und Pfadauflösung (26.10.2026)

Der MBR-Volumehandler aus `FUN_0813f0ac` verwendet im Runtime-Abbild die
VTable `0x085056b0`. Das wurde durch Abgleich des Body-Literals mit den rohen
Runtime-Wörtern bestätigt. Der Eintrag bei `+0x14` ist `0x0812a871`, also der
Thumb-Open-Callback `FUN_0812a870`; `+0x50` ist `0x0812aa07`, der
Pfad-/Metadaten-Callback `FUN_0812aa06`. Damit ist die zuvor generisch
vermutete Open-Schnittstelle für genau diesen FAT-Volumehandler identifiziert.

Der normale Open-Callback kopiert und normalisiert den Pfad, prüft ihn mit
`FUN_081e1694` und ruft anschließend den generischen Dateiöffner
`FUN_081382c2` auf. Die Prüfung verwirft Komponenten mit mehr als 255 Byte und
Gesamtpfade ab 260 Byte. Der Pfad `/.rockbox/bootloader.bin` ist 24 Byte lang
und liegt innerhalb dieser Grenzen. Die Verzeichnisauflösung verwendet
`FUN_081fdad2`, um den Standardlaufwerksindex aus dem per Task geführten
VFS-Kontext zu holen, prüft den Index auf 0 bis 3 und beginnt bei einem
absoluten Pfad am Root dieses Laufwerks. `FUN_081fdb38` zerlegt anschließend
die Pfadkomponenten in einen 256-Byte-Puffer. Im normalen Open-Pfad liegt
dieser Auflösung die genannte Längenprüfung voraus; die Splitterfunktion selbst
hat keine eigene Kapazitätsprüfung.

Das schließt eine Teilfrage des Loader-ROP-Kandidaten: Der MBR-Volumehandler
hat echte FAT-Open- und Pfadabfrage-Methoden, und der fest verdrahtete
Rockbox-Pfad passt in die sichtbaren Limits. Es beweist jedoch nicht, dass der
MainApp-Task beim Parser den passenden Standardlaufwerksindex ausgewählt hat,
dass Slot 0 zu diesem Zeitpunkt registriert ist, dass die Datei geöffnet und
vollständig gelesen wird oder dass die Folge den Loader erfolgreich startet.
Die Ausgabe der Candidate-ROP-Kette prüft Open-/Read-Statuswerte nicht; ein
Fehler kann daher statt Rockbox einen ungültigen Sprung bzw. Absturz ergeben.

Diese Nachverfolgung fand in den geprüften Pfadhelfern keinen zusätzlichen
Überlauf: Die auffällige unbeschränkte Komponenten-Kopie wird im normalen
Open-Callback durch die vorgeschaltete Pfadprüfung eingegrenzt, und die
konkrete ROP-Zielzeichenkette ist kurz. Das ist ein begrenzter Negativbefund,
kein vollständiger Audit aller VFS-Aufrufer.

Rohbelege: `/tmp/OSOS_runtime_fat_vfs_callbacks_20261026.txt`,
`/tmp/OSOS_runtime_fat_open_helpers_20261026.txt`,
`/tmp/OSOS_runtime_fat_path_resolution_20261026.txt`,
`/tmp/OSOS_runtime_fat_component_helpers_20261026.txt`,
`/tmp/OSOS_runtime_fat_mount_path_semantics_20261026.txt`,
`/tmp/OSOS_runtime_fat_default_service_followup_20261026.txt` und
`/tmp/OSOS_runtime_vfs_context_accessors_20261026.txt`. Alle Headless-Ghidra-
Läufe verwendeten `-noanalysis -readOnly`; keine Geräte-, USB-, DFU-, Boot-
oder Flashoperation wurde ausgeführt.

## Präzisierung: Loader-Stream bis zum FAT-Open-Callback

Die weitere Auflösung zeigt, dass der Kandidat bei registriertem Slot 0 nicht
beim generischen Fallback stehenbleibt. `FUN_0827ea84` ruft
`FUN_0819878c` mit Service-ID 0 und Öffnungsmodus 1 auf. `FUN_0819878c`
erzeugt mit `FUN_082784c8` den Dienstwrapper; `FUN_0827faca` fragt über
`FUN_08268cda` genau Slot 0 ab, und `FUN_0826384c` prüft, ob dieser Slot
belegt ist. Anschließend dispatcht `FUN_08224970` für den Öffnungsmodus über
VTable-Offset `+0x14`. Beim bestätigten MBR-Volumehandler zeigt dieser Eintrag
auf `FUN_0812a870`, der den Pfad normalisiert, Komponenten- und Gesamtlänge
prüft und den generischen FAT-Dateiöffner aufruft. Die Registry-Slot-ID des
Loader-Streams und die FAT-Open-Methode sind damit statisch verbunden.

Der darunterliegende Resolver nimmt bei einem Pfad ohne Laufwerkspräfix den
Standardindex aus dem aktuellen Taskkontext. `FUN_08229b84` nullt einen neu
angelegten 0x38-Byte-Kontexteintrag; im untersuchten Abbild liest
`FUN_08158f74` dessen Feld `+8`, aber unter den direkten Aufrufern von
`FUN_08229b84` wurde kein Schreiber dieses Felds gefunden. Das spricht für
Standardindex 0 im unveränderten Kontext, schließt indirekte oder externe
Schreiber jedoch nicht aus. Ein erfolgreiches Öffnen beziehungsweise Lesen
auf dem Gerät bleibt unbewiesen.

Die dokumentierte Installation auf der Nutzdaten-FAT enthält
`/.rockbox/rockbox.ipod` und `/.rockbox/n5g-ramdisk.img`; `bootloader.bin`
wurde im bisherigen Workflow vom PC nach SDRAM übertragen. Die lokale Datei
`build-n5g-blramdisk/bootloader.bin` ist aktuell 69.504 Byte groß und hat
SHA-256 `09b2dc3ff4940855b175508ce817c5f913798f3d7b2ba7669edef3427e224d03`.
Für den hier abgezählten Dateiladepfad müsste diese Datei erst zusätzlich als
`/.rockbox/bootloader.bin` auf der Nutzdaten-FAT liegen. Das wurde hier nicht
auf das Gerät kopiert.

Rohbelege: `/tmp/OSOS_runtime_loader_stream_path_followup_20261026.txt`,
`/tmp/OSOS_runtime_loader_stream_slot0_followup_20261026.txt`,
`/tmp/OSOS_runtime_slot_registry_dispatch_20261026.txt`,
`/tmp/OSOS_runtime_fat_default_service_followup_20261026.txt`,
`/tmp/OSOS_runtime_vfs_context_accessors_20261026.txt`,
`/tmp/OSOS_runtime_fat_vfs_callbacks_20261026.txt` und
`utils/ipodnano5g/README.md`. Ghidra lief mit `-readOnly -noanalysis`; die
lokale Binärdatei wurde nur mit `stat` und `sha256sum` gelesen.

## Nachtrag: Erfolgreicher Overflow-Trigger belegt denselben VFS-Slot (26.10.2026)

Die Slot-0-Abhängigkeit des ROP-Open-Aufrufs lässt sich mit dem Eingabepfad
selbst verknüpfen. Der verwundbare Parser `FUN_0802c3c4` öffnet
`iPod_Control/Device/accessories.reg` bei `0x0802c3f8` über
`FUN_082721f0(..., mode=0)`. Dieser Wrapper übergibt an `FUN_0827ea84` denselben
Service-Slot `0` und denselben internen Open-Modus `1` wie der abgezählte
ROP-Aufruf für `/.rockbox/bootloader.bin`. Der Parser prüft den Open-Status und
kehrt bei einem Fehler zurück, bevor er Token `0x44` lesen kann. Eine
tatsächlich ausgelöste Überlänge setzt daher voraus, dass Slot 0 den
Registry-Stream erfolgreich geöffnet hat.

Der Registry-Stream wird am Parserende geschlossen, der VFS-Provider selbst
wird dabei nicht aus Slot 0 entfernt. Der ROP-Kandidat öffnet den Loader direkt
nach Parserrückkehr im selben `MainAppTask`-Kontext und verwendet denselben
Standardlaufwerkskontext. Damit ist „Slot 0 war beim Overflow leer“ keine
zusätzliche unabhängige Bedingung: Bei erfolgreichem Overflow-Trigger war der
für beide Öffnungen verwendete Dienst bereits aktiv. Statisch offen bleibt,
ob der automatische Kaltstartaufruf den Registry-Open tatsächlich erfolgreich
erreicht und ob ein anderer Task den Provider genau in diesem kurzen Fenster
entfernen kann. Der erfolgreiche Loader-Open/Read, der Rücksprung in den
geladenen Code und ein Gerätelauf sind weiterhin nicht bestätigt.

Rohbelege: `/tmp/OSOS_accessories_parser_same_service_20261026.txt`,
`/tmp/OSOS_vfs_candidate_open_helper_20261026.txt`,
`/tmp/OSOS_vfs_stream_factory_20261026.txt` und
`/tmp/OSOS_accessories_open_path_helpers_20261026.txt`.

## Nachtrag: Loader-Ziel liegt in ausführbarer DRAM-Abbildung (26.10.2026)

Die zuvor offene XN-Frage ließ sich statisch auflösen. Die Bootprefix-Startkette
ruft `FUN_08005d3c` bei `0x080050c8` auf. Dessen Aufruf bei `0x08005da8` reicht
dem Abschnittsmapper die Werte `Start=0x08000000`, `Ende=0x0bffffff`,
`Physisch=0x08000000` und Attribute `0x00007c0e` weiter. Der indirekte Stub
`0x08003970` zeigt im Runtime-Abbild auf Thumb-Code bei `0x080e3e84`. Dieser
Mapper nimmt 1-MiB-Abschnittsindizes, berechnet Einträge ab der Seitentabelle
`0x086dc000` und schreibt für den DRAM-Bereich physische Adressen plus die
übergebenen Attribute. Damit umfasst die Identitätsabbildung 64 Abschnitte
einschließlich `0x09000000`.

Die Initialisierung setzt außerdem SCTLR.XP (Bit 23) über
`FUN_08004900` (`orr #0x00800000`) und aktiviert anschließend MMU und
Seitentabelle. Im ARMv6-Abschnittsdeskriptor `0x7c0e` ist XN (Bit 4) null;
laut ARM1176JZF-S-TRM bedeutet ein gelöschtes XN-Bit, dass Instruktionen aus
der Region ausgeführt werden dürfen. AP[1:0]=3 und APX=0 lassen den Bereich
auch für privilegierte Tasks les- und schreibbar. Der SVC-Taskkontext ist im
separaten Bericht belegt. Der read-only CP15-Scan findet im untersuchten
Abbild keinen weiteren Schreibzugriff auf TTBR nach dieser Initialisierung.

Der vorhandene Rockbox-Loader bereinigt vor dem Hand-off D-Cache und
Write-Buffer und verwirft stale I-Cache-/Prefetch-Zustand; sein Startcode
schaltet danach MMU und Caches ab. Die statischen Quellstellen stehen in
`firmware/target/arm/s5l8702/crt0.S` (N5G-Zweig ab `start_loc`). Damit ist eine
fehlende XN-Ausführbarkeit oder ein ungeklärter Cache-Flush kein sichtbarer
Blocker für den Sprung nach `0x09000000`.

Grenze: `0x09000000` liegt in der von OSOS verwalteten Heapregion. Die
MainAppTask-Stackbasis und die zur Laufzeit betroffenen Heapobjekte sind im
statischen Abbild nicht rekonstruierbar. Ein Lesen des Loaders dorthin könnte
also laufende Daten oder den aktiven Stack überschreiben; der geplante
Übergang ist nur als endgültiger Einweg-Handoff plausibel. Weder der
Datei-Read noch der Sprung wurden ausgeführt.

Rohbelege: `/tmp/OSOS_runtime_mmu_mapper_clarified_20261026.txt`,
`/tmp/OSOS_mmu_init_2026-10-25.txt`,
`/tmp/OSOS_cp15_scan_2026-10-25.txt`,
`utils/ipodnano5g/analysis/OSOS-task-context-privilege-handoff-2026-10-25.md`
und `firmware/target/arm/s5l8702/crt0.S`. Architekturreferenz:
[ARM1176JZF-S Technical Reference Manual, Abschnitte 3.2.1 und 6.5.3](https://documentation-service.arm.com/static/5e8e294efd977155116a6ca3).
Alle Projektdateien wurden nur gelesen; keine Geräte-, USB-, DFU-, Boot- oder
Flashaktion.

## Nachtrag: aktuelle VFAT-LFN-Namen und Open-Erreichbarkeit (26.10.2026)

Das angeschlossene Gerät wurde ohne DFU als `05ac:1265`-USB-Massenspeicher
erkannt. `/dev/sda1` war read-only unter `/tmp/ipod-sebipod-readonly`
eingehängt. Der Linux-ioctl `VFAT_IOCTL_READDIR_BOTH` bestätigte im aktuellen
Volume die Zuordnungen `IPOD_C~1` → `iPod_Control`, `DEVICE` → `Device` und
`ACCESS~1.REG` → `accessories.reg`. Die feste OSOS-Pfadzeichenkette verwendet
die Langnamen. Ihr erster Bestandteil trifft daher bereits im Volume-Root auf
einen VFAT-LFN-Eintrag; auch die spätere Datei ist ein LFN-Eintrag.

Zusammen mit der statischen LFN-Datenflussanalyse ist das ein konkreter Grund,
warum der automatische Parseraufruf nicht als erfolgreicher Datei-Open gelten
darf: Beim Folge-Kurznamen wird der Stackzeiger als Eintragsindex verwendet.
Wenn der erzeugte Langname dadurch nicht übereinstimmt, nimmt der Resolver den
8.3-Fallback `IPOD_C~1`, der ebenfalls nicht der angefragte Langname ist. Ein
Data Abort oder ein fehlender Match ist wahrscheinlich; ein erfolgreicher
Open ist ohne OSOS-Laufzeitbeobachtung nicht bestätigt. Der
USB-Massenspeichermodus liest die FAT vom Host, führt aber den OSOS-Datei-Open-
Callback nicht aus. Es wurde kein Neustart ausgelöst.

Im aktuellen `.rockbox`-Verzeichnis liegen `rockbox.ipod` und
`n5g-ramdisk.img`; `/.rockbox/bootloader.bin`, das die offline abgezählte
ROP-Folge derzeit öffnet, ist nicht vorhanden. Auch nach einer möglichen
Kontrollflussübernahme müsste der Payload-Pfad daher angepasst oder die Datei
später verfügbar gemacht werden. Es gab keine Schreiboperation.

Rohbelege: `/tmp/OSOS_live_vfat_dir_ioctl_20261026.txt`,
`/tmp/ipod_vfat_dir_ioctl.py`, `lsusb`, `fdisk -l /dev/sda` und der statische
Nachweis in `OSOS-FAT-LFN-index-taint-audit-2026-10-26.md`. Der MBR des
aktuellen Volumes meldet 4096-Byte-Sektoren, Start-LBA 63, Länge 3.901.312 und
3.901.376 Gerätesektoren insgesamt. Dieser Ist-Zustand testet keine präparierte
LBA-Kette.
