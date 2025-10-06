# scripts/convert.py - placeholder conversion script used in CI.
import argparse
from pathlib import Path
parser = argparse.ArgumentParser()
parser.add_argument("--model", required=True)
parser.add_argument("--out", required=True)
args = parser.parse_args()
model_path = Path(args.model)
out_path = Path(args.out)
out_path.parent.mkdir(parents=True, exist_ok=True)
with open(out_path, "wb") as f:
    f.write(b"converted placeholder - replace with real conversion pipeline")
print("WROTE", out_path)
