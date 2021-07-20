carehomes_gpu <- function(n_registers, clean = FALSE) {
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
  if (clean) {
    unlink(workdir, recursive = TRUE)
  }
  gpu <- dust::dust_cuda_options(flags = flags, fast_math = TRUE,
                                 profile = TRUE, quiet = FALSE)
  sircovid::compile_gpu(
    verbose = TRUE,
    real_t = "float",
    workdir = workdir,
    gpu = gpu,
    rewrite_constants = TRUE,
    substitutions = list(n_age_groups = 17, n_groups = 19,
                         n_vacc_classes = 1, n_strains = 1))
}


carehomes_init <- function(gen, block_size, n_particles, device_id = 0L,
                           n_threads = 10L) {
  p <- sircovid::carehomes_parameters(sircovid::sircovid_date("2020-02-07"),
                                      "england")
  if (is.null(block_size)) {
    message(sprintf("n_particles: %d, n_threads: %d", n_particles, n_threads))
    device <- NULL
  } else {
    message(sprintf("block_size: %d, n_particles: %d", block_size, n_particles))
    device <- list(device_id = device_id, run_block_size = block_size)
  }

  mod <- gen$new(p, 0, n_particles, seed = 1L, n_threads = n_threads,
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
  mod
}


basic_gpu <- function(n_registers, clean = FALSE) {
  version <- paste0("v", packageVersion("sircovid"))
  if (is.na(n_registers)) {
    workdir <- sprintf("src/%s-basic-unconstrained", version)
    flags <- NULL
    message("n_registers: 256 (unconstrained)")
    n_registers <- 256
  } else {
    workdir <- sprintf("src/%s-basic-%s", version, n_registers)
    flags <- sprintf("--maxrregcount %s", n_registers)
    message("n_registers: ", n_registers)
  }
  if (clean) {
    unlink(workdir, recursive = TRUE)
  }
  gpu <- dust::dust_cuda_options(flags = flags, fast_math = TRUE,
                                 profile = TRUE, quiet = FALSE)
  sircovid::compile_gpu(
    "basic",
    verbose = TRUE,
    real_t = "float",
    workdir = workdir,
    gpu = gpu,
    rewrite_constants = TRUE,
    substitutions = list(n_age_groups = 17))
}


basic_init <- function(gen, block_size, n_particles, device_id = 0L) {
  message(sprintf("block_size: %d, n_particles: %d", block_size, n_particles))
  p <- sircovid::basic_parameters(sircovid::sircovid_date("2020-02-07"),
                                  "england")
  device <- list(device_id = device_id, run_block_size = block_size)
  mod <- gen$new(p, 0, n_particles, seed = 1L, n_threads = 10L,
                 device_config = device)

  end <- sircovid::sircovid_date("2020-07-31") / p$dt
  info <- mod$info()
  initial <- sircovid::basic_initial(info, n_particles, p)
  mod$set_state(initial$state, 0)
  mod$set_index(sircovid::basic_index(info)$run)
  mod
}
