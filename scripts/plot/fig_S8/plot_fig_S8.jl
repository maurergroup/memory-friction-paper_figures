using DrWatson
@quickactivate "memory-friction-paper_figures"

using HDF5
using CairoMakie
using Colors

# -----------------------------------------------------------------------------
# Reproduce Figure S8 from the data saved by
# scripts/plot/scattering/ErpenbeckThoss/plot_H_scattering_PES.jl
#   (a) mean-field surface E(x) − E(5 Å) of H on the Erpenbeck–Thoss model for each Δ₀,
#       over the diabats U₀ (neutral) and U₁ (charged);
#   (b) zoom on the level crossing x_c: barrier E(x_c) (dots) and the friction window
#       |h| < Δ(x_c) + C_WINDOW·k_BT (halo on each surface).
# -----------------------------------------------------------------------------

# --- styling constants (kept identical to the original plotting script) ---
const ONE_COLUMN_WIDTH = 481
const FONT             = projectdir("assets", "fonts", "dejavu-sans.book.ttf")
const AXIS_LABEL_SIZE  = 14
const TICK_LABEL_SIZE  = 12
const ANNOTATION_SIZE  = 14
const LEGEND_SIZE      = 12
const PANEL_LABEL_SIZE = 13
const SPINEWIDTH       = 1.8

# Ordinal blue ramp, darker = broader level, in stored surface order (Δ₀ = 1.0, 0.4, 0.1, 0.01 eV).
const Δ_COLORS = [colorant"#0d366b", colorant"#1c5cab", colorant"#3987e5", colorant"#6da7ec"]
const DIABAT_COLOR = colorant"#8c8c8c"
const WINDOW_WIDTH = 9                   # halo marking the friction window in (b)
const WINDOW_ALPHA = 0.35

# --- load the reproduction data ---
h5_path = projectdir("figure_data", "fig_S8", "fig_S8_data.h5")

h5 = h5open(h5_path, "r")
E_inc       = read(h5["incident_energy_eV"])
x_start     = read(h5["x_start_A"])
C_WINDOW    = read(h5["C_WINDOW"])           # Int64, so the legend reads "3 kʙT"
x_c         = read(h5["x_c_A"])              # level crossing h(x_c) = 0, the same for every Δ₀
full_limits = read(h5["full_limits"])        # panel (a): (x_min, x_max, E_min, E_max)
zoom_limits = read(h5["zoom_limits"])        # panel (b), also the zoom box drawn on (a)
zoom_xticks = read(h5["zoom_xticks_A"])
x_grid      = read(h5["x_grid_A"])           # descending from 5 Å, contains x_c
n_surfaces  = length(read(h5["Gamma_values_eV"]))
# temperature_K is stored for the golden-data test only.

# One surface per Δ₀ (= Γ/2), in draw order k = 1:n_surfaces.
surfaces = map(1:n_surfaces) do k
    g = h5["surface_$(k)"]
    (Δ₀      = read(g["Delta0_eV"]),
     E       = read(g["E_eV"]),
     window  = Bool.(read(g["in_window"])),  # halo points on x_grid (zoom only)
     barrier = read(g["barrier_eV"]))
end

# Diabats relative to E(5 Å), on each panel's own x range.
read_diabats(name) = (x = read(h5[name]["x_A"]), U0 = read(h5[name]["U0_eV"]), U1 = read(h5[name]["U1_eV"]))
diabats_full = read_diabats("diabats_full")
diabats_zoom = read_diabats("diabats_zoom")
close(h5)

# --- figure ---
Δ₀_label(s) = "$(s.Δ₀) eV"               # legend entry; the row is titled Δ₀

fig = Figure(
    size = (ONE_COLUMN_WIDTH, 300),
    figure_padding = (2, 8, 2, 2),
    fonts = (; regular = FONT),
)

axis_kwargs = (
    xlabelsize      = AXIS_LABEL_SIZE,
    ylabelsize      = AXIS_LABEL_SIZE,
    xticklabelsize  = TICK_LABEL_SIZE,
    yticklabelsize  = TICK_LABEL_SIZE,
    xgridvisible    = false,
    ygridvisible    = false,
    xtickalign      = 1,
    ytickalign      = 1,
    xticksmirrored  = true,
    yticksmirrored  = true,
    spinewidth      = SPINEWIDTH,
    xtickwidth      = SPINEWIDTH,
    ytickwidth      = SPINEWIDTH,
)

ax_full = Axis(fig[1, 1]; xlabel = "x  (Å)", ylabel = "E(x) − E(5 Å)  (eV)",
               limits = Tuple(full_limits), xticks = 2:1:5, axis_kwargs...)
