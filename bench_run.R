source("R/new.R")

main <- function(args = commandArgs(TRUE)) {
  "Usage:
bench_run.R <model> [<n_registers>]" -> usage
  opts <- docopt::docopt(usage, args)
  model <- args$model
  if (is.null(opts$n_registers)) {
    res <- timing_run_cpu(model)
    filename <- sprintf("bench/%s/cpu.rds", model)
  } else {
    n_registers <- as.integer(opts$n_registers)
    res <- timing_run_gpu(model, n_registers)
    device_str <- gsub(" ", "-", tolower(res$device[[1]]))
    filename <- sprintf("bench/%s/%s-%d.rds", model, device_str, n_registers)
  }
  dir.create(dirname(filename), FALSE, TRUE)
  saveRDS(res, filename)
}


timing_run_gpu <- function(model, n_registers) {
  gen <- model_gpu_create(model, n_registers, TRUE)

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

  timing1 <- function(block_size, n_particles, n_steps, device_id = 0L) {
    message(sprintf("block_size: %d, n_particles: %d", block_size, n_particles))
    device_config <- list(device_id = device_id, run_block_size = block_size)
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


model_run_init <- function(gen, n_particles, device_config = NULL,
                           n_threads = 10L) {
  model <- gen$public_methods$name()
  date <- sircovid::sircovid_date("2020-02-07")
  if (model == "basic") {
    pars <- sircovid::basic_parameters(date, "england")
  } else {
    pars <- sircovid::carehomes_parameters(date, "england")
  }

  mod <- gen$new(pars, 0, n_particles, seed = 1L, n_threads = n_threads,
                 device_config = device_config)

  info <- mod$info()

  if (model == "basic") {
    initial <- sircovid::basic_initial(info, n_particles, pars)
    index <- sircovid::basic_index(info)$run
  } else {
    initial <- sircovid::carehomes_initial(info, n_particles, pars)
    index <- c(sircovid::carehomes_index(info)$run,
               deaths_carehomes = info$index[["D_carehomes_tot"]],
               deaths_comm = info$index[["D_comm_tot"]],
               deaths_hosp = info$index[["D_hosp_tot"]],
               admitted = info$index[["cum_admit_conf"]],
               diagnoses = info$index[["cum_new_conf"]],
               sympt_cases = info$index[["cum_sympt_cases"]],
               sympt_cases_over25 = info$index[["cum_sympt_cases_over25"]])
  }

  mod$set_state(initial$state, 0)
  mod$set_index(index)
  mod
}


if (!interactive()) {
  main()
}
