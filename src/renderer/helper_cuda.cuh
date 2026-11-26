#pragma once

#include <cuda_runtime.h>

#include <cstdio>
#include <cstdlib>

#define checkCudaErrors(call)                                                  \
    do {                                                                       \
        const cudaError_t result = (call);                                     \
        if (result != cudaSuccess) {                                           \
            std::fprintf(stderr, "CUDA error in %s:%d: %s\n", __FILE__,        \
                         __LINE__, cudaGetErrorString(result));                \
            std::exit(EXIT_FAILURE);                                           \
        }                                                                      \
    } while (false)
