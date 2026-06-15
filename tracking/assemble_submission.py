#!/usr/bin/env python3
"""Assemble the Milestone 2 submission ZIP — `nexamart_m2_group_<N>.zip`.

Submission spec (README.md / docs/tasks/lead.md Task 15):
  /report        nexamart_m2_report.pdf
  /notebooks     05_anomaly_resolution.ipynb, 06_gold_rebuild.ipynb   (+ _shared/ deps)
  /sql           anomaly_discovery, anomaly_resolution, validation_suite, kpi_views (4 files)
  /dashboard     nexamart_dashboard.(pbix|twbx) + screenshots/*.png
  /presentation  nexamart_m2_presentation.pptx + nexamart_m2_slides_outline.md
EXCLUDED: .private/, sql/_m1_seed/, snowflake_setup_m2.sql, M1 notebooks 01-04.

Usage:
  python tracking/assemble_submission.py            # dry-run: report present / MISSING
  python tracking/assemble_submission.py --build 7  # build nexamart_m2_group_7.zip (must be complete)
"""
import os, sys, zipfile, glob

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (repo-relative source, arc path inside zip, required?) — globs allowed in source
MANIFEST = [
    ("report/nexamart_m2_report.pdf",                 "report/nexamart_m2_report.pdf",                 True),
    ("notebooks/05_anomaly_resolution.ipynb",         "notebooks/05_anomaly_resolution.ipynb",         True),
    ("notebooks/06_gold_rebuild.ipynb",               "notebooks/06_gold_rebuild.ipynb",               True),
    ("notebooks/_shared/*.py",                         "notebooks/_shared/",                            False),  # 05/06 import these (include for runnability; non-blocking)
    ("sql/anomaly_discovery.sql",                     "sql/anomaly_discovery.sql",                     True),
    ("sql/anomaly_resolution.sql",                    "sql/anomaly_resolution.sql",                    True),
    ("sql/validation_suite.sql",                      "sql/validation_suite.sql",                      True),
    ("sql/kpi_views.sql",                             "sql/kpi_views.sql",                             True),
    ("presentation/nexamart_m2_presentation.pptx",   "presentation/nexamart_m2_presentation.pptx",    True),
    ("presentation/nexamart_m2_slides_outline.md",   "presentation/nexamart_m2_slides_outline.md",    True),
    ("dashboard/nexamart_dashboard.*",               "dashboard/",                                    True),   # .pbix/.twbx/.html
    ("dashboard/screenshots/*.png",                  "dashboard/screenshots/",                        True),
]
# Anything matching these is NEVER allowed in the zip (defence in depth).
FORBIDDEN = (".private", "_m1_seed", "snowflake_setup_m2.sql")

def resolve(src):
    """Return list of (abs_path, is_glob) for a manifest source entry."""
    p = os.path.join(REPO, src)
    if any(ch in src for ch in "*?[]"):
        return sorted(glob.glob(p))
    return [p] if os.path.exists(p) else []

def main():
    build = "--build" in sys.argv
    group = None
    if build:
        i = sys.argv.index("--build")
        group = sys.argv[i+1] if i+1 < len(sys.argv) else None

    rows, entries, missing = [], [], []
    for src, arc, req in MANIFEST:
        hits = resolve(src)
        if hits:
            for h in hits:
                arcname = arc + os.path.basename(h) if arc.endswith("/") else arc
                entries.append((h, arcname))
            rows.append((f"OK   ({len(hits)})", src))
        else:
            rows.append(("MISSING ", src))
            if req: missing.append(src)

    print(f"\nSubmission manifest  (repo: {REPO})\n" + "-"*70)
    for status, src in rows:
        print(f"  [{status}] {src}")
    # guard
    bad = [a for _, a in entries if any(f in a for f in FORBIDDEN)]
    if bad:
        sys.exit(f"\nABORT: forbidden paths matched: {bad}")

    if missing:
        print("\nNOT READY -- missing required items:")
        for m in missing: print(f"    - {m}")
        print("\n(The dashboard artifact + screenshots are produced in P7. "
              "Re-run with --build <N> once they exist.)")
        return

    if not build:
        print(f"\nALL PRESENT -- {len(entries)} files ready. "
              f"Run:  python tracking/assemble_submission.py --build <N>")
        return

    if not group or not group.isalnum():
        sys.exit("ERROR: provide a group number, e.g. --build 7")
    out = os.path.join(REPO, f"nexamart_m2_group_{group}.zip")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for src_path, arcname in entries:
            z.write(src_path, arcname)
    print(f"\nBUILT {out}  ({len(entries)} files, {os.path.getsize(out)//1024} KB)")

if __name__ == "__main__":
    main()
