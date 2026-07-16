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
from ase.io import read
from mpl_toolkits.mplot3d import proj3d


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


def _style_axes(ax):
    for spine in ax.spines.values():
        spine.set_linewidth(1.1)
    ax.tick_params(pad=7)
    ax.xaxis.set_minor_locator(AutoMinorLocator(2))
    ax.yaxis.set_minor_locator(AutoMinorLocator(2))
    ax.tick_params(which="minor", direction="in", top=True, right=True, length=3, width=1.0)


def _draw_coordinate_overlay(ax, basis_origin_3d, scale_3d, origin_2d=None):
    triad_colors = {"x": "#D62728", "y": "#2CA02C", "z": "#1F77B4"}
    vectors = {
        "x": np.array([scale_3d, 0.0, 0.0]),
        "y": np.array([0.0, scale_3d, 0.0]),
        "z": np.array([0.0, 0.0, scale_3d]),
    }

    fig = ax.figure
    fig.canvas.draw()

    def to_axes_fraction(point3d):
        x2, y2, _ = proj3d.proj_transform(*point3d, ax.get_proj())
        disp = ax.transData.transform((x2, y2))
        return ax.transAxes.inverted().transform(disp)

    # Keep the triad in clear white space while preserving the true projected
    # directions of the 3D coordinate axes.
    if origin_2d is None:
        origin_2d = np.array([0.13, 0.83], dtype=float)
    else:
        origin_2d = np.asarray(origin_2d, dtype=float)
    for axis_name, vec in vectors.items():
        tip_proj = to_axes_fraction(basis_origin_3d + vec)
        origin_proj = to_axes_fraction(basis_origin_3d)
        direction_2d = tip_proj - origin_proj
        norm = np.linalg.norm(direction_2d)
        if norm < 1e-12:
            continue
        direction_2d = direction_2d / norm
        if axis_name == "x":
            length_2d = 0.17
        elif axis_name == "y":
            length_2d = 0.17
        else:
            length_2d = 0.15
        tip_2d = origin_2d + direction_2d * length_2d
        ax.annotate(
            "",
            xy=tip_2d,
            xytext=origin_2d,
            xycoords="axes fraction",
            textcoords="axes fraction",
            arrowprops=dict(
                arrowstyle="-|>",
                lw=2.4,
                color=triad_colors[axis_name],
                shrinkA=0,
                shrinkB=0,
                mutation_scale=12,
            ),
            zorder=10,
        )
        ax.text2D(
            origin_2d[0] + (tip_2d[0] - origin_2d[0]) * 1.14,
            origin_2d[1] + (tip_2d[1] - origin_2d[1]) * 1.14,
            axis_name,
            transform=ax.transAxes,
            color=triad_colors[axis_name],
            fontsize=11,
            fontfamily=PLOT_STYLE_CAIRO["font.family"],
            fontweight="bold",
            ha="center",
            va="center",
            zorder=11,
        )


def _project_to_axes_fraction(ax, point3d):
    x2, y2, _ = proj3d.proj_transform(*point3d, ax.get_proj())
    disp = ax.transData.transform((x2, y2))
    return ax.transAxes.inverted().transform(disp)


