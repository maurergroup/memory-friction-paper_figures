using DrWatson
@quickactivate "memory-friction-paper_figures"

using HDF5
using CairoMakie

# -----------------------------------------------------------------------------
# Reproduce Figure S4 from the data saved by
# scripts/plot/cpa/NOAu/plot_vib_state_distribution_SI.jl
#
# NO/Au final vibrational-state distributions P(ν): rows = initial state νᵢ,
# columns = incidence energy Eₜ; memory CPA (arithmetic and local kernel
# averages) vs Markovian CPA, with binomial standard-error bars.
# -----------------------------------------------------------------------------

# --- styling constants (kept identical to the original plotting script) ---
const ONE_COLUMN_WIDTH = 481
const FONT = projectdir("assets", "fonts", "dejavu-sans.book.ttf")

const figsize          = (ONE_COLUMN_WIDTH, ONE_COLUMN_WIDTH * 0.75)
const panel_spinewidth = 1.8
const panel_ylims      = (-0.05, nothing)

const title_fontsize       = 14   # panel Eₜ headers
const label_fontsize       = 14   # axis labels
const tick_fontsize        = 12   # x / y tick labels
const legend_fontsize      = 12
const panel_label_fontsize = 13   # (a)–(f) tags

# Series styling by variant name; the draw order comes from the file (`variants`).
series_style = Dict(   # not const: a Dict would warn on redefinition when re-run in one session
    "memory_arithmetic" => (color = "#E89A3C", marker = :utriangle, label = "Memory (arithmetic)"),
    "memory_local"      => (color = "#B53A8C", marker = :diamond,   label = "Memory (local)"),
    "markovian"         => (color = "#3F9DCC", marker = :circle,    label = "Markovian"),
)
const color_md = "#444444"

# --- row_xspec logic (identical to the original) ---
function row_xspec(ν_init)
    if ν_init ≤ 5
        # ymax 1.25: every trajectory ends in ν = 0 here (P = 1), so leave
        # room above it for the panel letter.
        return (xticks = 0:1:5,         xlims = (-0.5, 5.5), ymax = 1.25)
    elseif ν_init ≤ 10
        return (xticks = 0:2:10,        xlims = (-0.5, 10.5))
    else
        # No tick at 16: with colgap 0 its label collides with the next
        # panel's "0".
        return (xticks = 0:5:15,        xlims = (-1, 17))
    end
end

# --- load the reproduction data ---
h5_path = projectdir("figure_data", "fig_S4", "fig_S4_data.h5")

nu_initial_list, E_trans_eV_list, variants, show_md_baseline, panels =
    h5open(h5_path, "r") do h5
        ν_inits  = read(h5["nu_initial_list"])
        Eₜs      = read(h5["E_trans_eV_list"])
        variants = read(h5["variants"])                 # draw order
        show_md  = Bool(read(h5["show_md_baseline"]))

        panels = Matrix{Any}(undef, length(ν_inits), length(Eₜs))
        for r_idx in eachindex(ν_inits), c_idx in eachindex(Eₜs)
            g = h5["panel_$(r_idx)_$(c_idx)"]
            series = Dict{String, Any}()
            for name in (show_md ? ["md"; variants] : variants)
                haskey(g, name) || continue             # the original skips missing results
                series[name] = (prob = read(g[name]["prob"]), err = read(g[name]["err"]))
            end
            panels[r_idx, c_idx] = (nu_init      = read(g["nu_init"]),
                                    panel_letter = read(g["panel_letter"]),
                                    nu_bins      = read(g["nu_bins"]),
                                    series       = series)
        end
        (ν_inits, Eₜs, variants, show_md, panels)
    end

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

