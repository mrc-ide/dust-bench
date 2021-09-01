# dust benchmarks

Code for benchmarking and performance testing of dust with sircovid

## Hardware

3 different machines used:

Consumer

* Dual Xeon 6230 (40 cores @ 2.10GHZ)
* 754GB RAM
* GeForce RTX 3090

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

## Experiments

We have 4 experiments tested here, in two groups of two.

The "run" benchmarks run a model forward in time by one day (4 steps), which is the basic timescale that we run the model with. We do this for the `basic` model, which is an example of a nontrivial but tractable odin model, and for the `carehomes` model, which is a large model that is currently under development.

The "filter" benchmarks run the `carehomes` model in a particle filter either with a small example data set (covering a few weeks) or with a much longer time series covering ~18 months of the epidemic.  These greatly increase the shared memory requirement for the kernels.

## Benchmarks

The benchmarks times how long it takes to launch the kernel (or in the case of the filter a series of kernels) and get data back to R. This includes potentially a number of overheads in addition to the actual kernel run, but we can explore lots of combinations of block sizes and particles quickly. Results will be saved into `bench/<experiment>/<device>-<registers>.rds`.  The script takes the type of run and the number of registers to use as its arguments. For example to run the "run" benchmark with the carehomes model and 96 registers, run:

```
Rscript bench_run.R carehomes 96
```

or to run the filter benchmark with the small data set and 128 registers:

```
Rscript bench_filter.R small 128
```

<details>
<summary>All runs</summary>

```sh
Rscript bench_run.R basic
Rscript bench_run.R basic 64
Rscript bench_run.R basic 96
Rscript bench_run.R basic 128
Rscript bench_run.R basic 256

Rscript bench_run.R carehomes
Rscript bench_run.R carehomes 64
Rscript bench_run.R carehomes 96
Rscript bench_run.R carehomes 128
Rscript bench_run.R carehomes 256

Rscript bench_filter.R small
Rscript bench_filter.R small 64
Rscript bench_filter.R small 96
Rscript bench_filter.R small 128
Rscript bench_filter.R small 256

Rscript bench_filter.R real
Rscript bench_filter.R real 64
Rscript bench_filter.R real 96
Rscript bench_filter.R real 128
Rscript bench_filter.R real 256
```

</details>

## Profile

We use `ncu` to get detailed information back about the kernel. These run fairly quickly but if you run too many then they're annoying to organise.  We use a little helper bash function within `helpers.sh` to make running and storing these a little less tedious. This takes arguments `dust_kernel_profile <experiment> <type> <registers> <block_size> <particles>`

Where `experiment` is one of `run` or `filter` and `type` is one of either `basic`/`carehomes` or `small`/`real`.

For example, to profile the `run` experiment with the `carehomes` models with 96 registers, block size of 128 and 65536 (2^16) particles, run:

```
. helper.sh
dust_kernel_profile run carehomes 96 128 65536
```

<details>
<summary>All profiles</summary>

```sh
#                                 registers  block_size  particles
dust_kernel_profile run carehomes 64         512         65536
dust_kernel_profile run carehomes 96         512         65536
dust_kernel_profile run carehomes 128        512         65536

dust_kernel_profile run carehomes 64         256         65536
dust_kernel_profile run carehomes 96         256         65536
dust_kernel_profile run carehomes 128        256         65536
dust_kernel_profile run carehomes 256        256         65536
```

</details>

The system profile is less interesting here but can be run in the same way with `dust_system_profile`.

<details>
<summary>All profiles</summary>

```sh
#                                registers  block_size  particles
dust_system_profile filter small 96         128         65536
```

</details>

## Visualising benchmark results

Pull results back from the 3 servers

```
scp -r john:dust-bench/bench .
scp -r hpc-gpu-1:dust-bench/bench .
scp -r hpc-gpu-2:dust-bench/bench .
```

Create plots

```
Rscript create_plots.R
```

## Visualising profile results

```
scp -r -C john:dust-bench/profile .
scp -r -C hpc-gpu-1:dust-bench/profile .
scp -r -C hpc-gpu-2:dust-bench/profile .
```

If working within this repo, the profiles are gziped and need to be inflated before loading, run:

```
find profile -name '*.ncu-rep.gz' -exec gunzip -k {} \;
```

Then, open `/usr/local/NVIDIA-Nsight-Compute/ncu-ui` or wherever `ncu-ui` has been hidden as, and open up a set of profiles to compare.

For the system profiles, open `nsys-ui` (perhaps at `/opt/nvidia/nsight-systems/2021.2.1/bin/nsys-ui` or similar) and open the trace. These are less massive so are not compressed.
