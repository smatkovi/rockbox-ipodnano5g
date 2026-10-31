# ATA-Cache-Wrap: Discovery- und Mountpfad im Runtime-Abbild

Stand: 31.10.2026. Statische Auswertung des read-only Runtime-Ghidra-Projekts
und der vorhandenen OSOS-Abbilder. In dieser Runde gab es keinen Gerätezugriff,
keine USB-/DFU-Aktion und keinen Flash-, NAND- oder NOR-Schreibvorgang.

## Ergebnis

Der frühere MBR-Cache-Wrap-Kandidat ist für den Discovery-Einstieg genauer
eingegrenzt. `DeviceDiscovery` liest zuerst LBA 0 über den Provider aus
`FUN_0819ae24(1)`. Derselbe Providerzeiger wird anschließend an
`FUN_0818e998` weitergereicht und als Unterobjekt des neu angelegten
Partitionsadapters gespeichert. Der MBR-Parser akzeptiert einen unterstützten
Partitionseintrag mit `Start = 0xffffffff` und `Länge = 1`, weil er sichtbar
nur Start und Länge auf null und die Länge gegen die Gerätesektorzahl prüft.

Ein Datei-Open auf Laufwerk 0 kann den FAT-Mountpfad auslösen. Der
BPB-Parser `FUN_0814ef74` fordert über `FUN_08158dd0` einen Ein-Sektor-Read
bei relativem LBA 0 an. Falls dieser Zugriff im dynamischen Laufwerks-I/O-
Dispatch beim registrierten Partitionsadapter und demselben ATA-Cacheprovider
ankommt, wird der MBR-Startwert als physische LBA an den Cache weitergereicht.
Mit dem früher read-only gemessenen 4096-Byte-Sektorformat ergibt sich für
`LBA = 0xffffffff`, `Count = 1` ein Cache-Hit-Wrap auf einen Quellzeiger
`cache_base - 0x1000`. Das ist ein möglicher Out-of-bounds-Read.

Die entscheidende Zuordnung des Laufwerks-I/O-Slots zu genau diesem
Partitionsadapter ist im vorliegenden RAM-Abbild nicht geschlossen. Eine
frühere Deutung der anschließenden Benachrichtigung als externem Callback war
falsch: Der Partitionsmanager leert eine interne Queue und übergibt das Feld
`+4` jedes Knotens an den OSOS-Präfixdienst `0x22005934`. Dieser legt einen
SVC-Aufruf mit Befehl 2 an; der Präfixhandler liest damit einen Eintrag aus
der Tabelle ab `0x2200980c`. Ein Funktionszeiger-Callback wird an dieser Stelle
nicht aufgerufen. Herkunft und Wertebereich des Queue-Felds `+4` sowie die
Queue-Produzenten sind noch nicht geklärt. Der Cache-Wrap bleibt daher ein
bedingter Speicherlesefehler, kein bestätigter automatischer Exploit. Ein
RAM-Write, kontrollierter Rücksprung oder Codeausführung ist nicht belegt.

## Verifizierte Kette

1. `FUN_0819ae24(1)` erzeugt bei Bedarf mit `FUN_0833a5e0` einen Provider.
   Dessen Konstruktor setzt die VTable auf `0x084fd570`. Die gespeicherten
   VTable-Wörter zeigen den Read-Wrapper bei `+0x14` auf Thumb-Adresse
   `0x0833a945` (`FUN_0833a944`); der vorhandene Read-Wrapper-Bericht ordnet
   diesen dem Cachepfad `FUN_0833a7fa` zu.
2. `FUN_08000a10` ruft `FUN_0800196c` auf. Diese liest LBA 0 mit Count 1 und
   parst danach MBR/GPT-Kennzeichen. Im MBR-Zweig werden FAT-Typen
   `0x01`, `0x04`, `0x06`, `0x0b`, `0x0c` und `0x0e` akzeptiert. Für einen
   akzeptierten Eintrag wird `FUN_0818e998` mit demselben Providerzeiger,
   Partition-Start und Partitionslänge aufgerufen.
