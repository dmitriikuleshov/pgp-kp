#pragma once

#include <vector>

#include "core/config.hpp"
#include "scene/geometry.cuh"

namespace rt {

inline void append_floor_triangles(const FloorConfig &floor,
                                   std::vector<Triangle> &triangles) {
    const Material material = {floor.color, floor.reflection, 0.0};
    const Vec3 &a = floor.vertices[0];
    const Vec3 &b = floor.vertices[1];
    const Vec3 &c = floor.vertices[2];
    const Vec3 &d = floor.vertices[3];
    const Vec2 uv_a{0, 0};
    const Vec2 uv_b{0, 1};
    const Vec2 uv_c{1, 1};
    const Vec2 uv_d{1, 0};

    // floor is divided into two triangles
    // they are used to find hits with the floor
    triangles.push_back({a, b, c, material, uv_a, uv_b, uv_c, true});
    triangles.push_back({a, c, d, material, uv_a, uv_c, uv_d, true});
}

} // namespace rt
