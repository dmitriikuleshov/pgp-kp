#pragma once

#include <cstdint>

#include "core/config.hpp"
#include "core/image.cuh"
#include "core/math.cuh"
#include "scene/geometry.cuh"

namespace rt {

constexpr double kRayEpsilon =
    1e-6; // prevents hits almost at the  beginning of the ray
constexpr double kMaximumRayDistance = 1e30;
constexpr double kLightAttenuation = 0.015;
constexpr double kMinimumRayContribution = 1.0 / 1024.0;

struct SceneView {
    const Triangle *triangles; // triangels
    int triangle_count;        // triangles count in scene
    const Cylinder *cylinders; //    cylinders (figures' edges)
    int cylinder_count;        //    cylinders count in scene
    const Sphere *spheres;     // spheres (light sources on the edges)
    int sphere_count;          // spheres count in scene
    const LightConfig *lights; //    global light sources
    int light_count;           //    global light sources count
};

struct TextureView {
    const Pixel *pixels;
    int width;
    int height;
};

__host__ __device__ inline bool closest_intersection(const Ray &ray,
                                                     const SceneView &scene,
                                                     double minimum_distance,
                                                     double maximum_distance,
                                                     Hit &nearest_hit) {
    bool found = false;
    double nearest_distance = maximum_distance;

    // check intersection with triangles
    for (int index = 0; index < scene.triangle_count; ++index) {
        Hit hit{};

        if (intersect_triangle(ray, scene.triangles[index], minimum_distance,
                               nearest_distance, hit)) {
            nearest_hit = hit;
            nearest_distance = hit.distance;
            found = true;
        }
    }

    // check intersection with cylinders (figures' edges)
    for (int index = 0; index < scene.cylinder_count; ++index) {
        Hit hit{};

        if (intersect_cylinder(ray, scene.cylinders[index], minimum_distance,
                               nearest_distance, hit)) {
            nearest_hit = hit;
            nearest_distance = hit.distance;
            found = true;
        }
    }

    // check intersection with spheres (light sources)
    for (int index = 0; index < scene.sphere_count; ++index) {
        Hit hit{};

        if (intersect_sphere(ray, scene.spheres[index], minimum_distance,
                             nearest_distance, hit)) {
            nearest_hit = hit;
            nearest_distance = hit.distance;
            found = true;
        }
    }

    return found;
}

__host__ __device__ inline bool light_is_blocked(const Hit &surface_hit,
                                                 const Vec3 &light_position,
                                                 const SceneView &scene) {
    const Vec3 to_light = light_position - surface_hit.point;
    const double distance_to_light = length(to_light);

    if (distance_to_light <= kRayEpsilon) {
        return false;
    }

    const Vec3 direction = to_light / distance_to_light;
    const Ray shadow_ray(surface_hit.point + surface_hit.normal * kRayEpsilon,
                         direction);
    Hit blocker{};

    // Light markers do not cast shadows.
    SceneView shadow_scene = scene;
    shadow_scene.spheres = nullptr;
    shadow_scene.sphere_count = 0;

    return closest_intersection(shadow_ray, shadow_scene, kRayEpsilon,
                                distance_to_light -
                                    kRayEpsilon, // because an object behind the
                                                 // light can't block this light
                                blocker);
}

// returns pixel color at (U, V)
__host__ __device__ inline Vec3 sample_texture(const TextureView &texture,
                                               const Vec2 &coordinates) {
    if (texture.pixels == nullptr || texture.width <= 0 ||
        texture.height <= 0) {
        return Vec3(1.0, 1.0, 1.0);
    }

    const double u = clamp(coordinates.x, 0.0, 1.0);
    const double v = clamp(coordinates.y, 0.0, 1.0);

    // texture_width - 1, because for width = 4, indices will be 0, 1, 2, 3
    // + 0.5 to reach the center of the pixel
    // static_cast = round down.
    const int x = static_cast<int>(u * (texture.width - 1) + 0.5);
    const int y = static_cast<int>((1.0 - v) * (texture.height - 1) + 0.5);
    return pixel_to_color(texture.pixels[y * texture.width + x]);
}

__host__ __device__ inline Vec3 shade_hit(const Hit &hit,
                                          const SceneView &scene,
                                          const TextureView &texture,
                                          std::uint64_t &ray_count) {

    // if we hit a light source at an edge of a figure, just return its color
    if (length_squared(hit.material.emission) > 0.0) {
        return clamp_color(hit.material.emission);
    }

    // first, take material color
    Vec3 surface_color = hit.material.color;

    // if the surface is textured, count texture color in this point
    if (hit.textured) {
        surface_color = component_product(
            surface_color, sample_texture(texture, hit.texture_coordinates));
    }

    // count ambient
    Vec3 result = surface_color * kAmbientStrength;

    // count every light source
    for (int index = 0; index < scene.light_count; ++index) {
        const LightConfig &light = scene.lights[index];
        // vector from the surface point to the light
        const Vec3 to_light = light.position - hit.point;
        const double distance_squared = length_squared(to_light);

        // skip lights too close
        if (distance_squared <= kRayEpsilon * kRayEpsilon) {
            continue;
        }

        // normalize direction and count Lambert lighting
        const Vec3 light_direction = to_light / ::sqrt(distance_squared);
        const double diffuse_strength = dot(hit.normal, light_direction);

        // skip lights behind the surface
        if (diffuse_strength <= 0.0) {
            continue;
        }

        // count a shadow ray and check for obstacles
        if (light.casts_shadow) {
            ++ray_count;

            if (light_is_blocked(hit, light.position, scene)) {
                continue;
            }
        }

        // weaken light with distance
        const double attenuation =
            1.0 / (1.0 + kLightAttenuation * distance_squared);
        // combine surface and light colors, then add the light contribution
        const Vec3 illuminated_color =
            component_product(surface_color, light.color);
        result += illuminated_color * (diffuse_strength * attenuation);
    }

    return clamp_color(result);
}

struct RayState {
    Ray ray;
    double contribution;
    int depth;
};

__host__ __device__ inline Vec3
trace_ray(const Ray &ray, const SceneView &scene, const TextureView &texture,
          int maximum_depth, std::uint64_t &ray_count) {
    RayState stack[kMaximumTraceDepth + 1];
    int stack_size = 1;
    stack[0] = {ray, 1.0, 0};
    Vec3 result{};
    ray_count = 0;

    while (stack_size > 0) {
        --stack_size;
        const RayState state = stack[stack_size];
        ++ray_count;

        Hit hit{};

        // look for the surface for current ray
        if (!closest_intersection(state.ray, scene, kRayEpsilon,
                                  kMaximumRayDistance, hit)) {
            continue; // found nothing, this point will be black
        }

        const Vec3 local_color = shade_hit(hit, scene, texture, ray_count);

        if (state.depth >= maximum_depth) {
            result += local_color * state.contribution;
            continue; // reached maximum depth
        }

        double reflection_weight = hit.material.reflection;
        double transmission_weight = hit.material.transparency;
        const double secondary_weight = reflection_weight + transmission_weight;

        if (secondary_weight > 1.0) {
            reflection_weight /= secondary_weight;
            transmission_weight /= secondary_weight;
        }

        // local_weight + reflection_weight + transmission_weight = 1
        const double local_weight =
            1.0 - reflection_weight - transmission_weight;
        result +=
            local_color * (state.contribution * local_weight); // count local

        const int next_depth = state.depth + 1;

        // calculate contribution for reflected and transmitted rays
        const double reflected_contribution =
            state.contribution * reflection_weight;
        const double transmitted_contribution =
            state.contribution * transmission_weight;

        // We add reflected first, and transmitted secont => transmitted will be
        // processed first. this is DFS

        // create reflected ray
        if (reflected_contribution >= kMinimumRayContribution &&
            stack_size < kMaximumTraceDepth + 1) {
            const Vec3 reflected_direction = normalize(reflect(
                state.ray.direction, hit.normal)); // reflect the parent ray
            stack[stack_size] = {
                Ray(hit.point + hit.normal * kRayEpsilon, reflected_direction),
                reflected_contribution,
                next_depth,
            };
            ++stack_size;
        }

        // create transmitted ray
        if (transmitted_contribution >= kMinimumRayContribution &&
            stack_size < kMaximumTraceDepth + 1) {
            // the same direction
            stack[stack_size] = {
                Ray(hit.point + state.ray.direction * kRayEpsilon,
                    state.ray.direction),
                transmitted_contribution,
                next_depth,
            };
            ++stack_size;
        }
    }

    return clamp_color(result);
}

} // namespace rt
