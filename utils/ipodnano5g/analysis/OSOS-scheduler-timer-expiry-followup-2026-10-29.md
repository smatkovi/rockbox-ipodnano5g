# OSOS-Timerliste und Callback-Dispatch: Folgeanalyse (29.10.2026)

## Umfang

Read-only-Auswertung des Runtime-Ghidra-Projekts
local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime.
Keine USB-, Geräte-, DFU-, Boot- oder Flashaktion.

## Verifizierte Befunde

- Die Timerliste wird über FUN_081a8320 -> FUN_081966b4 befüllt. Der Eintrag
  erhält eine Frist aus der aktuellen Zeit plus entry[1] * 1000, wird anhand
  dieser Frist sortiert eingehängt und bekommt entry[7] = 1. Der Store bei
  entry + 0x20 ist der konstante Marker 0x72756e20 (" run"), kein
  Callback-Zeiger.
- Die Liste wird von FUN_08021e3c verarbeitet. Sie verwendet denselben
  Listenanfang 0x085507b0, nimmt unter dem Timer-Lock alle Einträge heraus,
  deren Frist bei entry + 8 abgelaufen ist, und ruft zunächst
  FUN_081a8dd0 für Entfernen/Benachrichtigung auf. Bei einem Nullwert in
  entry + 0x14 folgt FUN_08197df8; andernfalls ruft der Worker den
  Callback-Zeiger aus entry + 0x14 auf. Danach berechnet er den nächsten
  Wartezeitraum.
- Der TimeManager wird in der BootTask-Initialisierung registriert:
  arm_8354b08 ruft FUN_0801d4ac auf; diese übergibt FUN_0835cc0c an
  FUN_0801e180, und FUN_0801e180 ruft den übergebenen Callback nach seiner
  Initialisierung auf. FUN_0835cc0c ruft FUN_0801f8a0 auf. Diese richtet
  einen Thread mit Namen TimeManager und Thumb-Einstieg 0x08021e3d
  (FUN_08021e3c) ein. Der Scheduler-Dispatcher ist damit im normalen OSOS-
  Startpfad vorhanden; daraus folgt noch kein manipulierbarer Timer-Eintrag.
- FUN_080945fc erzeugt separat ein TMusicLoadingTask, startet dessen
  Objekt und reiht einen eingebetteten Eintrag bei param_1 + 0x818 ein.
  Dessen konkreter Wert bei +0x14 und dessen Konstruktorquelle sind nicht
  aufgelöst. Der Eintrag FUN_080eb730 bei TMusicLoadingTask-VTable-Slot
  +0x14 ist ein anderer, nur numerisch gleich positionierter VTable-Slot;
  ein Zusammenhang mit dem Timer-Callback wurde nicht gezeigt. Der Pfad bis
  FUN_081ac420 bleibt an den bereits dokumentierten Status-/Eventkontext
  gebunden.
- Der einzige direkte Caller von FUN_0804b900 ist FUN_08038d38. Dort wird
  FUN_0804b900 nur in einem Zweig für Ereignistyp 0x12 aufgerufen und nur,
  wenn dessen Nutzdatenzeiger einem internen Subobjekt von param_1 entspricht.
  FUN_08228ac0 prüft danach zusätzlich ein Initialisierungsflag und einen
  virtuellen Statuswert, bevor es FUN_08076996 und FUN_080945fc erreicht.
  Damit ist der Musik-Task kein unbedingter Boot-Datei-Callback; Quelle und
  normale Erzeugung dieses Ereignisses bleiben offen.
