# `time`-Callback-Registry-Belege (31.10.2026)

Die `.application.log`-Dateien enthalten gezielte Ghidra-Abfragen zum
Callback-Tabellen-Eintrag `time`, seiner Registrierung und seinem Event-
Dispatch. Alle Abfragen nutzten das vorhandene Projekt `N5G_OSOS_runtime`
mit `-readOnly -noanalysis`. Es gab keine Geräte- oder Flashzugriffe.

Die Abfrage `OSOS_time_callback_userdata_abi_20261031.application.log`
verifiziert zusätzlich den Callback-ABI-Fluss: Der MainApp-Eintrag liefert
als Registry-Wert `0`; der Timerdatensatz wählt das Empfängerobjekt, ist aber
nicht der Nutzwert des nachfolgenden Typ-`0x12`-Events. Damit erreicht dieser
Eintrag den `FUN_0804bd38`-Identitätszweig nicht.

Der vollständige Befund und seine Grenzen stehen in
`../../OSOS-time-callback-registry-reachability-followup-2026-10-31.md`.
`SHA256SUMS` enthält Prüfsummen für die Rohlogs.
