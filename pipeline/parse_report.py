"""MT5の最適化レポート（Excel 2003形式のXML）を passes.csv に変換する。

レポートにはブローカーのサーバー名などが含まれるため、表の部分だけを取り出す。

使い方:
  python pipeline/parse_report.py <report.xml> <passes.csv>
"""
from __future__ import annotations

import csv
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {"ss": "urn:schemas-microsoft-com:office:spreadsheet"}


def read_passes(path: Path) -> list[dict[str, float]]:
    """最初のワークシートの表を、列名をキーにした辞書のリストとして返す。"""
    root = ET.parse(path).getroot()
    rows = root.findall(".//ss:Worksheet/ss:Table/ss:Row", NS)
    if not rows:
        raise ValueError(f"表が見つからない: {path}")
    table = [[(c.findtext("ss:Data", default="", namespaces=NS)) for c in r.findall("ss:Cell", NS)] for r in rows]
    header, body = table[0], table[1:]
    passes = []
    for row in body:
        if len(row) != len(header):
            raise ValueError(f"列数が見出しと合わない行がある: {row}")
        passes.append({h: float(v) for h, v in zip(header, row)})
    return passes


def write_csv(passes: list[dict[str, float]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    passes = sorted(passes, key=lambda p: p["Pass"])
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(passes[0].keys()))
        w.writeheader()
        for p in passes:
            w.writerow({k: (int(v) if float(v).is_integer() else v) for k, v in p.items()})


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    passes = read_passes(Path(argv[0]))
    write_csv(passes, Path(argv[1]))
    print(f"{len(passes)} passes -> {argv[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
