# iPodSettings: Prüfen, ob sich der vollständige Stream-Cleanup rehosten lässt

Stand: 31.10.2026. Read-only-Ghidra-Abfragen und Audit des bestehenden
ARM1176-QEMU-Rehosts. Kein Geräte-, USB-, DFU-, NAND-, NOR- oder
Firmwarezugriff.

## Ergebnis

Der erfolgreiche `N82_tail_00_streamslot_pass`-Lauf führt den Originalparser,
beide modellierten Callbackpaare, den Original-Freepfad, den Dokument-Cleanup
`FUN_0827ec10` und den Hilfsvektor-Aufbau/-Destruktor aus. Er führt **nicht**
den vollständigen Loader-Stream-Cleanup aus. Der fehlende Teil kann nicht
seriös ergänzt werden, indem man einen genullten oder frei erfundenen
Streamkontext an `FUN_081d0ff0` übergibt: Der Originalpfad benutzt eine
registrierte Objektinstanz, deren Felder und Referenzen beim echten VFS-Open
und bei der Providerwahl entstehen.

## Statisch verifizierte Kette

- `FUN_081d0ff0(context)` gibt zuerst den optionalen Pufferdeskriptor bei
  `context+0x54` frei und löscht seine beiden Wörter. Danach ruft es
  `FUN_081ada78(context)` auf.
- `FUN_081ada78` setzt den Stream-VTablezeiger, ruft `FUN_0825d99c` auf,
  zerstört den Hilfsvektor bei `context+0x40`, gibt das Unterobjekt bei
  `context+0x0c` frei und zerstört zuletzt den registrierten Wrapper.
- `FUN_0825d99c` erzeugt über `context+4` einen temporären, referenzgezählten
  Zugriff auf `+0x44`, prüft den Vektor und schließt nur bei Handle
  `context+0x18 != -1` den Provider. Im geschlossenen Fall liest es den
  Status bei `context+0x1c` und gibt den temporären Zugriff wieder frei.
- Der Wrapper-Cleanup `FUN_082784ac` geht in `FUN_0828c488` über. Diese
  Funktion hält die Referenz des Registryobjekts fest und ruft
  `FUN_08299178` auf. Der Decompiler zeigt dort eine Traversierung der
  Baumlinks bei Objektoffset `+0x10` und die Entfernung des Wrappers aus
  diesem Registrybaum. Danach wird die Referenz freigegeben.
- `FUN_08191cdc` gibt die äußere Instanz schließlich über den OSOS-Allocator
  mit Freigabetyp 2 frei.
- Der Originalkonstruktor `FUN_0831fdbc` ruft
  `FUN_0819878c(..., mode=1, ..., 0x400, 1, 0)` auf, initialisiert den
  Pufferdeskriptor und ruft `FUN_0833a668` für den Open-/Readerzustand auf.
  Der Konstruktor legt auch den Wrapper im Registrykontext an. Die nötigen
  Registry- und Providerobjekte lassen sich nicht aus den bisherigen
  Parser-Rehosts ableiten.

Die VTable-Abfragen bestätigen `DAT_081ada9c = 0x08535648` für das
Streamobjekt und `DAT_082784c4 = 0x0850174c` für den Wrapper. Die neuen
Ghidra-Abfragen wurden mit `-noanalysis -readOnly` auf dem bestehenden
Runtimeprojekt ausgeführt.

## Was damit offen bleibt

Die aktuelle QEMU-Variante mit `MODEL_STREAM_SLOT` bildet nur den
Ein-Element-Hilfsvektor ab und ruft dessen Originaldestruktor
`FUN_08281cf4` auf. Sie initialisiert keinen echten äußeren Stream über
`FUN_0831fdbc`, führt keinen echten Provider-Open aus und entfernt keinen
Wrapper aus dem globalen Registrybaum. Daher ist ihr `PASS` kein Test von
`FUN_081d0ff0`, `FUN_0825d99c`, `FUN_082784ac` oder dem abschließenden
`FUN_08191cdc`.

Eine synthetische Tree-/Refcount-Instanz würde nur zeigen, dass ein von uns
vorgegebenes Layout aufgerufen werden kann; sie würde die tatsächliche
Registrierung und Lebensdauer nicht validieren. Der nächste belastbare
Offline-Schritt wäre, den echten Konstruktor mit dem vorhandenen
Provider-/Volume-Rehost auszuführen und genau diesen Rückgabekontext wieder
abzubauen. Bis Providerregistrierung, Mount, Handle und Registrybaum im selben
Lauf initialisiert sind, bleibt der vollständige Stream-Cleanup bewusst
außerhalb des Harness.

## Belege

- Ghidra-Abfragen und VTables:
  `evidence/xml-stream-cleanup-2026-10-31/`
- Bisheriger N82-Rehost und Läufe:
  `evidence/xml-heap-qname-sweep-2026-10-31/`
- Constructor-/Destruktoroffsets:
  `evidence/xml-heap-2026-10-29/OSOS_iPodSettings_loader_cleanup_object_bridge_20261030.txt`

Es wurden keine Gerätesektoren geändert und keine Firmwareaktion durchgeführt.
