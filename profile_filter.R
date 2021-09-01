source("R/common.R")

main <- function(args = commandArgs(TRUE)) {
  "Usage:
bench_data.R <data_type> [options]

Options:
--n-registers=N  Number of registers
--n-particles=N  Number of particles
--block-size=N   Block size" -> usage
  opts <- docopt::docopt(usage, args)
  data_type <- opts$data_type
  n_registers <- as.integer(opts$n_registers)
  n_particles <- as.integer(opts$n_particles)
  block_size <- as.integer(opts$block_size)

  do_filter(data_type, n_registers, block_size, n_particles)
}


do_filter <- function(data_type, n_registers, block_size, n_particles) {
  n_vacc_classes <- if (data_type == "real") 4L else 1L
  gen <- model_gpu_create("carehomes", n_registers,
                          n_vacc_classes = n_vacc_classes)

  device_config <- list(device_id = 0L, run_block_size = block_size)
  dat <- create_filter(gen, n_particles,
                       data_type = data_type,
                       device_config = device_config,
                       n_threads = 10)

  dat$filter$run(dat$pars)
}


if (!interactive()) {
  find_library()
  main()
}
