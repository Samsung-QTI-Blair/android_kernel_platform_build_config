#!/bin/bash
# =============================================================================
# DDK external module build 
# The concept
#   - Modules with no cross-module symbol deps → Stage 1, single batch call
#     → modules_prepare runs ONCE for the whole batch
#   - Parallel (&) used between groups that have zero symbol dependency on each
#     other but can still share the modules_prepare output in OUT_DIR
#   - KBUILD_EXTRA_SYMBOLS consumers are gated on their producers completing first
# =============================================================================
set -e

cd ~/android/kernel_platform

export ANDROID_BUILD_TOP=~/android
export TARGET_BOARD_PLATFORM=blair
export CHIPSET_NAME=blair
export VARIANT=gki
export KERNEL_KIT=$ANDROID_BUILD_TOP/device/qcom/blair-kernel
export OUT_DIR=$ANDROID_BUILD_TOP/out/target/product/gta9pwifi/obj/DLKM_OBJ/kernel_platform
export ENABLE_DDK_BUILD=true
export ALLOW_UNSAFE_DDK_HEADERS=false
export SUBTARGET_REGEX='.*'
export EXTRA_DDK_ARGS=''

DLKM_BASE=$ANDROID_BUILD_TOP/out/target/product/gta9pwifi/obj/DLKM_OBJ/vendor/qcom/opensource

# Helper: run build_module.sh in a subshell, forwarding all env
bm() { ./build/build_module.sh BOARD_PLATFORM=blair "$@"; }

# ===========================================================================
# No cross-module symbol dependencies
# All modules are batched into a SINGLE build_module.sh call so that
# modules_prepare (make olddefconfig + make modules_prepare) runs exactly once
# ===========================================================================
EXT_MODULES="\
    ../vendor/qcom/opensource/securemsm-kernel \
    ../vendor/qcom/opensource/mmrm-driver \
    ../vendor/qcom/opensource/mm-drivers/msm_ext_display \
    ../vendor/qcom/opensource/mm-drivers/sync_fence \
    ../vendor/qcom/opensource/mm-drivers/hw_fence \
    ../vendor/qcom/opensource/dataipa/drivers/platform/msm \
    ../vendor/qcom/opensource/dsp-kernel \
    ../vendor/qcom/opensource/graphics-kernel \
" \
    bm

# ===========================================================================
# Depends on first stage outputs
# display and audio have no inter-dependency, so run concurrently
# video needs mmrm symvers
# datarmnet needs dataipa symvers
# ===========================================================================
EXT_MODULES="\
    ../vendor/qcom/opensource/display-drivers/msm \
" \
    bm CONFIG_DRM_MSM=m &
pid_display=$!

EXT_MODULES="\
    ../vendor/qcom/opensource/audio-kernel \
" \
    bm MODNAME=audio_dlkm &
pid_audio=$!

EXT_MODULES="\
    ../vendor/qcom/opensource/touch-drivers \
" \
    bm &
pid_touch=$!

EXT_MODULES="\
    ../vendor/qcom/opensource/video-driver \
" \
    KBUILD_EXTRA_SYMBOLS="$DLKM_BASE/mmrm-driver/Module.symvers" \
    bm &
pid_video=$!

EXT_MODULES="\
    ../vendor/qcom/opensource/datarmnet/core \
" \
    KBUILD_EXTRA_SYMBOLS="$DLKM_BASE/dataipa/drivers/platform/msm/Module.symvers" \
    bm &
pid_datarmnet=$!

# Wait for complete
wait $pid_display $pid_audio $pid_touch $pid_video $pid_datarmnet

# ===========================================================================
# Depends on previous stage
# camera has no external symver deps; bt needs audio + securemsm symvers
# datarmnet-ext submodules need datarmnet core symvers
# Batch the datarmnet-ext submodules that share only core symvers together
# ===========================================================================

EXT_MODULES="\
    ../vendor/qcom/opensource/camera-kernel \
" \
    bm MODNAME=camera &
pid_camera=$!

EXT_MODULES="\
    ../vendor/qcom/opensource/bt-kernel \
" \
    KO_DIRS="pwr/btpower.ko slimbus/bt_fm_slim.ko rtc6226/radio-i2c-rtc6226-qca.ko" \
    KBUILD_EXTRA_SYMBOLS="$DLKM_BASE/audio-kernel/Module.symvers \
        $DLKM_BASE/securemsm-kernel/Module.symvers" \
    bm &
pid_bt=$!

EXT_MODULES="\
    ../vendor/qcom/opensource/datarmnet-ext/offload \
    ../vendor/qcom/opensource/datarmnet-ext/perf_tether \
    ../vendor/qcom/opensource/datarmnet-ext/wlan \
" \
    KBUILD_EXTRA_SYMBOLS="$DLKM_BASE/datarmnet/core/Module.symvers" \
    bm &
pid_datarmnet_ext1=$!

# shs has to finish before perf (perf needs shs symvers)
EXT_MODULES="\
    ../vendor/qcom/opensource/datarmnet-ext/shs \
" \
    KBUILD_EXTRA_SYMBOLS="$DLKM_BASE/datarmnet/core/Module.symvers" \
    bm
# now perf can run
EXT_MODULES="\
    ../vendor/qcom/opensource/datarmnet-ext/perf \
" \
    KBUILD_EXTRA_SYMBOLS="$DLKM_BASE/datarmnet/core/Module.symvers \
        $DLKM_BASE/datarmnet-ext/shs/Module.symvers" \
    bm &
pid_datarmnet_perf=$!

# wait 
wait $pid_camera $pid_bt $pid_datarmnet_ext1 $pid_datarmnet_perf

# ===========================================================================
# WLAN stack 
# Depends on SECUREMSM only
# qcacld-3.0 needs wlan/platform symvers
# ===========================================================================

EXT_MODULES="../vendor/qcom/opensource/wlan/platform" \
    KBUILD_EXTRA_SYMBOLS="$DLKM_BASE/securemsm-kernel/Module.symvers" \
    bm

EXT_MODULES="../vendor/qcom/opensource/wlan/qcacld-3.0" \
    KBUILD_EXTRA_SYMBOLS="$DLKM_BASE/wlan/platform/Module.symvers" \
    bm MODNAME=wlan

echo ""
echo "DDK build complete."
