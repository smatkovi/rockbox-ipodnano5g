# Hold-Schalter und früher OSOS-Start

Stand: 29.10.2026. Read-only-Ghidra- und Rohbyteanalyse. Keine Abfrage des
iPods, kein DFU-Polling, kein Reboot und keine NAND-/NOR-/Flashoperation.

## Verifizierte Befunde

Der OSOS-PMU-Leser `FUN_082062c0` liest Register `0x05`, ein Byte, und gibt
Bit 0 zurück. Der lokale Nano-5G-Treiber bezeichnet Register `0x05` als
`D1759_REG_STATUSB` und Bit 0 als Hold-Eingang: null bedeutet verriegelt,
eins entriegelt. Rockbox' Bootloader liest dasselbe Register synchron; bei
Lesefehler behandelt er den Zustand als verriegelt und startet über
`launch_apple(APPLE_IMG_OSOS)` das signierte Apple-OS. Die Quellen sind
`firmware/target/arm/s5l8702/ipodnano5g/pmu-target.h`,
`firmware/target/arm/s5l8702/ipodnano5g/pmu-nano5g.c` und
`bootloader/ipodnano4g.c`.

Die direkten OSOS-Aufrufer der PMU-Abfrage sind:

- `FUN_081988fc`: fragt den Hold-Zustand ab und sendet beim ersten erfassten
  Zustand die Ereignisse `0x59` und `0x57`.
- `FUN_0819c3f0`: fragt ihn in einem bestimmten Event-/Statuszweig ab.
- `FUN_081ad510`: Tail-Branch zur Abfrage; der sichtbare Caller ist
  `FUN_08025b90`, dessen Metadaten auf `Accelerometer` zeigen.

`FUN_081988fc` wird über `FUN_0824dc22` erreicht. Eine Rohbyte-Branchsuche
findet Aufrufe von `FUN_0824dc22` bei `0x0804fe28`, `0x080a2a90`,
`0x080b9a2a` und `0x081e18b0`. Der Call bei `0x080b9a2a` liegt in einem
bedingten Ereignispfad; `0x081e18b0` liegt in einem UI/Event-Handler. Die
beiden kurzen Wrapper bei `0x0804fe28` und `0x080a2a90` haben im gespeicherten
Ghidra-Xref keine direkten Caller; ihre indirekte Verwendung und ihr
Startzeitpunkt bleiben offen. Der Rohbyte-Scan bestätigt direkte Branches,
aber allein keine Laufzeit-Erreichbarkeit.

Die tatsächlichen BootTask-Records wurden gegen Constructor und Consumer
abgeglichen. `FUN_08013d44` richtet `FUN_0819dcbc`-Records ein;
`FUN_0801e2b4` übergibt den Record-Einstieg an den Kernel und den Namen an
einen getrennten Tasknamen-Setter. Daraus folgt:

| Record | Laufzeitadresse | Priorität | Stack | Einstieg | Name |
|---:|---:|---:|---:|---:|---|
| 4 | `0x08760110` | 10 | `0x800` | `0x08017f30` | `DiskMgrTask` |
| 5 | `0x08760124` | 3 | `0x800` | `0x0801814c` | `HoldSwitchTask` |

Damit ist die frühere Zuordnung von `0x08017f30` zu `HoldSwitchTask` korrigiert.
`0x08017f30` ist im Constructor `DiskMgrTask`; sein Event-/Queue-Code bei
`0x08017f68` wartet auf Queue-ID 1 und enthält den direkten Aufruf
`FUN_0818eb44(0x14)`. `HoldSwitchTask` beginnt bei `0x0801814c`: der sichtbare
18-Byte-Taskstarter erzeugt ein Objekt, speichert einen Zeiger in einem
Globalen, ruft einen externen Dienst (`0x220059f4(0)`) und initialisiert das
Objekt über `FUN_0819ae90`/`FUN_08193b10`. Er ruft `FUN_082062c0` nicht direkt
auf.

