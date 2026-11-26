#pragma once

#include <cstdint>
#include <vector>

#include "core/camera.cuh"
#include "core/config.hpp"
#include "core/image.cuh"
#include "core/math.cuh"
#include "renderer/common.cuh"
#include "scene/geometry.cuh"

namespace rt {

inline std::vector<Pixel> render_cpu_frame(
    const RenderConfig &config, const std::vector<Triangle> &triangles,
    const std::vector<Cylinder> &cylinders, const std::vector<Sphere> &spheres,
    const std::vector<LightConfig> &lights, const Image &texture,
    int frame_index, std::uint64_t &ray_count) {
    const Camera camera =
        make_camera(config.image, config.animation, frame_index);
    const SceneView scene{
        triangles.data(), static_cast<int>(triangles.size()),
        cylinders.data(), static_cast<int>(cylinders.size()),
        spheres.data(),   static_cast<int>(spheres.size()),
        lights.data(),    static_cast<int>(lights.size()),
    };
    const TextureView texture_view{
        texture.pixels.data(),
        texture.width,
        texture.height,
    };
    std::vector<Pixel> pixels(static_cast<std::size_t>(config.image.width) *
                              config.image.height);
    ray_count = 0;

    for (int y = 0; y < config.image.height; ++y) {
        for (int x = 0; x < config.image.width; ++x) {
            Vec3 color{};
            std::uint64_t pixel_ray_count = 0;

            for (int sample_y = 0; sample_y < config.trace.ssaa_root;
                 ++sample_y) {
                for (int sample_x = 0; sample_x < config.trace.ssaa_root;
                     ++sample_x) {
                    const double offset_x =
                        (sample_x + 0.5) / config.trace.ssaa_root;
                    const double offset_y =
                        (sample_y + 0.5) / config.trace.ssaa_root;
                    const Ray ray =
                        sample_ray(camera, x + offset_x, y + offset_y,
                                   config.image.width, config.image.height);
                    std::uint64_t sample_ray_count = 0;
                    color +=
                        trace_ray(ray, scene, texture_view,
                                  config.trace.max_depth, sample_ray_count);
                    pixel_ray_count += sample_ray_count;
                }
            }

            color /= static_cast<double>(config.trace.ssaa_root) *
                     config.trace.ssaa_root;
            ray_count += pixel_ray_count;
            pixels[y * config.image.width + x] = color_to_pixel(color);
        }
    }

    return pixels;
}

} // namespace rt