def _plot_structure(ax, atoms):
    positions = atoms.get_positions()
    symbols = np.asarray(atoms.get_chemical_symbols())
    zmin = float(np.min(positions[:, 2]))
    zmax = float(np.max(positions[:, 2]))
    xmin = float(np.min(positions[:, 0]))
    xmax = float(np.max(positions[:, 0]))
    ymin = float(np.min(positions[:, 1]))
    ymax = float(np.max(positions[:, 1]))

    colors = {"Au": "#C9A227", "N": "#2E6FDF", "O": "#D43C2F"}
    sizes = {"Au": 158, "N": 50, "O": 54}

    no_idx = np.where((symbols == "N") | (symbols == "O"))[0]
    no_pos = positions[no_idx] if len(no_idx) == 2 else None
    no_center = np.mean(no_pos, axis=0) if no_pos is not None else np.mean(positions, axis=0)
    au_pos = positions[symbols == "Au"]
    top_au = au_pos[au_pos[:, 2] > np.max(au_pos[:, 2]) - 0.35] if len(au_pos) else positions

    # Draw a faint local surface plane to anchor the slab visually.
    xs = np.linspace(no_center[0] - 2.8, no_center[0] + 2.8, 2)
    ys = np.linspace(no_center[1] - 2.2, no_center[1] + 2.2, 2)
    xx, yy = np.meshgrid(xs, ys)
    zz = np.full_like(xx, float(np.max(top_au[:, 2])) - 0.02)
    ax.plot_surface(xx, yy, zz, color="#E6DDC0", alpha=0.18, linewidth=0, shade=False)

    # Plot atoms from back to front so depth reads naturally.
    order = np.argsort(positions[:, 2])
    for idx in order:
        sym = symbols[idx]
        x, y, z = positions[idx]
        ax.scatter(
            [x],
            [y],
            [z],
            s=sizes.get(sym, 70),
            c=colors.get(sym, "#808080"),
            edgecolors="white",
            linewidths=0.5,
            depthshade=True,
            alpha=0.98,
        )

    # Choose the view azimuth perpendicular to the NO bond's in-plane direction
    # so the projected N-O separation is close to maximal.
    if len(no_idx) == 2:
        bond = no_pos[1] - no_pos[0]
        bond_xy_angle = np.degrees(np.arctan2(bond[1], bond[0]))
        view_azim = bond_xy_angle - 90.0
    else:
        view_azim = -42.0
    ax.view_init(elev=14, azim=view_azim, roll=0)
    ax.set_proj_type("persp")
    ax.set_xlim(no_center[0] + 1.62, no_center[0] + 8.18)
    ax.set_ylim(no_center[1] - 4.095, no_center[1] + 0.745)
    ax.set_zlim(no_center[2] - 5.60, no_center[2] + 0.40)
    ax.set_box_aspect((6.56, 4.84, 6.00))
    ax.set_xticks([])
    ax.set_yticks([])
    ax.set_zticks([])
    ax.grid(False)
    for pane in [ax.xaxis.pane, ax.yaxis.pane, ax.zaxis.pane]:
        pane.set_alpha(0.0)
    ax.set_facecolor("white")
    ax.set_axis_off()

    # Use a local physical basis near the adsorbate to define the projected
    # x/y/z directions, but draw the triad in empty 2D space on top of the panel.
    origin_3d = np.array([xmin + 0.15, ymin + 0.25, zmin + 0.55])
    scale_3d = 0.72 * max(xmax - xmin, ymax - ymin, zmax - zmin)

    if len(no_idx) == 2:
        ax.figure.canvas.draw()
        n_2d = _project_to_axes_fraction(ax, no_pos[0])
        o_2d = _project_to_axes_fraction(ax, no_pos[1])
        triad_origin_2d = np.array([0.75, 0.83])
        _draw_coordinate_overlay(ax, origin_3d, scale_3d, origin_2d=triad_origin_2d)
        ax.annotate(
            "",
            xy=o_2d,
            xytext=n_2d,
            xycoords="axes fraction",
            textcoords="axes fraction",
            arrowprops=dict(
                arrowstyle="-",
                lw=2.0,
                color="#444444",
                shrinkA=0,
                shrinkB=0,
            ),
            zorder=11,
        )
        bond_vec_2d = o_2d - n_2d
        bond_norm = np.linalg.norm(bond_vec_2d)
        if bond_norm < 1e-12:
            return
        bond_tangent = bond_vec_2d / bond_norm
        bond_normal = np.array([-bond_tangent[1], bond_tangent[0]])
        label_2d = 0.5 * (n_2d + o_2d) + 0.055 * bond_normal
        ax.text2D(
            label_2d[0],
            label_2d[1],
            r"$r$",
            transform=ax.transAxes,
            fontsize=12,
            fontfamily=PLOT_STYLE_CAIRO["font.family"],
            ha="center",
            va="center",
            zorder=12,
        )
    else:
        _draw_coordinate_overlay(ax, origin_3d, scale_3d)