Der Datenbereich ab `0x08014000` enthält Funktionszeiger und Tasknamen, aber
die direkt benachbarten Wörter bilden nicht zuverlässig ein Task-Record-Paar.
Der Constructor lädt ausgewählte Einstiege von dort und übergibt den Namen als
separaten Parameter. Zum Beispiel wird `DAT_080140c4` (Wert `0x083527c0`) mit
dem Namen `RTCTimerMgr` in einen BootTask-Record übernommen. Die genaue
Zuordnung folgt deshalb dem Constructor und Record-Consumer, nicht einer
linearen Paarung der Rohwörter. Diese Präzisierung ist auch in
`OSOS-boot-task-table-followup-2026-10-25.md` eingetragen.

## Manager- und Callback-Reihenfolge

Der ARM-Listing-Export von `FUN_083534e8` zeigt die Reihenfolge
`FUN_08354b08` → `FUN_0801c684` (BootTask-Tabelle) → `FUN_08354ba8`.
Während `FUN_08354b08` läuft, ruft `FUN_0801d4ac` `FUN_0801e180` mit
Callback `FUN_0835cc0c` auf; `FUN_0801e180` ruft diesen Callback synchron per
`BLX` auf. Damit laufen die Setup-Aufrufe in `FUN_0835cc0c` vor dem Durchlauf
der BootTask-Tabelle. Der separate spätere Pfad in `FUN_08354ba8` fordert
`MainAppTask` an.

`FUN_0835cc0c` fordert über `FUN_08193984` die Tasks `EventManager`
(`0x08023050`) und `TimerEventManager` (`0x08023028`) an. Der zweite Einstieg
ist eine Schleife über `FUN_081a9b48`, `FUN_0802924c` und `FUN_081a9b5c`; der
frühere Kandidat `0x08021e3c` ist ein anderer Task (`TimeManager`). Die
EventManager-Schleife wartet über `FUN_0802889a` auf eine Nachricht von
`0x1c` Byte. Bei zwei Message-IDs ruft sie `FUN_081a9b84` auf, danach läuft
die generische Filterverarbeitung über `FUN_081a9bf8`. Die Literale bei
`0x0802308c` und `0x08023090` sind `0x6b44776e` (`kDwn`) und `0x6b557020`
(`kUp `), also Down-/Up-Tastennachrichten.

`FUN_0826107c` aktualisiert den Tastenzustand und erzeugt Tastennachrichten;
die untersuchten Wrapper übergeben unter anderem Codes `0x57`, `0x58`, `0x6e`
und `0x6f`. Ein Parser bei `0x080d4920` verarbeitet benannte Remote-Ereignisse
wie `HandleRemoteDownArrowUp` und ruft solche Wrapper auf. Das belegt normale
Eingabe-/Remote-Produzenten, aber keinen speziellen Hold-Messagecode und keine
Ausführung vor `MainAppTask`. Ein weiterer Ereignis-Helper verwendet zusätzlich
das Literal `0x6b557044` (`kUpD`); es ist nicht identisch mit dem vom
EventManager verglichenen `kUp `.

Die ARM-Funktion `FUN_0818ebd8` fragt über `FUN_0824dc22` den Holdstatus ab und
kehrt bei gesetztem Hold zurück, bevor sie im sichtbaren Pfad
`FUN_0826107c` aufruft. Ein roher Branchscan findet sechs Thumb-`BLX`-Ziele
auf `0x0818ebd8`, alle in der Funktion bei `0x08000b4e`. Der read-only
Ghidra-Export dieses Bereichs bestätigt die Instruktionsgrenzen und zeigt
einen `Wakeup button`-Pfad sowie Statusänderungen für fünf Button-Codes.
Damit ist der lokale Hold-Gate-Aufruf statisch bestätigt.

