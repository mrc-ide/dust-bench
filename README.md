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

Versions are a moving feast. Currently using:

* [dust](https://github.com/mrc-ide/dust/) @ v0.9.15
* [odin](https://github.com/mrc-ide/odin/) @ v1.2.2
* [odin.dust](https://github.com/mrc-ide/odin.dust/) @ v0.2.10
* [sircovid](https://github.com/mrc-ide/sircovid/) @ v0.11.30

Installation into a blank library, which will be used in the scripts

```
source("R/common.R")
build_library()
```

## Benchmarks

We have 4 benchmarks tested here:

* "basic": run the sircovid `basic` model forward in time by one day (4 steps). This is the most basic version of any sircovid model, uses the least amount of shared memory, focusses only on the run kernel. This is to show the effect of a fairly complicated but still somewhat understandable kernel where hand-optimisation might be possible.
* "carehomes": run the sircovid carehomes model forward in time by one day (4 steps). This is the most basic version of the main sircovid model, and does not include vaccination or strains which are now used in production.
* "data"
* "filter"

We know that our timings are highly dependent on register usage, and changing that requires recompiling the model. So each script takes as an argument a number of registers and varies a set of additional parameters.  We use 64, 96, 128 and 256 registers in these experiments.

Each experiment has two components:

**Basic benchmarking**: `bench_<name>.R` (e.g., `bench_basic.R`).  This times how long it takes to launch the kernel and get data back to R. This includes potentially a number of overheads in addition to the actual kernel run, but we can explore lots of combinations of block sizes and particles quickly. Results will be saved into `bench/<experiment>/<device>-<registers>.rds` and can be read with a corresponding `read_<name>.R` script.  The script takes the number of registers to use as its only argument.  Run with, for example

```
Rscript bench_basic.R 96
```


* `profile_<name>.R` - profiling with `ncu` to get detailed information back about the kernel. You need to specify the number of registers, block size and number of particles here.  We use a small bash function to help with this, used as `dust_profile <experiment> <registers> <block_size> <particles>`

```bash
. helper.sh
dust_profile basic 64 512 65536
```




ncu -o profile/run/$DEVICE-64-512-65536 \
  --kernel-id ::run_particles:2  --set full --target-processes all \
  Rscript profile_carehomes.R \
  --n-registers=64 --block-size=512 --n-particles=65536
ncu -o profile/run/$DEVICE-64-512-65536 \
  --kernel-id ::run_particles:2  --set full --target-processes all \
  Rscript profile_carehomes.R \
  --n-registers=64 --block-size=512 --n-particles=65536
ncu -o profile/run/$DEVICE-64-512-65536 \
  --kernel-id ::run_particles:2  --set full --target-processes all \
  Rscript profile_carehomes.R \
  --n-registers=64 --block-size=512 --n-particles=65536
ncu -o profile/run/$DEVICE-64-512-65536 \
  --kernel-id ::run_particles:2  --set full --target-processes all \
  Rscript profile_carehomes.R \
  --n-registers=64 --block-size=512 --n-particles=65536
```



To benchmark on 96 registers


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