3. Der Discovery-Aufruf übergibt `param9 = 0`; `FUN_0818e998` konstruiert
   daher den 0x58-Byte-Basisadapter über `FUN_0823d468`, nicht die 0x60-Byte-
   Cache-Unterklasse. Der Konstruktor speichert den Unterprovider bei `+4`,
   den Start bei `+0x10` und die Länge bei `+0x14`. `FUN_081c6996` rechnet
   relative Adressen in Geräteblöcke um und addiert den Start; in dieser
   Funktion ist keine Prüfung `relative_LBA + Count <= Partitionslänge`
   sichtbar.
4. Nach dem Eintrag in den Manager-Slot ruft `FUN_0818e998` `FUN_0819039e`
   auf. Diese setzt den Änderungszustand und leert die interne Queue bei
   `Manager + 0x34` über `FUN_0819f508`. Für jeden Knoten reicht diese Funktion
   dessen Feld `+4` unverändert an `FUN_081933f8` und den OSOS-Präfixdienst
   `0x22005934` weiter. Der Präfixdienst ruft SVC-Befehl 2 auf; dessen Handler
   indiziert die Tabelle ab `0x2200980c` mit diesem Wert. Ein direkter Aufruf
   des FAT-Mounters ist in `FUN_0819039e` nicht vorhanden.
5. Der VFS-Open-Einstieg `FUN_081382c2` ruft `FUN_081fdd06` auf.
   `FUN_081fdd06` stößt für den gewählten Index `FUN_0814e76c` an;
   `FUN_0816039c` kann danach `FUN_08158f90` und `FUN_0814ef74` ausführen.
   `FUN_08158dd0` fordert den ersten BPB-Sektor mit
   `FUN_082192c4(index, 0, buffer, 1, 0)` an. Die automatische
   `accessories.reg`-Pfaduntersuchung belegt statisch einen MainApp-Open ohne
   Laufwerkspräfix und damit den Standardindex 0; der erfolgreiche Open und
   eine daraus folgende Queuezustellung auf realer Hardware bleiben
   unbestätigt.
6. `FUN_082192c4` gelangt über `FUN_08160a3a` zu `FUN_0816a928`. Diese
   Funktion liest einen Objektzeiger aus der Tabelle an `DAT_0816a96c` und
   führt den Read indirekt aus. Die Tabelle liegt laut Ghidra bei
   `0x0883503c`, außerhalb des erfassten Runtime-Abbilds. Die Registrierung
   aus `FUN_0818e998` und dieser Tabellen-Slot sind statisch noch nicht
   miteinander verbunden.

## Cache-Arithmetik und Grenze der Aussage

Der vorherige ATA-Bericht belegt für die gelesene Sektorgröße 4096 Byte eine
Cachefüllung von höchstens acht Sektoren. Nach einem erfolgreichen Read von
LBA 0 ist der Cache ab LBA 0 gültig. Bei späterem `LBA = 0xffffffff`,
`Count = 1` laufen `LBA + max_count` auf 7 und `LBA + Count` auf 0 um.
Die sichtbaren 32-Bit-Vergleiche können dadurch den Cache-Hit-Zweig wählen;
der Quelloffset läuft auf minus 4096 Byte um. Der Lese-Wrapper kopiert dann
aus Speicher vor dem Cacheobjekt in den vom Aufrufer bereitgestellten
Puffer. Diese Aussage setzt voraus, dass der MBR-adapterbasierte Read den
Dispatch erreicht und der Cache nach LBA 0 gültig bleibt.

Der Rohbyte- und Ghidra-Abgleich an `DAT_0816a96c` stimmt überein: Die Bytes
`3c 50 83 08` kodieren little-endian `0x0883503c`, denselben Wert, den
Ghidra-`Data.getValue()` meldet. `0x0833503c` ist eine andere, im Snapshot
abbildbare Adresse und war irrtümlich mit dem Tabellenzeiger verwechselt
worden. Das Tabellenziel `0x0883503c` liegt weiterhin außerhalb der Aufnahme;
die vier Einträge sind damit aus diesem Abbild nicht auslesbar.

## Ergänzung vom 31.10.2026: gemeinsame Vierer-I/O-Tabelle

