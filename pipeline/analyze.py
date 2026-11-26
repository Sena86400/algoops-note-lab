"""passes.csv から、記事に埋め込む数値（summary.json）を作る。

記事の数値はすべてこのファイルから読み込み、手で書き写さない。

使い方:
  python pipeline/analyze.py <passes.csv> <summary.json>
"""
from __future__ import annotations

import csv
import json
import statistics as st
import sys
from pathlib import Path

# EAの既定値（mql5/README.md のパラメータ表と一致させる）
DEFAULTS = {"InpFastPeriod": 20, "InpSlowPeriod": 50, "InpSlAtrMult": 2.0, "InpTpAtrMult": 3.0}
PARAMS = ["InpFastPeriod", "InpSlowPeriod", "InpSlAtrMult", "InpTpAtrMult"]
METRICS = ["Profit", "Profit Factor", "Recovery Factor", "Sharpe Ratio", "Equity DD %", "Trades", "Custom"]
KEYS = {
    "Profit": "profit",
    "Profit Factor": "profit_factor",
    "Recovery Factor": "recovery_factor",
    "Sharpe Ratio": "sharpe_ratio",
    "Equity DD %": "equity_dd_pct",
    "Trades": "trades",
    "Custom": "custom",
    "InpFastPeriod": "fast",
    "InpSlowPeriod": "slow",
    "InpSlAtrMult": "sl_atr",
    "InpTpAtrMult": "tp_atr",
}


def load(path: Path) -> list[dict[str, float]]:
    with path.open(encoding="utf-8") as f:
        return [{k: float(v) for k, v in row.items()} for row in csv.DictReader(f)]




def describe(p: dict[str, float]) -> dict:
    return {KEYS[k]: p[k] for k in PARAMS + METRICS}


def rank(passes: list[dict[str, float]], target: dict[str, float], key: str) -> int:
    """key の降順で何位か（1始まり、同値は上位側）。"""
    return 1 + sum(p[key] > target[key] for p in passes)


def summarize(passes: list[dict[str, float]], defaults: dict[str, float]) -> dict:
    profits = [p["Profit"] for p in passes]
    q = st.quantiles(profits, n=4)
    default = next(p for p in passes if all(p[k] == defaults[k] for k in PARAMS))
    best = max(passes, key=lambda p: p["Custom"])
    best_profit = max(passes, key=lambda p: p["Profit"])
    n = len(passes)
    return {
        "passes": n,
        "profitable": sum(x > 0 for x in profits),
        "profitable_pct": round(100 * sum(x > 0 for x in profits) / n, 1),
        "profit": {
            "min": min(profits),
            "q1": q[0],
            "median": st.median(profits),
            "q3": q[2],
            "max": max(profits),
        },
        "trades": {"min": min(p["Trades"] for p in passes), "max": max(p["Trades"] for p in passes)},
        "default": {**describe(default), "rank_profit": rank(passes, default, "Profit"), "rank_custom": rank(passes, default, "Custom")},
        "best_custom": {**describe(best), "rank_profit": rank(passes, best, "Profit")},
        "best_profit": describe(best_profit),
    }


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    passes = load(Path(argv[0]))
    summary = summarize(passes, DEFAULTS)
    out = Path(argv[1])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"summary -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
