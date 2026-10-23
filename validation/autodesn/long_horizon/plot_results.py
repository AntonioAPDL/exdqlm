"""Render the frozen 500/500/100 experiment from its exported CSV evidence."""
from pathlib import Path
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = Path(os.getenv("AUTODESN_LONG_OUT", "validation/autodesn/long_horizon/artifacts"))
scores = pd.read_csv(OUT / "scores.csv")
observed = pd.read_csv(OUT / "observed.csv")
prob = pd.read_csv(OUT / "probability.csv")
names = {"dynamic_seasonal": "Trend + two seasonal harmonics · period 90",
         "linear": "Linear autoregression", "nonlinear": "Nonlinear autoregression"}
colors = {"AutoDESN": "#126DA6", "Fixed_DESN": "#C16B37", "Gaussian_AR1": "#9561A0",
          "Gaussian_AR90": "#508565", "Oracle_DGP": "#263746",
          "Seasonal_naive90": "#A29145", "Constant": "#999999"}
labels = {"AutoDESN": "AutoDESN", "Fixed_DESN": "Fixed DESN", "Gaussian_AR1": "Gaussian AR(1)",
          "Gaussian_AR90": "Gaussian AR(90)", "Oracle_DGP": "Known DGP",
          "Seasonal_naive90": "Seasonal naive", "Constant": "Constant"}
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10, "pdf.fonttype": 42,
    "axes.spines.top": False, "axes.spines.right": False, "axes.titleweight": "bold",
    "text.color": "#263746", "axes.labelcolor": "#263746", "figure.facecolor": "white"})

def save(fig, name):
    fig.savefig(OUT / f"{name}.png", dpi=190, bbox_inches="tight")
    fig.savefig(OUT / f"{name}.pdf", bbox_inches="tight")
    plt.close(fig)

def case(frame, kind="dynamic_seasonal", repetition=1):
    return frame[(frame.dgp == kind) & (frame.repetition == repetition)]

# Show every observation once, with the exact index contract.
fig, axes = plt.subplots(2, 1, figsize=(12.5, 7.5), gridspec_kw={"height_ratios": [1, 1.35]})
obs = case(observed)
auto = case(scores)[lambda x: x.method == "AutoDESN"]
oracle = case(scores)[lambda x: x.method == "Oracle_DGP"]
for i, ax in enumerate(axes):
    sub = obs if i == 0 else obs[obs.time >= 850]
    ax.plot(sub.time, sub.y, color="#70808D", lw=.65, alpha=.8, label="Observed")
    ax.plot(sub.time, sub.latent_location, color="#293B48", lw=1.2, alpha=.8, label="Latent signal (simulation)")
    time = 1000 + auto.horizon.to_numpy()
    ax.fill_between(time, auto.lower90.to_numpy(), auto.upper90.to_numpy(), color=colors["AutoDESN"], alpha=.13, label="AutoDESN 90% predictive")
    ax.fill_between(time, auto.lower50.to_numpy(), auto.upper50.to_numpy(), color=colors["AutoDESN"], alpha=.23, label="AutoDESN 50% predictive")
    ax.plot(time, auto["mean"], color=colors["AutoDESN"], lw=2, label="AutoDESN mean")
    ax.plot(time, oracle.mean_location, color="#40916C", ls="--", lw=1.5, label="Known-DGP forecast mean")
    ax.axvline(1000.5, color="#536576", ls=":", lw=1)
    ax.grid(axis="y", color="#E7ECF0", lw=.65)
    ax.set_ylabel("Response")
axes[0].axvspan(.5, 500.5, color="#DDE2E7", alpha=.6, zorder=-10)
axes[0].axvspan(500.5, 1000.5, color="#D9EAF3", alpha=.35, zorder=-10)
axes[0].axvline(500.5, color="#8C99A5", lw=.8)
axes[0].set_xlim(1, 1100)
for x, text in [(250, "500 washout"), (750, "500 training"), (1050, "100 forecast")]:
    axes[0].text(x, 1.025, text, transform=axes[0].get_xaxis_transform(), ha="center", fontsize=10)
