#pragma once

#include <array>
#include <cstddef>
#include <vector>

#include "core/config.hpp"
#include "core/math.cuh"
#include "scene/geometry.cuh"
#include "scene/mesh.hpp"

namespace rt {

struct SceneLights {
    std::vector<LightConfig> lights;
    std::vector<Sphere> markers;
};

inline SceneLights make_scene_lights(const std::array<Mesh, 3> &meshes,
                                     const SceneConfig &config) {
    SceneLights result;

    for (int index = 0; index < config.light_count; ++index) {
        result.lights.push_back(config.lights[index]);
    }

    for (std::size_t body_index = 0; body_index < meshes.size(); ++body_index) {
        const Mesh &mesh = meshes[body_index];
        const BodyConfig &body = config.bodies[body_index];
        const Vec3 marker_color =
            clamp_color(body.color * kMarkerColorMix +
                        Vec3(1.0, 1.0, 1.0) * kMarkerWhiteMix);
        const Vec3 light_color = marker_color * kEdgeLightIntensity;
        Material marker_material{};
        marker_material.color = marker_color;
        marker_material.reflection = 0.0;
        marker_material.transparency = 0.0;
        marker_material.emission = marker_color * kMarkerEmissionStrength;
        const double marker_radius = body.radius * kEdgeLightRadiusScale;

        for (const Edge &edge : mesh.edges) {
            const Vec3 &start =
                mesh.vertices[static_cast<std::size_t>(edge.vertex0)];
            const Vec3 &end =
                mesh.vertices[static_cast<std::size_t>(edge.vertex1)];

            for (int index = 0; index < body.lights_per_edge; ++index) {
                const double position =
                    static_cast<double>(index + 1) /
                    static_cast<double>(body.lights_per_edge + 1);
                const Vec3 point = start + (end - start) * position;
                LightConfig light{};
                light.position = point;
                light.color = light_color;
                light.casts_shadow = false;
                result.lights.push_back(light);
                result.markers.push_back(
                    {point, marker_radius, marker_material});
            }
        }
    }

    return result;
}

} // namespace rt
