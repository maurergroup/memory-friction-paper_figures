using DrWatson
@quickactivate "memory-friction-paper_figures"

using HDF5
using CairoMakie
using Colors

# -----------------------------------------------------------------------------
# Reproduce Figure S7 from the data saved by
# scripts/plot/friction/memory/ErpenbeckThoss/plot_Lambda_ErpenbeckThoss_time_fit.jl
# (styling from that script and the plot_Lambda_ErpenbeckThoss_time.jl it includes).
# Normalised Erpenbeck–Thoss memory kernels K(t; x)/K(0; x) (colour, one row per x)
# against their damped-cosine fits e^{−γt} cos Ωt (black dashed, one column per Δ₀).
# -----------------------------------------------------------------------------

# --- styling constants (kept identical to the original plotting script) ---
const ONE_COLUMN_WIDTH = 481
const panel_spinewidth = 1.8
const FONT = projectdir("assets", "fonts", "dejavu-sans.book.ttf")

const AXIS_LABEL_SIZE   = 14
const TICK_LABEL_SIZE   = 12
const ANNOTATION_SIZE   = 14   # Δ₀ column headers, x row labels
const LEGEND_LABEL_SIZE = 12

const colors = [
    colorant"#1f77b4",
    colorant"#2ca02c",
    colorant"#ff7f0e",
    colorant"#d62728",
]

const FIT_COLOR   = :black
const FIT_X_TICKS = [[0, 2, 4], [0, 4, 8], [0, 10, 20], [0, 50, 100]]   # per Δ₀ column

# --- load the reproduction data ---
h5_path = projectdir("figure_data", "fig_S7", "fig_S7_data.h5")

positions, Γ_values, t_windows, y_lims, panels = h5open(h5_path, "r") do h5
    positions = read(h5["positions_A"])        # rows i (x / Å)
    Γ_values  = read(h5["Gamma_values_eV"])    # columns k (Δ₀ = Γ/2)
    panels = [(; t   = read(h5["panel_$(i)_$(k)/t_fs"]),
                 y   = read(h5["panel_$(i)_$(k)/K_normalised"]),
                 fit = read(h5["panel_$(i)_$(k)/fit"]))
              for i in eachindex(positions), k in eachindex(Γ_values)]
    (positions, Γ_values, read(h5["t_windows_fs"]), read(h5["y_lims"]), panels)
end
# temperature_K, the ω-grid ends, K_u_ps2, the fit parameters and residuals are stored
# for the tests but not needed for plotting.

fig = Figure(size = (ONE_COLUMN_WIDTH, ONE_COLUMN_WIDTH * 0.9),
             figure_padding = (2, 6, 2, 2),
             fonts = (; regular = FONT))

# Panels in the original's order: column k (Δ₀) outer, row i (x) inner.
for k in eachindex(Γ_values), i in eachindex(positions)
    p  = panels[i, k]
    ax = Axis(fig[i + 1, k + 1];
        limits         = (0.0, t_windows[k], y_lims...),
        xticks         = FIT_X_TICKS[k],
        yticks         = [0.0, 1.0],
        xticklabelsize = TICK_LABEL_SIZE,
        yticklabelsize = TICK_LABEL_SIZE,
        xticklabelsvisible = i == length(positions),
        yticklabelsvisible = k == 1,
        xgridvisible   = false,
        ygridvisible   = false,
        xtickalign     = 1,
        ytickalign     = 1,
        spinewidth     = panel_spinewidth,
        xtickwidth     = panel_spinewidth,
        ytickwidth     = panel_spinewidth,
    )
    hlines!(ax, 0.0; color = :gray70, linewidth = 0.8)
    lines!(ax, p.t, p.y; color = colors[i], linewidth = 2)
    lines!(ax, p.t, p.fit; color = FIT_COLOR, linewidth = 1.2, linestyle = :dash)
end

# Column (Δ₀) and row (x) headers, shared axis labels.
for k in eachindex(Γ_values)
    Label(fig[1, k + 1], "Δ₀ = $(Γ_values[k] / 2) eV"; fontsize = ANNOTATION_SIZE,
          tellwidth = false, padding = (0, 0, 2, 0))
end
for (i, x) in enumerate(positions)
    Label(fig[i + 1, length(Γ_values) + 2], "x = $(x) Å"; rotation = -π / 2,
          fontsize = ANNOTATION_SIZE, color = colors[i], tellheight = false, padding = (4, 0, 0, 0))
end
Label(fig[2:length(positions) + 1, 1], "K(t ; x) / K(0 ; x)"; rotation = π / 2,
      fontsize = AXIS_LABEL_SIZE, tellheight = false, padding = (0, 4, 0, 0))
Label(fig[length(positions) + 2, 2:length(Γ_values) + 1], "t  (fs)";
      fontsize = AXIS_LABEL_SIZE, tellwidth = false)

Legend(fig[0, 1:length(Γ_values) + 2],
       [LineElement(color = :gray40, linewidth = 2),
        LineElement(color = FIT_COLOR, linewidth = 1.2, linestyle = :dash)],
       ["K(t ; x)", rich("fit e", Makie.superscript("−γt"), " cos Ωt")];   # "−" is U+2212
       orientation  = :horizontal,
       framevisible = false,
       tellwidth    = false,
       tellheight   = true,
       patchsize    = (22, 12),
       colgap       = 10,
       padding      = (2, 2, 1, 1),
       labelsize    = LEGEND_LABEL_SIZE)

rowgap!(fig.layout, 4)
colgap!(fig.layout, 6)

display(fig)

outdir = plotsdir("fig_S7")
mkpath(outdir)
save(joinpath(outdir, "fig_S7.pdf"), fig)
