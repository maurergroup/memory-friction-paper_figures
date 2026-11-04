using DrWatson
@quickactivate "memory-friction-paper_figures"

using HDF5
using CairoMakie
using Colors

# -----------------------------------------------------------------------------
# Reproduce Figure S3 from the data saved by
# scripts/plot/cpa/NOAu/plot_vib_DeltaE_kernel_SI.jl
#
# NO/Au energy loss vs initial vibrational state νᵢ for three CPA variants:
# rows = loss channel (vibration, translation), columns = incidence energy Eₜ.
# x is the index of νᵢ (equal spacing); the tick labels are the νᵢ values.
# Error bars are the asymmetric 2.5–97.5 % interval of the trajectory ensemble.
# -----------------------------------------------------------------------------

# --- styling constants (kept identical to the original plotting script) ---
const ONE_COLUMN_WIDTH = 481
const FONT = projectdir("assets", "fonts", "dejavu-sans.book.ttf")

const FIG_SIZE          = (ONE_COLUMN_WIDTH, ONE_COLUMN_WIDTH * 0.68)
const INDEX_LABEL_POS   = (0.03, 0.92)
const PANEL_SPINEWIDTH  = 1.8
const COLUMN_TITLE_SIZE = 14

const COLOR_ARITH  = parse(Colorant, "#E89A3C")   # orange
const COLOR_ENDPT  = parse(Colorant, "#B53A8C")   # magenta
const COLOR_MARKOV = parse(Colorant, "#3F9DCC")   # cyan-blue

# Per-variant style, keyed by the HDF5 variant names. The legend order is fixed
# (arithmetic, local, Markovian) as in the original; the draw order comes from
# the stored `variants`.
const VARIANT_STYLE = Dict(
    "memory_arithmetic" => (color = COLOR_ARITH,  marker = :utriangle, label = "memory (arithmetic)"),
    "memory_local"      => (color = COLOR_ENDPT,  marker = :diamond,   label = "memory (local)"),
    "markovian"         => (color = COLOR_MARKOV, marker = :circle,    label = "Markovian"),
)
const LEGEND_ORDER = ("memory_arithmetic", "memory_local", "markovian")
const SIDE_LABEL   = Dict("vib" => "Vibration", "tra" => "Translation")

# --- load the reproduction data ---
h5_path = projectdir("figure_data", "fig_S3", "fig_S3_data.h5")
h5 = h5open(h5_path, "r")

E_trans_eV_list = read(h5["E_trans_eV_list"])
nu_list         = read(h5["nu_list"])
variants        = read(h5["variants"])      # draw order
row_dofs        = read(h5["row_dofs"])      # row 1 = vibration, row 2 = translation

n_ticks = length(nu_list)
x_ticks = (collect(1:n_ticks), string.(nu_list))
n_rows  = length(row_dofs)
n_cols  = length(E_trans_eV_list)

fig = Figure(; size = FIG_SIZE,
               figure_padding = (8, 4, 6, 6),
               fonts = (; regular = FONT))

# ----- Row 1: header band — Eₜ column tags ----------------------------
for (c, Eₜ) in enumerate(E_trans_eV_list)
    Label(fig[1, c], "Eₜ = $(Eₜ) eV";
          fontsize   = COLUMN_TITLE_SIZE,
          halign     = :center,
          tellwidth  = false,
          tellheight = true,
          padding    = (c == 1 ? 6 : 0, c == n_cols ? 6 : 0, 2, 0))
end

