# -*-bash-*-
function dust_kernel_profile() {
    experiment=$1
    type=$2
    registers=$3
    block_size=$4
    particles=$5
    device=$(nvidia-smi --query-gpu=name --id=0 --format=csv,noheader |
                 sed 's/ /-/g')
    mkdir -p profile/$experiment
    ncu -o profile/$experiment/$device-$registers-$block_size-$particles \
        --kernel-id ::run_particles:2 --set full --target-processes all \
        Rscript profile_$experiment.R $type \
        --n-registers=$registers \
        --block-size=$block_size \
        --n-particles=$particles
}

function dust_system_profile() {
    experiment=$1
    type=$2
    registers=$3
    block_size=$4
    particles=$5
    device=$(nvidia-smi --query-gpu=name --id=0 --format=csv,noheader |
                 sed 's/ /-/g')
    mkdir -p profile/$experiment
    nsys profile \
         -o profile/$experiment/$device-$registers-$block_size-$particles \
         -c cudaProfilerApi --trace cuda,osrt,openmp \
        Rscript profile_$experiment.R $type \
        --n-registers=$registers \
        --block-size=$block_size \
        --n-particles=$particles
}
