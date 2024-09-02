import csv
import os
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np

# Determine the path to the script and the CSV file
script_dir = os.path.dirname(os.path.abspath(__file__))
csv_file_path = os.path.join(script_dir, "../results/parsed/spec06.csv")
output_dir = Path(script_dir) / "../results/plots/"
os.makedirs(output_dir, exist_ok=True)

# Initialize lists to hold the benchmark names and performance data
benchmarks = []
performance_griffin = []
performance_sideguard = []

# Read the data from the CSV file
with open(csv_file_path, "r") as csvfile:
    csvreader = csv.reader(csvfile)
    for row in csvreader:
        if len(row) != 3:
            continue  # Skip any malformed rows
        benchmark = row[0]
        griffin_value = float(row[1])
        sideguard_value = float(row[2])

        benchmarks.append(benchmark)
        performance_griffin.append(griffin_value)
        performance_sideguard.append(sideguard_value)

# Labels for the different bars
labels = ["GRIFFIN", "SIDEGUARD"]


# The plotting function as provided, with modifications to use data from the CSV file
def plot_vertical_grouped_barchart(benchmarks, performances, labels, title):
    fig, ax = plt.subplots(figsize=(6.4, 4))

    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_visible(False)

    # Number of groups and number of bars in one group
    n_groups = len(benchmarks)
    n_bars = 2  # Hardcoded for 2 bars (Griffin and SiDEGUARD)

    # Position of groups and width of each bar
    index = np.arange(n_groups)
    bar_width = 0.25

    # Optional: add some space between the groups
    space_between_groups = 0.01
    total_group_width = n_bars * bar_width + (n_bars - 1) * space_between_groups
    offset = (total_group_width - bar_width) / 2

    color_mapping = {"GRIFFIN": "#ffa28e", "SIDEGUARD": "#a52a2a"}

    # Function to get color for a given label
    def get_color(label):
        return color_mapping.get(
            label, "#000000"
        )  # Default to black if label not found

    for i, label in enumerate(labels):
        performance = performances[i]  # Select the corresponding performance list
        color = get_color(label)
        positions = index + i * (bar_width + space_between_groups) - offset
        ax.bar(
            positions,
            performance,
            bar_width,
            label=label,
            color=color,
            error_kw={"ecolor": "black", "capsize": 2, "elinewidth": 1},
            zorder=3,
        )

    # Formatting
    ax.yaxis.set_major_locator(ticker.MultipleLocator(20))
    ax.yaxis.set_minor_locator(ticker.MultipleLocator(10))
    ax.grid(which="major", axis="y", linestyle="--", linewidth="0.5", color="gray")
    ax.grid(which="minor", axis="y", linestyle="--", linewidth="0.25", color="silver")
    # ax.set_title(title)
    ax.set_xticks(index)
    ax.set_xticklabels(benchmarks, rotation=45)
    ax.legend(
        loc="upper center",
        bbox_to_anchor=(0.5, -0.3),
        ncol=2,
        fancybox=True,
        shadow=True,
    )

    # Layout and display
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, "figure10.pdf"), bbox_inches="tight")
    # plt.show()


# Call the plotting function with the data read from the CSV file
plot_vertical_grouped_barchart(
    benchmarks,
    [performance_griffin, performance_sideguard],
    labels,
    "SPEC CPU2006 Performance",
)
