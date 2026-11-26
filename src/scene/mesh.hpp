#pragma once

#include <array>
#include <cstddef>
#include <vector>

#include "scene/geometry.cuh"

namespace rt {

struct Face {
    int vertex0;
    int vertex1;
    int vertex2;
};

struct Edge {
    int vertex0;
    int vertex1;
};

struct Mesh {
    Vec3 center;
    Material material;
    std::vector<Vec3> vertices;
    std::vector<Face> faces;
    std::vector<Edge> edges;
};

inline void orient_faces_outward(Mesh &mesh) {
    for (Face &face : mesh.faces) {
        const Vec3 &vertex0 =
            mesh.vertices[static_cast<std::size_t>(face.vertex0)];
        const Vec3 &vertex1 =
            mesh.vertices[static_cast<std::size_t>(face.vertex1)];
        const Vec3 &vertex2 =
            mesh.vertices[static_cast<std::size_t>(face.vertex2)];
        const Vec3 normal = cross(vertex1 - vertex0, vertex2 - vertex0);

        // find the center of the triangle
        const Vec3 face_center = (vertex0 + vertex1 + vertex2) / 3.0;

        // face_center - mesh.center points from the figure to the outside
        // if dot < 0 => normal points inside, and it must be changed to point
        // outward
        if (dot(normal, face_center - mesh.center) < 0.0) {
            const int temporary = face.vertex1;
            face.vertex1 = face.vertex2;
            face.vertex2 = temporary;
        }
    }
}

inline void add_unique_edge(std::vector<Edge> &edges, int vertex0,
                            int vertex1) {
    if (vertex0 > vertex1) {
        const int temporary = vertex0;
        vertex0 = vertex1;
        vertex1 = temporary;
    }

    for (const Edge &edge : edges) {
        if (edge.vertex0 == vertex0 && edge.vertex1 == vertex1) {
            return;
        }
    }

    edges.push_back({vertex0, vertex1});
}

inline std::vector<Edge>
edges_from_triangular_faces(const std::vector<Face> &faces) {
    std::vector<Edge> edges;

    for (const Face &face : faces) {
        add_unique_edge(edges, face.vertex0, face.vertex1);
        add_unique_edge(edges, face.vertex1, face.vertex2);
        add_unique_edge(edges, face.vertex2, face.vertex0);
    }

    return edges;
}

inline void append_mesh_triangles(const Mesh &mesh,
                                  std::vector<Triangle> &triangles) {
    for (const Face &face : mesh.faces) {
        triangles.push_back(
            {mesh.vertices[static_cast<std::size_t>(face.vertex0)],
             mesh.vertices[static_cast<std::size_t>(face.vertex1)],
             mesh.vertices[static_cast<std::size_t>(face.vertex2)],
             mesh.material});
    }
}

inline std::vector<Triangle>
triangulate_meshes(const std::array<Mesh, 3> &meshes) {
    std::vector<Triangle> triangles;

    for (const Mesh &mesh : meshes) {
        append_mesh_triangles(mesh, triangles);
    }

    return triangles;
}

} // namespace rt
