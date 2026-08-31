"""Renderizza tavole dedicate alla variante realistica di FOCUS!.

Usa lo stesso impaginatore del catalogo MVP, ma legge e scrive esclusivamente
nelle cartelle della nuova variante.
"""

import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
import render_asset_catalog as renderer


PROJECT_ROOT = Path(__file__).resolve().parents[2]
renderer.MODEL_DIR = PROJECT_ROOT / "assets" / "models" / "realistic"
renderer.PREVIEW_DIR = PROJECT_ROOT / "assets" / "previews" / "realistic"


if __name__ == "__main__":
    renderer.main()
