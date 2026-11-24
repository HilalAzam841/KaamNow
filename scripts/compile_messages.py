"""Compiles locale/*/LC_MESSAGES/django.po into django.mo without GNU gettext.

    pip install -r requirements-dev.txt
    python scripts/compile_messages.py

(`python manage.py compilemessages` does the same if GNU gettext is installed.)
"""

from pathlib import Path

import polib

root = Path(__file__).resolve().parent.parent / "locale"
for po_path in sorted(root.glob("*/LC_MESSAGES/*.po")):
    po = polib.pofile(str(po_path))
    po.save_as_mofile(str(po_path.with_suffix(".mo")))
    print(f"{po_path.relative_to(root.parent)}: {len(po.translated_entries())}/{len(po)} translated")
