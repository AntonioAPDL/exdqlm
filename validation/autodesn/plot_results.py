"""Reproduce scientific PNG/PDF plots from the R study's exported CSV files."""
from pathlib import Path
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = Path(os.getenv("AUTODESN_OUT", "validation/autodesn/artifacts"))
scores = pd.read_csv(OUT / "scores.csv")
observed = pd.read_csv(OUT / "observed.csv")
prob = pd.read_csv(OUT / "model_probabilities.csv")
names = {"linear": "Linear AR(1)", "nonlinear": "Nonlinear autoregression", "seasonal": "Seasonal autoregression"}
methods = ["AutoDESN", "Fixed_DESN", "Gaussian_AR1", "Gaussian_AR12"]
labels = {"AutoDESN": "AutoDESN", "Fixed_DESN": "Fixed DESN", "Gaussian_AR1": "Gaussian AR(1)", "Gaussian_AR12": "Gaussian AR(12)"}
colors = dict(zip(methods, ["#126DA6", "#C56C24", "#78904A", "#8A62A6"]))
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10,
    "axes.spines.top": False, "axes.spines.right": False,
    "axes.labelcolor": "#263747", "text.color": "#263747",
    "axes.titleweight": "bold", "figure.facecolor": "white",
    "savefig.facecolor": "white", "pdf.fonttype": 42})

def save(fig, name):
    fig.savefig(OUT / (name + ".png"), dpi=190, bbox_inches="tight")
    fig.savefig(OUT / (name + ".pdf"), bbox_inches="tight")
    plt.close(fig)

# A prespecified illustrative series: repetition 1, last origin for each DGP.
origin = scores.origin.max()
fig, axes = plt.subplots(3, 1, figsize=(11.7, 8.7), sharex=True)
for ax, kind in zip(axes, names):
    obs = observed[(observed.dgp == kind) & (observed.repetition == 1)]
    obs = obs[(obs.time >= origin - 45) & (obs.time <= origin + 12)]
    ax.plot(obs.time, obs.y, color="#344657", lw=1.25, label="Observed")
    auto = scores[(scores.dgp == kind) & (scores.repetition == 1) & (scores.origin == origin) & (scores.method == "AutoDESN")]
    time = origin + auto.horizon.to_numpy()
    ax.fill_between(time, auto.lower90.to_numpy(), auto.upper90.to_numpy(), color=colors["AutoDESN"], alpha=.17, label="AutoDESN 90% interval")
    for method in ["AutoDESN", "Fixed_DESN", "Gaussian_AR12"]:
        sub = scores[(scores.dgp == kind) & (scores.repetition == 1) & (scores.origin == origin) & (scores.method == method)]
        ax.plot(origin + sub.horizon, sub["mean"], color=colors[method], lw=1.8 if method == "AutoDESN" else 1.25,
                ls="-" if method == "AutoDESN" else "--", label=labels[method])
    ax.axvline(origin + .5, color="#8493A2", ls=":", lw=1)
    ax.set_title(names[kind], loc="left", fontsize=11)
    ax.set_ylabel("Response")
    ax.grid(axis="y", color="#E6EBF0", lw=.7)
axes[-1].set_xlabel("Time · forecast origin at 240")
handles, leg = axes[0].get_legend_handles_labels()
fig.legend(handles, leg, loc="lower center", bbox_to_anchor=(.5, .01), ncol=3, frameon=False, fontsize=9)
fig.suptitle("Gaussian AutoDESN · recursive held-out forecasts", x=.075, ha="left", fontsize=17, weight="bold")
fig.text(.075, .942, "One prespecified example per process. Future observations are excluded from fitting and recursive inputs.", fontsize=10, color="#627181")
fig.subplots_adjust(top=.9, bottom=.14, hspace=.36)
save(fig, "forecast_examples")

