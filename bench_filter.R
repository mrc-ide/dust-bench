source("R/common.R")

timing1 <- function(gen, block_size, n_particles, device_id = 0L) {
  message(sprintf("block_size: %d, n_particles: %d", block_size, n_particles))
  path <- system.file("extdata/example.csv", package = "sircovid",
                      mustWork = TRUE)
  start_date <- sircovid::sircovid_date("2020-02-02")
  pars <- sircovid::carehomes_parameters(start_date, "england")
  suppressMessages(
    data <- sircovid:::carehomes_data(read_csv(path), start_date, pars$dt))
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


timing_cpu <- function() {
  start_date <- sircovid::sircovid_date("2020-02-02")
  p <- sircovid::carehomes_parameters(start_date, "england")
  path <- system.file("extdata/example.csv", package = "sircovid",
                      mustWork = TRUE)
  suppressMessages(
    data <- sircovid:::carehomes_data(read_csv(path), start_date, p$dt))

  timing1 <- function(n_particles, n_threads) {
    seed <- 42L
    pf <- mcstate::particle_filter$new(
      sircovid:::carehomes_particle_filter_data(data),
      sircovid::carehomes,
      n_particles,
      compare = NULL,
      index = sircovid::carehomes_index,
      initial = sircovid::carehomes_initial,
      n_threads = n_threads,
      seed = seed)
    system.time(pf$run(p))[["elapsed"]]
  }

  timing5 <- function(n_particles, n_threads) {
    median(replicate(5, timing1(n_particles, n_threads)))
  }

  n_threads <- unique(c(1L, 10L, parallel::detectCores() / 2))
  n_particles_per_thread <- 100L
  pars <- expand.grid(
    device = "cpu",
    n_threads = n_threads,
    n_particles_per_thread = n_particles_per_thread)
  pars$n_particles <- pars$n_threads * pars$n_particles_per_thread

  res <- Map(timing5,
             n_particles = pars$n_particles, n_threads = pars$n_threads)
  pars$time <- vapply(res, identity, numeric(1))
  pars
}


## Due to a limitation in dust's caching
main <- function(args = commandArgs(TRUE)) {
  "Usage:
bench_filter.R <n_registers>
bench_filter.R --cpu" -> usage
  opts <- docopt::docopt(usage, args)
  if (opts$cpu) {
    res <- timing_cpu()
    filename <- "bench/run/cpu.rds"
  } else {
    res <- timing(as.integer(opts$n_registers))
    device_str <- gsub(" ", "-", tolower(res$device[[1]]))
    filename <- sprintf("bench/filter/%s-%s.rds", device_str, opts$n_registers)
  }
  dir.create(dirname(filename), FALSE, TRUE)
  saveRDS(res, filename)
}

if (!interactive()) {
  main()
}