Die offene Kante liegt eine Stufe davor: Für den Einstieg bei `0x08000b4e`
gibt es im gespeicherten Ghidra-Xref keine Referenz; der Branchscan findet
keinen direkten Branch auf diesen Einstieg und der Wortsuchlauf keinen
absoluten Funktionszeiger. Ein externer Callback oder berechneter Aufruf ist
nicht ausgeschlossen. Die Funktion enthält also einen echten Hold-Gate für
Button-/Wakeup-Verarbeitung, aber ihr Auslöser und eine Ausführung vor dem
`accessories.reg`-Parser sind weiterhin nicht belegt. Der separat referenzierte
Thumb-Einstieg `FUN_0818ecfc` wird von `FUN_08183928` benutzt; er darf nicht
mit der ARM-Funktion `FUN_0818ebd8` gleichgesetzt werden.

Nach bestandenem Hold-Check und einem zusätzlichen aktivierten Statusbyte
ruft `FUN_0818ebd8` bei `0x0818ec48` außerdem `FUN_083522bc` auf, bevor der
weitere Tastenzustand verarbeitet wird. Der Helper aktualisiert einen
gemeinsamen Eingabezustand; im gespeicherten Ghidra-Xref ist dies sein
einziger direkter Callsite. Das verknüpft den Zustandshelper mit dem
Hold-geprüften Eingabepfad, belegt aber weiterhin weder den äußeren Aufruf
von `0x08000b4e` noch dessen Zeitpunkt im Startablauf.

Ein konkreter äußerer Kandidat liegt außerhalb dieses Abbilds: Die BootTask-
Tabelle enthält einen `PowerMgmt`-Record mit Prioritätswert 4 und Einstieg
`0x22004fc1` (Thumb-Code außerhalb des Runtime-Abbilds). Der Record wird vor
dem späteren `MainAppTask`-Request verarbeitet. Das passt zur Wakeup-/Button-
Rolle, belegt aber weder, dass `PowerMgmt` `0x08000b4e` registriert/aufruft,
noch die Schedulerreihenfolge oder einen Aufruf vor dem Parser.

Im selben Setup registriert `FUN_080203c8` den Filter `FUN_080237a8` über
`FUN_08023094`. Der Filter kopiert ein Wort aus einem globalen Objekt und
liefert Erfolg; er liest den PMU-Holdstatus nicht. Das belegt frühe
Event-Infrastruktur, aber noch keinen frühen Hold-Callback.

Die statische Callbackliste bei `0x0853ba98` wird vom Singleton-Constructor
`FUN_0807db28` an `FUN_081a94f0` übergeben und in dessen Objekt abgelegt. Sie
enthält unter anderem `0x081e181d` (Thumb-Einstieg `FUN_081e181c`) und die
Wrapper `0x080ba83b`/`0x080ba8cd`, die `FUN_081e181c` aufrufen. Der
Singletonzugang `FUN_08197d9c` konstruiert das Objekt nur, wenn sein
Globalfeld noch null ist. Einer seiner Aufrufer ist der BootTask-Eintrag
`RTCTimerMgr` (`FUN_083527c0`, Priorität 4); dort ist der Aufruf zusätzlich
davon abhängig, dass ein Tabellenindex gültig und zwei Statusbytes gesetzt
sind. Die Aufgabe läuft in einer Schleife, aber aus dem statischen Bild folgt
nicht, dass diese Bedingung beim Kaltstart erfüllt ist oder dass der Singleton
vor `MainAppTask` angelegt wird. Von 123 direkten Referenzen auf den
Singletonzugang liegen zwei in `RTCTimerMgr`; direkte Aufrufe aus den
untersuchten Einstiegen von `HoldSwitchTask` und `EventManager` fanden sich
nicht. Indirekte Aufrufe bleiben damit unberührt.

