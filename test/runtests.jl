using DrWatson, Test
@quickactivate "memory-friction-paper_figures"

println("Starting reproducibility tests for all figures")
ti = time()

# -----------------------------------------------------------------------------
# Helper: run a figure script and check that its output PDF was created.
# -----------------------------------------------------------------------------
function test_figure(fig_number, script_relpath, output_relpath)
    @testset "Figure $fig_number" begin
        script_path = projectdir(script_relpath)
        output_path = projectdir(output_relpath)

        # Remove any previous output so the test is honest.
        if isfile(output_path)
            rm(output_path)
        end

        @test isfile(script_path)

        # Run the plotting script in a fresh module so `const` definitions
        # shared across figure scripts (AXIS_LABEL_SIZE, FONT, etc.) don't collide.
        m = Module()
        script_ok = try
            Base.include(m, script_path)
            true
        catch e
            println("     Script error: ", sprint(showerror, e))
            false
        end
        @test script_ok

        # Only check output if the script ran without error.
        if script_ok
            @test isfile(output_path)
            @test filesize(output_path) > 1024
            println("  ✓ Figure $fig_number: $(round(filesize(output_path)/1024, digits=1)) KB PDF")
        end
    end
end

# -----------------------------------------------------------------------------
# Figure-by-figure tests.
# -----------------------------------------------------------------------------
@testset "memory-friction-paper_figures — all figures" begin
    test_figure(2,
        "scripts/plot/fig_2/plot_fig_2.jl",
        "plots/fig_2/fig_2.pdf")

    test_figure(3,
        "scripts/plot/fig_3/plot_fig_3.jl",
        "plots/fig_3/fig_3.pdf")

    test_figure(4,
        "scripts/plot/fig_4/plot_fig_4.jl",
        "plots/fig_4/fig_4.pdf")

    test_figure(5,
        "scripts/plot/fig_5/plot_fig_5.jl",
        "plots/fig_5/fig_5.pdf")

    # Supplementary figures S2–S9
    for n in 2:9
        test_figure("S$n",
            "scripts/plot/fig_S$n/plot_fig_S$n.jl",
            "plots/fig_S$n/fig_S$n.pdf")
    end
end

# -----------------------------------------------------------------------------
# Data integrity checks: verify that all required HDF5 data files exist
# and are non-empty (catches partial git-lfs pulls, corruption, etc.).
# -----------------------------------------------------------------------------
@testset "Data file integrity" begin
    for fig in [string.(2:5); ["S$n" for n in 2:9]]
        data_path = projectdir("figure_data", "fig_$fig", "fig_$(fig)_data.h5")
        @test isfile(data_path)
        @test filesize(data_path) > 0
    end
end

# -----------------------------------------------------------------------------
elapsed = round((time() - ti) / 60; digits = 2)
println("\nAll tests completed in $elapsed minutes")
