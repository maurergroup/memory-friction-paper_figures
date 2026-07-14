from __future__ import annotations

import os
import sys
from pathlib import Path


import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


PLOT_STYLE_CAIRO = {
    "font.family": "STIXGeneral",
    "mathtext.fontset": "stix",
    "axes.linewidth": 1.1,
    "xtick.direction": "in",
    "ytick.direction": "in",
    "xtick.top": True,
    "ytick.right": True,
    "xtick.major.size": 6,
    "ytick.major.size": 6,
    "xtick.major.width": 1.0,
    "ytick.major.width": 1.0,
    "axes.labelsize": 14,
    "axes.titlesize": 13,
    "xtick.labelsize": 11,
    "ytick.labelsize": 11,
    "legend.fontsize": 10,
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
    data = np.load(here / "fig2_approximations_data.npz")

    scheme_order = ["local_raw", "local_broadened", "conf_avg_local", "separable", "separable_broadened"]
    labels = [
        r"Endpoint, $\sigma = 0.01$ eV",
        r"Endpoint, $\sigma = 0.05$ eV",
        r"Arith-mean, $\sigma = 0.01$ eV",
        r"Sep. coupling, $\sigma = 0.01$ eV",
        r"Sep. coupling, $\sigma = 0.05$ eV",
    ]
    colors = ["#4C78A8", "#F58518", "#54A24B", "#B279A2", "#E45756"]
    x = np.arange(len(scheme_order))
    totals = [data[f"totals_{name}"] for name in scheme_order]
    modes = [data[f"modes_{name}"] for name in scheme_order]

    with plt.rc_context(PLOT_STYLE_CAIRO):
        fig = plt.figure(figsize=(6.8, 4.5))
        gs = fig.add_gridspec(3, 2, width_ratios=[1.35, 1.05], height_ratios=[1, 1, 1], wspace=0.42, hspace=0.14)

        ax_total = fig.add_subplot(gs[:, 0])
        _apply_boxplot(ax_total, totals, colors, x)
        for idx, arr in enumerate(totals):
            ax_total.scatter(_beeswarm_x(x[idx], arr, jitter=0.09), arr, s=20, color=colors[idx], alpha=0.70, edgecolor="none", zorder=3)
        _style_axes_box(ax_total)
        ax_total.set_xticks(x, labels, rotation=22, ha="right")
        ax_total.set_ylabel(r"$\Delta E$ (eV)")

        mode_axes = [fig.add_subplot(gs[row, 1], sharex=ax_total) for row in range(3)]
        mode_titles = [r"$r$", r"$\theta$", r"$z$"]
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

        fig.text(0.02, 0.965, "(a)", fontsize=PLOT_STYLE_CAIRO["axes.titlesize"], fontfamily=PLOT_STYLE_CAIRO["font.family"], va="bottom", ha="left")
        fig.text(0.58, 0.965, "(b)", fontsize=PLOT_STYLE_CAIRO["axes.titlesize"], fontfamily=PLOT_STYLE_CAIRO["font.family"], va="bottom", ha="left")
        fig.subplots_adjust(left=0.13, right=0.985, bottom=0.24, top=0.96)

    out_pdf = here / "fig2_approximations_self_contained.pdf"
    out_png = here / "fig2_approximations_self_contained.png"
    fig.savefig(out_pdf, bbox_inches="tight")
    fig.savefig(out_png, bbox_inches="tight", dpi=300)
    plt.close(fig)
    print(out_pdf)


if __name__ == "__main__":
    main()
