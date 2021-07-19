source("R/common.R")

main <- function(args = commandArgs(TRUE)) {
  "Usage:
bench_run.R [options]

Options:
--n-registers=N  Number of registers
--n-particles=N  Number of particles
--block-size=N   Block size" -> usage
  opts <- docopt::docopt(usage, args)
  n_registers <- as.integer(opts$n_registers)
  n_particles <- as.integer(opts$n_particles)
  block_size <- as.integer(opts$block_size)

  do_run(n_registers, block_size, n_particles)
}


do_run <- function(n_registers, block_size, n_particles) {
  device_id <- 0L
  n_steps <- 4L
  gen <- carehomes_gpu(n_registers)
  mod <- carehomes_gpu_init(gen, block_size, n_particles, device_id)
  res <- mod$run(4, device = TRUE)
  end <- 4 + n_steps
  mod$run(4 + n_steps, device = TRUE)
}


if (!interactive()) {
  main()
}
