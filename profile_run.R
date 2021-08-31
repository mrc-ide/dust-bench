source("R/new.R")

main <- function(args = commandArgs(TRUE)) {
  "Usage:
bench_run.R <model> [options]

Options:
--n-registers=N  Number of registers
--n-particles=N  Number of particles
--block-size=N   Block size" -> usage
  opts <- docopt::docopt(usage, args)
  model <- opts$model
  n_registers <- as.integer(opts$n_registers)
  n_particles <- as.integer(opts$n_particles)
  block_size <- as.integer(opts$block_size)

  do_run(model, n_registers, block_size, n_particles)
}


do_run <- function(model, n_registers, block_size, n_particles) {
  device_id <- 0L
  n_steps <- 4L
  message(sprintf("block_size: %d, n_particles: %d", block_size, n_particles))
  device_config <- list(device_id = device_id, run_block_size = block_size)
  gen <- model_gpu_create(model, n_registers)
  mod <- model_run_init(gen, n_particles, device_config)
  res <- mod$run(4, device = TRUE)
  end <- 4 + n_steps
  mod$run(4 + n_steps, device = TRUE)
  invisible()
}


if (!interactive()) {
  main()
}
