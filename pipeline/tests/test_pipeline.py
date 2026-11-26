import csv
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import analyze  # noqa: E402
import parse_report  # noqa: E402

COLS = ["Pass", "Result", "Profit", "Profit Factor", "Recovery Factor", "Sharpe Ratio", "Custom",
        "Equity DD %", "Trades", "InpFastPeriod", "InpSlowPeriod", "InpSlAtrMult", "InpTpAtrMult"]
ROWS = [
    [1, 2, 300, 1.3, 2.0, 1.1, 2.0, 10, 100, 10, 100, 2.0, 4.0],
    [0, -1, -100, 0.9, -0.5, -0.4, -0.5, 20, 120, 20, 50, 2.0, 3.0],
    [2, 0, 50, 1.05, 0.2, 0.1, 0.2, 15, 90, 10, 50, 1.0, 0.0],
]


def report_xml() -> str:
    def row(cells, kind):
        return "<Row>" + "".join(f'<Cell><Data ss:Type="{kind}">{c}</Data></Cell>' for c in cells) + "</Row>"
    body = row(COLS, "String") + "".join(row(r, "Number") for r in ROWS)
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" '
        'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">'
        "<DocumentProperties xmlns=\"urn:schemas-microsoft-com:office:office\"><Server>Broker-LIVE</Server></DocumentProperties>"
        f'<Worksheet ss:Name="Tester Optimizator Results"><Table>{body}</Table></Worksheet></Workbook>'
    )


class PipelineTest(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        (self.dir / "r.xml").write_text(report_xml(), encoding="utf-8")

    def test_parse_drops_metadata_and_sorts_by_pass(self):
        passes = parse_report.read_passes(self.dir / "r.xml")
        self.assertEqual(len(passes), 3)
        parse_report.write_csv(passes, self.dir / "p.csv")
        text = (self.dir / "p.csv").read_text(encoding="utf-8")
        self.assertNotIn("Broker", text)
        with (self.dir / "p.csv").open(encoding="utf-8") as f:
            self.assertEqual([r["Pass"] for r in csv.DictReader(f)], ["0", "1", "2"])

    def test_summary(self):
        parse_report.write_csv(parse_report.read_passes(self.dir / "r.xml"), self.dir / "p.csv")
        s = analyze.summarize(analyze.load(self.dir / "p.csv"), analyze.DEFAULTS)
        self.assertEqual(s["passes"], 3)
        self.assertEqual(s["profitable"], 2)
        self.assertEqual(s["default"]["profit"], -100)
        self.assertEqual(s["default"]["rank_profit"], 3)
        self.assertEqual(s["best_custom"]["fast"], 10)
        self.assertEqual(s["best_custom"]["slow"], 100)


if __name__ == "__main__":
    unittest.main()
