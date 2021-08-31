source("R/common.R")

main <- function(args = commandArgs(TRUE)) {
  "Usage:
bench_run.R <model> [<n_registers>]" -> usage
  opts <- docopt::docopt(usage, args)
  model <- opts$model
  if (is.null(opts$n_registers)) {
    res <- timing_run_cpu(model)
    filename <- sprintf("bench/run/%s/cpu.rds", model)
  } else {
    n_registers <- as.integer(opts$n_registers)
    res <- timing_run_gpu(model, n_registers)
    device_str <- gsub(" ", "-", tolower(res$device[[1]]))
    filename <- sprintf("bench/run/%s/%s-%d.rds",
                        model, device_str, n_registers)
  }
  dir.create(dirname(filename), FALSE, TRUE)
  saveRDS(res, filename)
}


timing_run_gpu <- function(model, n_registers) {
  gen <- model_gpu_create(model, n_registers)

  n_particles <- 2^(13:17)

  if (n_registers == 96) {
    block_size <- seq(32, 640, by = 32)
  } else {
    block_size <- seq(32, 65536 / n_registers, by = 32)
  }
  n_steps <- 4

  device <- gen$public_methods$device_info()$devices$name[[1]]
  pars <- expand.grid(device = device,
                      n_registers = n_registers,
                      block_size = block_size,
                      n_particles = n_particles,
                      n_steps = n_steps,
                      stringsAsFactors = FALSE)

  timing1 <- function(block_size, n_particles, n_steps) {
    message(sprintf("block_size: %d, n_particles: %d", block_size, n_particles))
    device_config <- list(device_id = 0L, run_block_size = block_size)
    mod <- model_run_init(gen, n_particles, device_config)
    res <- mod$run(4, device = TRUE) # burn-in step
    system.time(mod$run(4 + n_steps, device = TRUE))[["elapsed"]]
  }

  time <- Map(timing1, pars$block_size, pars$n_particles, pars$n_steps)
  pars$time <- vapply(time, identity, numeric(1))
  pars
}


timing_run_cpu <- function(model) {
  gen <- switch(model,
                basic = sircovid::basic,
                carehomes = sircovid::carehomes,
                stop(sprintf("Unknown model '%s'", model)))

  timing1 <- function(n_particles, n_threads) {
    mod <- model_run_init(gen, n_particles, NULL, n_threads)
    res <- mod$run(4)
    n_steps <- 4L
    end <- 4 + n_steps
    system.time(mod$run(end))[["elapsed"]]
  }

  timing5 <- function(n_particles, n_threads) {
    message(sprintf("n_particles: %d, n_threads: %d", n_particles, n_threads))
    median(replicate(5, timing1(n_particles, n_threads)))
  }

  n_threads <- unique(c(1L, 10L, parallel::detectCores() / 2))
  n_particles_per_thread <- 500L
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
