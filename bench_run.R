## Benchmark running model over a short window of time
##
## * no time varying parameters
## * no particle filter
##
## To vary:
##
## * device
## * number of registers
## * block size
## * number of particles
## * number of steps
timing1 <- function(gen, block_size, n_particles, n_steps, device_id = 0L) {
  message(sprintf("block_size: %d, n_particles: %d, n_steps: %d",
                  block_size, n_particles, n_steps))
  p <- sircovid::carehomes_parameters(sircovid::sircovid_date("2020-02-07"),
                                      "england")
  device <- list(device_id = device_id, run_block_size = block_size)
  mod <- gen$new(p, 0, n_particles, seed = 1L, n_threads = 10L,
                   device_config = device)

  end <- sircovid::sircovid_date("2020-07-31") / p$dt
  info <- mod$info()
  initial <- sircovid::carehomes_initial(info, n_particles, p)
  mod$set_state(initial$state, 0)
  index <- c(sircovid::carehomes_index(info)$run,
             deaths_carehomes = info$index[["D_carehomes_tot"]],
             deaths_comm = info$index[["D_comm_tot"]],
             deaths_hosp = info$index[["D_hosp_tot"]],
             admitted = info$index[["cum_admit_conf"]],
             diagnoses = info$index[["cum_new_conf"]],
             sympt_cases = info$index[["cum_sympt_cases"]],
             sympt_cases_over25 = info$index[["cum_sympt_cases_over25"]])
  mod$set_index(index)
  res <- mod$run(4, device = TRUE)
  end <- 4 + n_steps
  system.time(mod$run(end, device = TRUE))
}


timing <- function(n_registers) {
  version <- paste0("v", packageVersion("sircovid"))
  if (is.na(n_registers)) {
    workdir <- sprintf("src/%s-unconstrained", version)
    flags <- NULL
    message("n_registers: 256 (unconstrained)")
    n_registers <- 256
  } else {
    workdir <- sprintf("src/%s-%s", version, n_registers)
    flags <- sprintf("--maxrregcount %s", n_registers)
    message("n_registers: ", n_registers)
  }
  unlink(workdir, recursive = TRUE)
  gpu <- dust::dust_cuda_options(flags = flags, fast_math = TRUE, quiet = FALSE)
  gen <- sircovid::compile_gpu(
    verbose = TRUE,
    real_t = "float",
    workdir = workdir,
    gpu = gpu,
    rewrite_constants = TRUE,
    substitutions = list(n_age_groups = 17, n_groups = 19,
                         n_vacc_classes = 1, n_strains = 1))

  n_particles_1wave <- NULL # 52840
  n_particles <- c(2^(13:17), n_particles_1wave)

  if (n_registers == 96) {
    block_size <- seq(32, 640, by = 32)
  } else {
    block_size <- seq(32, 65536 / n_registers, by = 32)
  }
  n_steps <- 4

  pars <- expand.grid(device = gpu$devices$name[[1]],
                      n_registers = n_registers,
                      block_size = block_size,
                      n_particles = n_particles,
                      n_steps = n_steps,
                      stringsAsFactors = FALSE)
  time <- Map(timing1,
              list(gen), pars$block_size, pars$n_particles, pars$n_steps)
  pars$time <- vapply(time, "[[", numeric(1), "elapsed")
  pars
}


## Due to a limitation in dust's caching
main <- function(args = commandArgs(TRUE)) {
  "Usage:
bench_run.R <n_registers>" -> usage
  opts <- docopt::docopt(usage, args)
  res <- timing(as.integer(opts$n_registers))
  device_str <- gsub(" ", "-", tolower(res$device[[1]]))
  filename <- sprintf("run/%s-%s.rds", device_str, opts$n_registers)
  dir.create(dirname(filename), FALSE, TRUE)
  saveRDS(res, filename)
}

if (!interactive()) {
  main()
}
