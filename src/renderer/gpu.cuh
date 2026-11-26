#pragma once

#include <cuda_runtime.h>

#include <cstdint>
#include <vector>

#include "core/camera.cuh"
#include "core/config.hpp"
#include "core/image.cuh"
#include "renderer/common.cuh"
#include "renderer/helper_cuda.cuh"
#include "scene/geometry.cuh"

namespace rt {

__global__ void render_kernel(Camera camera, int width, int height,
                              SceneView scene, TextureView texture,
                              int maximum_depth, int ssaa_root, Pixel *pixels,
                              unsigned long long *ray_count) {
    const int x = blockIdx.x * blockDim.x + threadIdx.x;
    const int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height) {
        return;
    }

    Vec3 color{};
    std::uint64_t pixel_ray_count = 0;

    // one thread processes one pixel (multiple rays for ssaa)
    for (int sample_y = 0; sample_y < ssaa_root; ++sample_y) {
        for (int sample_x = 0; sample_x < ssaa_root; ++sample_x) {
            const double offset_x = (sample_x + 0.5) / ssaa_root;
            const double offset_y = (sample_y + 0.5) / ssaa_root;
            const Ray ray =
                sample_ray(camera, x + offset_x, y + offset_y, width, height);
            std::uint64_t sample_ray_count = 0;
            color +=
                trace_ray(ray, scene, texture, maximum_depth, sample_ray_count);
            pixel_ray_count += sample_ray_count;
        }
    }

    color /= static_cast<double>(ssaa_root) * ssaa_root;
    pixels[y * width + x] = color_to_pixel(color);
    atomicAdd(ray_count, static_cast<unsigned long long>(pixel_ray_count));
}

inline std::vector<Pixel> render_gpu_frame(
    const RenderConfig &config, const std::vector<Triangle> &triangles,
    const std::vector<Cylinder> &cylinders, const std::vector<Sphere> &spheres,
    const std::vector<LightConfig> &lights, const Image &texture,
    int frame_index, std::uint64_t &ray_count) {
    const Camera camera =
        make_camera(config.image, config.animation, frame_index);
    const std::size_t pixel_count =
        static_cast<std::size_t>(config.image.width) * config.image.height;
    const std::size_t triangle_bytes = triangles.size() * sizeof(Triangle);
    const std::size_t cylinder_bytes = cylinders.size() * sizeof(Cylinder);
    const std::size_t sphere_bytes = spheres.size() * sizeof(Sphere);
    const std::size_t light_bytes = lights.size() * sizeof(LightConfig);
    const std::size_t pixel_bytes = pixel_count * sizeof(Pixel);
    const std::size_t texture_bytes = texture.pixels.size() * sizeof(Pixel);

    Triangle *device_triangles = nullptr;
    Cylinder *device_cylinders = nullptr;
    Sphere *device_spheres = nullptr;
    LightConfig *device_lights = nullptr;
    Pixel *device_texture = nullptr;
    Pixel *device_pixels = nullptr;
    unsigned long long *device_ray_count = nullptr;

    checkCudaErrors(cudaMalloc(&device_triangles, triangle_bytes));
    checkCudaErrors(cudaMalloc(&device_cylinders, cylinder_bytes));
    checkCudaErrors(cudaMalloc(&device_texture, texture_bytes));
    checkCudaErrors(cudaMalloc(&device_pixels, pixel_bytes));
    checkCudaErrors(cudaMalloc(&device_ray_count, sizeof(*device_ray_count)));
    checkCudaErrors(cudaMemset(device_ray_count, 0, sizeof(*device_ray_count)));

    if (!spheres.empty()) {
        checkCudaErrors(cudaMalloc(&device_spheres, sphere_bytes));
    }

    if (!lights.empty()) {
        checkCudaErrors(cudaMalloc(&device_lights, light_bytes));
    }

    checkCudaErrors(cudaMemcpy(device_triangles, triangles.data(),
                               triangle_bytes, cudaMemcpyHostToDevice));
    checkCudaErrors(cudaMemcpy(device_cylinders, cylinders.data(),
                               cylinder_bytes, cudaMemcpyHostToDevice));
    if (!spheres.empty()) {
        checkCudaErrors(cudaMemcpy(device_spheres, spheres.data(), sphere_bytes,
                                   cudaMemcpyHostToDevice));
    }
    checkCudaErrors(cudaMemcpy(device_texture, texture.pixels.data(),
                               texture_bytes, cudaMemcpyHostToDevice));

    if (!lights.empty()) {
        checkCudaErrors(cudaMemcpy(device_lights, lights.data(), light_bytes,
                                   cudaMemcpyHostToDevice));
    }

    const SceneView scene{
        device_triangles, static_cast<int>(triangles.size()),
        device_cylinders, static_cast<int>(cylinders.size()),
        device_spheres,   static_cast<int>(spheres.size()),
        device_lights,    static_cast<int>(lights.size()),
    };
    const TextureView texture_view{
        device_texture,
        texture.width,
        texture.height,
    };
    constexpr int block_width = 16;
    constexpr int block_height = 16;
    const dim3 block(block_width, block_height);
    const dim3 grid((config.image.width + block_width - 1) / block_width,
                    (config.image.height + block_height - 1) / block_height);

    render_kernel<<<grid, block>>>(
        camera, config.image.width, config.image.height, scene, texture_view,
        config.trace.max_depth, config.trace.ssaa_root, device_pixels,
        device_ray_count);

    checkCudaErrors(cudaGetLastError());
    checkCudaErrors(cudaDeviceSynchronize());

    std::vector<Pixel> pixels(pixel_count);
    checkCudaErrors(cudaMemcpy(pixels.data(), device_pixels, pixel_bytes,
                               cudaMemcpyDeviceToHost));
    unsigned long long total_ray_count = 0;
    checkCudaErrors(cudaMemcpy(&total_ray_count, device_ray_count,
                               sizeof(total_ray_count),
                               cudaMemcpyDeviceToHost));
    ray_count = static_cast<std::uint64_t>(total_ray_count);

    checkCudaErrors(cudaFree(device_triangles));
    checkCudaErrors(cudaFree(device_cylinders));

    if (device_spheres != nullptr) {
        checkCudaErrors(cudaFree(device_spheres));
    }

    if (device_lights != nullptr) {
        checkCudaErrors(cudaFree(device_lights));
    }

    checkCudaErrors(cudaFree(device_texture));
    checkCudaErrors(cudaFree(device_pixels));
    checkCudaErrors(cudaFree(device_ray_count));
    return pixels;
}

} // namespace rt
