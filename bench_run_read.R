files <- dir("run", full.names = TRUE)
dat <- do.call(rbind, lapply(files, readRDS))

## What we care about is the performance *per particle*

dat$time_rel <- dat$time / dat$n_particles * 1e6

library(ggplot2)

ggplot(dat, aes(x = block_size, y = time_rel, group = n_registers)) +
  scale_y_continuous(trans = "log10") +
  geom_line(aes(col = factor(n_registers))) +
  geom_point() +
  facet_grid(device ~ n_particles)
