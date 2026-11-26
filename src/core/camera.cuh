#pragma once

#include <cmath>
#include <stdexcept>
#include <string>

#include "core/config.hpp"
#include "core/math.cuh"

namespace rt {

constexpr double kPi = 3.14159265358979323846;

struct Camera {
    Vec3 position;
    Vec3 forward;
    Vec3 right;
    Vec3 up;
    double half_width;
    double half_height;
};

__host__ __device__ inline double frame_time(int frame_index, int frame_count) {
    return 2.0 * kPi * frame_index / frame_count;
}

__host__ __device__ inline Vec3 motion_position(const MotionConfig &motion,
                                                double time) {
    const double radius =
        motion.radius +
        motion.radius_amplitude *
            ::sin(motion.radius_frequency * time + motion.radius_phase);
    const double height =
        motion.height +
        motion.height_amplitude *
            ::sin(motion.height_frequency * time + motion.height_phase);
    const double angle = motion.angle + motion.angle_frequency * time;

    return Vec3(radius * ::cos(angle), radius * ::sin(angle), height);
}

inline Camera make_camera(const ImageConfig &image,
                          const AnimationConfig &animation, int frame_index) {
    const double time = frame_time(frame_index, animation.frame_count);
    const Vec3 position = motion_position(animation.camera, time);
    const Vec3 target = motion_position(animation.target, time);
    const Vec3 view_direction = target - position;

    if (length_squared(view_direction) == 0.0) {
        throw std::invalid_argument(
            "Camera position and target coincide at frame " +
            std::to_string(frame_index));
    }

    const Vec3 forward = normalize(view_direction);

    Vec3 right = cross(forward, Vec3(0.0, 0.0, 1.0));

    // camera looks directly up or down
    // we take another axis for cross
    if (length_squared(right) < 1e-24) {
        right = cross(forward, Vec3(0.0, 1.0, 0.0));
    }

    right = normalize(right);
    const Vec3 up = normalize(cross(right, forward));
    const double half_width = ::tan(image.horizontal_fov * kPi / 360.0);
    const double half_height =
        half_width * static_cast<double>(image.height) / image.width;

    return {position, forward, right, up, half_width, half_height};
}

__host__ __device__ inline Ray sample_ray(const Camera &camera, double sample_x,
                                          double sample_y, int width,
                                          int height) {

    const double screen_x = (2.0 * sample_x / width - 1.0) * camera.half_width;

    const double screen_y =
        (1.0 - 2.0 * sample_y / height) * camera.half_height;

    const Vec3 direction = normalize(camera.forward + screen_x * camera.right +
                                     screen_y * camera.up);

    return Ray(camera.position, direction);
}

} // namespace rt