def main():
    here = Path(__file__).resolve().parent
    data = np.load(here / "fig1b_data.npz")
    atoms = read(here / "no_au111_example.xyz")

    omega_eV = data["omega_eV"]
    raw_components = data["raw_components"]
    broadened_components = data["broadened_components"]
    eta_odf = data["eta_odf"]
    eta_avg = data["eta_avg"]

    titles = [r"(r,r)", r"(z,z)", r"(r,z)"]
    colors = {
        "raw": "#444444",
        "broadened": "#2ca02c",
        "odf": "#d62728",
        "avg": "#1f77b4",
    }

    with plt.rc_context(PLOT_STYLE_CAIRO):
        fig = plt.figure(figsize=(3.25, 4.3))
        gs = fig.add_gridspec(
            3,
            2,
            width_ratios=[1.0, 1.0],
            height_ratios=[0.26, 1.08, 1.08],
            wspace=0.38,
            hspace=0.07,
        )

        ax_legend = fig.add_subplot(gs[0, :])
        ax_legend.axis("off")

        ax_coord = fig.add_subplot(gs[1, 0], projection="3d")
        _plot_structure(ax_coord, atoms)

        friction_axes = [
            fig.add_subplot(gs[1, 1]),
            fig.add_subplot(gs[2, 0]),
            fig.add_subplot(gs[2, 1]),
        ]
        legend_handles = None
        legend_labels = None

        for panel_idx, ax in enumerate(friction_axes):
            raw = raw_components[panel_idx]
            broadened = broadened_components[panel_idx]
            ax.plot(
                omega_eV,
                raw,
                color=colors["raw"],
                lw=1.9,
                label=r"$\sigma=0.01\ \mathrm{eV}$",
            )
            ax.plot(
                omega_eV,
                broadened,
                color=colors["broadened"],
                lw=1.9,
                label=r"$\sigma=0.05\ \mathrm{eV}$",
            )
            ax.axhline(
                eta_avg[panel_idx],
                color=colors["avg"],
                lw=1.6,
                ls="--",
                label=r"$\eta_{\mu\nu}^{\mathrm{Avg}}$",
            )
            ax.axhline(
                eta_odf[panel_idx],
                color=colors["odf"],
                lw=1.6,
                ls=":",
                label=r"$\eta_{\mu\nu}^{\mathrm{ODF}}$",
            )
            ax.axvspan(1.0, 3.0, color=colors["avg"], alpha=0.08, linewidth=0)

            ax.set_xlim(0.0, 3.0)
            y_vals = np.concatenate(
                [
                    raw[omega_eV <= 3.0],
                    broadened[omega_eV <= 3.0],
                    eta_avg[panel_idx : panel_idx + 1],
                    eta_odf[panel_idx : panel_idx + 1],
                ]
            )
            pad = 0.12 * max(np.max(np.abs(y_vals)), 1e-6)
            if panel_idx == 1:
                ax.set_ylim(float(np.min(y_vals)) - pad, 9.0)
            elif panel_idx == 2:
                ax.set_ylim(-9,5)
            else:
                ax.set_ylim(float(np.min(y_vals)) - pad, float(np.max(y_vals)) + pad)
            _style_axes(ax)

            ax.text(
                0.93,
                0.96,
                titles[panel_idx],
                transform=ax.transAxes,
                ha="right",
                va="top",
                fontsize=PLOT_STYLE_CAIRO["axes.titlesize"],
                fontfamily=PLOT_STYLE_CAIRO["font.family"],
                #fontweight="bold",
            )

            if legend_handles is None:
                legend_handles, legend_labels = ax.get_legend_handles_labels()

            if panel_idx in (1, 2):
                ax.set_xlabel(r"$\hbar\omega$ (eV)")
            else:
                ax.tick_params(labelbottom=False)

        order = [0, 1, 2, 3]
        legend_handles = [legend_handles[i] for i in order]
        legend_labels = [legend_labels[i] for i in order]
        ax_legend.legend(
            legend_handles,
            legend_labels,
            ncol=2,
            frameon=False,
            loc="center",
            columnspacing=1.0,
            handlelength=2.2,
            handletextpad=0.6,
        )

        friction_axes[0].set_ylabel(r"$K_{\mu\nu}(\omega)$ (u $\cdot$ ps$^{-1}$)")
        friction_axes[1].set_ylabel(r"$K_{\mu\nu}(\omega)$ (u $\cdot$ ps$^{-1}$)")
        bbox_a = ax_coord.get_position()
        bbox_b = friction_axes[0].get_position()
        bbox_c = friction_axes[1].get_position()
        bbox_d = friction_axes[2].get_position()
        left_x = min(bbox_a.x0, bbox_c.x0) - 0.0
        right_x = min(bbox_b.x0, bbox_d.x0) + 0.06
        top_y = max(bbox_a.y1, bbox_b.y1) + 0.07
        bottom_y = max(bbox_c.y1, bbox_d.y1) - 0.006
        for label, x, y in [
            ("(a)", left_x, top_y),
            ("(b)", right_x, top_y),
            ("(c)", left_x, bottom_y),
            ("(d)", right_x, bottom_y),
        ]:
            fig.text(
                x,
                y,
                label,
                fontsize=PLOT_STYLE_CAIRO["axes.titlesize"],
                fontfamily=PLOT_STYLE_CAIRO["font.family"],
                fontweight="bold",
                ha="left",
                va="top",
            )
        fig.subplots_adjust(left=0.11, right=0.99, bottom=0.05, top=0.98)

    out_pdf = here / "fig6.pdf"
    out_png = out_pdf.with_suffix(".png")
    fig.savefig(out_pdf, bbox_inches="tight")
    fig.savefig(out_png, bbox_inches="tight", dpi=300)
    plt.close(fig)
    print(out_pdf)


if __name__ == "__main__":
    main()