# ----- Rows 2 & 3: panel grid ----------------------------------------
panel_axes = Matrix{Any}(undef, n_rows, n_cols)
for r in 1:n_rows
    is_bottom = r == n_rows
    for c in 1:n_cols
        panel = h5["panel_$(r)_$(c)"]
        ylo, yhi = read(panel["ylims"])
        ax = Axis(fig[r + 1, c];
                  ylabel             = "",
                  xticklabelsize     = 12,
                  yticklabelsize     = 12,
                  xminorticksvisible = false,
                  yminorticksvisible = true,
                  xminorgridvisible  = false,
                  yminorgridvisible  = false,
                  xgridvisible       = false,
                  ygridvisible       = false,
                  xticks             = x_ticks,
                  xlabel             = "",
                  limits             = (0.5, n_ticks + 0.5, ylo, yhi),
                  spinewidth         = PANEL_SPINEWIDTH,
                  xtickwidth         = PANEL_SPINEWIDTH,
                  ytickwidth         = PANEL_SPINEWIDTH,
                  xminortickwidth    = PANEL_SPINEWIDTH,
                  yminortickwidth    = PANEL_SPINEWIDTH,
                  xtickalign         = is_bottom ? 0 : 1,
                  xminortickalign    = is_bottom ? 0 : 1,
                  ytickalign         = 1,
                  yminortickalign    = 1,
                  # right-hand y ticks only (the original's panel_axis, mirror_top = false)
                  xticksmirrored     = false,
                  yticksmirrored     = true)

        for v in variants
            haskey(panel, v) || continue
            series = panel[v]
            xs = read(series["x"])
            ys = read(series["mean_eV"])
            lo = read(series["err_lo_eV"])
            hi = read(series["err_hi_eV"])
            isempty(xs) && continue
            st = VARIANT_STYLE[v]
            lines!(ax, xs, ys;
                   color = st.color, linewidth = 1.8, linestyle = :solid)
            errorbars!(ax, xs, ys, lo, hi;
                       color = st.color, whiskerwidth = 8, linewidth = 1.0)
            scatter!(ax, xs, ys;
                     color = st.color, marker = st.marker, markersize = 9,
                     strokecolor = :black, strokewidth = 1.2)
        end

        # Faux-bold "(a)"–"(f)" (thin same-colour stroke), as in the original.
        text!(ax, INDEX_LABEL_POS[1], INDEX_LABEL_POS[2];
              text        = read(panel["panel_letter"]),
              space       = :relative,
              align       = (:left, :top),
              fontsize    = 13,
              color       = :black,
              strokewidth = 0.5,
              strokecolor = :black)

        panel_axes[r, c] = ax
    end
end

close(h5)

# ----- Linking ---------------------------------------------------------
for r in 1:n_rows
    linkyaxes!(panel_axes[r, :]...)
end
for c in 1:n_cols
    linkxaxes!(panel_axes[:, c]...)
end

for r in 1:(n_rows - 1), c in 1:n_cols
    hidexdecorations!(panel_axes[r, c]; grid = false, ticks = false, minorticks = false)
end
for r in 1:n_rows, c in 2:n_cols
    hideydecorations!(panel_axes[r, c]; grid = false, ticks = false, minorticks = false)
end

# ----- Shared y-axis labels --------------------------------------------
Label(fig[2:(n_rows + 1), 0], "Energy loss (eV)";
      fontsize   = 14,
      rotation   = π / 2,
      tellheight = false,
      padding    = (0, 4, 0, 0))

# Right side — row-specific loss-channel labels (a new right-hand column).
for r in 1:n_rows
    Label(fig[r + 1, n_cols + 1], SIDE_LABEL[row_dofs[r]];
          fontsize   = 14,
          rotation   = π / 2,
          tellheight = false,
          padding    = (2, 0, 0, 0))
end

# ----- Row 4: shared x-axis label -------------------------------------
Label(fig[n_rows + 2, 1:n_cols], "Initial vibrational state νᵢ";
      fontsize   = 14,
      tellheight = true,
      tellwidth  = false,
      padding    = (0, 0, 0, 2))

# ----- Row 5: legend (methods only, colour-coded) ----------------------
legend_elems  = Any[]
legend_labels = String[]
for v in LEGEND_ORDER
    v in variants || continue
    st = VARIANT_STYLE[v]
    push!(legend_elems,
          [LineElement(; color = st.color, linewidth = 1.8, linestyle = :solid),
           MarkerElement(; color = st.color, marker = st.marker, markersize = 10,
                           strokecolor = :black, strokewidth = 1.2)])
    push!(legend_labels, st.label)
end

Legend(fig[n_rows + 3, 1:n_cols],
       legend_elems,
       legend_labels;
       orientation   = :horizontal,
       nbanks        = 1,
       tellwidth     = false,
       tellheight    = true,
       halign        = :center,
       framevisible  = false,
       margin        = (4, 4, 2, 0),
       rowgap        = 2,
       colgap        = 14,
       titlegap      = 4,
       groupgap      = 8,
       patchsize     = (22, 12),
       labelsize     = 12,
       titlesize     = 12)

# ----- Spacing (identical to the original) ----------------------------
rowgap!(fig.layout, 1, 0)   # header → panels
rowgap!(fig.layout, 2, 0)   # vib → tra
rowgap!(fig.layout, 3, 4)   # tra → x-label
rowgap!(fig.layout, 4, 2)   # x-label → legend
colgap!(fig.layout, 0)

display(fig)

outdir = plotsdir("fig_S3")
mkpath(outdir)
save(joinpath(outdir, "fig_S3.pdf"), fig)
