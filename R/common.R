find_library <- function() {
  pos <- dir("lib", full.names = TRUE)
  if (length(pos) > 0L) {
    lib <- max(pos)
    message(sprintf("Using library '%s'", lib))
    .libPaths(lib)
  }
}


build_library <- function(clean = FALSE) {
  lib <- sprintf("lib/%s", Sys.Date())
  if (clean) {
    unlink(lib, recursive = TRUE)
  }
  dir.create(lib, FALSE, TRUE)
  .libPaths(lib)
  install.packages(c("dust", "odin.dust", "sircovid", "docopt"),
                   repos = c(CRAN = "https://cloud.r-project.org",
                             ncov = "https://ncov-ic.github.io/drat/"))
  message(sprintf("Created library at '%s'", lib))
  invisible(lib)
}


model_gpu_create <- function(model, n_registers, clean = FALSE,
                             n_vacc_classes = 1L) {
  version <- paste0("v", packageVersion("sircovid"))
  workdir <- sprintf("src/%s-%s-%d-%s", model, version, n_vacc_classes,
                     n_registers)
  flags <- sprintf("--maxrregcount %s", n_registers)
  message("n_registers: ", n_registers)
  if (clean) {
    unlink(workdir, recursive = TRUE)
  }
  gpu <- dust::dust_cuda_options(flags = flags, fast_math = TRUE,
                                 profile = TRUE, quiet = FALSE,
                                 debug = FALSE)
  if (model == "basic") {
    subs <- list(n_age_groups = 17)
  } else {
    subs <- list(n_age_groups = 17, n_groups = 19,
                 n_vacc_classes = n_vacc_classes, n_strains = 1)
  }
  sircovid::compile_gpu(
    model,
    verbose = TRUE,
    real_t = "float",
    workdir = workdir,
    gpu = gpu,
    rewrite_constants = TRUE,
    substitutions = subs)
}


model_run_init <- function(generator, n_particles, device_config = NULL,
                           n_threads = 10L) {
  model <- generator$public_methods$name()
  date <- sircovid::sircovid_date("2020-02-07")
  if (model == "basic") {
    pars <- sircovid::basic_parameters(date, "england")
  } else {
    pars <- sircovid::carehomes_parameters(date, "england")
  }

  mod <- generator$new(pars, 0, n_particles, seed = 1L, n_threads = n_threads,
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


create_filter <- function(generator, n_particles, data_type = "small",
                          device_config = NULL, n_threads = 10L) {
  if (data_type == "real") {
    dat <- readRDS("data/2021-07-31-london.rds")
    pars <- dat$pars
    data <- dat$data
  } else {
    start_date <- sircovid::sircovid_date("2020-02-02")
    pars <- sircovid::carehomes_parameters(start_date, "england")
    path <- system.file("extdata/example.csv", package = "sircovid",
                        mustWork = TRUE)
    csv <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    data <- suppressMessages(
      sircovid:::carehomes_data(csv, start_date, pars$dt))
  }

  seed <- 42L

  filter <- mcstate::particle_filter$new(
    sircovid:::carehomes_particle_filter_data(data),
    generator,
    n_particles,
    compare = NULL,
    index = sircovid::carehomes_index,
    initial = sircovid::carehomes_initial,
    n_threads = n_threads,
    seed = seed,
    device_config = device_config)

  list(filter = filter, pars = pars)
}


cpuname <- function(clean) {
  dat <- jsonlite::fromJSON(system2("lscpu", "-J", stdout = TRUE))$lscpu
  model <- dat$data[dat$field == "Model name:"]
  if (clean) {
    model <- tolower(gsub(" +", "-", gsub("(\\(.+\\)|@)", "", model)))
  }
  model
}
