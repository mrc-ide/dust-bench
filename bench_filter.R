source("R/common.R")

timing1 <- function(gen, block_size, n_particles, device_id = 0L) {
  path <- system.file("extdata/example.csv", package = "sircovid",
                      mustWork = TRUE)
  start_date <- sircovid::sircovid_date("2020-02-02")
  pars <- sircovid::carehomes_parameters(start_date, "england")
  data <- sircovid:::carehomes_data(read_csv(path), start_date, pars$dt)
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

  ## In order to make this nicer for the gpu, it would be nicer to
  ## sync the device first. We will however, pay this cost once
  ## anyway, but this timing likely overstates it a bit. Better might
  ## be to run it twice?
  system.time(pf$run(pars))
}


timing <- function(n_registers) {
  gen <- carehomes_gpu(n_registers, TRUE)

  n_particles <- 2^(13:17)
  n_particles <- 2^13

  if (n_registers == 96) {
    block_size <- seq(32, 640, by = 32)
  } else {
    block_size <- seq(32, 65536 / n_registers, by = 32)
  }

  device <- gen$public_methods$device_info()$devices$name[[1]]
  pars <- expand.grid(device = device,
                      n_registers = n_registers,
                      block_size = block_size,
                      n_particles = n_particles,
                      stringsAsFactors = FALSE)
  time <- Map(timing1,
              list(gen), pars$block_size, pars$n_particles)
  pars$time <- vapply(time, "[[", numeric(1), "elapsed")
  pars
}


if (FALSE) {
  source("bench_filter.R")
  gen <- carehomes_gpu(96, TRUE)
  timing1(gen, 32, 2^13)
}
