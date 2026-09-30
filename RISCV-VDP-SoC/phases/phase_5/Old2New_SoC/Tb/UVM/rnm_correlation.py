import sys
import pandas as pd
import matplotlib.pyplot as plt


def main(csv_path, out_png="rnm_correlation.png"):
    df = pd.read_csv(csv_path)
    numeric_df = df.select_dtypes(include="number")  # drops text like result
    corr = numeric_df.corr(method="pearson")

    print("Correlation matrix:\n")
    print(corr.round(3).to_string())

    # --- What to look for ---
    # temp_c_in vs temp_read_tenths / ideal_tenths -> should be ~1.0
    #   (confirms the RNM chain faithfully tracks the commanded input)
    # error vs seed -> should be ~0
    #   (confirms noise isn't secretly seed-biased)
    # error vs temp_c_in -> should be ~0
    #   (confirms additive noise, not a gain error scaling with temperature)
    # adc_code vs sensor_voltage -> should be ~1.0
    #   (confirms the ADC quantizer itself isn't broken)
    # error vs noise_on -> large jump when noise_on=1
    #   (confirms noise really is the dominant error source)

    fig, ax = plt.subplots(figsize=(8, 6))
    im = ax.imshow(corr, vmin=-1, vmax=1, cmap="coolwarm")
    ax.set_xticks(range(len(corr.columns)))
    ax.set_yticks(range(len(corr.columns)))
    ax.set_xticklabels(corr.columns, rotation=45, ha="right")
    ax.set_yticklabels(corr.columns)
    for i in range(len(corr.columns)):
        for j in range(len(corr.columns)):
            ax.text(j, i, f"{corr.iloc[i, j]:.2f}", ha="center", va="center", fontsize=8)
    fig.colorbar(im, ax=ax, label="Pearson correlation")
    ax.set_title("RNM sweep correlation matrix")
    fig.tight_layout()
    fig.savefig(out_png, dpi=150)
    print(f"\nSaved heatmap to {out_png}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python rnm_correlation.py <results.csv> [out.png]")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "rnm_correlation.png")