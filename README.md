# dust benchmarks

Code for benchmarking and performance testing of dust with sircovid

## Hardware

3 different machines used:

Consumer

* Dual Xeon 6230 (40 cores @ 2.10GHZ)
* 754GB RAM
* GeForce RTX 3090
* GeForce RTX 2080 Ti

A100

* Dual AMD EPYC 7552 48-Core Processor
* 503GB RAM
* NVIDIA A100-PCIE-40GB (x2)

A5000

* Dual AMD EPYC 7542 32-Core Processor
* 503GB RAM
* NVIDIA RTX A5000 (x8)

## Software versions

Everything is a moving feast. Currently using:

* [dust](https://github.com/mrc-ide/dust/) @ v0.9.10
* [odin.dust](https://github.com/mrc-ide/odin.dust/) @ v0.2.8
* [sircovid](https://github.com/mrc-ide/sircovid/) @ v0.11.24

## Benchmarks

* `bench_run.R`: run the carehomes model forward in time by one day (4 steps). This uses the least amount of shared memory, focusses essentially only on the run kernel. Run the script with the number of registers as an argument.

To benchmark on 96 registers

```
Rscript bench_run.R 96
```

To profile:

```
mkdir -p profile/run
DEVICE=G3090

ncu -o profile/run/$DEVICE-64-512-65536 \
  --kernel-id ::run_particles:2  --set full --target-processes all \
  Rscript profile_run.R --n-registers=64 --block-size=512 --n-particles=65536
ncu -o profile/run/$DEVICE-96-512-65536 \
  --kernel-id ::run_particles:2  --set full --target-processes all \
  Rscript profile_run.R --n-registers=96 --block-size=512 --n-particles=65536
ncu -o profile/run/$DEVICE-128-512-65536 \
  --kernel-id ::run_particles:2  --set full --target-processes all \
  Rscript profile_run.R --n-registers=128 --block-size=512 --n-particles=65536
ncu -o profile/run/$DEVICE-256-256-65536 \
  --kernel-id ::run_particles:2  --set full --target-processes all \
  Rscript profile_run.R --n-registers=256 --block-size=256 --n-particles=65536

ncu -o profile/run/$DEVICE-64-256-65536 \
  --kernel-id ::run_particles:2  --set full --target-processes all \
  Rscript profile_run.R --n-registers=64 --block-size=256 --n-particles=65536
ncu -o profile/run/$DEVICE-96-256-65536 \
  --kernel-id ::run_particles:2  --set full --target-processes all \
  Rscript profile_run.R --n-registers=96 --block-size=256 --n-particles=65536
ncu -o profile/run/$DEVICE-128-256-65536 \
  --kernel-id ::run_particles:2  --set full --target-processes all \
  Rscript profile_run.R --n-registers=128 --block-size=256 --n-particles=65536

nsys profile -o profile/data/$DEVICE-128-256-65536 \
  -c cudaProfilerApi --trace cuda,osrt,openmp \
  Rscript profile_data.R --n-registers=128 --block-size=256 --n-particles=65536
```
