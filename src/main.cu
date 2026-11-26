#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <iostream>
#include <string>
#include <vector>

#include "core/config.hpp"
#include "core/image.cuh"
#include "renderer/cpu.hpp"
#include "renderer/gpu.cuh"
#include "scene/scene.hpp"

enum class ExecutionMode {
    Cpu,
    Gpu,
    PrintDefault,
};

void print_usage(const char *program_name) {
    std::fprintf(stderr, "Usage: %s [--cpu | --gpu | --default]\n",
                 program_name);
}

bool parse_execution_mode(int argc, char **argv, ExecutionMode *mode) {
    if (argc == 1) {
        *mode = ExecutionMode::Gpu;
        return true;
    }

    if (argc != 2) {
        std::fprintf(stderr, "Expected at most one command-line argument.\n");
        return false;
    }

    if (std::strcmp(argv[1], "--cpu") == 0) {
        *mode = ExecutionMode::Cpu;
        return true;
    }

    if (std::strcmp(argv[1], "--gpu") == 0) {
        *mode = ExecutionMode::Gpu;
        return true;
    }

    if (std::strcmp(argv[1], "--default") == 0) {
        *mode = ExecutionMode::PrintDefault;
        return true;
    }

    std::fprintf(stderr, "Unknown command-line argument: %s\n", argv[1]);
    return false;
}

bool read_floor_texture(const rt::FloorConfig &floor, rt::Image &texture) {
    std::string path = floor.texture_path;

    if (path.rfind("~/", 0) == 0) {
        const char *home = std::getenv("HOME");

        if (home != nullptr) {
            path = std::string(home) + path.substr(1);
        }
    }

    if (rt::read_image(path.c_str(), texture)) {
        return true;
    }

    std::fprintf(stderr, "Failed to read floor texture: %s\n", path.c_str());
    return false;
}

int run_cpu(const rt::RenderConfig &config) {
    const rt::SceneGeometry geometry = rt::make_scene_geometry(config.scene);
    rt::Image texture{};

    if (!read_floor_texture(config.scene.floor, texture)) {
        return 1;
    }

    for (int frame = 0; frame < config.animation.frame_count; ++frame) {
        const auto start = std::chrono::steady_clock::now();
        std::uint64_t ray_count = 0;
        const std::vector<rt::Pixel> pixels = rt::render_cpu_frame(
            config, geometry.triangles, geometry.cylinders,
            geometry.light_markers, geometry.lights, texture, frame, ray_count);
        const auto finish = std::chrono::steady_clock::now();
        const double milliseconds =
            std::chrono::duration<double, std::milli>(finish - start).count();
        const std::string path =
            rt::output_path(config.animation.output_path_pattern, frame);

        if (!rt::write_image(path.c_str(), config.image.width,
                             config.image.height, pixels)) {
            std::fprintf(stderr, "Failed to write image: %s\n", path.c_str());
            return 1;
        }

        std::printf("%d\t%.3f\t%llu\n", frame, milliseconds,
                    static_cast<unsigned long long>(ray_count));
        std::fflush(stdout);
        std::fprintf(stderr, "Wrote CPU frame: %s (%dx%d)\n", path.c_str(),
                     config.image.width, config.image.height);
    }

    return 0;
}

int run_gpu(const rt::RenderConfig &config) {
    const rt::SceneGeometry geometry = rt::make_scene_geometry(config.scene);
    rt::Image texture{};

    if (!read_floor_texture(config.scene.floor, texture)) {
        return 1;
    }

    for (int frame = 0; frame < config.animation.frame_count; ++frame) {
        const auto start = std::chrono::steady_clock::now();
        std::uint64_t ray_count = 0;
        const std::vector<rt::Pixel> pixels = rt::render_gpu_frame(
            config, geometry.triangles, geometry.cylinders,
            geometry.light_markers, geometry.lights, texture, frame, ray_count);
        const auto finish = std::chrono::steady_clock::now();
        const double milliseconds =
            std::chrono::duration<double, std::milli>(finish - start).count();
        const std::string path =
            rt::output_path(config.animation.output_path_pattern, frame);

        if (!rt::write_image(path.c_str(), config.image.width,
                             config.image.height, pixels)) {
            std::fprintf(stderr, "Failed to write image: %s\n", path.c_str());
            return 1;
        }

        std::printf("%d\t%.3f\t%llu\n", frame, milliseconds,
                    static_cast<unsigned long long>(ray_count));
        std::fflush(stdout);
        std::fprintf(stderr, "Wrote GPU frame: %s (%dx%d)\n", path.c_str(),
                     config.image.width, config.image.height);
    }

    return 0;
}

int main(int argc, char **argv) {
    ExecutionMode mode;

    if (!parse_execution_mode(argc, argv, &mode)) {
        print_usage(argv[0]);
        return 1;
    }

    if (mode == ExecutionMode::PrintDefault) {
        rt::print_config(std::cout, rt::default_config());
        return 0;
    }

    rt::RenderConfig config{};

    if (!rt::read_config(std::cin, config)) {
        std::fputs("Failed to read input configuration\n", stderr);
        return 1;
    }

    try {
        switch (mode) {
        case ExecutionMode::Cpu:
            return run_cpu(config);
        case ExecutionMode::Gpu:
            return run_gpu(config);
        case ExecutionMode::PrintDefault:
            break;
        }
    } catch (const std::exception &error) {
        std::fprintf(stderr, "%s\n", error.what());
        return 1;
    }

    std::fprintf(stderr, "Internal error: unsupported execution mode.\n");
    return 1;
}
