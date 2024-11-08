import csv
import os
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np

# Constants for directory structure
script_dir = os.path.dirname(os.path.abspath(__file__))
output_dir = Path(script_dir) / "../results/plots/"
os.makedirs(output_dir, exist_ok=True)
spec_file = Path(script_dir) / "../results/parsed/spec17.csv"
apps_file = Path(script_dir) / "../results/parsed/apps.csv"


def parse_spec_file(filename):
    benchmarks = []
    cfi = []
    fineibt = []
    sidecfi = []
    scs = []
    sidestack = []
    asan = []
    sideasan = []
    std_devs_cfi = []
    std_devs_fineibt = []
    std_devs_sidecfi = []
    std_devs_scs = []
    std_devs_sidestack = []
    std_devs_asan = []
    std_devs_sideasan = []

    with open(filename, "r") as file:
        reader = csv.reader(file)
        for row in reader:
            benchmarks.append(row[0])
            cfi.append(float(row[1]))
            std_devs_cfi.append(float(row[2]))
            fineibt.append(float(row[3]))
            std_devs_fineibt.append(float(row[4]))
            sidecfi.append(float(row[5]))
            std_devs_sidecfi.append(float(row[6]))
            scs.append(float(row[7]))
            std_devs_scs.append(float(row[8]))
            sidestack.append(float(row[9]))
            std_devs_sidestack.append(float(row[10]))
            asan.append(float(row[11]))
            std_devs_asan.append(float(row[12]))
            sideasan.append(float(row[13]))
            std_devs_sideasan.append(float(row[14]))

    return (
        benchmarks,
        cfi,
        fineibt,
        sidecfi,
        scs,
        sidestack,
        asan,
        sideasan,
        std_devs_cfi,
        std_devs_fineibt,
        std_devs_sidecfi,
        std_devs_scs,
        std_devs_sidestack,
        std_devs_asan,
        std_devs_sideasan,
    )


def parse_apps_file(filename):
    benchmarks = []
    overheads = []

    with open(filename, "r") as file:
        reader = csv.reader(file)
        for row in reader:
            benchmarks.append(row[0].strip('"'))
            overheads.append([float(val) for val in row[1:]])

    return benchmarks, overheads