# Cluster bootstrap: resample independent simulated series, keeping their
# overlapping origins and all horizons together. Descriptive, not hypothesis tests.
by_series = scores.groupby(["dgp", "method", "repetition"])[["squared_error", "crps", "covered90"]].mean()
rng = np.random.default_rng(93211)
fig, axes = plt.subplots(1, 3, figsize=(12.3, 5), sharey=True)
metrics = [("squared_error", "RMSE ↓", True), ("crps", "CRPS ↓", False), ("covered90", "90% interval coverage", False)]
summary = []
for ai, (metric, title, root) in enumerate(metrics):
    ax = axes[ai]
    for gi, kind in enumerate(names):
        for mi, method in enumerate(methods):
            v = by_series.loc[(kind, method)][metric].to_numpy()
            bootstrap = v[rng.integers(0, len(v), size=(3000, len(v)))].mean(axis=1)
            point = v.mean()
            if root:
                bootstrap = np.sqrt(bootstrap)
                point = np.sqrt(point)
            lo, hi = np.quantile(bootstrap, [.025, .975])
            yy = 2 - gi + (1.5 - mi) * .14
            ax.errorbar(point, yy, xerr=[[max(0, point-lo)], [max(0, hi-point)]], fmt="o", color=colors[method],
                        ms=5, capsize=2, lw=1.35, label=labels[method] if gi == 0 else None)
            summary.append(dict(dgp=kind, method=method, metric=metric, estimate=point, lower=lo, upper=hi))
    ax.set_title(title, loc="left", fontsize=12)
    ax.grid(axis="x", color="#E6EBF0", lw=.7)
    ax.set_ylim(-.45, 2.45)
    ax.set_yticks([2, 1, 0], [names[x] for x in names])
    if metric == "covered90":
        ax.axvline(.9, ls=":", lw=1, color="#526272")
        ax.set_xlim(.45, 1.025)
        ax.xaxis.set_major_formatter(matplotlib.ticker.PercentFormatter(1))
    else:
        ax.set_xlim(left=0)
    ax.spines["left"].set_visible(False)
    ax.tick_params(axis="y", length=0)
fig.suptitle("Forecast validation across repeated simulated series", x=.055, ha="left", fontsize=16, weight="bold")
fig.text(.055, .885, f"{scores.repetition.nunique()} independent series per process · 2 origins · 12 horizons · 1,000 predictive paths", color="#627181")
fig.legend(*axes[0].get_legend_handles_labels(), loc="lower center", bbox_to_anchor=(.5, .04), ncol=4, frameon=False)
fig.text(.055, .01, f"Points are pooled scores. Intervals: 95% bootstrap over whole series (descriptive; {scores.repetition.nunique()} independent replicates).", fontsize=9, color="#627181")
fig.subplots_adjust(left=.21, right=.98, top=.8, bottom=.22, wspace=.22)
save(fig, "forecast_scores")
pd.DataFrame(summary).to_csv(OUT / "bootstrap_summary.csv", index=False)

# Depth and memory mass are meaningful only relative to this finite dictionary.
fig, axes = plt.subplots(1, 2, figsize=(11.4, 4.8))
for ax, field, title in zip(axes, ["D", "m"], ["Reservoir depth", "Input lag count"]):
    grouped = prob.groupby(["dgp", "repetition", "origin", field]).posterior_probability.sum().reset_index()
    avg = grouped.groupby(["dgp", field]).posterior_probability.mean()
    vals = sorted(prob[field].unique())
    width = .7 / len(vals)
    for vi, val in enumerate(vals):
        yy = np.array([avg.loc[(kind, val)] for kind in names])
        xx = np.arange(3) + (vi - (len(vals)-1)/2) * width
        bars = ax.bar(xx, yy, width=width*.9, color=plt.cm.Blues(.4 + .5*vi/max(1,len(vals)-1)), label=f"{field} = {val}")
        mass_labels = ["<1%" if 0 < v < .005 else ">99%" if .995 < v < 1 else f"{v:.0%}" for v in yy]
        ax.bar_label(bars, labels=mass_labels, padding=3, fontsize=9)
    ax.set_xticks(range(3), ["Linear", "Nonlinear", "Seasonal"])
    ax.set_ylim(0, 1.06)
    ax.yaxis.set_major_formatter(matplotlib.ticker.PercentFormatter(1))
    ax.set_title(title, loc="left", fontsize=12)
    ax.grid(axis="y", color="#E6EBF0", zorder=0)
    ax.set_axisbelow(True)
    ax.legend(frameon=False, ncol=len(vals), fontsize=9)
axes[0].set_ylabel("Mean posterior probability")
fig.suptitle("What AutoDESN selects within the prespecified bank", x=.065, ha="left", fontsize=16, weight="bold")
fig.text(.065, .885, "Probabilities averaged across series and origins. These describe predictive representations, not true DGP architecture.", color="#627181", fontsize=9)
fig.subplots_adjust(top=.76, left=.08, right=.98, bottom=.15, wspace=.25)
save(fig, "specification_probabilities")
print("Saved forecast_examples, forecast_scores and specification_probabilities as PNG and PDF.")
