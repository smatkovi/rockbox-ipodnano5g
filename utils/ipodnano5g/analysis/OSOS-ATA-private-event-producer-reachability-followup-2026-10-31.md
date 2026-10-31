# ATA-Event-Producer und Descriptor-Dispatch beim Kaltstart

Stand: 31.10.2026. Read-only-Auswertung vorhandener Runtime- und Body-Ghidra-
Projekte. Keine Geräte-, USB-, DFU- oder Flashabfrage; keine NAND-/NOR-
Änderung.

## Ergebnis

Der private ATA-Producer ist statisch erreichbar, wenn der externe Manager den
registrierten Descriptor aufruft. Dann prüft `FUN_0833c464` sein zweites
Argument auf Nichtnull und ruft `Parent->VTable+0x10(Parent, Descriptor,
Source)` auf. Der ATA-Konstruktor setzt das Gatebyte `Parent+0x54` auf 1.
Deshalb passieren bei einem solchen Aufruf sowohl das Gate als auch die
Nichtnullprüfung von `FUN_0833c504`; der Producer kann direkt zustellen oder
einen dynamisch allozierten Queueknoten einreihen.

Der fehlende Beleg ist der Manageraufruf von Descriptor-Slot 0 und sein
Zeitpunkt relativ zum ersten `ATAWorkLoopTask`-Receive. Die ATA-Queue wird
zunächst leer initialisiert, aber daraus folgt nicht, dass sie bis zum ersten
Receive leer bleibt. Der externe Registry-/Managerzustand liegt außerhalb des
aufgenommenen Runtime-Abbilds.

## Verifizierte Kette

1. `FUN_0833a6e8` legt bei Bedarf das ATA-Elternobjekt an und führt dessen
   Initialisierung aus. `FUN_0833aef0` setzt `Parent+0x54` auf 1, richtet
   Queue und Descriptor ein und startet über `FUN_0833c118` die Tasks
   `ATAWorkLoopTask` und `ATAWorkLoopIRQTask`.
2. Die Eltern-VTable bei `0x084f5270` enthält bei `+0x10` den Thumb-Zeiger
   `0x0833bced` zu `FUN_0833bcec`. Diese prüft das Gatebyte und reicht bei
   gesetztem Byte ihre Registerargumente an `FUN_0833c504` weiter.
3. Der Laufwerksdescriptor besitzt die VTable bei `0x084fb4dc`; Slot 0 zeigt
   auf `FUN_0833c464`. Die Funktion gibt bei `Source == 0` `-1` zurück.
   Andernfalls ruft sie über `Parent->VTable+0x10` den ATA-Callback mit
   Descriptor und Source als den beiden Nutzargumenten auf.
4. `FUN_0833c504` lehnt Nullargumente ab. Wird der Descriptor-Slot mit
   nichtnuller Source aufgerufen, sind Descriptor und Source nichtnull und
   dieser Guard wird passiert. Stimmen die drei Identitätsfelder des ATA-
   Objekts mit Konstanten überein, speichert der Code den Source-Zeiger und
   ruft einen virtuellen Handler; andernfalls hängt er einen dynamischen
   8-Byte-Knoten an die Queue und stößt eine Benachrichtigung an.
5. `FUN_0833c2a8` registriert den Descriptor in einer Tabelle mit höchstens
   vier Slots. Der Code prüft den Zähler gegen 4 und den Zielslot auf 0,
   bevor er schreibt; in diesem Ausschnitt ist kein Tabellenüberlauf
   erkennbar.

Die separat untersuchte `FUN_0801f74a`-Kante ist ein USB-Transfercallback:
`FUN_08006d34` gehört zur USB-Interfacekonstruktion, und die Callbackadresse
`0x0801f74b` wird in deren Requestpfad übergeben. Das erklärt einen möglichen
späteren ATA-Aufruf bei USB-Transferverarbeitung, belegt aber keinen
automatischen Kaltstarttrigger.

## Abgrenzung

`FUN_08005828` nutzt ebenfalls den unteren Queue-Sendehelfer, holt sein Objekt
aber über `FUN_0818edd4`; der ATA-Producer verwendet `FUN_081e2554`. Die
Accessor-/Singletonpfade sind verschieden. Der generische System-Eventpfad
belegt daher keine Befüllung der privaten ATA-Queue.

Die IRQ-Task wartet über einen externen Semaphorwrapper. Anfangszähler und
Signalisierung sind im Runtime-Dump nicht enthalten. Ebenso ist kein
Kontrollfluss vom externen Registry-Manager zu `FUN_0833c464` und kein Aufruf
vor dem ersten Worker-Receive nachgewiesen. Damit liegt weder ein bestätigter
Kaltstart-Event noch ein Speicherfehler, beliebige Codeausführung oder
Rockbox-Handoff vor.

## Nächste statische Schritte

1. Für den externen Descriptor-Manager die Dispatchimplementierung und den
   Aufruf von Slot 0 in weiteren OSOS-Komponenten oder einer passenden
   Laufzeitaufnahme identifizieren.
2. Danach bestimmen, ob dieser Aufruf vor dem ersten privaten ATA-Receive
   möglich ist und welchen Source-Zeiger er übergibt.
3. Unabhängig davon die Ready-/Current-TCB-Verkettung nach dem Queue-4-Post
   mit den tatsächlichen Schedulerlistenvariablen schließen. Die vorhandenen
   statischen Exporte zeigen, dass ein geweckter Task in die Ready-Liste
   sortiert wird; `FUN_08000b1c` setzt Current beim Blockieren auf den
   bisherigen `TCB->next`. Eine reale Kaltstartreihenfolge folgt daraus noch
   nicht.

## Rohbelege

Die zu dieser Prüfung gehörenden Ghidra-Exports und Prüfsummen liegen dauerhaft
im Repository unter
`utils/ipodnano5g/analysis/evidence/rtos-task-order-2026-10-29/`. Der
Manifest `SHA256SUMS_ata-event-audit-20261031.txt` listet die für diesen
Bericht verwendeten Roh-Exports und diesen Bericht selbst.
