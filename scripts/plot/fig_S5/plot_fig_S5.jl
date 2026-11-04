using DrWatson
@quickactivate "memory-friction-paper_figures"

using HDF5
using CairoMakie

# -----------------------------------------------------------------------------
# Reproduce Figure S5 from the data saved by
# scripts/plot/cpa/NOAu/plot_vib_state_distribution_SI_kde.jl
#
# NO/Au final vibrational-state densities ρ(ν): Gaussian KDEs (width σ) of the
# continuous EBK quantum numbers, memory CPA (local kernel) vs Markovian CPA.
# Rows: initial state ν_i; columns: incidence energy Eₜ. The shaded strip
# ν < −½ holds the below-well states.
# -----------------------------------------------------------------------------

# --- styling constants (kept identical to the original plotting script) ---
const ONE_COLUMN_WIDTH = 481
const FONT = projectdir("assets", "fonts", "dejavu-sans.book.ttf")

const figsize              = (ONE_COLUMN_WIDTH, ONE_COLUMN_WIDTH * 0.75)
const panel_spinewidth     = 1.8
const panel_ylims          = (0.0, nothing)   # `ylims` in the original; the top is an autolimit
const title_fontsize       = 14   # panel Eₜ headers
const label_fontsize       = 14   # axis labels
const tick_fontsize        = 12   # x / y tick labels
const legend_fontsize      = 12
const panel_label_fontsize = 13   # (a)–(f) tags

const color_endpt = "#B53A8C"     # memory CPA, local (endpoint) kernel
const color_mark  = "#3F9DCC"     # Markovian CPA
const variant_color = Dict("memory_local" => color_endpt, "markovian" => color_mark)

# --- row_xspec (identical to the original); the replay takes only the ticks from
# it, the limits come from the stored `xlims` (which equal these) ---
function row_xspec(ν_init)
    if ν_init ≤ 5
        return (xticks = -2:2:4,        xlims = (-2.5, 5.5))
    elseif ν_init ≤ 10
        return (xticks = 0:2:10,        xlims = (-0.5, 10.5))
    else
        return (xticks = 0:5:15,        xlims = (-1, 17))
    end
end

# --- load the reproduction data ---
h5_path = projectdir("figure_data", "fig_S5", "fig_S5_data.h5")

h5 = h5open(h5_path, "r")
nu_initial_list = read(h5["nu_initial_list"])
E_trans_eV_list = read(h5["E_trans_eV_list"])
variants        = read(h5["variants"])            # draw order

n_rows = length(nu_initial_list)
n_cols = length(E_trans_eV_list)

# --- build figure ---
fig = Figure(; size = figsize,
               figure_padding = (8, 12, 6, 6),
               fonts = (; regular = FONT))

for (c, Eₜ) in enumerate(E_trans_eV_list)
    Label(fig[1, c], "Eₜ = $(Eₜ) eV";
          fontsize   = title_fontsize,
          halign     = :center,
          tellwidth  = false,
          tellheight = true,
          padding    = (0, 0, 2, 0))
end

axes = Matrix{Any}(undef, n_rows, n_cols)
for r_idx in 1:n_rows, c_idx in 1:n_cols          # row by row, as the original
    panel   = h5["panel_$(r_idx)_$(c_idx)"]
    nu_init = read(panel["nu_init"])
    x_lims  = read(panel["xlims"])
    nu_grid = read(panel["nu_grid"])
    spec    = row_xspec(nu_init)

    ax = Axis(fig[r_idx + 1, c_idx];
              xticks = spec.xticks,
              xticklabelsize = tick_fontsize,
              yticklabelsize = tick_fontsize,
              xtickalign = 1.0,
              ytickalign = 1.0,
              xticksmirrored = true,
              yticksmirrored = true,
              limits = (x_lims[1], x_lims[2], panel_ylims[1], panel_ylims[2]),
              yautolimitmargin = (0.05, 0.15),   # headroom for the panel letter
              spinewidth = panel_spinewidth,
              xtickwidth = panel_spinewidth,
              ytickwidth = panel_spinewidth,
              xgridvisible = false, ygridvisible = false,
              xminorticksvisible = false, yminorticksvisible = false)

    # Below-well states (ν < −½) and the initial vibrational state
    vspan!(ax, x_lims[1], -0.5; color = (:grey, 0.15))
    vlines!(ax, [nu_init]; color = :black, linestyle = :dash,
            linewidth = 1.8)

    # KDE curves: memory CPA (local kernel), then Markovian CPA
    for v in variants
        haskey(panel, v) || continue
        lines!(ax, nu_grid, read(panel[v]["rho"]);
               color = variant_color[v], linewidth = 2.0)
    end

    # Panel letter (top-left, faux-bold via stroke)
    text!(ax, 0.04, 0.95;
          text        = read(panel["panel_letter"]),
          space       = :relative,
          align       = (:left, :top),
          fontsize    = panel_label_fontsize,
          color       = :black,
          strokewidth = 0.5,
          strokecolor = :black)

    axes[r_idx, c_idx] = ax
end
close(h5)

# Link y-axes across each row and hide y-decorations on non-first columns
for r_idx in 1:n_rows
    linkyaxes!(axes[r_idx, :]...)
end
for r_idx in 1:n_rows, c_idx in 2:n_cols
    hideydecorations!(axes[r_idx, c_idx]; grid = false, ticks = false)
end

# Axis labels
Label(fig[:, 0], "Probability density";
      fontsize = label_fontsize,
      rotation = π / 2,
      tellheight = false,
      padding = (0, 4, 0, 0))
Label(fig[n_rows + 2, 1:n_cols], "Final vibrational state ν";
      fontsize = label_fontsize,
      tellwidth = false,
      padding = (0, 0, 0, 0))

# Legend
legend_elems  = [
    LineElement(; color = color_endpt, linewidth = 2.0),
    LineElement(; color = color_mark,  linewidth = 2.0),
    LineElement(; color = :black, linestyle = :dash, linewidth = 1.8),
]
legend_labels = ["Memory", "Markovian", "Initial vibrational state"]

Legend(fig[n_rows + 3, 1:n_cols], legend_elems, legend_labels;
       orientation = :horizontal,
       nbanks = 1,
       tellwidth = false,
       tellheight = true,
       framevisible = false,
       labelsize = legend_fontsize,
       patchsize = (24, 12),
       margin = (0, 0, 0, 0))

# Row and column gaps (identical to the original)
rowgap!(fig.layout, 1, 2)
for r_idx in 2:n_rows
    rowgap!(fig.layout, r_idx, 4)
end
rowgap!(fig.layout, n_rows + 1, 0)
rowgap!(fig.layout, n_rows + 2, 4)
colgap!(fig.layout, 0)

display(fig)

outdir = plotsdir("fig_S5")
mkpath(outdir)
save(joinpath(outdir, "fig_S5.pdf"), fig)
