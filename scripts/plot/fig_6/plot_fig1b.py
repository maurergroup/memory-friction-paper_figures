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


def _style_axes(ax):
    for spine in ax.spines.values():
        spine.set_linewidth(1.1)
    ax.tick_params(pad=7)


def main():
    here = Path(__file__).resolve().parent
    data = np.load(here / "fig1b_data.npz")

    omega_eV = data["omega_eV"]
    raw_components = data["raw_components"]
    broadened_components = data["broadened_components"]
    eta_odf = data["eta_odf"]
    eta_avg = data["eta_avg"]

    titles = [r"(r,r)", r"(z,z)", r"(r,z)"]
    panel_labels = ["(a)", "(b)", "(c)"]
    colors = {
        "raw": "black",
        "broadened": "#F58518",
        "odf": "#4C78A8",
        "avg": "#54A24B",
    }

    with plt.rc_context(PLOT_STYLE_CAIRO):
        fig, axes = plt.subplots(3, 1, figsize=(3.6, 4.75), sharex=True)
        legend_handles = None
        legend_labels = None

        for panel_idx, ax in enumerate(axes):
            raw = raw_components[panel_idx]
            broadened = broadened_components[panel_idx]
            ax.plot(omega_eV, raw, color=colors["raw"], lw=1.5, label=r"$\sigma=0.01\ \mathrm{eV}$")
            ax.plot(omega_eV, broadened, color=colors["broadened"], lw=1.5, label=r"$\sigma=0.05\ \mathrm{eV}$")
            ax.axhline(eta_avg[panel_idx], color=colors["avg"], lw=1.4, ls="--", label=r"$\boldsymbol{\eta}^{\mathrm{Avg}}$")
            ax.axhline(eta_odf[panel_idx], color=colors["odf"], lw=1.4, ls=":", label=r"$\boldsymbol{\eta}^{\mathrm{ODF}}$")
            ax.axvspan(1.0, 3.0, color=colors["avg"], alpha=0.08, linewidth=0)

            ax.set_xlim(0.0, 3.0)
            y_vals = np.concatenate([raw[omega_eV <= 3.0], broadened[omega_eV <= 3.0], eta_avg[panel_idx:panel_idx+1], eta_odf[panel_idx:panel_idx+1]])
            pad = 0.12 * max(np.max(np.abs(y_vals)), 1e-6)
            if panel_idx == 1:
                ax.set_ylim(float(np.min(y_vals)) - pad, 9.0)
            else:
                ax.set_ylim(float(np.min(y_vals)) - pad, float(np.max(y_vals)) + pad)
            _style_axes(ax)

            ax.text(0.04, 0.90, panel_labels[panel_idx], transform=ax.transAxes, ha="left", va="top", fontsize=PLOT_STYLE_CAIRO["axes.titlesize"], fontfamily=PLOT_STYLE_CAIRO["font.family"])
            ax.text(0.96, 0.90, titles[panel_idx], transform=ax.transAxes, ha="right", va="top", fontsize=PLOT_STYLE_CAIRO["axes.titlesize"], fontfamily=PLOT_STYLE_CAIRO["font.family"])

            if legend_handles is None:
                legend_handles, legend_labels = ax.get_legend_handles_labels()

        order = [0, 1, 2, 3]
        legend_handles = [legend_handles[i] for i in order]
        legend_labels = [legend_labels[i] for i in order]

        axes[1].set_ylabel(r"$K_{\mu\nu}(\omega)$ (u $\cdot$ ps$^{-1}$)")
        fig.supxlabel(r"$\hbar\omega$ (eV)", x=0.58, y=0.06, fontsize=PLOT_STYLE_CAIRO["axes.labelsize"], fontfamily=PLOT_STYLE_CAIRO["font.family"])
        fig.legend(legend_handles, legend_labels, ncol=2, frameon=False, loc="upper center", bbox_to_anchor=(0.5, 0.968), columnspacing=1.0, handlelength=2.2, handletextpad=0.6)
        fig.subplots_adjust(left=0.15, right=0.98, bottom=0.13, top=0.93, hspace=0.18)

    out_pdf = here / "fig1b_self_contained.pdf"
    out_png = here / "fig1b_self_contained.png"
    fig.savefig(out_pdf, bbox_inches="tight")
    fig.savefig(out_png, bbox_inches="tight", dpi=300)
    plt.close(fig)
    print(out_pdf)


if __name__ == "__main__":
    main()