ax_zoom = Axis(fig[1, 2]; xlabel = "x  (Å)",
               limits = Tuple(zoom_limits), xticks = zoom_xticks, axis_kwargs...)

for (ax, d) in ((ax_full, diabats_full), (ax_zoom, diabats_zoom))
    # Diabats, the shared crossing and the incident energy.
    lines!(ax, d.x, d.U0; color = DIABAT_COLOR, linestyle = :dash,    linewidth = 1.5)
    lines!(ax, d.x, d.U1; color = DIABAT_COLOR, linestyle = :dashdot, linewidth = 1.5)
    vlines!(ax, x_c; color = :black, linewidth = 1)
    hlines!(ax, E_inc; color = :black, linestyle = :dot, linewidth = 1.5)

    for (k, s) in enumerate(surfaces)
        ax === ax_zoom && lines!(ax, x_grid[s.window], s.E[s.window];
                                 color = (Δ_COLORS[k], WINDOW_ALPHA), linewidth = WINDOW_WIDTH)
        lines!(ax, x_grid, s.E; color = Δ_COLORS[k], linewidth = 2)
    end
end

# --- (a) labels ---
text!(ax_full, x_start - 0.05, E_inc;
      text = rich("E", subscript("inc"), " = $(E_inc) eV"),
      align = (:right, :bottom), fontsize = ANNOTATION_SIZE)
text!(ax_full, x_c + 0.04, full_limits[3] + 0.05; text = rich("x", subscript("c")),
      align = (:left, :bottom), fontsize = ANNOTATION_SIZE)
text!(ax_full, 2.5, 2.6; text = "U₀", align = (:left, :center), fontsize = ANNOTATION_SIZE, color = DIABAT_COLOR)
text!(ax_full, 3.0, 0.75; text = "U₁", align = (:left, :bottom), fontsize = ANNOTATION_SIZE, color = DIABAT_COLOR)
# Zoom window of panel (b).
poly!(ax_full, Rect2f(zoom_limits[1], zoom_limits[3], zoom_limits[2] - zoom_limits[1], zoom_limits[4] - zoom_limits[3]);
      color = :transparent, strokecolor = :gray40, strokewidth = 1)

# --- (b) barrier at x_c; KE at x_c is the gap up to E_inc ---
for (k, s) in enumerate(surfaces)
    scatter!(ax_zoom, [x_c], [s.barrier]; color = Δ_COLORS[k], markersize = 10,
             strokecolor = :white, strokewidth = 1.5)
end

# Panel labels in empty corners: (a) top right, (b) bottom left.
for (ax, label, pos, align) in ((ax_full, "(a)", (0.97, 0.97), (:right, :top)),
                                (ax_zoom, "(b)", (0.04, 0.03), (:left, :bottom)))
    text!(ax, pos...; text = label, space = :relative, align = align,
          fontsize = PANEL_LABEL_SIZE, strokewidth = 0.5, strokecolor = :black)
end

# --- legend: surfaces by Δ₀ on the first row, diabats and window on the second ---
legend_kwargs = (orientation = :horizontal, framevisible = false, labelsize = LEGEND_SIZE,
                 patchsize = (18, 12), colgap = 6, padding = (2, 2, 1, 1),
                 tellheight = true, tellwidth = false)
legend_grid = GridLayout(fig[0, 1:2])
Legend(legend_grid[1, 1], [LineElement(color = c, linewidth = 2) for c in Δ_COLORS],
       Δ₀_label.(surfaces), "Δ₀"; titleposition = :left, titlefont = :regular,
       titlesize = LEGEND_SIZE, legend_kwargs...)
Legend(legend_grid[2, 1],
       [LineElement(color = DIABAT_COLOR, linestyle = :dash,    linewidth = 1.5),
        LineElement(color = DIABAT_COLOR, linestyle = :dashdot, linewidth = 1.5),
        LineElement(color = (DIABAT_COLOR, WINDOW_ALPHA), linewidth = WINDOW_WIDTH)],
       ["U₀ (neutral)", "U₁ (charged)", rich("|h| < Δ(x", subscript("c"), ") + $(C_WINDOW) kʙT")];
       legend_kwargs...)
rowgap!(legend_grid, 0)

colgap!(fig.layout, 10)
rowgap!(fig.layout, 4)

display(fig)

outdir = plotsdir("fig_S8")
mkpath(outdir)
save(joinpath(outdir, "fig_S8.pdf"), fig)