Die direkte Ghidra-Referenz auf das von `RTCTimerMgr` gelesene Indexfeld
`0x085515c0` zeigt einen Schreibzugriff in `FUN_083a737c`, die aus der
RTCTimerMgr-Schleife aufgerufen wird. Das stützt den Pfad über den Task, sagt
aber nichts darüber aus, wann er im Scheduler erstmals läuft; indirekte oder
externe Zugriffe sind damit nicht ausgeschlossen.

Die fünf Statusbytes der Timer-Einträge werden in `FUN_0835d0e0` vor dem
BootTask-Tabellendurchlauf auf null gesetzt. `FUN_083a7320` findet bei fünf
inaktiven Einträgen keinen gültigen Slot. Der sichtbare Setter
`FUN_0825f92c` aktiviert einen Slot; seine Referenzen führen über
`FUN_0828ab9c` zu `FUN_081b09ec`, einem Alarm-/Zeitkonfigurationspfad mit 16
direkten Callern aus Anwendungsmodulen. Der zusätzliche Caller `FUN_080cb6ee`
hat weder direkte noch Daten-Xrefs und keinen gefundenen exakten
Funktionszeiger im Runtime-Abbild. Damit ist kein Kaltstart-Schreiber der
Statusbytes gefunden; berechnete/indirekte Zugriffe bleiben offen.

Auch die Ausführung der gespeicherten Callbackliste ist nicht geschlossen:
`FUN_081a94f0` speichert sie im Objekt, aber der konkrete Dispatcher und der
Zeitpunkt eines Aufrufs von `FUN_081e181c` vor dem Parser sind weiterhin offen.
Ein zusätzlicher Zeigerfund bei `0x08509bec` zeigt auf `0x0804fe25` und damit
auf das `bx lr` bei `FUN_0804fe24`; er ist kein Zeiger auf den Hold-Wrapper ab
`0x0804fe28`.

### Zusätzlicher Status-Callback `0x0804bc50`

Der direkte Aufruf von `FUN_081d4a68` bei `0x0804bcb4` gehört zu einer
Funktion, die bei `0x0804bc50` beginnt. Der vollständige Thumb-Export zeigt
einen Ereignisdispatcher mit den Statuswerten `0x00010006`, `0x00040002`
und `0x00040003`: `0x00010006` geht über einen virtuellen Callback zurück;
`0x00040002` ruft `FUN_081d4a68(..., 1)` auf; `0x00040003` ruft
`FUN_081d4a68(..., 0)` nur auf, wenn Byte `+0xe2` des Objekts von
`FUN_081a70d8` null ist. Für `0x00040002` setzt `FUN_081d4a68` einen
Timer-/Singletonpfad zurück und ruft `FUN_0818ece0` auf. Der Handler selbst
fragt den PMU-Holdstatus nicht ab.

Der Thumb-Funktionszeiger `0x0804bc51` steht an `0x084f763c`. Seine drei
benachbarten Slots teilen sich mit 14 weiteren Tabellenblöcken dieselben
Einträge `0x080bd4d3`, `0x080bd507` und `0x080bd50b`; der vierte Slot variiert.
Die 15 Tabellenanfänge haben in den gespeicherten Ghidra-Xrefs keine
eingehenden Referenzen, und eine byteweise Rohsuche findet im Runtime-Abbild
keinen exakten Zeiger auf diese Tabellenanfänge. Das passt zu einer
vtable-artigen Callbackfamilie, identifiziert aber weder den konkreten
Objektbesitzer noch einen Aufrufzeitpunkt. Berechnete oder externe Verweise
sind damit nicht ausgeschlossen. Dieser Pfad liefert daher keinen Nachweis
für einen frühen Hold-Check oder eine Ausführung vor dem Parser.

## Nachtrag: PowerMgmt-Task im OSOS-Bootprefix (31.10.2026)

