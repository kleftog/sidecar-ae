# Artifact Evaluation for SideCar - ACSAC'24

_This documentation contains the steps necessary to reproduce the artifacts for our paper titled **SIDECAR: Leveraging Debugging Extensions in Commodity Processors to Secure Software**.
We use a 24-core Intel i9-13900K at 5.20 GHz to evaluate all the experiments to which we will provide access through HotCRP._

## Installation

- Detailed instructions can be found in the [README.md of our GitHub repository](https://github.com/stevens-s3lab/sidecar).
- Our server comes with everything prebuilt and preinstalled. There is no need to rebuild anything, but if required, you can run the following commands for building and installing all software dependencies, LLVM 12, testing tools (wrk, memtier_benchmark, etc.):

```bash
./sidecar/tools/install.sh
python3 tools/build_fig9.py
python3 tools/build_fig10.py
```

## Evaluation Workflow

### Major Claims

1. **Section 6.2**: We show that SIDECAR is able to detect a wide range of attacks by testing it against RIPE64, which can imitate up to 850 attacks.
2. **Figure 9**: We find that SIDECFI outperforms LLVM-CFI on real-world applications and that SIDECAR performs reasonably well on SPEC CPU2017.
3. **Figure 10**: We find that SIDEGUARD is slower but on par with GRIFFIN, which requires a large amount of resources.
4. **Table 2**: We show the average CPU utilization for SIDECFI and SIDESTACK and argue that it is considerably lower than GRIFFIN, which requires a minimum of 6 cores.

### Experiments

1. **[Reproducing Sec. 6.2; verifying claim C1]**  
   **[5 human-minutes + 1 hour compute-hour]**

- Run the following command:

```bash
python3 tools/run_sec6.2.sh
```

- The raw results will be saved under `../sidecar-results/ripe64`.
- The complete RIPE64 logs are stored in `../sidecar-results/ripe64/results.log`, and the final stats can be found in `../sidecar-results/ripe64/stats.log`.

2. **[Reproducing Fig. 9; verifying claim C2]**  
   **[5 human-minutes + 10 hours compute-hour]**

- Run the following command:

```bash
python3 tools/run_fig9.sh
```

- The raw results will be saved under `../sidecar-results/raw`, while the parsed results will be in `../sidecar-results/parsed`.
- Run the following command to produce Figure 9:

```bash
python3 tools/plot_fig9.sh
```

- The plot will be saved in `../sidecar-results/plots/figure9.pdf`.

3. **[Reproducing Fig. 10; verifying claim C3]**  
   **[5 human-minutes + 2 hours compute-hour]**

- Run the following command:

```bash
python3 tools/run_fig10.sh
```

- The raw results will be saved under `../sidecar-results/raw`, while the parsed results will be in `../sidecar-results/parsed`.
- Run the following command to produce Figure 10:

```bash
python3 tools/plot_fig10.sh
```

- The plot will be saved in `../sidecar-results/plots/figure10.pdf`.

4. **[Reproducing Tab. 2; verifying claim C4]**  
   **[5 human-minutes + 1 hour compute-hour]**

- Run the following command:

```bash
python3 tools/run_tab2.sh
```

- The table will be saved under `../sidecar-results/cpu-usage/tab2.csv`.
- Run the following command to produce the LaTeX file:

```bash
./parse_tab2.sh
```

- The LaTeX file will be saved in `../sidecar-results/cpu-usage/tab2.tex`.