Ein Wortreferenzscan im Runtime-Abbild findet drei globale Zeigerzellen mit
demselben Wert `0x0883503c`: `DAT_08110e2c`, `DAT_08135320` und
`DAT_0816a96c`. Der erste gehört zum Freigabepfad, der zweite zur Registrierung
und der dritte zum Block-I/O-Dispatcher. Damit sind Registrierung/Freigabe und
`FUN_0816a928` statisch an dieselbe Vierer-Tabelle gebunden. Die Werte der
vier Tabellenplätze selbst liegen weiterhin außerhalb des Snapshots.

`FUN_081352fc` trägt ein Objekt mit leerem Feld `+0x10` in den ersten freien
Tabellenplatz 0 bis 3 ein und setzt das Feld auf `'A'` bis `'D'`. Sind alle
Plätze belegt, kehrt die Funktion zurück, ohne das Feld zu setzen.
`FUN_0816a928` liest aus derselben Tabelle den Platz für den übergebenen
Laufwerksindex und führt den Blockzugriff über das gefundene Objekt aus.
`FUN_08110e14` wandelt das Feld `+0x10` höchstens von Klein- in Großbuchstaben
um und schreibt danach ohne sichtbare Bereichsprüfung null an
`Tabelle + (Buchstabe - 'A') * 4`. Wenn das Feld nach einer erfolglosen
Registrierung null blieb, ergibt die sichtbare Arithmetik die Adresse
`0x08834f38`, 0x104 Byte vor Tabellenbeginn. Das ist derselbe bedingte
Nullschreibkandidat, der im älteren VFS-Bericht mit einem falschen
Funktionslabel dokumentiert war; ein kontrollierter Zeiger oder Codefluss
folgt daraus nicht.

`FUN_0812a9ca` ist als Thumb-Funktionszeiger `0x0812a9cb` bei `+0x28` in der
VTable ab `0x085056d0` abgelegt; der folgende Slot `+0x2c` zeigt auf die
Cleanup-Methode `FUN_0811ee70`. Die Mountmethode ruft `FUN_081352fc` auf, leitet
den Buchstaben an `FUN_08158f90` weiter und markiert das Objekt erst nach
erfolgreichem Parserpfad mit `FUN_081e0a28` als geöffnet. Ghidra findet keinen
direkten Codeaufrufer von `FUN_0812a9ca` und keine eingehenden Referenzen auf
die VTable-Region; der Wortscan belegt aber den VTable-Eintrag. Ein indirekter
Aufruf ist damit strukturell möglich, die konkrete Instanz und ihr Erzeuger
sind im Runtime-Abbild nicht belegt.

Die MBR-Discovery bleibt von diesem Mountpfad getrennt: `FUN_0818e998`
registriert den Partitionsadapter im Managerobjekt und löst über
`FUN_0819039e`/`FUN_0819f508` die Verarbeitung einer internen Queue aus.
Queue-Knoten reichen ihr Feld `+4` an den SVC-Befehl 2 des OSOS-Präfixes
weiter; das ist kein Aufruf eines Listener-Funktionszeigers. Im geladenen Code
gibt es keine direkte Kante von dieser Verarbeitung zu `FUN_0812a9ca` oder
`FUN_081352fc`. Außerdem verwendet der MBR-Partitionsadapter `+0x10` für
seinen Partitionsstart, während die Tabellenobjekte `+0x10` als Laufwerks-
buchstaben verwenden; für dieselbe I/O-Tabelle wäre daher ein zusätzlicher
Wrapper oder eine andere Instanz erforderlich. Die gemeinsame Tabelle
belegt damit für Objekte, die `FUN_0812a9ca` über `FUN_081352fc` registriert,
denselben Tabellenlink zum I/O-Dispatcher. Offen bleibt, ob der MBR-Adapterpfad
diese Methode erreicht und woher eine Instanz mit der Mount-VTable stammt.

Diese Nachprüfung korrigiert zwei alte Funktionslabels: Die Registrierung ist
`FUN_081352fc` (Runtime-Adresse; zugehörige Body-Adresse `0x08163578`), und
die Mountmethode ist `FUN_0812a9ca` (Runtime-Adresse; zugehörige Body-Adresse
`0x08158c46`). Die früher dazu notierten Labels `FUN_081353fc` und
`FUN_0812c9ca` waren falsch. Der Offset zwischen Runtime- und Body-Adressen
beträgt `0x2e27c`.

