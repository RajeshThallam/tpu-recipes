# Uncomment below to set the Huggingface token
# HF_TOKEN=hf_***
PJRT_DEVICE=TPU
XLA_IR_DEBUG=1
XLA_HLO_DEBUG=1
PROFILE_EPOCH=0
PROFILE_STEP=3
PROFILE_DURATION_MS=120000
XLA_USE_SPMD=1
MAX_STEPS=20
SEQ_LENGTH=4096

GLOBAL_BATCH_SIZE=2048

# XLA flags
LIBTPU_INIT_ARGS=--xla_tpu_enable_flash_attention=false --xla_tpu_enable_async_collective_fusion=true --xla_tpu_enable_async_collective_fusion_fuse_all_gather=true --xla_tpu_enable_async_collective_fusion_multiple_steps=true --xla_tpu_overlap_compute_collective_tc=true --xla_enable_async_all_gather=true --xla_tpu_scoped_vmem_limit_kib=81920