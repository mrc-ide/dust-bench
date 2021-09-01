read_data <- function(path) {
  files <- dir(path, full.names = TRUE)
  is_cpu <- grepl("^cpu", basename(files))

  read_files <- function(files) {
    ret <- do.call(rbind, lapply(files, readRDS))
    ret$time_rel <- ret$time / ret$n_particles * 1e6
    ret
  }

  dat_gpu <- read_files(files[!is_cpu])
  dat_cpu <- read_files(files[is_cpu])
  dat_cpu$label <- sprintf("%s: %d", dat_cpu$device, dat_cpu$n_threads)

  list(cpu = dat_cpu, gpu = dat_gpu)
}


make_plot <- function(dat) {
  ## Need a small data set here with the cpu information to work with
  ## the way that ggplot wants annotations
  cpu_label <- data.frame(block_size = 1024,
                          time_rel = dat$cpu$time_rel,
                          label = dat$cpu$label,
                          n_registers = 0)

  p_gpu <-
    ggplot(dat$gpu, aes(x = block_size, y = time_rel, group = n_registers)) +
    scale_y_continuous(trans = "log10") +
    scale_x_continuous(trans = "log2") +
    geom_line(aes(col = factor(n_registers))) +
    scale_colour_discrete(name = "Registers") +
    facet_grid(device ~ n_particles) +
    xlab("Block size") +
    ylab("Relative time (seconds per million particles)") +
    theme_bw()

  p_cpu <-
    p_gpu +
    geom_hline(yintercept = dat$cpu$time_rel,
               lwd = 0.5, col = "grey", lty = 2) +
    geom_text(aes(label = label), data = cpu_label,
              size = 2, hjust = 1, vjust = 1.5, col = "grey")

  list(gpu = p_gpu, cpu = p_cpu)
}


save_plots <- function(path) {
  dat <- read_data(path)
  base <- sub("/", "-", sub("bench/", "", path))
  plots <- make_plot(dat)
  ggsave(sprintf("figures/%s-gpu.png", base), plots$gpu, "png",
         scale = 4, width = 1000, height = 800, units = "px")
  ggsave(sprintf("figures/%s-cpu.png", base), plots$cpu, "png",
         scale = 4, width = 1000, height = 800, units = "px")
}