Der im BootTask-Record gespeicherte Einstieg `0x22004fc1` liegt nicht nur
außerhalb des Runtime-DRAM-Abbilds: Im separat geladenen Prefix-Abbild ist der
Thumb-Task ab `0x22004fc0` vorhanden. Sein Loop verarbeitet Status-/Eventwerte,
aktualisiert einen internen Zustandsdatensatz und verzweigt bei ausgewählten
Übergängen zu weiteren Services. Die erzwungene Thumb-Dekompilierung und die
Rohbytes sind unter `evidence/hold-power-mgmt-2026-10-31/` abgelegt.

Ein sichtbarer Übergang ruft über den Prefix-Veneer bei `0x22003a58` den
Runtime-Einstieg `FUN_081b2854` auf. Diese Funktion gibt anhand von Statusfeldern
eines globalen Objekts einen booleschen Wert zurück; bei einem Sonderwert ruft
sie außerdem `FUN_081a87fc` zur Initialisierung auf. Diese Kette ist bis
`FUN_081abab0` verfolgt: Der Initialisierer fragt PMU-Register `0x0a` und
`0x33` ab. Er ruft den bekannten PMU-Hold-Reader `FUN_082062c0` nicht direkt
auf und liest im sichtbaren Pfad nicht dessen Register `0x05`. Der separate
Hold-Reader liest Register `0x05` und gibt Bit 0 über einen Ausgabezeiger
zurück. Weitere externe Dienstpfade bleiben ungeklärt.

Die zusätzliche Prefix-Analyse zeigt somit **keinen** Hold-Gate in diesem
sichtbaren Übergangspfad. Der aufgelöste Initialisierer verwendet andere
PMU-Register als der Hold-Reader. Sie schließt weitere externe Dienste oder
indirekte Aufrufe nicht aus. Dass der `PowerMgmt`-Task vor `MainAppTask`
angefordert wird, belegt weder seine erste Ausführung vor dem MainApp-Parser
noch einen abgeschlossenen Hold-Read zu diesem Zeitpunkt.

## Nachtrag: PowerMgmt-Bereitschaft und Callback (31.10.2026)

Der erste Prefix-Veneer im Task (`0x22003a80`) zeigt auf
`FUN_0824dec4`. Diese Runtime-Funktion wartet, bis der von `DAT_0824ded8`
referenzierte Wert ungleich null ist; dazwischen ruft sie
`FUN_08190a9c(2)` auf. Der einzige im Runtime-Projekt erkannte direkte Caller,
`FUN_08142830`, verwendet den Rückgabewert als Handle. Der dekompilierte
Rückgabetyp ist daher nicht verlässlich rekonstruiert. Für `DAT_0824ded8` ist
im Runtime-Projekt nur der Lesezugriff aus `FUN_0824dec4` referenziert; ein
Setzer in diesem Abbild wurde nicht gefunden. Ein externer oder indirekter
Setzer bleibt möglich.

Nach diesem Warten ruft der Prefix-Task über `0x220039c8` den Thumb-Einstieg
`0x08009094` mit dem Callback-Zeiger `0x2200607d` auf. Der sichtbare Code
führt eine synchronisierte Listen-/Array-Operation über Felder bei `+0x10`,
`+0x14` und `+0x18` aus und erreicht anschließend einen indirekten Aufruf.
Die genaue Semantik der außerhalb des Ausschnitts liegenden Hilfsfunktionen
und damit die Frage, ob genau dieser Aufruf bereits während der Registrierung
den übergebenen Callback ausführt, bleibt offen.

Der Callback `0x2200607c` liest ein globales Statusbyte und ruft bei null
`FUN_22005bec(1, param != 0)` auf. Diese Routine begrenzt den Index auf die
23 Einträge des Statusarrays, aktualisiert einen Eintrag und ruft bei einer
Änderung `FUN_220061a4` auf. Dessen sichtbarer Pfad fragt über den Prefix-
Veneer `0x22003a58` die Runtime-Funktion `FUN_081b2854` ab. Der zugehörige
Initialisierungspfad liest PMU-Register `0x0a` und `0x33`; ein Zugriff auf
das Hold-Register `0x05` oder ein direkter Aufruf von `FUN_082062c0` ist in
dieser Kette nicht sichtbar.