### Statuspfad bei ausgeschöpfter Tabelle

Der Überlaufindex aus einem nicht vergebenen Laufwerksbuchstaben führt im
BPB-Parser nicht selbst zu einem Zugriff außerhalb der Zustandsliste.
`FUN_0814ef74` kopiert den Index nach `r6` und übergibt ihn in `r0` an
`FUN_08200c32`; diese Funktion akzeptiert nur vorzeichenlos Werte kleiner als
4. Für `-65` (32-Bit `0xffffffbf`) liefert sie 0, worauf `FUN_0814ef74` vor
dem Zugriff auf `base + index * 0x1fc` mit Status 2 zurückkehrt. Es wird auf
diesem Zweig kein BPB-Sektor gelesen.

Der Aufrufer behandelt diesen Fehlerstatus jedoch als Erfolg: `FUN_08158f90`
gibt Status 2 weiter, und `FUN_0812a9ca` prüft nur auf Status 0. Bei jedem
nichtnullen Ergebnis ruft es `FUN_081352e8` auf und setzt mit
`FUN_081e0a28` das Open-Flag. Ein späterer Cleanup über `FUN_0811ee70` erreicht
dadurch `FUN_08110e14`; das leere Buchstabenfeld erzeugt den oben beschriebenen
Nullschreibzugriff bei `0x08834f38`. Eine erfolgreiche BPB-Prüfung ist für
diesen bedingten Schreibpfad also nicht erforderlich. Weiter offen bleiben
eine tatsächlich volle Vierertabelle, der indirekte Methodenaufruf und der
spätere Cleanup. Der feste Nullwert belegt weiterhin weder kontrollierte
Speicherbeschädigung noch Codeausführung.

### Zusatzrunde: Cache-Untertyp und Partitionsverwaltung

Die zweite eingehende Kante zu `FUN_0818e998` führt über den Wrapper
`FUN_082154b8`. Bei Untertyp `param_9 != 0` reserviert `FUN_0818e998` ein
0x60-Byte-Objekt und ruft `FUN_080fecf0` auf. Dieser Konstruktor beginnt mit
`FUN_0823d468`, überschreibt danach die VTable mit `0x0850b254` und setzt die
Felder `+0x58 = 1` und `+0x5c = 0`. Der Basiskonstruktor setzt zunächst die
VTable `0x08536a78`. Beide VTables unterscheiden sich von der zuvor
untersuchten Mount-VTable `0x085056d0`; im erfassten Bereich der Cache-VTable
steht nicht der Eintrag `FUN_0812a9ca`.

Der interne Pfad `FUN_08095dcc` → `FUN_080b4e00` erreicht zwei Aufrufe von
`FUN_082154b8`; die vom Aufrufer belegten Stackfelder liefern dabei die Slots
5 und 6 sowie den Untertypwert 1. Der verschachtelte Pfad über
`FUN_080ce8b0` belegt Slot 6 ebenfalls vorübergehend; bei erfolgreichem
Abschluss entfernt `FUN_0821545a(6)` diesen Eintrag, bevor der übergeordnete
Pfad Slot 6 erneut registriert. `FUN_0818e998` prüft den Slot über
`FUN_0826384c`: Vor dem Tabellenzugriff muss der unsigned Index kleiner als 7
sein; bei dem hier übergebenen Modus 1 muss der Slot leer sein. Diese
Partitionsverwaltung hat sieben geprüfte Einträge. Die Cache-Untertyp-
Registrierungen belegen aber weder einen Aufruf der Mountmethode noch einen
Eintrag in der gemeinsamen Vierer-Laufwerkstabelle.

`FUN_08095dcc` wird im Runtime-Abbild direkt von `FUN_08076996` aufgerufen.
Ob `FUN_08076996` selbst regulär beim Kaltstart ausgeführt wird, ist mit
dieser Xref-Prüfung nicht geklärt. `FUN_080b123c` ruft `FUN_080cbae0` mit
Index 4 auf; dieser Pfad registriert mit Untertyp 0 in Partitionsslot 4 und
verwendet den Basiskonstruktor. Auch er schließt die fehlende Kante zur
Vierer-Laufwerkstabelle nicht.

