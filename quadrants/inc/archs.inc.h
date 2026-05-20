// Potentially supported backends

// CPU archs
PER_ARCH(x64, 0)     // a.k.a. AMD64/x86_64
PER_ARCH(arm64, 1)   // a.k.a. Aarch64, WIP
PER_ARCH(js, 2)      // Javascript, N/A

// Arch value 3 was formerly python. Keep it reserved so serialized Arch
// values in cache keys/AOT artifacts fail closed instead of decoding as cuda.

// GPU archs
PER_ARCH(cuda, 4)    // NVIDIA CUDA
PER_ARCH(metal, 5)   // Apple Metal
PER_ARCH(opencl, 6)  // OpenCL, N/A
PER_ARCH(amdgpu, 7)  // AMD GPU
PER_ARCH(vulkan, 8)  // Vulkan
