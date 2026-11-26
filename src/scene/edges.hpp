#pragma once

#include <array>
#include <cstddef>
#include <vector>

#include "core/config.hpp"
#include "scene/geometry.cuh"
#include "scene/mesh.hpp"

namespace rt {

inline std::vector<Cylinder>
make_edge_cylinders(const std::array<Mesh, 3> &meshes,
                    const SceneConfig &config) {
    std::vector<Cylinder> cylinders;
    Material edge_material{};
    edge_material.color = Vec3(0.04, 0.04, 0.05);
    edge_material.reflection = 0.15;
    edge_material.transparency = 0.0;

    for (std::size_t body_index = 0; body_index < meshes.size(); ++body_index) {
        const Mesh &mesh = meshes[body_index];
        const double radius =
            config.bodies[body_index].radius * kEdgeRadiusScale;

        for (const Edge &edge : mesh.edges) {
            cylinders.push_back(
                {mesh.vertices[static_cast<std::size_t>(edge.vertex0)],
                 mesh.vertices[static_cast<std::size_t>(edge.vertex1)], radius,
                 edge_material});
        }
    }

    return cylinders;
}

} // namespace rt
