"""
RNM correlation analysis.

Reads results.csv (from parse_results.py) and produces:
  1. An OVERALL correlation matrix (all rows pooled).
  2. PER-SCENARIO correlation matrices, grouped by noise_on and batt.
  3. Explicit sample counts (N) printed with every matrix.
  4. Existing PNG heatmaps.
  5. A multi-page VECTOR PDF containing all heatmaps.

Usage:
    python rnm_correlation.py results.csv [out_prefix]
"""

import sys
import os
import pandas as pd

import matplotlib
matplotlib.use("Agg")  # non-interactive backend

import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages


def corr_and_plot(df, title, out_png, pdf=None):
    numeric_df = df.select_dtypes(include="number")
    n = len(numeric_df)

    print(f"\n=== {title}  (N={n}) ===\n")

    if n < 5:
        print(
            f"WARNING: only {n} rows - correlation is not statistically "
            f"meaningful below ~5-10 samples. Treat these numbers as "
            f"placeholders until you have more data."
        )

    corr = numeric_df.corr(method="pearson")
    print(corr.round(3).to_string())

    # ---------------------------------------------------------
    # Create heatmap
    # ---------------------------------------------------------
    fig, ax = plt.subplots(figsize=(8, 6))

    im = ax.imshow(
        corr,
        vmin=-1,
        vmax=1,
        cmap="coolwarm"
    )

    ax.set_xticks(range(len(corr.columns)))
    ax.set_yticks(range(len(corr.columns)))

    ax.set_xticklabels(
        corr.columns,
        rotation=45,
        ha="right"
    )

    ax.set_yticklabels(corr.columns)

    # Write correlation values into cells
    for i in range(len(corr.columns)):
        for j in range(len(corr.columns)):
            val = corr.iloc[i, j]

            label = (
                f"{val:.2f}"
                if pd.notna(val)
                else "nan"
            )

            ax.text(
                j,
                i,
                label,
                ha="center",
                va="center",
                fontsize=8
            )

    fig.colorbar(
        im,
        ax=ax,
        label="Pearson correlation"
    )

    ax.set_title(
        f"{title}  (N={n})"
    )

    fig.tight_layout()

    # ---------------------------------------------------------
    # Save PNG
    # ---------------------------------------------------------
    out_png = os.path.abspath(out_png)

    try:
        fig.savefig(
            out_png,
            dpi=150
        )

        print(f"Saved heatmap to {out_png}")

    except OSError as e:
        print(
            f"WARNING: could not save {out_png} ({e}). "
            f"Matrix above is still valid - PNG save is optional."
        )

    # ---------------------------------------------------------
    # Add same figure to PDF
    #
    # PdfPages preserves Matplotlib text and graphics as
    # vector elements instead of rasterizing the figure.
    # ---------------------------------------------------------
    if pdf is not None:
        pdf.savefig(
            fig,
            bbox_inches="tight"
        )

        print("Added heatmap to PDF")

    plt.close(fig)


def main(csv_path, out_prefix="rnm_correlation"):

    df = pd.read_csv(csv_path)

    # Absolute path for final PDF
    pdf_path = os.path.abspath(
        f"{out_prefix}.pdf"
    )

    print(f"\nCreating vector PDF:")
    print(f"  {pdf_path}")

    # ---------------------------------------------------------
    # PdfPages creates a multi-page PDF.
    # Each correlation matrix becomes one page.
    # ---------------------------------------------------------
    with PdfPages(pdf_path) as pdf:

        # -----------------------------------------------------
        # 1. Overall pooled correlation
        # -----------------------------------------------------
        corr_and_plot(
            df,
            "RNM sweep correlation matrix (overall, pooled)",
            f"{out_prefix}_overall.png",
            pdf
        )

        # -----------------------------------------------------
        # 2. Per-scenario: noise_on
        # -----------------------------------------------------
        if (
            "noise_on" in df.columns
            and df["noise_on"].nunique(dropna=True) > 1
        ):

            for val, group in df.groupby("noise_on"):

                corr_and_plot(
                    group,
                    f"RNM sweep correlation matrix (noise_on={val})",
                    f"{out_prefix}_noise{val}.png",
                    pdf
                )

        else:

            print(
                "\n(Skipping noise_on grouping: only one noise_on "
                "value present - run sweep_full with "
                'NOISE_LIST="0 1" to get both.)'
            )

        # -----------------------------------------------------
        # 3. Per-scenario: batt
        # -----------------------------------------------------
        if (
            "batt" in df.columns
            and df["batt"].nunique(dropna=True) > 1
        ):

            for val, group in df.groupby("batt"):

                corr_and_plot(
                    group,
                    f"RNM sweep correlation matrix (batt={val})",
                    f"{out_prefix}_batt{val}.png",
                    pdf
                )

        else:

            print(
                "\n(Skipping batt grouping: only one batt value "
                "present - run sweep_full with "
                'BATT_LIST="10 80" (or similar) to vary it.)'
            )

    print(f"\nSaved VECTOR PDF to:")
    print(f"  {pdf_path}")

    # ---------------------------------------------------------
    # Interpretation notes
    # ---------------------------------------------------------
    print("\n--- Interpretation notes ---")

    print(
        "temp_c_in vs temp_read_tenths/adc_code -> ~1.0 is "
        "EXPECTED and trivial: it only confirms the bus/monitor "
        "path is lossless, not that the RTL logic is correct."
    )

    print(
        "temp_alarm_exp vs temp_alarm_act, batt_alarm_exp vs "
        "batt_alarm_act -> THESE are the real model-vs-RTL checks. "
        "Below 1.0 means the RTL's alarm bit and the model's "
        "independent expectation disagree on some runs - check "
        "for threshold-boundary jitter."
    )

    print(
        "error vs seed, error vs temp_c_in -> compare the "
        "noise_on=1 group specifically; the pooled/noise_on=0 "
        "numbers will always look closer to 0 by construction."
    )


if __name__ == "__main__":

    if len(sys.argv) < 2:

        print(
            "Usage: python rnm_correlation.py "
            "<results.csv> [out_prefix]"
        )

        sys.exit(1)

    main(
        sys.argv[1],
        sys.argv[2]
        if len(sys.argv) > 2
        else "rnm_correlation"
    )