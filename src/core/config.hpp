#pragma once

#include <array>
#include <iomanip>
#include <istream>
#include <ostream>
#include <string>

#include "core/math.cuh"

namespace rt {

constexpr int kMaximumTraceDepth = 16;

struct MotionConfig {
    // c - camera, n - target point.
    double radius;           // r_c0, r_n0
    double height;           // z_c0, z_n0
    double angle;            // φ_c0, φ_n0
    double radius_amplitude; // A_cr, A_nr
    double height_amplitude; // A_cz, A_nz
    double radius_frequency; // w_cr, w_nr
    double height_frequency; // w_cz, w_nz
    double angle_frequency;  // w_cφ, w_nφ
    double radius_phase;     // p_cr, p_nr
    double height_phase;     // p_cz, p_nz
};

enum BodyIndex { Tetrahedron, Cube, Icosahedron };

struct BodyConfig {
    Vec3 center;
    Vec3 color;
    double radius;
    double reflection;   // in [0, 1]
    double transparency; // in [0, 1]
    int lights_per_edge;
};

struct FloorConfig {
    std::array<Vec3, 4> vertices;
    std::string texture_path;
    Vec3 color;
    double reflection; // in [0, 1]
};

struct LightConfig {
    Vec3 position;
    Vec3 color; // normalized
    bool casts_shadow = true;
};

struct ImageConfig {
    int width;             // width > 0
    int height;            // height > 0
    double horizontal_fov; // 0 < fov < 180
};

struct AnimationConfig {
    int frame_count; // > 0
    std::string output_path_pattern;
    MotionConfig camera;
    MotionConfig target;
};

struct SceneConfig {
    std::array<BodyConfig, 3> bodies;
    FloorConfig floor;
    int light_count;                   // in [0, 4]
    std::array<LightConfig, 4> lights; // outer sources
};

struct TraceConfig {
    int max_depth; // in [0, 16]
    int ssaa_root; // > 0
};

struct RenderConfig {
    ImageConfig image;
    AnimationConfig animation;
    SceneConfig scene;
    TraceConfig trace;
};

inline bool read_vec3(std::istream &input, Vec3 &value) {
    return static_cast<bool>(input >> value.x >> value.y >> value.z);
}

inline bool read_motion(std::istream &input, MotionConfig &motion) {
    return static_cast<bool>(
        input >> motion.radius >> motion.height >> motion.angle >>
        motion.radius_amplitude >> motion.height_amplitude >>
        motion.radius_frequency >> motion.height_frequency >>
        motion.angle_frequency >> motion.radius_phase >> motion.height_phase);
}

inline bool read_body(std::istream &input, BodyConfig &body) {
    return read_vec3(input, body.center) && read_vec3(input, body.color) &&
           static_cast<bool>(input >> body.radius >> body.reflection >>
                             body.transparency >> body.lights_per_edge);
}

inline bool valid_color(const Vec3 &color) {
    return color.x >= 0.0 && color.x <= 1.0 && color.y >= 0.0 &&
           color.y <= 1.0 && color.z >= 0.0 && color.z <= 1.0;
}

inline bool valid_config(const RenderConfig &config) {
    if (config.animation.frame_count <= 0 || config.image.width <= 0 ||
        config.image.height <= 0 || config.image.horizontal_fov <= 0.0 ||
        config.image.horizontal_fov >= 180.0 ||
        config.animation.output_path_pattern.find("%d") == std::string::npos ||
        config.scene.light_count < 0 || config.scene.light_count > 4 ||
        config.trace.max_depth < 0 ||
        config.trace.max_depth > kMaximumTraceDepth ||
        config.trace.ssaa_root <= 0) {
        return false;
    }

    for (const BodyConfig &body : config.scene.bodies) {
        if (!valid_color(body.color) || body.radius <= 0.0 ||
            body.reflection < 0.0 || body.reflection > 1.0 ||
            body.transparency < 0.0 || body.transparency > 1.0 ||
            body.lights_per_edge < 0) {
            return false;
        }
    }

    if (!valid_color(config.scene.floor.color) ||
        config.scene.floor.reflection < 0.0 ||
        config.scene.floor.reflection > 1.0) {
        return false;
    }

    for (int index = 0; index < config.scene.light_count; ++index) {
        if (!valid_color(config.scene.lights[index].color)) {
            return false;
        }
    }

    return true;
}

inline bool read_config(std::istream &input, RenderConfig &config) {
    if (!(input >> config.animation.frame_count >>
          config.animation.output_path_pattern >> config.image.width >>
          config.image.height >> config.image.horizontal_fov) ||
        !read_motion(input, config.animation.camera) ||
        !read_motion(input, config.animation.target)) {
        return false;
    }

    for (BodyConfig &body : config.scene.bodies) {
        if (!read_body(input, body)) {
            return false;
        }
    }

    for (Vec3 &vertex : config.scene.floor.vertices) {
        if (!read_vec3(input, vertex)) {
            return false;
        }
    }

    if (!(input >> config.scene.floor.texture_path) ||
        !read_vec3(input, config.scene.floor.color) ||
        !(input >> config.scene.floor.reflection >> config.scene.light_count) ||
        config.scene.light_count < 0 || config.scene.light_count > 4) {
        return false;
    }

    for (int index = 0; index < config.scene.light_count; ++index) {
        if (!read_vec3(input, config.scene.lights[index].position) ||
            !read_vec3(input, config.scene.lights[index].color)) {
            return false;
        }
    }

    if (!(input >> config.trace.max_depth >> config.trace.ssaa_root)) {
        return false;
    }

    return valid_config(config);
}

inline void print_vec3(std::ostream &output, const Vec3 &value) {
    output << value.x << ' ' << value.y << ' ' << value.z << '\n';
}

inline void print_motion(std::ostream &output, const MotionConfig &motion) {
    output << motion.radius << ' ' << motion.height << ' ' << motion.angle
           << '\n';
    output << motion.radius_amplitude << ' ' << motion.height_amplitude << '\n';
    output << motion.radius_frequency << ' ' << motion.height_frequency << ' '
           << motion.angle_frequency << '\n';
    output << motion.radius_phase << ' ' << motion.height_phase << '\n';
}

inline void print_config(std::ostream &output, const RenderConfig &config) {
    output << std::setprecision(15);
    output << config.animation.frame_count << '\n';
    output << config.animation.output_path_pattern << '\n';
    output << config.image.width << ' ' << config.image.height << ' '
           << config.image.horizontal_fov << '\n';
    print_motion(output, config.animation.camera);
    print_motion(output, config.animation.target);

    for (const BodyConfig &body : config.scene.bodies) {
        output << body.center.x << ' ' << body.center.y << ' ' << body.center.z
               << ' ' << body.color.x << ' ' << body.color.y << ' '
               << body.color.z << ' ' << body.radius << ' ' << body.reflection
               << ' ' << body.transparency << ' ' << body.lights_per_edge
               << '\n';
    }

    for (const Vec3 &vertex : config.scene.floor.vertices) {
        print_vec3(output, vertex);
    }

    output << config.scene.floor.texture_path << '\n';
    print_vec3(output, config.scene.floor.color);
    output << config.scene.floor.reflection << '\n';
    output << config.scene.light_count << '\n';

    for (int index = 0; index < config.scene.light_count; ++index) {
        print_vec3(output, config.scene.lights[index].position);
        print_vec3(output, config.scene.lights[index].color);
    }

    output << config.trace.max_depth << ' ' << config.trace.ssaa_root << '\n';
}

// Scene appearance settings; rebuild after changing these values.
constexpr double kAmbientStrength = 0.05;       // Background illumination.
constexpr double kEdgeRadiusScale = 0.018;      // Edge radius / body radius.
constexpr double kEdgeLightRadiusScale = 0.032; // Lamp radius / body radius.
constexpr double kEdgeLightIntensity = 0.016;   // Light cast onto the scene.
constexpr double kMarkerWhiteMix = 0.1;         // White fraction, in [0, 1].
constexpr double kMarkerColorMix = 1.0 - kMarkerWhiteMix;
constexpr double kMarkerEmissionStrength = 1.2; // Visible lamp brightness.

inline RenderConfig default_config() {
    RenderConfig config{};
    config.animation.frame_count = 60;
    config.animation.output_path_pattern = "data/out/frame_%d.data";
    config.image.width = 960;
    config.image.height = 720;
    config.image.horizontal_fov = 50.0;

    auto &camera = config.animation.camera;
    camera.radius = 9.0;
    camera.height = 4.0;
    camera.angle = 0.1;
    camera.radius_amplitude = 0.35;
    camera.height_amplitude = 0.25;
    camera.radius_frequency = 1.0;
    camera.height_frequency = 2.0;
    camera.angle_frequency = 1.0;
    camera.radius_phase = 0.0;
    camera.height_phase = 0.0;

    auto &target = config.animation.target;
    target.radius = 0.0;
    target.height = -0.15;
    target.angle = 0.0;
    target.radius_amplitude = 0.0;
    target.height_amplitude = 0.0;
    target.radius_frequency = 1.0;
    target.height_frequency = 1.0;
    target.angle_frequency = 0.0;
    target.radius_phase = 0.0;
    target.height_phase = 0.0;

    auto &tetrahedron = config.scene.bodies[Tetrahedron];
    tetrahedron.center = Vec3(-0.7, -2.1, -0.3649147039);
    tetrahedron.color = Vec3(0.78, 0.42, 0.25);
    tetrahedron.radius = 1.1;
    tetrahedron.reflection = 0.58;
    tetrahedron.transparency = 0.34;
    tetrahedron.lights_per_edge = 3;

    auto &cube = config.scene.bodies[Cube];
    cube.center = Vec3(0.9, 0.0, -0.3649147039);
    cube.color = Vec3(0.35, 0.57, 0.65);
    cube.radius = 1.1;
    cube.reflection = 0.58;
    cube.transparency = 0.38;
    cube.lights_per_edge = 4;

    auto &icosahedron = config.scene.bodies[Icosahedron];
    icosahedron.center = Vec3(-0.65, 2.15, 0.02078097);
    icosahedron.color = Vec3(0.72, 0.65, 0.4);
    icosahedron.radius = 1.2;
    icosahedron.reflection = 0.62;
    icosahedron.transparency = 0.32;
    icosahedron.lights_per_edge = 3;

    config.scene.floor.vertices = {
        Vec3(-6, -6, -1),
        Vec3(-6, 6, -1),
        Vec3(6, 6, -1),
        Vec3(6, -6, -1),
    };
    config.scene.floor.texture_path = "data/textures/floor_stone_hex.data";
    config.scene.floor.color = Vec3(0.95, 0.95, 0.95);
    config.scene.floor.reflection = 0.28;

    config.scene.light_count = 3;
    config.scene.lights[0] = {Vec3(3.0, -4.0, 5.0), Vec3(1.0, 0.92, 0.8)};
    config.scene.lights[1] = {Vec3(-3.0, 2.0, 4.0), Vec3(0.35, 0.42, 0.55)};
    config.scene.lights[2] = {Vec3(-2.0, 0.0, 6.0), Vec3(0.45, 0.5, 0.6)};
    config.trace.max_depth = 10;
    config.trace.ssaa_root = 3;
    return config;
}

inline std::string output_path(const std::string &pattern, int frame_number) {
    std::string result = pattern;
    const std::size_t position = result.find("%d");
    result.replace(position, 2, std::to_string(frame_number));
    return result;
}

} // namespace rt
