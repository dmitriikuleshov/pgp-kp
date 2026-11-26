#pragma once

#include <array>
#include <utility>
#include <vector>

#include "core/config.hpp"
#include "scene/edge_lights.hpp"
#include "scene/edges.hpp"
#include "scene/floor.hpp"
#include "scene/geometry.cuh"
#include "scene/mesh.hpp"
#include "scene/solids.hpp"

namespace rt {

struct SceneGeometry {
    std::vector<Triangle> triangles;
    std::vector<Cylinder> cylinders;
    std::vector<Sphere> light_markers;
    std::vector<LightConfig> lights;
};

inline SceneGeometry make_scene_geometry(const SceneConfig &config) {
    const std::array<Mesh, 3> meshes = make_variant_meshes(config);
    SceneLights lights = make_scene_lights(meshes, config);
    SceneGeometry geometry;
    geometry.triangles = triangulate_meshes(meshes);
    geometry.cylinders = make_edge_cylinders(meshes, config);
    geometry.light_markers = std::move(lights.markers);
    geometry.lights = std::move(lights.lights);
    append_floor_triangles(config.floor, geometry.triangles);
    return geometry;
}

} // namespace rt
