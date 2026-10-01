# Mouser All-Doc-Types Harvest (5K list)

## What this does
For every MPN in a4.xlsx (3,998 parts):
1. Opens Mouser category search `/en/c/?q={MPN}` through the Google translate bridge
2. Extracts PCN rows (your spec) AND finds the product page link
3. Opens the product page through the bridge (3-lane fallback with qs-fix)
4. Extracts ALL document sections: Datasheets, PCN/EOL, Environmental Documents,
   3D Models/CAD, Application Notes, Spec Sheets, ...
5. Writes:
   - final_all.csv  -> Manufacturer, Doc Type, Doc Link, Part Number  (ALL doc types)
   - pcn_docs.csv   -> your exact PCN schema
   - results.jsonl  -> raw per-part records

## Run on your PC (recommended: no DataDome, no Google penalties)
```
pip install -r requirements.txt
python bridge_all.py --mode all --rpm 6 --workers 8
```
- Checkpoint-safe (bridge_done.txt) - safe to stop/resume any time
- CSVs update every 10 parts
- Optional: `python bkeeper2.py` auto-restarts and probe-gates the run

## Files
- bridge_all.py    - the harvester (search PCN mode + full all-doc mode)
- bkeeper2.py      - supervisor: probe-gated launch, crash recovery
- selftest_all.py  - offline parser tests
- mouser_harvester.py / _fast.py - original browser harvesters (home IP)
- mouser_api_harvest.py - Mouser Search API mode (free key = fastest)
- input_lists/a4_5K_parts.xlsx - the 3,998-part queue

## Troubleshooting: DNS / translate.goog won't resolve (home PC)
Some ISP/corporate DNS filters block or poison `*.translate.goog`. Switch DNS to
Google Public DNS (per https://developers.google.com/speed/public-dns/docs/using):
- Quick: set DNS to 8.8.8.8 / 8.8.4.4 on your NIC or router
- Private: DNS-over-TLS `dns.google:853` (Windows 11 / Android 9+ / Linux systemd-resolved)
- Test in browser: https://dns.google/resolve?name=www-mouser-com.translate.goog&type=A
Note: Google rate-limits by SOURCE IP (verified: all 142.250.x.x frontends share the
penalty), so if you see google.com/sorry pages - pause the run 1-4 h; changing DNS
or frontend IPs will NOT lift it. The keeper's probe-gating handles this automatically.

## Smart circuit breakers module (menu option 8)
Put one part number per line in `input_lists/smart_breakers.txt` (`#` = comment),
then run `run_mouser.bat` -> 8. It uses its own checkpoint/output so it never mixes
with the 5K run: results go to `pc_bundle/final_breakers.csv` and `pc_bundle/mm_data_breakers/`.
`--file` also accepts .txt/.csv lists (first column) in addition to .xlsx.

## Watch it browse (menu option 9)
Opens visible Camoufox windows (one per worker) and loads mouser.com directly,
so you can watch each part get searched and its product page opened.
Requires the `camoufox` and `playwright` packages plus the Camoufox browser
download (menu option 1 does both). Keep workers low (2-4) - each one is a full browser window and
uses much more CPU/RAM than the invisible mode. Results go to the same
final_all.csv / bridge_done.txt as option 4, so it can pick up where a
headless run left off, and vice versa.

### Camoufox browser, close/reopen per part (menu option 9)
Option 9 drives a visible Camoufox window (a stealth Firefox build, run through
Playwright) per worker. Plain Selenium Firefox is flagged as automated by
Mouser's bot protection; Camoufox hides those signs. A brand-new browser is
opened for every part and closed when that part is done.

- Install once (menu option 1 does it): `pip install camoufox playwright`, then
  `python -m camoufox fetch` (or `python bridge_visible.py --fetch`).
- Default `--profile-mode persistent`: a permanent profile per window in
  `pc_bundle/camoufox_profile_N/`. Run once with
  `python bridge_visible.py --setup-login`, solve Mouser's slider in the
  window, press Enter. The trust cookie is kept for every later run.
- `--profile-mode fresh`: blank profile every part (slider shows up often).
  The old `copy`/`direct` modes are treated as persistent.
- `--window 1280x800` sets the window size. `--no-tls-compat` leaves the
  post-quantum TLS / HTTP3 settings of the browser alone (they are switched
  off by default because some networks break them).
- One profile = one browser at a time, so each worker has its own folder.
- The script stays on the Mouser host you get redirected to (for example
  eu.mouser.com).

If Mouser shows its own check (captcha), the Camoufox window is left open for
`--captcha-wait` seconds (default 120) so you can solve it by hand; the run
then continues automatically.

### Human-like navigation (`--nav human`, default in direct mode)
Mouser's bot protection can answer a bare driver.get() with "Access Denied ...
automation tools" even though the same URL typed by hand works. Each part now
first lands on mouser.com, pauses, then moves inside the site with a
page-initiated navigation (real Referer). `--nav plain` restores plain
driver.get(). For a guaranteed, supported route use mouser_api_harvest.py
(Mouser Search API, free key).
