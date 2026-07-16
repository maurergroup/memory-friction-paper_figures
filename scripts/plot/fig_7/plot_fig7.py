from __future__ import annotations

import os
import sys
from pathlib import Path

_CONDA_PY = Path("/Users/u1865573/miniconda3/envs/CUDA-torch-base/bin/python")
if (
    os.environ.get("MF_SELF_CONTAINED_BOOTSTRAPPED") != "1"
    and _CONDA_PY.exists()
    and Path(sys.executable) != _CONDA_PY
):
    os.environ["MF_SELF_CONTAINED_BOOTSTRAPPED"] = "1"
    os.execv(str(_CONDA_PY), [str(_CONDA_PY), str(Path(__file__).resolve()), *sys.argv[1:]])

os.environ.setdefault("MPLCONFIGDIR", str(Path(__file__).resolve().parent / ".mplconfig_shared"))
os.environ.setdefault("XDG_CACHE_HOME", str(Path(__file__).resolve().parent / ".cache_shared"))

import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import AutoMinorLocator


PLOT_STYLE_CAIRO = {
    "font.family": "DejaVu Sans",
    "mathtext.fontset": "dejavusans",
    "axes.linewidth": 1.4,
    "xtick.direction": "in",
    "ytick.direction": "in",
    "xtick.top": True,
    "ytick.right": True,
    "xtick.major.size": 5,
    "ytick.major.size": 5,
    "xtick.major.width": 1.2,
    "ytick.major.width": 1.2,
    "axes.labelsize": 10,
    "axes.titlesize": 9,
    "xtick.labelsize": 8,
    "ytick.labelsize": 8,
    "legend.fontsize": 8,
}


def _apply_boxplot(ax, data_sets, colors, positions, widths=0.58):
    bp = ax.boxplot(
        data_sets,
        positions=positions,
        widths=widths,
        patch_artist=True,
        showfliers=False,
        whis=(0, 100),
        medianprops={"color": "#111111", "linewidth": 1.1},
        whiskerprops={"linewidth": 1.0},
        capprops={"linewidth": 1.0},
        boxprops={"linewidth": 1.0},
    )
    for patch, color in zip(bp["boxes"], colors):
        patch.set_facecolor(color + "33")
        patch.set_edgecolor(color)
    for whisker, color in zip(bp["whiskers"], np.repeat(colors, 2)):
        whisker.set_color(color)
    for cap, color in zip(bp["caps"], np.repeat(colors, 2)):
        cap.set_color(color)
    return bp


def _style_axes_box(ax):
    for spine in ax.spines.values():
        spine.set_linewidth(1.1)
    ax.tick_params(pad=7)
    ax.xaxis.set_minor_locator(AutoMinorLocator(2))
    ax.yaxis.set_minor_locator(AutoMinorLocator(2))
    ax.tick_params(which="minor", direction="in", top=True, right=True, length=3, width=1.0)


def _beeswarm_x(x0, y, jitter=0.085):
    y = np.asarray(y, dtype=float)
    if y.size <= 1:
        return np.full_like(y, x0, dtype=float)
    order = np.argsort(y)
    x = np.empty_like(y, dtype=float)
    offsets = np.zeros_like(y, dtype=float)
    step = jitter / 2.5
    for k, idx in enumerate(order):
        if k == 0:
            offsets[idx] = 0.0
        else:
            sign = -1 if k % 2 else 1
            offsets[idx] = sign * ((k + 1) // 2) * step
    x[:] = x0 + offsets
    return x


def main():
    here = Path(__file__).resolve().parent
    data = np.load(here / "fig2_original_data.npz")

    scheme_order = ["low", "high", "nonmarkov"]
    labels = [
        r"Markov. ($\boldsymbol{\eta}^{\mathrm{ODF}}$)",
        r"Markov. ($\boldsymbol{\eta}^{\mathrm{Avg}}$)",
        r"Non-Markov.",
    ]
    colors = ["#d62728", "#1f77b4", "#444444"]
    x = np.arange(len(scheme_order))
    totals = [data[f"totals_{name}"] for name in scheme_order]
    modes = [data[f"modes_{name}"] for name in scheme_order]

    with plt.rc_context(PLOT_STYLE_CAIRO):
        fig = plt.figure(figsize=(3.25, 3.35))
        gs = fig.add_gridspec(3, 2, width_ratios=[1.30, 1.0], height_ratios=[1, 1, 1], wspace=0.54, hspace=0.12)

        ax_total = fig.add_subplot(gs[:, 0])
        _apply_boxplot(ax_total, totals, colors, x)
        for idx, arr in enumerate(totals):
            ax_total.scatter(_beeswarm_x(x[idx], arr, jitter=0.09), arr, s=20, color=colors[idx], alpha=0.70, edgecolor="none", zorder=3)
        _style_axes_box(ax_total)
        ax_total.set_xticks(x, labels, rotation=22, ha="right")
        ax_total.set_ylabel(r"$\Delta E$ (eV)")

        mode_axes = [fig.add_subplot(gs[row, 1], sharex=ax_total) for row in range(3)]
        mode_titles = [r"$\mathrm{r}$", r"$\mathrm{\theta}$", r"$\mathrm{z}$"]
        all_mode_values = np.concatenate([arr.reshape(-1) for arr in modes])
        ymin = min(np.percentile(all_mode_values, 1.5), 0.0)
        ymax = max(np.percentile(all_mode_values, 98.5), 1e-3)

        for row, (ax, mode_col, title) in enumerate(zip(mode_axes, range(3), mode_titles)):
            mode_sets = [arr[:, mode_col] for arr in modes]
            _apply_boxplot(ax, mode_sets, colors, x)
            for idx, arr in enumerate(mode_sets):
                ax.scatter(_beeswarm_x(x[idx], arr, jitter=0.09), arr, s=18, color=colors[idx], alpha=0.72, edgecolor="none", zorder=3)
            _style_axes_box(ax)
            if row == 0:
                ax.set_ylim(ymin, 0.5)
            elif row == 2:
                ax.set_ylim(ymin, 0.1)
            else:
                ax.set_ylim(ymin, ymax)
            ax.text(0.03, 0.82, title, transform=ax.transAxes, fontsize=PLOT_STYLE_CAIRO["axes.titlesize"], fontfamily=PLOT_STYLE_CAIRO["font.family"])
            ax.set_xlim(-0.5, len(x) - 0.5)
            if row == 1:
                ax.set_ylabel(r"$\Delta E_{\mu}$ (eV)")
            if row == 2:
                ax.set_xticks(x, labels, rotation=22, ha="right")
            else:
                ax.tick_params(labelbottom=False)

        fig.text(0.02, 0.975, "(a)", fontsize=PLOT_STYLE_CAIRO["axes.titlesize"], fontfamily=PLOT_STYLE_CAIRO["font.family"], fontweight="bold", va="bottom", ha="left")
        fig.text(0.56, 0.975, "(b)", fontsize=PLOT_STYLE_CAIRO["axes.titlesize"], fontfamily=PLOT_STYLE_CAIRO["font.family"], fontweight="bold", va="bottom", ha="left")
        fig.subplots_adjust(left=0.16, right=0.985, bottom=0.21, top=0.96)

    out_pdf = here / "fig7.pdf"
    out_png = here / "fig7.png"
    fig.savefig(out_pdf, bbox_inches="tight")
    fig.savefig(out_png, bbox_inches="tight", dpi=300)
    plt.close(fig)
    print(out_pdf)


if __name__ == "__main__":
    main()
