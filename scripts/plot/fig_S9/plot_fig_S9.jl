using DrWatson
@quickactivate "memory-friction-paper_figures"

using HDF5
using CairoMakie
using Colors

# -----------------------------------------------------------------------------
# Reproduce Figure S9 from the data saved by
# scripts/plot/friction/memory/NOAu/plot_LambdaElement_r_time_fit.jl
# (normalised NO/Au memory kernel, K_rr and K_rz, with damped-cosine fits)
# -----------------------------------------------------------------------------

# --- styling constants (kept identical to the original plotting script) ---
const SI_WIDTH             = 481
const SI_AXIS_LABEL_SIZE   = 14
const SI_TICK_LABEL_SIZE   = 12
const SI_HEADER_SIZE       = 14
const SI_LEGEND_LABEL_SIZE = 12
const FONT = projectdir("assets", "fonts", "dejavu-sans.book.ttf")

const panel_spinewidth = 1.8
const FIT_COLOR        = :black
const FIT_X_TICKS      = [0, 2, 4]

const colors = [            # one per z
    colorant"#1f77b4",
    colorant"#2ca02c",
    colorant"#d62728",
]

# --- load the reproduction data ---
h5_path = projectdir("figure_data", "fig_S9", "fig_S9_data.h5")

h5 = h5open(h5_path, "r")
R_values = read(h5["R_values_A"])
z_sorted = read(h5["Z_values_A"])
elements = read(h5["elements"])       # row blocks, in draw order: "rr", then "rz"
t_window = read(h5["t_window_fs"])
t_fs     = read(h5["t_fs"])
y_lims   = read(h5["y_lims"])
# temperature_K, omega_*_eV, K_u_ps2 and the fit parameters/errors are stored but not drawn

n_r    = length(R_values)
n_rows = length(elements) * n_r

fig = Figure(size = (SI_WIDTH, SI_WIDTH * 0.9),
             figure_padding = (2, 6, 2, 2),
             fonts = (; regular = FONT))

# Rows: (r,r) at each r, then (r,z) at each r; columns: z. Panels are created in the
# original's order (element, then r, then z); only the bottom row carries t tick labels.
for k in eachindex(elements), ir in 1:n_r, iz in eachindex(z_sorted)
    row = (k - 1) * n_r + ir
    g   = h5["panel_$(row)_$(iz)"]
    y   = read(g["K_normalised"])
    fit = read(g["fit"])

    ax = Axis(fig[row + 1, iz + 1];
        limits         = (0.0, t_window, y_lims...),
        xticks         = FIT_X_TICKS,
        yticks         = [0.0, 1.0],
        xticklabelsize = SI_TICK_LABEL_SIZE,
        yticklabelsize = SI_TICK_LABEL_SIZE,
        xticklabelsvisible = row == n_rows,
        yticklabelsvisible = iz == 1,
        xgridvisible   = false,
        ygridvisible   = false,
        xtickalign     = 1,
        ytickalign     = 1,
        spinewidth     = panel_spinewidth,
        xtickwidth     = panel_spinewidth,
        ytickwidth     = panel_spinewidth,
    )
    hlines!(ax, 0.0; color = :gray70, linewidth = 0.8)
    lines!(ax, t_fs, y; color = colors[iz], linewidth = 2)
    lines!(ax, t_fs, fit; color = FIT_COLOR, linewidth = 1.2, linestyle = :dash)
end

close(h5)

# Column (z) and row (r) headers; one y-label per element, spanning its r rows.
for (i, z) in enumerate(z_sorted)
    Label(fig[1, i + 1], "z = $(z) Å"; fontsize = SI_HEADER_SIZE, color = colors[i],
          tellwidth = false, padding = (0, 0, 2, 0))
end
for row in 1:n_rows
    Label(fig[row + 1, length(z_sorted) + 2], "r = $(R_values[mod1(row, n_r)]) Å"; rotation = -π / 2,
          fontsize = SI_HEADER_SIZE, tellheight = false, padding = (4, 0, 0, 0))
end
for (k, name) in enumerate(elements)
    Label(fig[(k - 1) * n_r .+ (2:n_r + 1), 1],
          rich("K", subscript(name), "(t ; x) / K", subscript(name), "(0 ; x)"); rotation = π / 2,
          fontsize = SI_AXIS_LABEL_SIZE, tellheight = false, padding = (0, 4, 0, 0))
end
Label(fig[n_rows + 2, 2:length(z_sorted) + 1], "t  (fs)";
      fontsize = SI_AXIS_LABEL_SIZE, tellwidth = false)

Legend(fig[0, 1:length(z_sorted) + 2],
       [LineElement(color = :gray40, linewidth = 2),
        LineElement(color = FIT_COLOR, linewidth = 1.2, linestyle = :dash)],
       ["K(t ; x)", rich("fit e", superscript("−γt"), " cos Ωt")];
       orientation  = :horizontal,
       framevisible = false,
       tellwidth    = false,
       tellheight   = true,
       patchsize    = (22, 12),
       colgap       = 10,
       padding      = (2, 2, 1, 1),
       labelsize    = SI_LEGEND_LABEL_SIZE)

rowgap!(fig.layout, 4)
colgap!(fig.layout, 6)

display(fig)

outdir = plotsdir("fig_S9")
mkpath(outdir)
save(joinpath(outdir, "fig_S9.pdf"), fig)