- Der Dispatcher vergleicht in diesem Ereignistyp auch den Zeiger
  param_1 + 0x818 und ruft dafür FUN_0804bd38 auf. FUN_080945fc reiht genau
  an param_1 + 0x818 einen Timer-Eintrag ein. FUN_0804bd38 prüft den globalen
  TMusicLoadingTask-Zeiger und dessen Byte bei +0x20; abhängig davon startet
  es FUN_08058a6c oder reiht den Eintrag erneut ein. Das ist eine plausible
  Verbindung des Timer-Subobjekts zur App-Zustandsmaschine. Der generische
  Timer-Worker sendet bei leerem Callback über FUN_08197df8 ->
  FUN_081a8f50 die Eintragsadresse; dass genau diese Nachricht als
  Ereignistyp 0x12 an FUN_08038d38 zugestellt wird, ist anhand des sichtbaren
  Codes noch nicht vollständig bewiesen.
- Gegenprüfung eines möglichen Ein-Byte-Heap-Overwrites im Taskkonstruktor:
  FUN_080945fc fordert vor FUN_080bb0c0 0x2c Byte bei FUN_0818eb44 an und
  übergibt den zurückgegebenen Zeiger als Konstruktorziel. FUN_080bb0c0
  schreibt seine Nullmarke bei Offset +0x28; dieser Zugriff liegt innerhalb
  der angeforderten 44 Byte. Das in FUN_082772a0 gespeicherte Metadatenfeld
  0x28 ist daher kein Beleg für eine zu kleine tatsächliche Allokation.

## Bewertung

Die Ablauf- und Callback-Logik der generischen Timerliste ist geklärt. Zusätzlich
passt der bei +0x818 eingereihte Eintrag zum Pointerzweig, der FUN_0804bd38
aufruft; die Zustellung desselben Timerereignisses als Nachricht 0x12 bleibt
aber eine plausible, noch nicht vollständig geschlossene Verbindung. Es ist
kein neuer Speicherfehler. Es fehlt weiterhin ein datei- oder hostkontrollierter
Wert, der einen Timer-Callback setzt/überschreibt, ein vollständiger
Kaltstartpfad zum Parser sowie ein Rockbox-Handoff. Die Kandidatenrangfolge
ändert sich nicht: accessories.reg bleibt der nächste Kontrollflusskandidat,
während iPodSettings.xml der am klarsten reproduzierte Heap-Schreibfehler ohne
belegte reale Erreichbarkeit bleibt.

## Nächster sinnvoller Schritt

Als Nächstes die Queue-/Nachrichtenstruktur in FUN_081a8f50 mit dem
Ereignisobjekt von FUN_08038d38 abgleichen und beweisen oder widerlegen, dass
ein Ablauf des Eintrags bei +0x818 FUN_0804bd38 aufruft. Danach den
Timer-Eintrag-Callback bei +0x14 und die Zustandsbedingung bis FUN_08058a6c
verfolgen. Das kann eine automatische MainApp-Dateiöffnung erklären, ist
derzeit aber nicht als kompletter Kaltstartpfad nachgewiesen.

## Rohbelege

Die Ghidra-Exporte liegen unter
evidence/silver-slot4-2026-10-28/:

- OSOS_silver_scheduler_queue_head_xrefs_20261029.log
- OSOS_silver_scheduler_timer_worker_followup_20261029.log
- OSOS_silver_scheduler_time_task_and_tmusic_join_20261029.log
- OSOS_silver_scheduler_tmusic_entry_refs_20261029.log
- OSOS_silver_scheduler_boot_init_owner_20261029.log
- OSOS_silver_scheduler_boot_init_listing_20261029.log
- OSOS_silver_scheduler_time_manager_registration_20261029.log
- OSOS_silver_tmusic_timer_producer_path_20261029.log
- OSOS_silver_tmusic_event_timer_join_20261029.log
- OSOS_silver_tmusic_timer_event_delivery_20261029.log
- OSOS_silver_tmusic_timer_event_callback_trace_20261029.log
- OSOS_silver_tmusic_task_alloc_bounds_20261029.log
- OSOS_silver_tmusic_task_object_allocation_trace_20261029.log
- außerdem die vorangegangenen OSOS_silver_scheduler_timer_expiration_followup_20261029.log
  und OSOS_silver_timer_enqueue_callers_20261029.log.

Alle Läufe verwendeten Ghidra -noanalysis -readOnly.
