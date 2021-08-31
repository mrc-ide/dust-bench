source("R/common.R")

main <- function(args = commandArgs(TRUE)) {
  "Usage:
bench_filter.R <data_type> [<n_registers>]" -> usage
  opts <- docopt::docopt(usage, args)

  data_type <- opts$data_type
  if (is.null(opts$n_registers)) {
    res <- timing_filter_cpu(data_type)
    filename <- sprintf("bench/filter/%s/cpu.rds", data_type)
  } else {
    res <- timing_filter_gpu(data_type, as.integer(opts$n_registers))
    device_str <- gsub(" ", "-", tolower(res$device[[1]]))
    filename <- sprintf("bench/filter/%s/%s-%s.rds",
                        data_type, device_str, opts$n_registers)
  }
  dir.create(dirname(filename), FALSE, TRUE)
  saveRDS(res, filename)
}


timing_filter_gpu <- function(data_type, n_registers) {
  n_vacc_classes <- if (data_type == "real") 4L else 1L
  gen <- model_gpu_create("carehomes", n_registers,
                          n_vacc_classes = n_vacc_classes)

  n_particles <- 2^(13:17)
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

  timing1 <- function(block_size, n_particles) {
    message(sprintf("block_size: %d, n_particles: %d", block_size, n_particles))
    device_config <- list(device_id = 0L, run_block_size = block_size)
    dat <- create_filter(gen, n_particles,
                         data_type = data_type,
                         device_config = device_config,
                         n_threads = 10)
    system.time(dat$filter$run(dat$pars))
    system.time(dat$filter$run(dat$pars))[["elapsed"]]
  }

  time <- Map(timing1, pars$block_size, pars$n_particles)
  pars$time <- vapply(time, identity, numeric(1))
  pars
}


timing_filter_cpu <- function(data_type) {
  timing1 <- function(n_particles, n_threads) {
    dat <- create_filter(sircovid::carehomes, n_particles,
                         data_type = data_type,
                         device_config = NULL,
                         n_threads = n_threads)
    system.time(dat$filter$run(dat$pars))[["elapsed"]]
  }

  timing5 <- function(n_particles, n_threads) {
    message(sprintf("n_particles: %d, n_threads: %d", n_particles, n_threads))
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


if (!interactive()) {
  find_library()
  main()
}
