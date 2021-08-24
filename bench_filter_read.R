files <- dir("bench/filter", "\\.rds$", full.names = TRUE)
files <- files[!grepl("^cpu-", basename(files))]

dat <- do.call(rbind, lapply(files, readRDS))

## What we care about is the performance *per particle*
dat$time_rel <- dat$time / dat$n_particles * 1e6

library(ggplot2)

ggplot(dat, aes(x = block_size, y = time_rel, group = n_registers)) +
  scale_y_continuous(trans = "log10") +
  scale_x_continuous(trans = "log2") +
  geom_line(aes(col = factor(n_registers))) +
  facet_grid(device ~ n_particles)

cpu <- readRDS("bench/filter/cpu-xeon-6230.rds")
cpu$time_rel <- cpu$time / cpu$n_particles * 1e6