### Zusatzrunde: Änderungssignalqueue und OSOS-SVC-Argument

Die Zuordnung des Präfixes klärt die zuvor offene Trampolinstelle. Der
Runtime-Trampolin bei `0x08201220` lädt `0x22005934`; im korrekt geladenen
OSOS-Body entspricht diese Präfixadresse `0x08005934`. `FUN_08005934` baut
einen SVC-Datensatz mit Befehl 2 und kopiert sein Argument unverändert hinein.
Der im selben Bodyprojekt ausgelesene Zeiger `DAT_08001640` hat den Wert
`0x2200980c`. Der Handler `FUN_08000b70` liest bei Befehl 2 aus
`0x2200980c + 4 * Argument`. Vor diesem Tabellenzugriff ist im sichtbaren
Handler kein Indexvergleich vorhanden. Der gelesene Tabellenwert wird auf
`0` und `-1` geprüft; er wird nicht als Funktion aufgerufen. Das belegt einen
prüfenswerten Kernel-Tabellenzugriff, aber weder die Tabellengrenze noch einen
vom Datenträger kontrollierbaren Index oder eine ausnutzbare Folge.

Auch die Queueform ist jetzt belegt: `FUN_08020448` richtet beim
Partitionsmanager die Queue bei `Manager + 0x34` ein. `FUN_0819e35c` setzt
deren Sperrzeiger auf `Manager + 0x2c` und setzt Kopf und Ende bei `+0x38` und
`+0x3c` zunächst auf null. `FUN_0819039e` sperrt diesen Bereich, setzt das
Änderungsbyte bei `+0x28`, ruft `FUN_0819f508(Manager + 0x34)` auf und gibt
anschließend die Sperre frei. `FUN_0819f508` entnimmt Knoten aus der Liste ab
`+0x38` und reicht jeweils das Knotenfeld `+4` an den SVC-Wrapper weiter.

Die zuvor offene Produzentenkante ist jetzt identifiziert. `FUN_08268cda`
erhält den Singleton aus `FUN_0818e934`. Solange das Änderungsbyte bei
`Manager + 0x28` null ist, wartet es über `FUN_081ad3a8(Manager + 0x34)`.
Der Synchronisationshelfer holt dafür einen 32-Bit-Wert über
`FUN_081a4508`/SVC `0x0d`, Unterindex 2, und hängt seinen Zweifeld-Datensatz
an der Liste ab `Manager + 0x38` ein. Das zweite Feld ist der Wert, den
`FUN_0819f508` später aus dem Listeneintrag `+4` liest und an SVC-Befehl 2
weitergibt. Beim Registrieren eines Objekts schreibt `FUN_0818e998` in
denselben Singleton und ruft `FUN_0819039e` auf; diese setzt das Änderungsbyte
und leert die Queue. Damit ist der SVC-2-Zugriff auf diesem wartenden
Resolverpfad statisch erreichbar. Das korrigiert die vorherige Aussage, es
sei kein Produzent für genau diese Queue gefunden worden.

Die Herkunft des SVC-2-Arguments ist zugleich eingegrenzt: `FUN_081a4508`
liest einen Eintrag aus dem internen Ringindex 2. `FUN_08222424` legt Werte
über SVC `0x0c`, ebenfalls Unterindex 2, wieder in diesen Ring; seine
Aufrufstellen verwenden den Wert als Synchronisationskennung. Der sichtbare
Runtime-Pfad leitet das Argument daher aus diesem internen Kennungspool ab,
nicht aus einem MBR-Sektor. Die Anfangsbelegung und Kapazität des Pools sowie
die Größe der Tabelle ab `0x2200980c` liegen außerhalb des Runtime-Snapshots.
Der SVC-2-Handler hat an der Zugriffsstelle weiterhin keine sichtbare
Indexprüfung; ein vom Datenträger kontrollierbarer Tabellenindex oder eine
ausnutzbare Auswirkung ist aber nicht belegt.

