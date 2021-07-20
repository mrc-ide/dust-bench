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

source("R/common.R")

timing1 <- function(gen, block_size, n_particles, n_steps, device_id = 0L) {
  mod <- carehomes_gpu_init(gen, block_size, n_particles, device_id)
  res <- mod$run(4, device = TRUE)
  end <- 4 + n_steps
  system.time(mod$run(end, device = TRUE))
}


timing <- function(n_registers) {
  gen <- carehomes_gpu(n_registers, TRUE)

  n_particles_1wave <- NULL # 52840
  n_particles <- c(2^(13:17), n_particles_1wave)

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
  filename <- sprintf("bench/run/%s-%s.rds", device_str, opts$n_registers)
  dir.create(dirname(filename), FALSE, TRUE)
  saveRDS(res, filename)
}

if (!interactive()) {
  main()
}

## 64:  ok to 1024 particles
## 96:  ok to 640 particles, then dies
## 128: fine to 512 (didn't test beyond)
## 256: fine to 256 (didn't test beyond)
