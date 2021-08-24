source("R/common.R")

main <- function(args = commandArgs(TRUE)) {
  "Usage:
bench_data.R [options]

Options:
--n-registers=N  Number of registers
--n-particles=N  Number of particles
--block-size=N   Block size" -> usage
  opts <- docopt::docopt(usage, args)
  n_registers <- as.integer(opts$n_registers)
  n_particles <- as.integer(opts$n_particles)
  block_size <- as.integer(opts$block_size)

  do_data(n_registers, block_size, n_particles)
}


do_data <- function(n_registers, block_size, n_particles) {
  device_id <- 0L
  n_steps <- 4L
  gen <- carehomes_gpu(n_registers, TRUE, 4L)

  dat <- readRDS("data/2021-07-31-london.rds")
  pars <- dat$pars
  steps_per_day <- pars$steps_per_day
  initial_step <- 1
  data <- mcstate::particle_filter_data(dat$data, "date", steps_per_day,
                                        initial_step)

  n_threads <- 10L
  seed <- 42L

  device_config <- list(device_id = device_id, run_block_size = block_size)

  pf <- mcstate::particle_filter$new(
    sircovid:::carehomes_particle_filter_data(data),
    gen,
    n_particles,
    compare = NULL,
    index = sircovid::carehomes_index,
    initial = sircovid::carehomes_initial,
    n_threads = n_threads,
    seed = seed,
    device_config = device_config)

  pf$run(pars)
}


if (!interactive()) {
  main()
}