### Zusatzrunde: direkte Aufrufer und Startup-Registrierung

Die 12 eindeutigen direkten Aufrufer von `FUN_0818e934` wurden dekompiliert.
Der Startup-Pfad ist `FUN_080202d8` → `FUN_08021d08` → Managerzugriff und
`FUN_08029e80`; der letzte Eintrag ist im Runtime-Abbild nur `bx lr`. Für
`FUN_08021d08` und `FUN_08029e80` gibt es jeweils genau eine direkte
Code-Referenz. Dieser Stub selbst richtet keine sichtbaren Queue-Einträge
ein. `FUN_0819039e` hat genau zwei direkte Code-Aufrufer:
`FUN_0818e998` nach Registrierung und `FUN_080029de` im Fehlerpfad.

Der frühere Audit der direkten Präfix-Listen-Aufrufe hatte den Produzenten
übersehen: Der Runtime-Code ruft zunächst `FUN_081ad3a8` auf; erst dieser
berechnet `Manager + 0x38` aus dem übergebenen `Manager + 0x34` und ruft den
Listenhelfer auf. Ein statischer Abgleich nur der direkten Listen-Callsites
konnte diese Objektzuordnung nicht herstellen. Die Queue ist damit nicht nur
initialisiert, sondern hat auf dem wartenden Resolverpfad einen belegten
Produzenten und einen Registrierungs-/Weckpfad.

### Zusatzrunde: OSOS-SVC-Callbacks und Kommando `0x22`

Im OSOS-Dispatcher `FUN_08000b70` ruft Kommando `0x30` den Request-Wert bei
`request[2]` als Funktion mit `request[1]` auf und speichert den Rückgabewert
bei `request[3]`. Der Body-Wrapper `FUN_08005ac0` bildet genau dieses
Kommando. Im Runtime-Abbild hat der Wrapper drei direkte Aufrufstellen; deren
Ziele sind die festen Funktionen `FUN_08053a58` (Getter), `FUN_08053a14`
(Setter) und `FUN_0812e990` (Leerlisten-Prädikat). Der Setter prüft Besitzer
1 bis 80 sowie Slot 0 oder 1 und schreibt Callback und Kontext in eine
Tabelle ab `0x086c63d8`. Diese Adresse liegt 0x2030 Bytes hinter dem Ende des
aufgenommenen Runtime-Abbilds `0x086c43a8`; Tabelleninhalt und Initialisierung
sind hier nicht sichtbar. Die Instruktionsprüfung bestätigt außerdem, dass
`FUN_0835e444` den vierten Setter-Parameter vor dem Tail-Call auf null setzt.
Die weiteren erkannten Setter-Aufrufstellen übergeben statische
Funktionsadressen oder null. Ein vom Datenträger gesetztes Ziel für Kommando
`0x30` ist damit nicht belegt.

Kommando `0x2e` initialisiert einen Ringdeskriptor über
`DAT_08001654 + request[2] * 0x2c`. Die Felder an den Offsets 0 bis 8 werden
vor der Kapazitätsprüfung beschrieben; für `request[2]` ist im sichtbaren
Handler keine Indexgrenze vorhanden. Der Body-Wrapper `FUN_08005248` erzeugt
Kommando `0x2e`. Für seine Body-Adresse und die entsprechende Runtime-Import-
Adresse `0x22005248` ergaben die Ghidra-Referenzabfragen keine Aufrufer. Das
bleibt ein ungeprüfter Initialisierungspfad ohne nachgewiesene Erreichbarkeit
aus dem Runtime-Abbild.

