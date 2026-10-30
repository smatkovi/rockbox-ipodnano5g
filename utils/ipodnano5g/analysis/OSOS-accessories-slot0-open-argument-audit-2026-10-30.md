# `accessories.reg`: Slot-0-Argumentprüfung des Startup-Open-Pfads

Stand: 30.10.2026. Read-only-Ghidra-Auswertung des vorhandenen OSOS-Runtime-Abbilds. Kein Geräte-, USB-, DFU-, Reboot-, NAND-/NOR- oder Flashzugriff.

## Ergebnis

Der automatische Open-Pfad für `iPod_Control/Device/accessories.reg` wählt statisch Registry-Slot 0. Die `1`, die in `FUN_0827dce0(..., 1)` auftaucht, ist kein Provider-Slot: `FUN_0827dce0` leitet sie an `FUN_08263d14` weiter, dessen zweites Argument den Bereitschafts-/Wartepfad steuert. Die anschließende Registry-Auswahl findet separat in `FUN_08268cda` statt.

Damit ist die zuvor offene mögliche Abweichung zwischen `DeviceDiscovery`-Registrierung in Slot 0 und Parser-Open geschlossen: Beide statischen Pfade verwenden Slot 0. Das bestätigt weiterhin weder den Scheduler-Zeitpunkt noch einen erfolgreichen Geräte-Open.

## Register- und Argumentfluss

1. `FUN_0802c3c4` ruft `FUN_082721f0(local_1c, uVar1, 0)` für den festen Registry-Pfad auf. In `FUN_082721f0` wird `r2 == 0` als Open-Modus 1 an `FUN_0827ea84` abgebildet; der vierte Parameter ist dort die Konstante 0.
2. `FUN_0827ea84` reicht diesen vierten Parameter unverändert als `r3` an `FUN_0819878c` weiter. `FUN_0819878c` setzt daraus `r1 = 0` für den Aufruf von `FUN_082784c8`.
3. Die Instruktionen von `FUN_082784c8` ändern `r1` vor `bl FUN_0827faca` nicht. `FUN_0827faca` übernimmt diesen Wert in `r4` und reicht ihn als Index an `FUN_08268cda` weiter.
4. `FUN_08268cda` ruft `FUN_0826384c(manager, index, 0)` auf. Bei erfolgreichem Slot-Check lädt es `*(manager + index*4)`; für diesen Pfad ist `index == 0`. `FUN_0828ca1e` formt daraus den Provider-Kontext `provider + 0x44`.
5. Der anschließend bereits dokumentierte `FUN_08224970`-Dispatch ruft den Open-Eintrag des Provider-VTables bei `+0x14` auf. Für den FAT-Provider zeigt dieser Eintrag auf `FUN_0812a870`.

## Bedeutung des Arguments `1`

`FUN_0827dce0` lädt den Kontext aus `param_1 + 4` und ruft `FUN_08263d14(context, 1)` auf. `FUN_08263d14` wartet bei fehlendem Kontext oder — bei gesetztem zweiten Argument — solange der Kontextstatus nicht bereit ist; nach dem ersten Warten setzt es dieses Argument auf 0 und holt den Managerkontext neu. Der Wert 1 wird nicht an `FUN_08268cda` durchgereicht und kann deshalb nicht Slot 1 bezeichnen.

## Belege

- `evidence/accessories-slot0-open-2026-10-30/ghidra_accessories_open_slot_path_20261030.application.log` — Ghidra-Decompilierungen von `FUN_082721f0`, `FUN_0827ea84`, `FUN_0819878c`, `FUN_082784c8`, `FUN_0827faca`, `FUN_08268cda` und `FUN_0823fad4`.
- `evidence/accessories-slot0-open-2026-10-30/ghidra_accessories_open_slot_listing_20261030.application.log` — Thumb-Instruktionen mit Registerübergaben, insbesondere der unveränderte `r1`-Wert bei `FUN_082784c8` → `FUN_0827faca` und der Indexfluss in `FUN_08268cda`.
- `evidence/accessories-slot0-open-2026-10-30/SHA256SUMS` — Prüfsummen der beiden Ghidra-Belege.
- `OSOS-accessories-fat-read-chain-followup-2026-10-29.md` sowie `evidence/rtos-task-order-2026-10-29/OSOS_runtime_slot0_provider_chain_20261029.log` — VFS-/FAT-Open-Dispatch und Slot-0-Provider-Provenienz.
- Die beiden neuen Ghidra-Läufe öffneten das bestehende Projekt mit `-readOnly -noanalysis`; sie änderten das Ghidra-Projekt nicht.

## Grenzen und nächster Offline-Schritt

Statisch verbunden sind jetzt der Startup-Open-Aufruf, sein Slotindex 0, der Provider-Kontext und die FAT-Open-Methode. Der vorherige Parser-Rehost setzt Volume-/Stream-/Handlezustand teilweise vor und trifft daher den echten Open-Aufruf nicht. Der nächste sinnvolle Offline-Schritt ist, den Rehost an dieser Grenze zu erweitern und die Original-Open-/Read-Funktionen mit lokal gespeicherten FAT-/Verzeichnisdaten auszuführen. Ein tatsächlicher Geräte-Open, Queue-Zustellung, Overflow, Codeausführung und Rockbox-Handoff bleiben unbestätigt.
