using DrWatson
@quickactivate "memory-friction-paper_figures"

using HDF5
using CairoMakie
using Colors

# -----------------------------------------------------------------------------
# Reproduce Figure S2 (ΔE vs Δ(0), Erpenbeck–Thoss, three CPA variants) from the
# data saved by scripts/plot/cpa/ErpenbeckThoss/plot_Γ_DeltaE_SI.jl
# -----------------------------------------------------------------------------

# --- styling constants (kept identical to the original plotting script) ---
const ONE_COLUMN_WIDTH  = 481
const FIG_WIDTH         = ONE_COLUMN_WIDTH
const FIG_HEIGHT        = round(Int, FIG_WIDTH * 0.6)
const AXIS_LABEL_SIZE   = 14
const TICK_LABEL_SIZE   = 12
const LEGEND_LABEL_SIZE = 12
const LEGEND_TITLE_SIZE = 12
const LINE_WIDTH        = 1.8
const MARKER_SIZE       = 8
const SPINE_WIDTH       = 1.8

const FONT = projectdir("assets", "fonts", "dejavu-sans.book.ttf")

# Sequential temperature colour ramp from HokseonPlots' NICECOLORS (a single
# temperature picks NICECOLORS[end-1] = #AB1866).
const NICECOLORS = parse.(Colorant, ["#FCE1A4","#FABF7B","#F08F6E","#E05C5C","#D12959","#AB1866","#6E005F"])
function temperature_palette(Ts)
    n = length(Ts)
    n == 1 ? [NICECOLORS[end-1]] :
             [NICECOLORS[Int(round(1 + (length(NICECOLORS)-1) * (i-1)/(n-1)))]
              for i in 1:n]
end

# Per-variant curve styling: both memory variants are solid with filled markers
# (diamond vs circle); Markovian is dashed with a white-faced circle.
variant_style(::Val{:memory_arithmetic}) = (linestyle = :solid, marker = :diamond, filled = true)
variant_style(::Val{:memory_local})      = (linestyle = :solid, marker = :circle,  filled = true)
variant_style(::Val{:markovian})         = (linestyle = :dash,  marker = :circle,  filled = false)

# Canonical legend ordering for the variant block.
const VARIANT_ORDER = (:memory_arithmetic, :memory_local, :markovian)

# -----------------------------------------------------------------------------
# Load the reproduction data
# -----------------------------------------------------------------------------
h5_path = projectdir("figure_data", "fig_S2", "fig_S2_data.h5")
h5 = h5open(h5_path, "r")
Delta0_values = read(h5["Delta0_values"])          # eV; x positions and x ticks
T_K_values    = sort(read(h5["T_K_values"]))
curves_group  = h5["curves"]
curves = map(1:length(keys(curves_group))) do k   # curve_k, k = draw order
    g = curves_group["curve_$(k)"]
    (; DeltaE_eV     = read(g["DeltaE_eV"]),
       T_K           = read(g["T_K"]),
       variant       = Symbol(read(g["variant"])),
       variant_label = read(g["variant_label"]),
       valid         = Bool.(read(g["valid"])))
end
close(h5)

color_map  = Dict(T_K_values .=> temperature_palette(T_K_values))
variants   = unique(c.variant for c in curves)
label_of   = Dict(c.variant => c.variant_label for c in curves)

# -----------------------------------------------------------------------------
# Figure and axis (HokseonPlots.MyAxis → Axis with mirrored ticks)
# -----------------------------------------------------------------------------
fig = Figure(; size = (FIG_WIDTH, FIG_HEIGHT),
               figure_padding = (8, 12, 6, 6),
               fonts = (; regular = FONT))
axis_kwargs = (
    xlabel = "Δ(0) (eV)",
    ylabel = "ΔE (eV)",
    xscale = log10,
    xlabelsize     = AXIS_LABEL_SIZE,
    ylabelsize     = AXIS_LABEL_SIZE,
    xticklabelsize = TICK_LABEL_SIZE,
    yticklabelsize = TICK_LABEL_SIZE,
    xminorticksvisible = false,     # x ticks are pinned to the swept Δ(0) values
    yminorticksvisible = true,
    xminorgridvisible  = false,
    yminorgridvisible  = false,
    xgridvisible       = false,
    ygridvisible       = false,
    xtickalign = 1, ytickalign = 1,
    xminortickalign = 1, yminortickalign = 1,
    spinewidth = SPINE_WIDTH,
    xtickwidth = SPINE_WIDTH, ytickwidth = SPINE_WIDTH,
    xticksmirrored = true,
    yticksmirrored = true,
)
ax = Axis(fig[1, 1]; axis_kwargs..., xticks = (Delta0_values, string.(Delta0_values)))

# --- curves, in draw order: lines! then scatter! per curve ---
for c in curves
    any(c.valid) || continue
    Δ0  = Delta0_values[c.valid]
    ΔE  = c.DeltaE_eV[c.valid]
    col = color_map[c.T_K]
    st  = variant_style(Val(c.variant))
    lines!(ax, Δ0, ΔE;
           color = col, linewidth = LINE_WIDTH, linestyle = st.linestyle)
    scatter!(ax, Δ0, ΔE;
             color       = st.filled ? col : :white,
             marker      = st.marker, markersize = MARKER_SIZE,
             strokecolor = col, strokewidth = st.filled ? 0.5 : 1.0)
end

# --- legend: temperature block only when >1 T; variant block otherwise untitled ---
T_elems = [[LineElement(; color = color_map[T], linewidth = LINE_WIDTH),
            MarkerElement(; color = color_map[T], marker = :circle,
                            markersize = MARKER_SIZE, strokecolor = color_map[T],
                            strokewidth = 0.5)] for T in T_K_values]
T_labels = ["$(T) K" for T in T_K_values]

vcol = length(T_K_values) == 1 ? color_map[only(T_K_values)] : :black
variant_elems  = Any[]
variant_labels = String[]
for v in VARIANT_ORDER
    v in variants || continue
    st = variant_style(Val(v))
    push!(variant_elems,
          [LineElement(; color = vcol, linewidth = LINE_WIDTH, linestyle = st.linestyle),
           MarkerElement(; color = st.filled ? vcol : :white, marker = st.marker,
                           markersize = MARKER_SIZE, strokecolor = vcol,
                           strokewidth = st.filled ? 0.5 : 1.0)])
    push!(variant_labels, label_of[v])
end

groups       = length(T_K_values) > 1 ? [T_elems, variant_elems]   : [variant_elems]
group_labels = length(T_K_values) > 1 ? [T_labels, variant_labels] : [variant_labels]
group_titles = length(T_K_values) > 1 ? ["temperature", "CPA"]     : [nothing]

Legend(fig[1, 1],
       groups, group_labels, group_titles;
       tellwidth   = false, tellheight = false,
       valign      = :top,
       halign      = :right,
       margin      = (4, 4, 4, 4),
       framevisible = true,
       framecolor   = :black,
       framewidth   = 0.8,
       rowgap       = 1,
       titlegap     = 3,
       groupgap     = 6,
       patchsize    = (13, 9),
       labelsize    = LEGEND_LABEL_SIZE,
       titlesize    = LEGEND_TITLE_SIZE)

display(fig)

outdir = plotsdir("fig_S2")
mkpath(outdir)
save(joinpath(outdir, "fig_S2.pdf"), fig)