panel_axes = Matrix{Any}(undef, n_rows, n_cols)
for r_idx in 1:n_rows, c_idx in 1:n_cols          # row-major, as the original
    p    = panels[r_idx, c_idx]
    spec = row_xspec(p.nu_init)

    ax = Axis(fig[r_idx + 1, c_idx];
              xticks = spec.xticks,
              xticklabelsize = tick_fontsize,
              yticklabelsize = tick_fontsize,
              xtickalign = 1.0,
              ytickalign = 1.0,
              xticksmirrored = true,
              yticksmirrored = true,
              limits = (spec.xlims[1], spec.xlims[2], panel_ylims[1], get(spec, :ymax, panel_ylims[2])),
              spinewidth = panel_spinewidth,
              xtickwidth = panel_spinewidth,
              ytickwidth = panel_spinewidth,
              xgridvisible = false, ygridvisible = false,
              xminorticksvisible = false, yminorticksvisible = false)

    # Dashed vertical line at the initial vibrational state
    vlines!(ax, [p.nu_init]; color = :black, linestyle = :dash,
            linewidth = 1.0)

    # MD baseline (no friction), drawn first when enabled
    if show_md_baseline && haskey(p.series, "md")
        s = p.series["md"]
        errorbars!(ax, p.nu_bins, s.prob, s.err;
                   color = color_md, whiskerwidth = 12, linewidth = 2.0)
        scatterlines!(ax, p.nu_bins, s.prob;
                      color = color_md,
                      linewidth = 1.2,
                      markersize = 9,
                      marker = :circle,
                      strokecolor = :black,
                      strokewidth = 1.2)
    end

    # CPA series: memory (arithmetic) → memory (local) → Markovian
    for name in variants
        haskey(p.series, name) || continue
        s     = p.series[name]
        style = series_style[name]
        errorbars!(ax, p.nu_bins, s.prob, s.err;
                   color = style.color, whiskerwidth = 12, linewidth = 2.0)
        scatterlines!(ax, p.nu_bins, s.prob;
                      color = style.color,
                      linewidth = 1.6,
                      markersize = 9,
                      marker = style.marker,
                      strokecolor = :black,
                      strokewidth = 1.2)
    end

    # Panel letter (a)–(f), top-left inset, faux-bold via a thin stroke
    text!(ax, 0.04, 0.95;
          text        = p.panel_letter,
          space       = :relative,
          align       = (:left, :top),
          fontsize    = panel_label_fontsize,
          color       = :black,
          strokewidth = 0.5,
          strokecolor = :black)

    panel_axes[r_idx, c_idx] = ax
end

for r_idx in 1:n_rows
    linkyaxes!(panel_axes[r_idx, :]...)
end
for r_idx in 1:n_rows, c_idx in 2:n_cols
    hideydecorations!(panel_axes[r_idx, c_idx]; grid = false, ticks = false)
end

# Axis labels
Label(fig[:, 0], "Probability";
      fontsize = label_fontsize,
      rotation = π / 2,
      tellheight = false,
      padding = (0, 4, 0, 0))
Label(fig[n_rows + 2, 1:n_cols], "Final vibrational state ν";
      fontsize = label_fontsize,
      tellwidth = false,
      padding = (0, 0, 0, 0))

# Legend: one entry per variant in draw order, then the initial-state line
legend_elems  = Any[]
legend_labels = String[]
for name in variants
    style = series_style[name]
    push!(legend_elems,
          [LineElement(;   color = style.color, linewidth = 1.6),
           MarkerElement(; color = style.color, marker = style.marker, markersize = 10,
                           strokecolor = :black, strokewidth = 1.2)])
    push!(legend_labels, style.label)
end
push!(legend_elems, LineElement(; color = :black, linestyle = :dash, linewidth = 1.0))
push!(legend_labels, "Initial vibrational state")
if show_md_baseline
    pushfirst!(legend_elems,
        [MarkerElement(; color = color_md, marker = :circle, markersize = 10,
                         strokecolor = :white, strokewidth = 0.8),
         LineElement(;   color = color_md, linewidth = 1.2)])
    pushfirst!(legend_labels, "MD (no friction)")
end

Legend(fig[n_rows + 3, 1:n_cols], legend_elems, legend_labels;
       orientation = :horizontal,
       nbanks = 2,
       tellwidth = false,
       tellheight = true,
       framevisible = false,
       framecolor = :black,
       framewidth = panel_spinewidth,
       labelsize = legend_fontsize,
       patchsize = (24, 12),
       margin = (4, 4, 2, 2))

# Row and column gaps (identical to the original)
rowgap!(fig.layout, 1, 2)
for r_idx in 2:n_rows
    rowgap!(fig.layout, r_idx, 4)
end
rowgap!(fig.layout, n_rows + 1, 0)
rowgap!(fig.layout, n_rows + 2, 4)
colgap!(fig.layout, 0)

display(fig)

outdir = plotsdir("fig_S4")
mkpath(outdir)
save(joinpath(outdir, "fig_S4.pdf"), fig)
