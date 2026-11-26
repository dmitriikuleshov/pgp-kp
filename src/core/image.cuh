#pragma once

#include <cstdint>
#include <cstdio>
#include <vector>

#include "core/math.cuh"

namespace rt {

struct Pixel {
    std::uint8_t red;
    std::uint8_t green;
    std::uint8_t blue;
    std::uint8_t alpha;

    __host__ __device__ Pixel() : red(0), green(0), blue(0), alpha(255) {}

    __host__ __device__ Pixel(std::uint8_t red_value, std::uint8_t green_value,
                              std::uint8_t blue_value,
                              std::uint8_t alpha_value = 255)
        : red(red_value), green(green_value), blue(blue_value),
          alpha(alpha_value) {}
};

struct Image {
    int width;
    int height;
    std::vector<Pixel> pixels;
};

static_assert(sizeof(Pixel) == 4, "A pixel must occupy exactly four bytes");

__host__ __device__ inline std::uint8_t color_component(double value) {
    return static_cast<std::uint8_t>(255.0 * clamp(value, 0.0, 1.0) + 0.5);
}

__host__ __device__ inline Pixel color_to_pixel(const Vec3 &color) {
    return Pixel(color_component(color.x), color_component(color.y),
                 color_component(color.z));
}

__host__ __device__ inline Vec3 pixel_to_color(const Pixel &pixel) {
    constexpr double byte_to_unit = 1.0 / 255.0;
    return Vec3(pixel.red * byte_to_unit, pixel.green * byte_to_unit,
                pixel.blue * byte_to_unit);
}

inline bool read_image(const char *path, Image &image) {
    std::FILE *file = std::fopen(path, "rb");

    if (file == nullptr) {
        return false;
    }

    std::int32_t width = 0;
    std::int32_t height = 0;
    bool success = std::fread(&width, sizeof(width), 1, file) == 1 &&
                   std::fread(&height, sizeof(height), 1, file) == 1 &&
                   width > 0 && height > 0;

    if (success) {
        const std::size_t pixel_count =
            static_cast<std::size_t>(width) * height;
        image.width = width;
        image.height = height;
        image.pixels.resize(pixel_count);
        success = std::fread(image.pixels.data(), sizeof(Pixel), pixel_count,
                             file) == pixel_count;
    }

    if (std::fclose(file) != 0) {
        success = false;
    }

    return success;
}

inline bool write_image(const char *path, int width, int height,
                        const std::vector<Pixel> &pixels) {
    if (width <= 0 || height <= 0) {
        return false;
    }

    const std::size_t pixel_count =
        static_cast<std::size_t>(width) * static_cast<std::size_t>(height);

    if (pixels.size() != pixel_count) {
        return false;
    }

    std::FILE *file = std::fopen(path, "wb");

    if (file == nullptr) {
        return false;
    }

    const std::int32_t stored_width = width;
    const std::int32_t stored_height = height;

    bool success =
        std::fwrite(&stored_width, sizeof(stored_width), 1, file) == 1 &&
        std::fwrite(&stored_height, sizeof(stored_height), 1, file) == 1 &&
        std::fwrite(pixels.data(), sizeof(Pixel), pixel_count, file) ==
            pixel_count;

    if (std::fclose(file) != 0) {
        success = false;
    }

    return success;
}

} // namespace rt
