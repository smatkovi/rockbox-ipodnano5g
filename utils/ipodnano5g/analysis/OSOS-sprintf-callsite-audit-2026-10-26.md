# OSOS: Audit direkter Aufrufer des unbeschränkten Formatierers

Stand: 26.10.2026. Die Prüfung lief statisch und read-only auf dem lokalen
OSOS-Ghidra-Projekt. Kein Gerätezugriff, kein USB-/DFU-/Bootversuch und keine
Flashoperation.

## Neuer Speicherfehler-Kandidat: `FUN_081d75a8`

`FUN_081d75a8` setzt den Zielstring zunächst auf leer und durchläuft danach
acht Iterationen. In jeder Iteration ruft es `FUN_081c38b0` mit dem Format
`"%s %08x"` auf und hängt das Ergebnis an denselben Zielpuffer an. Jeder
Durchlauf schreibt ein Leerzeichen und acht Hexziffern; acht Durchläufe plus
NUL-Terminierung ergeben 73 Bytes.

Zwei direkte Aufrufer reservieren jeweils einen 68-Byte-Stackpuffer:

- `FUN_081ca8a4`, Aufruf `0x081ca954`, Ziel `sp+8`. Die fünf Bytes hinter dem
  Array treffen die lokalen Ausgabeplätze bei `sp+0x4c` und `sp+0x50`.
- `FUN_081d66a0`, Aufruf `0x081d680a`, Ziel `sp+0xc`. Die fünf Bytes dahinter
  treffen ein lokales Zwischenwort und den ersten Byteplatz des nachfolgenden
  Ausgabeobjekts.

Damit ist ein Schreibzugriff von fünf Bytes über beide Arrayenden hinaus
statisch belegt. `FUN_081d75a8` liest außerdem acht Wörter aus seinem eigenen
Stackbereich bei `sp+4`, für die im Funktionskörper keine vorherigen Stores
liegen. Die resultierenden Hexwerte können daher alte Stackdaten offenlegen;
ein kontrollierter Angreiferwert dafür ist nicht nachgewiesen.

Die übergeschriebenen Bytes erreichen in den beiden Aufrufern weder einen
gespeicherten LR noch einen Funktionszeiger. Direkt danach werden die
benachbarten Slots als Ausgabespeicher an `FUN_081cbb38` übergeben. Dessen
vorgelagerte Hilfsfunktion `FUN_08289cb8` ist ein `bx lr`-Stub; die alten
Inhalte dieser Slots werden in dem geprüften Pfad nicht als Zeiger verwendet.
Ein Absturz, eine zuverlässige Kontrollflussübernahme oder beliebige
Codeausführung ist dadurch nicht belegt.

Die beiden Aufrufer sind reale Codeverweise im untersuchten OSOS-Abbild. Ein
beim Kaltstart wiederholbarer Auslöser sowie eine vom Nutzer kontrollierbare
Eingabe zu diesen Aufrufen wurden nicht festgestellt. Der Kandidat ist daher
ein bestätigter kleiner Stack-Out-of-bounds-Schreibzugriff, aber kein
bestätigter RCE-Pfad.

## Weitere direkte Aufrufstellen

Die Prüfung der direkten Referenzen auf `FUN_081c38b0` ergab 40 Aufrufstellen
im Ghidra-Projekt. Die fünf kurzen Pfadformatierer im Bereich `0x081066a4`
bis `0x081071ac` verwenden verschleierte, im Code gespeicherte Namenswerte.
Mehrere kleine Thread-Namenspuffer formatieren Zahlen mit `%d`. Der
Formatzeichenfolgen-Builder `FUN_08288698` erhält von seinen zwei gefundenen
Aufrufern statische Formatbausteine. In diesen geprüften Aufrufstellen ergab
sich kein weiterer belegter dateikontrollierter Schreibpfad.

Der zuvor gefundene Device-XML-Loader `0x08087d2c` bleibt der stärkste
dateikontrollierte Formatter-Kandidat: Er kombiniert geparste XML-Knotennamen
in einem 252-Byte-Puffer. Der Parser erhält `0x8000` als Anfangsgröße, kann
seinen Puffer laut Wachstumspfad aber vergrößern. Seine Registrierung oder
indirekte Aufrufstelle und der Kaltstartpfad sind weiterhin nicht gefunden.
Details dazu stehen in
`OSOS-dynamic-device-xml-parser-audit-2026-10-26.md`.

## Nächste statische Schritte

1. Die Registrierung bzw. virtuelle Bindung von `0x08087d2c` finden und die
   Herkunft seines Dateinamens bis zu einem normalen Start- oder Eventpfad
   verfolgen.
2. Den Ereignis- und Callback-Ursprung von `FUN_081ca8a4` und
   `FUN_081d66a0` zuordnen; klären, ob die ausgegebenen Stackwerte außerhalb
   des lokalen Callbacks sichtbar werden.
3. Den bereits dokumentierten `accessories.reg`- und ATA-Providerpfad nur an
   den noch offenen automatischen Startstellen weiterverfolgen, statt die
   zuvor bewiesenen Stack-/ROP-Bausteine erneut abzuleiten.

## Rohbelege

- `/tmp/OSOS_sprintf_callers_20261026.txt` – direkte Referenzen auf den
  Formatter
- `/tmp/OSOS_sprintf_callers_decomp_followup_20261026.txt` – Decompilation der
  Aufrufer
- `/tmp/OSOS_hex_formatter_followup_20261026.txt` – Schleife, Stackpuffer und
  Aufrufkontexte
- `/tmp/OSOS_hex_string_helper_followup_20261026.txt` – nachgelagerter
  String-Helper
- `/tmp/OSOS_other_sprintf_refs_20261026.txt` – Referenzen auf weitere
  geprüfte Formatter-Aufrufer
- `/tmp/OSOS_sprintf_constant_values_20261026.txt` – Bytes der geprüften
  Formatzeichenfolgen

Alle verwendeten Ghidra-Läufe liefen mit `-noanalysis -readOnly`; Änderungen
am Projekt wurden verworfen.
