using DrWatson
@quickactivate "memory-friction-paper_figures"

using HDF5
using CairoMakie
using Colors

# -----------------------------------------------------------------------------
# Reproduce Figure S6 from the data saved by
# scripts/plot/cpa/NOAu/plot_negative_bound_ratio_noau.jl
#
# Negative-tail bound relative to the memory-CPA energy loss,
# ⟨|ΔE_neg|⟩ / ⟨ΔE_mem⟩ in %, against Eₜ; one panel per initial vibrational
# state νᵢ. No header or legend for a single memory-CPA variant (T and the
# kernel average go in the caption).
#
# Font: DejaVu Sans instead of the original's MinionPro-Capt. DejaVu Sans has
# ⟨ ⟩, so the y label uses them directly; the original borrows them from the
# math font (BRACKET_FONT) because MinionPro lacks them.
# -----------------------------------------------------------------------------

# --- styling constants (kept identical to the original plotting script) ---
const FONT = projectdir("assets", "fonts", "dejavu-sans.book.ttf")

const FIG_WIDTH  = 481                          # HokseonPlots.TWO_COLUMN_WIDTH
const FIG_HEIGHT = round(Int, FIG_WIDTH * 0.4)

const panel_spinewidth = 1.8
const LINE_WIDTH       = 1.6
const MARKER_SIZE      = 9
const PANEL_COLGAP     = 10

const TITLE_SIZE        = 14   # νᵢ panel headers
const AXIS_LABEL_SIZE   = 14
const TICK_LABEL_SIZE   = 12
const LEGEND_LABEL_SIZE = 12
const PANEL_LABEL_SIZE  = 13   # (a)–(c) tags

# Colour and marker per stored variant (kernel average :endpoint / :arithmetic).
const STYLE = Dict("memory_local"      => (color = colorant"#B53A8C", marker = :diamond),
                   "memory_arithmetic" => (color = colorant"#E89A3C", marker = :utriangle))

# --- load the reproduction data ---
h5_path = projectdir("figure_data", "fig_S6", "fig_S6_data.h5")

h5 = h5open(h5_path, "r")
vibs          = read(h5["vibs"])          # Int64, so the titles read "νᵢ = 0"
variants      = read(h5["variants"])      # draw order
legend_labels = read(h5["labels"])
Ek_xlims      = read(h5["xlims"])         # eV, data-derived
Ek_ticks      = read(h5["xticks"])
Ek_minorticks = read(h5["xminorticks"])

# One entry per panel, left to right; a variant without data has no group.
panels = map(eachindex(vibs)) do col
    p = h5["panel_1_$(col)"]
    series = [(style = STYLE[v], label = legend_labels[i],
               E_trans_eV = read(p[v]["E_trans_eV"]), ratio_pct = read(p[v]["ratio_pct"]))
              for (i, v) in enumerate(variants) if haskey(p, v)]
    (vib = read(p["vib"]), letter = read(p["panel_letter"]),
     ylims = read(p["ylims"]),            # [0, 1.3 × largest ratio]; NaN upper value: automatic
     series = series)
end
close(h5)

# --- build figure ---
fig = Figure(size = (FIG_WIDTH, FIG_HEIGHT), figure_padding = (2, 4, 2, 2),
             fonts = (; regular = FONT))
panel_grid = GridLayout(fig[1, 2])

axs = map(enumerate(panels)) do (col, pd)
    Axis(panel_grid[1, col];
         title              = rich("ν", subscript("i"), " = $(pd.vib)"),
         titlesize          = TITLE_SIZE,
         titlefont          = :regular,
         xticklabelsize     = TICK_LABEL_SIZE,
         yticklabelsize     = TICK_LABEL_SIZE,
         limits             = (Ek_xlims[1], Ek_xlims[2],
                               pd.ylims[1], isnan(pd.ylims[2]) ? nothing : pd.ylims[2]),
         xticks             = Ek_ticks,
         xtickformat        = v -> [string(round(x; digits = 1)) for x in v],
         xminorticks        = Ek_minorticks,
         xminorticksvisible = true,
         xminortickwidth    = panel_spinewidth,
         xgridvisible       = false, ygridvisible = false,
         xticksmirrored     = true,
         yticksmirrored     = true,
         xtickalign         = 1,
         ytickalign         = 1,
         xminortickalign    = 1,
         spinewidth         = panel_spinewidth,
         xtickwidth         = panel_spinewidth,
         ytickwidth         = panel_spinewidth)
end
linkxaxes!(axs...)
colgap!(panel_grid, PANEL_COLGAP)

for (col, pd) in enumerate(panels), s in pd.series
    scatterlines!(axs[col], s.E_trans_eV, s.ratio_pct; color = s.style.color, linewidth = LINE_WIDTH,
                  marker = s.style.marker, markersize = MARKER_SIZE,
                  strokecolor = :black, strokewidth = 1.2, label = s.label)
end

# Panel labels (a), (b), (c), faux-bold.
for (ax, pd) in zip(axs, panels)
    text!(ax, 0.04, 0.95; text = pd.letter, space = :relative,
          align = (:left, :top), fontsize = PANEL_LABEL_SIZE, color = :black,
          strokewidth = 0.5, strokecolor = :black)
end

# Shared axis labels.
Label(fig[1, 1], rich("⟨|ΔE", subsup("neg", "f"), "|⟩ / ⟨ΔE", subsup("mem", "f"), "⟩  (%)");
      rotation = π / 2, tellheight = false, tellwidth = true, fontsize = AXIS_LABEL_SIZE)
Label(fig[2, 2], rich("E", subscript("t"), "  (eV)");
      tellwidth = false, tellheight = true, fontsize = AXIS_LABEL_SIZE)

# A legend only for several memory-CPA variants.
length(variants) > 1 &&
    axislegend(axs[end]; position = (:right, :center), framevisible = false,
               labelsize = LEGEND_LABEL_SIZE, patchsize = (18, 10), rowgap = 0)

colgap!(fig.layout, 4)
rowgap!(fig.layout, 4)

display(fig)

outdir = plotsdir("fig_S6")
mkpath(outdir)
save(joinpath(outdir, "fig_S6.pdf"), fig)