axes[1].set_xlim(850, 1100)
axes[1].set_title("Forecast detail · parameters stay fixed within each simulated path", loc="left", fontsize=11)
axes[1].set_xlabel("Observation index · one forecast issued after observation 1,000")
fig.suptitle("Gaussian AutoDESN · 500 washout + 500 training + 100 forecast", x=.07, ha="left", fontsize=16, weight="bold")
fig.text(.07, .933, "Repository DGP: period 90, two harmonics, local linear trend and Gaussian observation SD 10. Prespecified replication 1.", fontsize=9.7, color="#607181")
fig.legend(*axes[1].get_legend_handles_labels(), loc="lower center", ncol=3, frameon=False, fontsize=9, bbox_to_anchor=(.52, -.005))
fig.subplots_adjust(top=.855, bottom=.14, hspace=.42)
save(fig, "forecast_500_500_100")

# Identical forecast issue time and horizon for the two simpler controls.
fig, axes = plt.subplots(3, 1, figsize=(12.2, 9.3), sharex=True)
for ax, kind in zip(axes, names):
    obs = case(observed, kind)
    obs = obs[obs.time >= 930]
    sub = case(scores, kind)
    auto = sub[sub.method == "AutoDESN"]
    time = 1000 + auto.horizon.to_numpy()
    ax.plot(obs.time, obs.y, color="#768592", lw=.8, label="Observed")
    ax.fill_between(time, auto.lower90.to_numpy(), auto.upper90.to_numpy(), color=colors["AutoDESN"], alpha=.15, label="AutoDESN 90% predictive")
    for method in ("AutoDESN", "Fixed_DESN", "Oracle_DGP"):
        z = sub[sub.method == method]
        ax.plot(1000 + z.horizon, z.mean_location, color=colors[method], lw=1.8 if method == "AutoDESN" else 1.15,
                ls="-" if method == "AutoDESN" else "--", label=labels[method])
    ax.axvline(1000.5, color="#657583", lw=1, ls=":")
    ax.set_title(names[kind], loc="left", fontsize=11)
    ax.set_ylabel("Response")
    ax.grid(axis="y", color="#E7ECF0", lw=.65)
axes[-1].set_xlabel("Observation index · forecast leads 1–100 use simulated feedback only")
fig.suptitle("100-step recursive forecasts across three processes", x=.075, ha="left", fontsize=16, weight="bold")
fig.text(.075, .94, "Replication 1 shown for every process; uncertainty includes specification, readout and observation noise.", color="#607181")
fig.legend(*axes[0].get_legend_handles_labels(), loc="lower center", ncol=3, frameon=False, bbox_to_anchor=(.5, .005))
fig.subplots_adjust(top=.89, bottom=.115, hspace=.36)
save(fig, "forecast_examples_h100")

# Lead-band metrics: independent DGP replications, not individual horizons,
# are the unit to use for any future uncertainty assessment.
bands = pd.read_csv(OUT / "lead_bands.csv")
fig, axes = plt.subplots(3, 2, figsize=(11.8, 9.6))
for row, kind in enumerate(names):
    for col, metric in enumerate(("rmse", "crps")):
        ax = axes[row, col]
        for method in ("AutoDESN", "Fixed_DESN", "Gaussian_AR1", "Gaussian_AR90", "Oracle_DGP"):
            z = bands[(bands.dgp == kind) & (bands.method == method)].set_index("band").loc[["1-10", "11-30", "31-60", "61-100"]]
            ax.plot(range(4), z[metric], marker="o", ms=4, color=colors[method],
                    lw=1.8 if method == "AutoDESN" else 1.15, ls="--" if method == "Oracle_DGP" else "-", label=labels[method])
        ax.set_xticks(range(4), ["1–10", "11–30", "31–60", "61–100"])
        ax.grid(axis="y", color="#E7ECF0", lw=.65)
        ax.set_ylim(bottom=0)
        ax.set_title((names[kind] if col == 0 else "") + (" · RMSE" if col == 0 else "CRPS"), loc="left", fontsize=10.5)
        if row == 2:
            ax.set_xlabel("Forecast lead band")
fig.suptitle("Forecast error over the full 100-step horizon", x=.07, ha="left", fontsize=16, weight="bold")
fig.text(.07, .943, f"{scores.repetition.nunique()} independent series per process · identical 500-row training windows · known-DGP comparator has true parameters.", fontsize=9.8, color="#607181")
fig.legend(*axes[0, 0].get_legend_handles_labels(), loc="lower center", ncol=5, frameon=False, fontsize=9, bbox_to_anchor=(.5, .015))
fig.subplots_adjust(top=.89, bottom=.105, hspace=.43, wspace=.26)
save(fig, "horizon_scores")

