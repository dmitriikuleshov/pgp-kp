#pragma once

#include <array>
#include <cmath>

#include "core/config.hpp"
#include "scene/mesh.hpp"

namespace rt {

inline Material body_material(const BodyConfig &body) {
    return {body.color, body.reflection, body.transparency};
}

// figures are defined in two steps
// 1. define a simple figure near 0
// 2. change its size and position

// body.radius defines space between figure's center and a vertex
// vertex * scale changes figure's size
// + body.center moves a figure to the needed

inline Mesh make_tetrahedron_mesh(const BodyConfig &body) {
    enum Vertex { A, B, C, D };

    const double scale = body.radius / ::sqrt(3.0);
    Mesh mesh{};
    mesh.center = body.center;
    mesh.material = body_material(body);
    mesh.vertices = {
        {1, 1, 1},   // A
        {1, -1, -1}, // B
        {-1, 1, -1}, // C
        {-1, -1, 1}, // D
    };
    for (Vec3 &vertex : mesh.vertices) {
        vertex = body.center + scale * vertex;
    }
    mesh.faces = {
        {A, B, C},
        {A, D, B},
        {A, C, D},
        {B, D, C},
    };
    orient_faces_outward(mesh);
    mesh.edges = edges_from_triangular_faces(mesh.faces);
    return mesh;
}

inline Mesh make_cube_mesh(const BodyConfig &body) {
    enum Vertex { A, B, C, D, E, F, G, H };

    const double scale = body.radius / ::sqrt(3.0);
    Mesh mesh{};
    mesh.center = body.center;
    mesh.material = body_material(body);
    mesh.vertices = {
        {-1, -1, -1}, // A
        {1, -1, -1},  // B
        {1, 1, -1},   // C
        {-1, 1, -1},  // D
        {-1, -1, 1},  // E
        {1, -1, 1},   // F
        {1, 1, 1},    // G
        {-1, 1, 1},   // H
    };
    for (Vec3 &vertex : mesh.vertices) {
        vertex = body.center + scale * vertex;
    }
    mesh.faces = {
        {A, B, C}, {A, C, D}, // bottom
        {E, F, G}, {E, G, H}, // top
        {A, B, F}, {A, F, E}, // y = -1
        {B, C, G}, {B, G, F}, // x = +1
        {C, D, H}, {C, H, G}, // y = +1
        {D, A, E}, {D, E, H}, // x = -1
    };

    // cube's meshes explicitly
    mesh.edges = {
        {A, B}, {B, C}, {C, D}, {A, D}, {E, F}, {F, G},
        {G, H}, {E, H}, {A, E}, {B, F}, {C, G}, {D, H},
    };
    orient_faces_outward(mesh);
    return mesh;
}

inline Mesh make_icosahedron_mesh(const BodyConfig &body) {
    enum Vertex { A, B, C, D, E, F, G, H, I, J, K, L };

    const double phi = (1.0 + ::sqrt(5.0)) / 2.0;
    const double scale = body.radius / ::sqrt(1.0 + phi * phi);
    Mesh mesh{};
    mesh.center = body.center;
    mesh.material = body_material(body);
    mesh.vertices = {
        {-1, phi, 0},  // A
        {1, phi, 0},   // B
        {-1, -phi, 0}, // C
        {1, -phi, 0},  // D
        {0, -1, phi},  // E
        {0, 1, phi},   // F
        {0, -1, -phi}, // G
        {0, 1, -phi},  // H
        {phi, 0, -1},  // I
        {phi, 0, 1},   // J
        {-phi, 0, -1}, // K
        {-phi, 0, 1},  // L
    };
    for (Vec3 &vertex : mesh.vertices) {
        vertex = body.center + scale * vertex;
    }
    mesh.faces = {
        {A, L, F}, {A, F, B}, {A, B, H}, {A, H, K}, {A, K, L},

        {B, F, J}, {F, L, E}, {L, K, C}, {K, H, G}, {H, B, I},

        {D, J, E}, {D, E, C}, {D, C, G}, {D, G, I}, {D, I, J},

        {E, J, F}, {C, E, L}, {G, C, K}, {I, G, H}, {J, I, B},
    };
    orient_faces_outward(mesh);
    mesh.edges = edges_from_triangular_faces(mesh.faces);
    return mesh;
}

inline std::array<Mesh, 3> make_variant_meshes(const SceneConfig &config) {
    return {
        make_tetrahedron_mesh(config.bodies[Tetrahedron]),
        make_cube_mesh(config.bodies[Cube]),
        make_icosahedron_mesh(config.bodies[Icosahedron]),
    };
}

} // namespace rt