Diese zusätzliche Kette löst einen Teil des zuvor externen
`PowerMgmt`-Setups auf, weist aber weiterhin keinen frühen Hold-Guard nach.
Der Zeitpunkt, zu dem das Bereitschaftsobjekt gesetzt wird, die vollständige
Semantik des Listen-Helpers und die Taskausführung relativ zum
`accessories.reg`-Parser bleiben offen.

## Was die Befunde für den Hold-Guard bedeuten

`HoldSwitchTask` erhält laut Constructor den numerischen Prioritätswert 3;
`MainAppTask` wird später angefordert und erhält `0x34`. Der Hold-Record wird
also vor dem späteren MainApp-Request verarbeitet. Die Schedulersemantik der
externen Create-/Release-Dienste ist im Runtime-Abbild nicht enthalten. Es
zeigt **nicht**, dass die PMU-Abfrage oder ein Hold-Ereignis vor dem automatischen
`accessories.reg`-Parser abgeschlossen ist: der sichtbare Starter liest den
PMU nicht selbst und delegiert an einen externen Dienst, dessen Verhalten im
Runtime-Abbild fehlt.

Die aktuelle 720-Byte-ROP-Variante
`candidate_accessories_reg_ipodpkg_unexecuted.bin` hat keinen Hold-Guard. Bei
verriegeltem Schalter kann der Rockbox-Bootloader zwar das Apple-OS starten;
falls der automatische `accessories.reg`-Pfad bei diesem OSOS-Start erneut
ausgeführt wird, könnte er den Loader wieder aufrufen. Eine Endlosschleife ist
damit nicht nachgewiesen, aber das Kandidatenverhalten unter Hold ist nicht
abgesichert.

## Offene Schritte

1. Weitere Prefix-Service-Veneers des `PowerMgmt`-Tasks auf indirekte
   PMU-/Hold-Zugriffe prüfen. Der sichtbare Bereitschafts- und Callbackpfad
   bis `0x2200607c` liest in der aufgelösten Initialisierung Register `0x0a`
   und `0x33`; er belegt keinen Hold-Read. Offen sind der Setzer von
   `DAT_0824ded8`, die genaue Semantik des Runtime-Listen-Helpers und der
   Zeitpunkt des Callbackaufrufs. Auch die Registrierung der
   Wakeup-Button-Funktion bei `0x08000b4e` bleibt offen. Danach klären, ob
   irgendein Hold-Pfad vor `MainAppTask` und dem `accessories.reg`-Parser
   laufen kann. Der bekannte Remote-Parser ist dafür kein Beleg.
2. Die Schedulerwirkung der Task-Create-/Release-Dienste außerhalb des
   Runtime-Abbilds klären. Die statische Reihenfolge der Anforderungsaufrufe
   belegt noch keine Reihenfolge der Task-Ausführung.
3. Den konkreten Dispatcher der bei `FUN_081a94f0` gespeicherten Callbackliste
   und den ersten Aufruf von `FUN_081e181c` relativ zum Parser bestimmen.
   Die fünf Timer-Slots sind vor Taskstart inaktiv; der sichtbare Setter ist
   an den Alarm-/Anwendungspfad gebunden.
4. Erst bei einem belegten frühen Hold-Pfad einen Guard für den
   Parser-Loader entwerfen; der aktuelle ROP-Kandidat hat keinen solchen Guard.

Rohbelege der bisherigen HoldSwitch-Analyse liegen unter
`utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/`; der Prefix-
Nachtrag liegt unter `utils/ipodnano5g/analysis/evidence/hold-power-mgmt-2026-10-31/`.
