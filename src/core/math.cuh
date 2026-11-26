#pragma once

#include <cmath>

namespace rt {

struct Vec3 {
    double x;
    double y;
    double z;

    __host__ __device__ Vec3() : x(0.0), y(0.0), z(0.0) {}

    __host__ __device__ Vec3(double x_value, double y_value, double z_value)
        : x(x_value), y(y_value), z(z_value) {}

    __host__ __device__ Vec3 operator-() const { return Vec3(-x, -y, -z); }

    __host__ __device__ Vec3 &operator+=(const Vec3 &other) {
        x += other.x;
        y += other.y;
        z += other.z;
        return *this;
    }

    __host__ __device__ Vec3 &operator-=(const Vec3 &other) {
        x -= other.x;
        y -= other.y;
        z -= other.z;
        return *this;
    }

    __host__ __device__ Vec3 &operator*=(double scalar) {
        x *= scalar;
        y *= scalar;
        z *= scalar;
        return *this;
    }

    __host__ __device__ Vec3 &operator/=(double scalar) {
        x /= scalar;
        y /= scalar;
        z /= scalar;
        return *this;
    }
};

__host__ __device__ inline Vec3 operator+(Vec3 left, const Vec3 &right) {
    left += right;
    return left;
}

__host__ __device__ inline Vec3 operator-(Vec3 left, const Vec3 &right) {
    left -= right;
    return left;
}

__host__ __device__ inline Vec3 operator*(Vec3 vector, double scalar) {
    vector *= scalar;
    return vector;
}

__host__ __device__ inline Vec3 operator*(double scalar, Vec3 vector) {
    vector *= scalar;
    return vector;
}

__host__ __device__ inline Vec3 operator/(Vec3 vector, double scalar) {
    vector /= scalar;
    return vector;
}

__host__ __device__ inline double dot(const Vec3 &left, const Vec3 &right) {
    return left.x * right.x + left.y * right.y + left.z * right.z;
}

__host__ __device__ inline Vec3 component_product(const Vec3 &left,
                                                  const Vec3 &right) {
    return Vec3(left.x * right.x, left.y * right.y, left.z * right.z);
}

__host__ __device__ inline Vec3 cross(const Vec3 &left, const Vec3 &right) {
    return Vec3(left.y * right.z - left.z * right.y,
                left.z * right.x - left.x * right.z,
                left.x * right.y - left.y * right.x);
}

__host__ __device__ inline double length_squared(const Vec3 &vector) {
    return dot(vector, vector);
}

__host__ __device__ inline double length(const Vec3 &vector) {
    return ::sqrt(length_squared(vector));
}

__host__ __device__ inline Vec3 normalize(const Vec3 &vector) {
    const double vector_length = length(vector);

    if (vector_length == 0.0) {
        return Vec3();
    }

    return vector / vector_length;
}

__host__ __device__ inline Vec3 reflect(const Vec3 &incident,
                                        const Vec3 &normal) {
    return incident - 2.0 * dot(incident, normal) * normal;
}

__host__ __device__ inline double clamp(double value, double minimum,
                                        double maximum) {
    if (value < minimum) {
        return minimum;
    }

    if (value > maximum) {
        return maximum;
    }

    return value;
}

__host__ __device__ inline Vec3 clamp(const Vec3 &vector, double minimum,
                                      double maximum) {
    return Vec3(clamp(vector.x, minimum, maximum),
                clamp(vector.y, minimum, maximum),
                clamp(vector.z, minimum, maximum));
}

__host__ __device__ inline Vec3 clamp_color(const Vec3 &color) {
    return clamp(color, 0.0, 1.0);
}

struct Ray {
    Vec3 origin;
    Vec3 direction;

    __host__ __device__ Ray() : origin(), direction() {}

    __host__ __device__ Ray(const Vec3 &ray_origin, const Vec3 &ray_direction)
        : origin(ray_origin), direction(ray_direction) {}

    __host__ __device__ Vec3 at(double distance) const {
        return origin + direction * distance;
    }
};

} // namespace rt
