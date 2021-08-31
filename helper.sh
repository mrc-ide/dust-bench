# -*-bash-*-
function dust_profile() {
  experiment=$1
  registers=$2
  block_size=$3
  particles=$4
  device=$(nvidia-smi --query-gpu=name --id=0 --format=csv,noheader |
    sed 's/ /-/g')
  mkdir -p profile/$experiment
  ncu -o profile/$experiment/$device-$registers-$block_size-$particles \
    --kernel-id ::run_particles:2 --set full --target-processes all \
    Rscript profile_$experiment.R \
    --n-registers=$registers --block-size=$block_size --n-particles=$particles
}
