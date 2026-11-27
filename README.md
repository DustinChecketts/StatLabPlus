# StatLabPlus prototype

Install: download prototype ZIP, extract and rename folder StatLabPlus, place in Interface/AddOns. Interface 16001 is provisional.

Recording starts on login/reload. /slp shows status; /slp snap or /slp scan forces a snapshot; /slp pause toggles collection; /slp new starts a fresh session; /slp export prints instructions. Reload or log out to flush account-wide WTF/Account/<account>/SavedVariables/StatLabPlus.lua. Upload privately, not to this public repository.

Schema 1 stores sessions with build, character, realm, start/end times and snapshots. Snapshots store timestamp, trigger, raw API return tuples and missing/error/restricted/type markers, primary and derived stats, equipment IDs and links, legacy talent, buff and skill API results. No formulas applied. Events coalesced for 0.5 seconds; identical snapshots suppressed. Limit 2,000 snapshots per session; no automatic session pruning.

First test: log in, /slp scan, change several gear pieces, wait a second between changes, apply/remove a blessing, /slp snap, reload and upload SavedVariables.

Limitations: not tested in client. API signatures and availability need verification. Legacy aura/talent/skill APIs may be absent. Direct item stat tables, modern aura fallback, pet collection, explicit health regeneration API and periodic polling are pending. Debounce may miss brief changes; aura timing may defeat deduplication. StormCore integration and native character sheet source audit pending. No combat logging or CSV exporter; raw SavedVariables is intended for offline analysis.
