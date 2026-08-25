from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "42" / "mod.info"
VERSION_FILE = ROOT / "VERSION"
README = ROOT / "README.md"


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


version = VERSION_FILE.read_text(encoding="utf-8").strip()
manifest = MANIFEST.read_text(encoding="utf-8")
readme = README.read_text(encoding="utf-8")

if f"modversion={version}" not in manifest:
    fail("VERSION and 42/mod.info modversion do not match")
if "id=CursedFrequencies" not in manifest:
    fail("the stable public Mod ID changed")
if not readme.startswith(f"# Cursed Frequencies v{version}\n"):
    fail("README heading and VERSION do not match")

lua_files = sorted((ROOT / "42" / "media" / "lua").rglob("*.lua"))
if not lua_files:
    fail("no Lua source files found")

for path in lua_files:
    text = path.read_text(encoding="utf-8")
    if "<<<<<<<" in text or ">>>>>>>" in text or "=======" in text:
        fail(f"merge-conflict marker found in {path.relative_to(ROOT)}")
print(f"Validated Cursed Frequencies v{version}: {len(lua_files)} Lua files")