Ein weiterer Runtime-Aufruf des Dispatchers ist Kommando `0x22`. Der Handler
läuft über eine nullterminierte ID-Liste und indiziert `0x2200980c + 4 * ID`,
ohne an dieser Stelle eine Tabellengrenze zu prüfen. Die beiden gefundenen
Runtime-Aufrufer übergeben statische Listen: `FUN_08010afc` verwendet
`[0x47, 0]` bei `0x08444a90`; `FUN_08010be8` kopiert
`[9, 10, 11, 0x11, 0]` von `0x08430d10`. Die frühere BootTask-Rekonstruktion
ordnet diese Einstiege `RadioTask` beziehungsweise `AlarmTask` zu
(`OSOS-FAT-LFN-rehost-impact-followup-2026-10-28.md`). Die ebenfalls
gefundenen Zeigerwörter bei `0x08014034` und `0x080140d4` liegen in einem
Metadatenblock, dessen benachbarte Namen laut jener Analyse keine verlässlichen
Entry-/Namenspaare bilden. Die konkreten Listenwerte sind belegt; die Größe
der Tabelle bei `0x2200980c` bleibt offen. Für diese beiden Pfade ist keine
datenträgerkontrollierte ID belegt.

Die weiteren sichtbar unbeschränkten Listenoperationen `0x2b` und `0x2c`
haben unter den 21 erkannten direkten Request-Wrappern keinen eigenen
Wrapper. Indirekte Request-Aufrufer und außerhalb des Runtime-Abbilds
liegende Initialisierung sind damit nicht ausgeschlossen.

## Nächste Schritte

- Die Laufzeitinitialisierung und Kapazität des Kennungspools an
  `0x2200975c` sowie die Größe der SVC-2-Tabelle ab `0x2200980c` klären.
  Insbesondere die für Kommando `0x22` verwendete Tabellengrenze mit den
  statischen IDs bis `0x47` verifizieren.
- Die SVC-Befehle 1 und 2 samt Kennungslebenszyklus weiter auf Wertebereich
  und Fehlerzustände prüfen. Der sichtbare SVC-2-Handler prüft den Index vor
  dem Tabellenzugriff nicht, der ermittelte Runtime-Pfad bezieht ihn aber aus
  dem internen Kennungspool.
- Prüfen, wann `RadioTask` und `AlarmTask` im normalen Resetpfad tatsächlich
  laufen; die vorhandene Rekonstruktion ordnet die BootTask-Records zu, belegt
  aber keine Ausführungsreihenfolge vor dem Medienparser.
- Untersuchen, ob Kommando `0x2e` außerhalb des Runtime-Xref-Satzes aufgerufen
  wird und ob ein indirekter Request-Pfad die Operationen `0x2b`/`0x2c`
  erreicht.
- Den Erzeuger der VTable-Instanz bei `0x085056d0` finden. Die VTable hat im
  Runtime-Abbild keine erkannten eingehenden Code-Referenzen.
- Belegen, ob der MBR-Partitionsadapter in einen Tabellenobjekt-Wrapper
  überführt wird, der anschließend `FUN_081352fc` aufruft. Die beiden
  `+0x10`-Felder haben unterschiedliche Bedeutung.
- Ermitteln, ob der normale Start oder ein erreichbarer VFS-Aufruf fünf
  Registrierungsobjekte in die Vierertabelle bringen kann; nur dann wird der
  gerade präzisierte Fehler-/Cleanup-Pfad ausgelöst.
- Erst danach den konkreten OOB-Read-Effekt auf den BPB-Puffer und mögliche
  Folgeparser bewerten. Derzeit ist keine Codeausführung nachgewiesen.

## Belege und Eingaben

Neue Roh- und Ghidra-Belege liegen in
`analysis/evidence/ata-mbr-followup-2026-10-31/`; ihr Manifest ist dort
`SHA256SUMS`. Die zentrale frühere Cache-Analyse steht in
`OSOS-ATA-block-io-bounds-followup-2026-10-26.md`, Abschnitt
„konkreter Cache-Hit-Wrap über MBR-Startsektor“. Die MBR-/FAT- und
MainApp-Open-Grenzen stehen in
`OSOS-accessories-full-path-reachability-followup-2026-10-29.md`.

Runtime-Abbild:
`/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin`
(SHA-256 `1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`).
OSOS-Body:
`/home/sebastian/ipod-re/nano5g/osos_decrypted/osos_body.bin`
(SHA-256 `01f8f8c7adb81e548d000f74f2d1335bda6ce48f9c7ac74d81d80a278d7ee5ec`).
Alle neuen Ghidra-Läufe verwendeten `-readOnly -noanalysis`.