def plot_vertical_grouped_barchart(benchmarks, overheads, std_devs, labels, title):
    fig, ax = plt.subplots(figsize=(12, 4))

    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_visible(False)

    n_groups = len(benchmarks)
    n_bars = len(overheads)

    index = np.arange(n_groups)
    bar_width = 0.07

    space_between_groups = 0.005
    total_group_width = n_bars * bar_width + (n_bars - 1) * space_between_groups
    offset = (total_group_width - bar_width) / 2

    color_mapping = {
        "LLVM-CFI": "#FFB6C1",
        "FINEIBT": "#E23BBF",
        "SIDECFI": "#9c27b0",
        "LLVM-SCS": "#90EE90",
        "SIDESTACK": "#008000",
        "LLVM-ASAN": "#FFD580",
        "SIDEASAN": "#FFAC1C",
    }

    def get_color(label):
        return color_mapping.get(label, "#000000")

    for i, (overhead, std_dev, label) in enumerate(zip(overheads, std_devs, labels)):
        if any(o > 0 for o in overhead):
            color = get_color(label)

            # Adjust the position for the CFI pink bar only for the specific apps
            if label == "LLVM-CFI":
                adjusted_index = index.astype(float).copy()
                for j, benchmark in enumerate(benchmarks):
                    if benchmark in [
                        "httpd",
                        "memcached",
                        "bind",
                        "lighttpd",
                    ]:
                        adjusted_index[j] += bar_width + space_between_groups
                    elif benchmark in ["chromium", "**geomean"]:
                        adjusted_index[j] += 3 * bar_width + space_between_groups
                    elif benchmark in ["geomean"]:
                        adjusted_index[j] += bar_width + space_between_groups
                    else:
                        adjusted_index[j] = index[
                            j
                        ]  # No adjustment for other benchmarks
            elif label == "SIDECFI":
                adjusted_index = index.astype(float).copy()
                for j, benchmark in enumerate(benchmarks):
                    if benchmark in ["chromium", "**geomean"]:
                        adjusted_index[j] += 2 * bar_width + space_between_groups
                    elif benchmark in ["geomean"]:
                        adjusted_index[j] += bar_width + space_between_groups
                    else:
                        adjusted_index[j] = index[j]
            elif label == "FINEIBT":
                adjusted_index = index.astype(float).copy()
                for j, benchmark in enumerate(benchmarks):
                    if benchmark in ["geomean"]:
                        adjusted_index[j] += bar_width + space_between_groups
                    else:
                        adjusted_index[j] = index[j]
            else:
                adjusted_index = index

            bars = ax.bar(
                adjusted_index + i * (bar_width + space_between_groups) - offset,
                [o if o > 0 else 0 for o in overhead],
                bar_width,
                yerr=std_dev,
                label=label,
                color=color,
                error_kw={"ecolor": "black", "capsize": 2, "elinewidth": 1},
                zorder=3,
            )

        for bar, value in zip(bars, overhead):
            if value < 0:
                ax.text(
                    bar.get_x() + bar.get_width() - 0.0261,
                    0,
                    " X    X    X    X    X    X    X    X    X",
                    ha="center",
                    va="bottom",
                    color="red",
                    fontsize=6,
                    rotation=90,
                )

    ax.yaxis.set_major_locator(ticker.MultipleLocator(20))
    ax.yaxis.set_minor_locator(ticker.MultipleLocator(10))
    ax.grid(which="major", axis="y", linestyle="--", linewidth="0.5", color="gray")
    ax.grid(which="minor", axis="y", linestyle="--", linewidth="0.25", color="silver")
    ax.set_xticks(index)
    ax.set_xticklabels(benchmarks, rotation=45)
    ax.legend(
        loc="upper center",
        bbox_to_anchor=(0.5, 1.15),
        ncol=7,
        fancybox=True,
        shadow=True,
    )

    geomean_spec_index = benchmarks.index("geomean") + 0.5
    plt.axvline(x=geomean_spec_index, color="grey", linestyle="--", linewidth="0.5")

    plt.tight_layout()

    plt.savefig(os.path.join(output_dir, "figure9.pdf"), bbox_inches="tight")
    # plt.show()


def plot_graph():
    (
        benchmarks_spec,
        cfi,
        fineibt,
        sidecfi,
        scs,
        sidestack,
        asan,
        sideasan,
        std_devs_cfi,
        std_devs_fineibt,
        std_devs_sidecfi,
        std_devs_scs,
        std_devs_sidestack,
        std_devs_asan,
        std_devs_sideasan,
    ) = parse_spec_file(spec_file)
    benchmarks_apps, overheads_apps = parse_apps_file(apps_file)

    benchmarks = benchmarks_spec + benchmarks_apps
    overheads = [
        cfi + [x[0] for x in overheads_apps],
        fineibt + [x[1] for x in overheads_apps],
        sidecfi + [x[2] for x in overheads_apps],
        scs + [x[3] for x in overheads_apps],
        sidestack + [x[4] for x in overheads_apps],
        asan + [x[5] for x in overheads_apps],
        sideasan + [x[6] for x in overheads_apps],
    ]

    std_devs = [
        std_devs_cfi + [0] * len(benchmarks_apps),
        std_devs_fineibt + [0] * len(benchmarks_apps),
        std_devs_sidecfi + [0] * len(benchmarks_apps),
        std_devs_scs + [0] * len(benchmarks_apps),
        std_devs_sidestack + [0] * len(benchmarks_apps),
        std_devs_asan + [0] * len(benchmarks_apps),
        std_devs_sideasan + [0] * len(benchmarks_apps),
    ]

    labels = [
        "LLVM-CFI",
        "FINEIBT",
        "SIDECFI",
        "LLVM-SCS",
        "SIDESTACK",
        "LLVM-ASAN",
        "SIDEASAN",
    ]
    title = "Relative Performance (%) under Different Policies."

    plot_vertical_grouped_barchart(benchmarks, overheads, std_devs, labels, title)


if __name__ == "__main__":
    plot_graph()