# Posterior mass within the prespecified dictionary.
fig, axes = plt.subplots(1, 3, figsize=(12.2, 4.8))
for ax, field, title in zip(axes, ("D", "m", "width"), ("Depth", "Input lag count", "Units per layer")):
    by_rep = prob.groupby(["dgp", "repetition", field]).posterior_probability.sum()
    avg = by_rep.groupby(["dgp", field]).mean()
    values = sorted(prob[field].unique())
    w = .72 / len(values)
    for j, value in enumerate(values):
        mass = np.array([avg.loc[(kind, value)] for kind in names])
        x = np.arange(3) + (j - (len(values) - 1) / 2) * w
        bars = ax.bar(x, mass, w * .92, color=plt.cm.Blues(.4 + .5 * j / max(1, len(values)-1)), label=str(value))
        ax.bar_label(bars, labels=[f"{p:.0%}" if .005 <= p <= .995 else ("<1%" if p < .005 else ">99%") for p in mass], padding=3, fontsize=8)
    ax.set_ylim(0, 1.12)
    ax.set_xticks(range(3), ["Trend + season", "Linear", "Nonlinear"], fontsize=9)
    ax.set_title(title, loc="left", fontsize=11)
    ax.yaxis.set_major_formatter(matplotlib.ticker.PercentFormatter(1))
    ax.grid(axis="y", color="#E7ECF0", lw=.65)
    ax.set_axisbelow(True)
    ax.legend(title=field, ncol=len(values), frameon=False, loc="upper center", bbox_to_anchor=(.5, -.12), fontsize=9)
axes[0].set_ylabel("Mean posterior mass across independent series")
fig.suptitle("What AutoDESN selects with 500 training observations", x=.065, ha="left", fontsize=16, weight="bold")
fig.text(.065, .89, "72 fixed candidates · identity bridges · posterior mass describes this bank, not a unique true neural architecture.", color="#607181", fontsize=9.5)
fig.subplots_adjust(left=.075, right=.99, top=.78, bottom=.23, wspace=.25)
save(fig, "specification_probabilities_h100")

# This comparison is descriptive: an inner-path average is the intended mean,
# while zero-innovation plug-in recursion is a different nonlinear operation.
plugin = pd.read_csv(OUT / "dynamic_seasonal_r01_plugin_by_draw.csv").iloc[:, 1:].mean(axis=1)
sensitivity = pd.read_csv(OUT / "sensitivity.csv")
fig, axes = plt.subplots(1, 2, figsize=(12, 4.7))
for K, z in sensitivity.groupby("K"):
    axes[0].plot(z.horizon, z.mean_location, lw=1.6, label=f"K = {K}")
axes[0].plot(np.arange(1, 101), plugin, color="#98587B", ls="--", lw=1.6, label="Zero-innovation plug-in")
axes[0].set_title("Mean conditional location", loc="left", fontsize=11)
for K in (64, 128):
    z = sensitivity[sensitivity.K == K]
    axes[1].plot(z.horizon, z.lower90, color=colors["AutoDESN"] if K == 64 else "#C16B37", ls="-" if K == 64 else "--", label=f"K = {K}: 5% / 95%")
    axes[1].plot(z.horizon, z.upper90, color=colors["AutoDESN"] if K == 64 else "#C16B37", ls="-" if K == 64 else "--")
axes[1].set_title("Pooled predictive quantiles", loc="left", fontsize=11)
for ax in axes:
    ax.set_xlabel("Forecast lead")
    ax.set_ylabel("Response")
    ax.grid(axis="y", color="#E7ECF0", lw=.65)
    ax.legend(frameon=False, fontsize=9)
fig.suptitle("Recursive forecast and inner-path sensitivity audit", x=.07, ha="left", fontsize=16, weight="bold")
fig.text(.07, .89, "Same posterior draws and paired innovation subsets; prespecified trend-and-season example, replication 1.", color="#607181", fontsize=9.5)
fig.subplots_adjust(top=.78, bottom=.15, wspace=.27)
save(fig, "recursion_audit")
