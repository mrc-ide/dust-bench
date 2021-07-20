files <- dir("bench/run", "-[0-9]+\\.rds$", full.names = TRUE)
dat <- do.call(rbind, lapply(files, readRDS))
dat$time_rel <- dat$time / dat$n_particles * 1e6

## Our cpu comparison:
cpu <- readRDS("bench/run/cpu-i9.rds")
cpu <- readRDS("bench/run/cpu-xeon-6230.rds")
cpu <- readRDS("bench/run/cpu-amd-6230.rds")
cpu$time_rel <- cpu$time / cpu$n_particles * 1e6

library(ggplot2)

ggplot(dat, aes(x = block_size, y = 1 / time_rel, group = n_registers)) +
  scale_y_continuous(trans = "log10") +
  scale_x_continuous(trans = "log2") +
  geom_line(aes(col = factor(n_registers))) +
  facet_grid(device ~ n_particles)
