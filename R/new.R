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
