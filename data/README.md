# Data

This dataset was created from the public repo https://github.com/mrc-ide/sarscov2-roadmap-england on 2021-08-24 by running

```r
orderly::orderly_run("vaccine_fits_data")
orderly::orderly_develop_start(
  "vaccine_fits_regional",
  parameters = list(region = "london", assumptions = "central"),
  use_draft = TRUE)
```

then running `script.R` to where the particle filter was created, followed by

```r
inputs <- filter$inputs()
saveRDS(list(data = inputs$data, pars = pars$model(pars$initial())),
        "2021-07-31-london.rds")
```
