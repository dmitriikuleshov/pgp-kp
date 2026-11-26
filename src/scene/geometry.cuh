#pragma once

#include <cmath>

#include "core/math.cuh"

namespace rt {

struct Vec2 {
    double x;
    double y;

    __host__ __device__ Vec2() : x(0.0), y(0.0) {}
    __host__ __device__ Vec2(double x_value, double y_value)
        : x(x_value), y(y_value) {}
};

struct Material {
    Vec3 color;
    double reflection;
    double transparency;
    Vec3 emission{};
};

struct Triangle {
    Vec3 vertex0;
    Vec3 vertex1;
    Vec3 vertex2;
    Material material;
    Vec2 texture0{};
    Vec2 texture1{};
    Vec2 texture2{};
    bool textured = false;
};

struct Cylinder {
    Vec3 start;
    Vec3 end;
    double radius;
    Material material;
};

struct Sphere {
    Vec3 center;
    double radius;
    Material material;
};

struct Hit {
    double distance;          // distance to the surface
    Vec3 point;               // hit point
    Vec3 normal;              // normal to the surface
    Vec2 texture_coordinates; // texture point to use
    bool textured;
    Material material; // surface material
};

__host__ __device__ inline bool
intersect_triangle(const Ray &ray, const Triangle &triangle,
                   double minimum_distance, double maximum_distance, Hit &hit) {

    // define two edtes of the triangle
    const Vec3 edge1 = triangle.vertex1 - triangle.vertex0;
    const Vec3 edge2 = triangle.vertex2 - triangle.vertex0;

    // p = D x E2
    // u = (T, p) / (E1, p)
    const Vec3 direction_cross_edge2 = cross(ray.direction, edge2);
    const double determinant = dot(edge1, direction_cross_edge2);

    // zero-division check
    if (::fabs(determinant) < 1e-12) {
        return false;
    }

    const double inverse_determinant = 1.0 / determinant;
    const Vec3 vertex0_to_origin = ray.origin - triangle.vertex0;
    const double u =
        dot(vertex0_to_origin, direction_cross_edge2) * inverse_determinant;

    // u in [0, 1]
    if (u < 0.0 || u > 1.0) {
        return false;
    }

    const Vec3 origin_cross_edge1 = cross(vertex0_to_origin, edge1);
    const double v =
        dot(ray.direction, origin_cross_edge1) * inverse_determinant;

    if (v < 0.0 || u + v > 1.0) {
        return false;
    }

    const double distance =
        dot(edge2, origin_cross_edge1) * inverse_determinant;

    // if distance < 0, the intersection is behind the camera or in the
    // beginning of a secondary ray
    if (distance < minimum_distance || distance > maximum_distance) {
        return false;
    }

    const Vec3 outward_normal = normalize(cross(edge1, edge2));
    const bool front_face = dot(ray.direction, outward_normal) < 0.0;

    hit.distance = distance;
    hit.point = ray.at(distance);
    hit.normal = front_face ? outward_normal : -outward_normal;
    const double w = 1.0 - u - v;
    hit.texture_coordinates =
        Vec2(w * triangle.texture0.x + u * triangle.texture1.x +
                 v * triangle.texture2.x,
             w * triangle.texture0.y + u * triangle.texture1.y +
                 v * triangle.texture2.y);
    hit.textured = triangle.textured;
    hit.material = triangle.material;
    return true;
}

__host__ __device__ inline bool
intersect_cylinder(const Ray &ray, const Cylinder &cylinder,
                   double minimum_distance, double maximum_distance, Hit &hit) {

    // cylinder vector
    const Vec3 axis_vector = cylinder.end - cylinder.start;
    const double axis_length = length(axis_vector);

    if (axis_length <= 1e-12 || cylinder.radius <= 0.0) {
        return false;
    }

    const Vec3 axis = axis_vector / axis_length;
    const Vec3 start_to_origin = ray.origin - cylinder.start;
    const Vec3 perpendicular_direction =
        ray.direction - axis * dot(ray.direction, axis);
    const Vec3 perpendicular_origin =
        start_to_origin - axis * dot(start_to_origin, axis);
    const double a = dot(perpendicular_direction, perpendicular_direction);

    if (a < 1e-24) {
        return false;
    }

    const double b = 2.0 * dot(perpendicular_direction, perpendicular_origin);
    const double c = dot(perpendicular_origin, perpendicular_origin) -
                     cylinder.radius * cylinder.radius;
    const double discriminant = b * b - 4.0 * a * c;

    if (discriminant < 0.0) {
        return false;
    }

    const double square_root = ::sqrt(discriminant);
    const double roots[2] = {
        (-b - square_root) / (2.0 * a),
        (-b + square_root) / (2.0 * a),
    };

    for (double distance : roots) {
        if (distance < minimum_distance || distance > maximum_distance) {
            continue;
        }

        const Vec3 point = ray.at(distance);
        const double position_on_axis = dot(point - cylinder.start, axis);

        // check if the point is on cylinder
        if (position_on_axis < 0.0 || position_on_axis > axis_length) {
            continue;
        }

        const Vec3 point_on_axis = cylinder.start + axis * position_on_axis;
        const Vec3 outward_normal = normalize(point - point_on_axis);
        const bool front_face = dot(ray.direction, outward_normal) < 0.0;

        hit.distance = distance;
        hit.point = point;
        hit.normal = front_face ? outward_normal : -outward_normal;
        hit.texture_coordinates = Vec2();
        hit.textured = false;
        hit.material = cylinder.material;
        return true;
    }

    return false;
}

__host__ __device__ inline bool
intersect_sphere(const Ray &ray, const Sphere &sphere, double minimum_distance,
                 double maximum_distance, Hit &hit) {
    if (sphere.radius <= 0.0) {
        return false;
    }

    const Vec3 center_to_origin = ray.origin - sphere.center;
    const double a = length_squared(ray.direction);
    const double half_b = dot(center_to_origin, ray.direction);
    const double c =
        length_squared(center_to_origin) - sphere.radius * sphere.radius;
    const double discriminant = half_b * half_b - a * c;

    if (discriminant < 0.0) {
        return false;
    }

    const double square_root = ::sqrt(discriminant);
    const double roots[2] = {
        (-half_b - square_root) / a,
        (-half_b + square_root) / a,
    };

    for (double distance : roots) {
        if (distance < minimum_distance || distance > maximum_distance) {
            continue;
        }

        const Vec3 point = ray.at(distance);
        const Vec3 outward_normal = (point - sphere.center) / sphere.radius;
        const bool front_face = dot(ray.direction, outward_normal) < 0.0;

        hit.distance = distance;
        hit.point = point;
        hit.normal = front_face ? outward_normal : -outward_normal;
        hit.texture_coordinates = Vec2();
        hit.textured = false;
        hit.material = sphere.material;
        return true;
    }

    return false;
}

} // namespace rt
