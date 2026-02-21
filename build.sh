#!/bin/bash
# =============================================================================
# build script for Samsung GTA9PWiFi (Blair/P86803AA1)
# SM-X210 kernel platform build — external build
#
# For integrated Android builds, AndroidBoard.mk calls
# prepare_vendor.sh directly with the same environment
#
# =============================================================================
set -e

# Timmer
exec > >(tee build.log) 2>&1
START_TIME=$(date +%s)
echo "Build started at $(date)"

# -----------------------------------------------------------------------------
# Device & chipset 
# -----------------------------------------------------------------------------
MODEL=gta9pwifi
CHIPSET_NAME=P86803AA1
TARGET_BOARD_PLATFORM=blair
TARGET_BUILD_VARIANT=user

# ANDROID_BUILD_TOP: resolve from script location rather than
# relying on $(pwd) can call from any directory
ANDROID_BUILD_TOP="$(cd "$(dirname "$0")" && pwd)"
export ANDROID_BUILD_TOP

# MSM_ARCH required by build.config.msm.gki.sec — must match CHIPSET_NAME
export CHIPSET_NAME
export MSM_ARCH=${CHIPSET_NAME}
export TARGET_BOARD_PLATFORM
export TARGET_BUILD_VARIANT

# TARGET_PRODUCT here means the kernel variant (gki), NOT the Android
# lunch target. Only safe in this build context, never export
# into make
export TARGET_PRODUCT=gki

# -----------------------------------------------------------------------------
# Output directories
# -----------------------------------------------------------------------------
export ANDROID_PRODUCT_OUT=${ANDROID_BUILD_TOP}/out/target/product/${MODEL}
export OUT_DIR=${ANDROID_BUILD_TOP}/out/msm-kernel-${CHIPSET_NAME}-${TARGET_PRODUCT}

mkdir -p "${ANDROID_PRODUCT_OUT}"
mkdir -p "${OUT_DIR}"

echo "Build environment:"
echo "  MODEL:               ${MODEL}"
echo "  CHIPSET:             ${CHIPSET_NAME}"
echo "  TARGET_BUILD_VARIANT:${TARGET_BUILD_VARIANT}"
echo "  OUT_DIR:             ${OUT_DIR}"
echo "  ANDROID_PRODUCT_OUT: ${ANDROID_PRODUCT_OUT}"

# -----------------------------------------------------------------------------
# Techpack 
# Module.symvers paths consumed by KBUILD_EXTRA_SYMBOLS during
# external module compilation. These are generated during the build
# into DLKM_OBJ by techpack modules
# -----------------------------------------------------------------------------
DLKM_OBJ=${ANDROID_PRODUCT_OUT}/obj/DLKM_OBJ/kernel_platform/vendor/qcom/opensource

export KBUILD_EXTRA_SYMBOLS="\
${DLKM_OBJ}/mmrm-driver/Module.symvers \
${DLKM_OBJ}/mm-drivers/hw_fence/Module.symvers \
${DLKM_OBJ}/mm-drivers/sync_fence/Module.symvers \
${DLKM_OBJ}/mm-drivers/msm_ext_display/Module.symvers \
${DLKM_OBJ}/securemsm-kernel/Module.symvers"

export KBUILD_EXT_MODULES="\
../vendor/qcom/opensource/mm-drivers/msm_ext_display \
../vendor/qcom/opensource/mm-drivers/sync_fence \
../vendor/qcom/opensource/mm-drivers/hw_fence \
../vendor/qcom/opensource/mmrm-driver \
../vendor/qcom/opensource/securemsm-kernel \
../vendor/qcom/opensource/display-drivers/msm \
../vendor/qcom/opensource/audio-kernel \
../vendor/qcom/opensource/camera-kernel"

export MODNAME=audio_dlkm

export RECOMPILE_KERNEL=1

echo ""
echo "Invoking prepare_vendor.sh ${CHIPSET_NAME} ${TARGET_PRODUCT}..."
echo ""

"${ANDROID_BUILD_TOP}/kernel_platform/build/android/prepare_vendor.sh" \
    "${CHIPSET_NAME}" "${TARGET_PRODUCT}"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo ""
echo "Build finished at $(date)"
echo "Duration: $(( ELAPSED / 3600 ))h $(( (ELAPSED / 60) % 60 ))m $(( ELAPSED % 60 ))s"
