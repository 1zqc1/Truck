import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd


parser = argparse.ArgumentParser()
parser.add_argument(
    "--csv",
    default=r"D:\Program Files (x86)\TruckSim\data\Results\Run_2920185f-8d94-4568-994a-041f9e06e86b\LastRun_full.csv",
)
args = parser.parse_args()
CSV_PATH = Path(args.csv)

WHEEL_COLUMNS = [
    "Fz_L4", "Fz_L5", "Fz_L6",
    "Fz_R4", "Fz_R5", "Fz_R6",
]
CHANNELS = [
    "Time", "Vx_2", "Ay_2", "Roll_2", "AVz_2", "AVx_2", "Art_H", "Fz_H",
    "Steer_SW", *WHEEL_COLUMNS,
]


def extreme(series: pd.Series, mode: str = "max") -> dict:
    if mode == "max_abs":
        idx = series.abs().idxmax()
    elif mode == "min":
        idx = series.idxmin()
    else:
        idx = series.idxmax()
    return {"value": float(series.loc[idx]), "time_s": float(df.loc[idx, "Time"])}


def settling_time(time: np.ndarray, values: np.ndarray, target: float, tolerance: float) -> float | None:
    if not np.isfinite(target) or tolerance <= 0:
        return None
    within = np.abs(values - target) <= tolerance
    suffix_all = np.logical_and.accumulate(within[::-1])[::-1]
    matches = np.flatnonzero(suffix_all)
    return float(time[matches[0]]) if matches.size else None


df = pd.read_csv(CSV_PATH, usecols=CHANNELS)
df = df.apply(pd.to_numeric, errors="coerce").dropna(subset=["Time"])

left = df[["Fz_L4", "Fz_L5", "Fz_L6"]].sum(axis=1)
right = df[["Fz_R4", "Fz_R5", "Fz_R6"]].sum(axis=1)
denominator = left + right
df["LTR"] = np.where(denominator.abs() > 1e-9, (right - left) / denominator, np.nan)
df["Fz_trailer_total"] = denominator
df["Fz_trailer_left"] = left
df["Fz_trailer_right"] = right
for axle in (4, 5, 6):
    df[f"Fz_axle_{axle}"] = df[f"Fz_L{axle}"] + df[f"Fz_R{axle}"]

time_end = float(df["Time"].max())
end_start = time_end - 1.0
post = df[df["Time"] >= 10.0].copy()
end = df[(df["Time"] >= end_start) & (df["Time"] <= time_end)].copy()

wheel_stack = post[WHEEL_COLUMNS].stack()
wheel_idx = wheel_stack.idxmin()
min_row, min_channel = int(wheel_idx[0]), str(wheel_idx[1])

end_stats = {}
for col in [
    "Vx_2", "Ay_2", "Roll_2", "LTR", "AVz_2", "AVx_2", "Art_H", "Fz_H",
    "Fz_trailer_left", "Fz_trailer_right", "Fz_trailer_total",
    "Fz_axle_4", "Fz_axle_5", "Fz_axle_6",
]:
    end_stats[col] = {
        "mean": float(end[col].mean()),
        "std": float(end[col].std(ddof=1)),
        "min": float(end[col].min()),
        "max": float(end[col].max()),
    }

settling = {}
for col in ["Roll_2", "LTR", "Ay_2", "AVz_2"]:
    target = end_stats[col]["mean"]
    tolerance = max(abs(target) * 0.02, 1e-6)
    settling[col] = {
        "target": target,
        "tolerance_abs": tolerance,
        "settling_time_s": settling_time(
            post["Time"].to_numpy(), post[col].to_numpy(), target, tolerance
        ),
    }

result = {
    "source": str(CSV_PATH),
    "rows": int(len(df)),
    "time_start_s": float(df["Time"].min()),
    "time_end_s": time_end,
    "sample_dt_median_s": float(df["Time"].diff().median()),
    "post_step_window_s": [10.0, time_end],
    "end_window_s": [end_start, time_end],
    "peaks_post_step": {
        "Ay_2_max": extreme(post["Ay_2"], "max"),
        "Ay_2_max_abs": extreme(post["Ay_2"], "max_abs"),
        "Roll_2_max": extreme(post["Roll_2"], "max"),
        "Roll_2_max_abs": extreme(post["Roll_2"], "max_abs"),
        "LTR_max_abs": extreme(post["LTR"], "max_abs"),
        "AVz_2_max_abs": extreme(post["AVz_2"], "max_abs"),
        "AVx_2_max_abs": extreme(post["AVx_2"], "max_abs"),
        "Art_H_max_abs": extreme(post["Art_H"], "max_abs"),
        "Steer_SW_max_abs": extreme(post["Steer_SW"], "max_abs"),
    },
    "wheel_loads_post_step": {
        "minimum_single_wheel_load_N": float(df.loc[min_row, min_channel]),
        "minimum_channel": min_channel,
        "minimum_time_s": float(df.loc[min_row, "Time"]),
        "all_positive": bool((post[WHEEL_COLUMNS] > 0).all().all()),
        "per_channel_min_N": {c: float(post[c].min()) for c in WHEEL_COLUMNS},
    },
    "end_window_stats": end_stats,
    "settling_2pct": settling,
}

print(json.dumps(result, ensure_ascii=False, indent=2))
