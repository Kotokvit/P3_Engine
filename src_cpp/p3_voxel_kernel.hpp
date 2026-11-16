#pragma once
#include <cmath>
#include <array>
#include <vector>
#include <algorithm>
#include <cstdint>
#include <iostream>

namespace P3 {

// Homogeneous 4D coordinates [X : Y : Z : W] on projective manifold P³
struct alignas(16) HomVec4 {
    double x = 0.0;
    double y = 0.0;
    double z = 0.0;
    double w = 1.0; // Homogeneous scale / Dimension level

    constexpr HomVec4() = default;
    constexpr HomVec4(double x_, double y_, double z_, double w_ = 1.0)
        : x(x_), y(y_), z(z_), w(w_) {}

    // Dehomogenization P³ -> R³ for spatial collision and rendering
    [[nodiscard]] std::array<double, 3> toCartesian() const noexcept {
        const double inv_w = (std::abs(w) > 1e-7) ? (1.0 / w) : 1.0;
        return { x * inv_w, y * inv_w, z * inv_w };
    }

    // Fubini-Study Projective Metric (No precision loss on distant coordinates)
    [[nodiscard]] double distanceFubiniStudy(const HomVec4& other) const noexcept {
        const double dot = x * other.x + y * other.y + z * other.z + w * other.w;
        const double n1 = std::sqrt(x * x + y * y + z * z + w * w);
        const double n2 = std::sqrt(other.x * other.x + other.y * other.y + other.z * other.z + other.w * other.w);
        if (n1 < 1e-12 || n2 < 1e-12) return 0.0;
        const double cos_theta = std::clamp(std::abs(dot) / (n1 * n2), 0.0, 1.0);
        return std::acos(cos_theta);
    }
};

enum class BlockType : uint8_t {
    Air = 0,
    Grass = 1,
    Dirt = 2,
    Stone = 3,
    Wood = 4,
    Leaves = 5,
    HyperDimensionBlock = 6 // A block containing an entire inner world!
};

// A nested pocket dimension stored inside a single cube
struct PocketDimension {
    static constexpr int CHUNK_SIZE = 16;
    static constexpr int CHUNK_HEIGHT = 16;
    
    // Inner voxels
    std::array<BlockType, CHUNK_SIZE * CHUNK_SIZE * CHUNK_HEIGHT> voxels{};
    double inner_scale = 0.0625; // Scale relative to parent world (1/16)
    
    void generateInnerWorld() {
        voxels.fill(BlockType::Air);
        // Floor of the inner dimension
        for (int x = 0; x < CHUNK_SIZE; ++x) {
            for (int y = 0; y < CHUNK_SIZE; ++y) {
                voxels[x + y * CHUNK_SIZE + 0 * CHUNK_SIZE * CHUNK_SIZE] = BlockType::Stone;
                voxels[x + y * CHUNK_SIZE + 1 * CHUNK_SIZE * CHUNK_SIZE] = BlockType::Dirt;
                voxels[x + y * CHUNK_SIZE + 2 * CHUNK_SIZE * CHUNK_SIZE] = BlockType::Grass;
            }
        }
        // A mini tower inside the block
        for (int z = 3; z <= 7; ++z) {
            voxels[8 + 8 * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE] = BlockType::Wood;
        }
        voxels[8 + 8 * CHUNK_SIZE + 8 * CHUNK_SIZE * CHUNK_SIZE] = BlockType::Leaves;
    }

    [[nodiscard]] BlockType getVoxel(int x, int y, int z) const noexcept {
        if (x < 0 || x >= CHUNK_SIZE || y < 0 || y >= CHUNK_SIZE || z < 0 || z >= CHUNK_HEIGHT)
            return BlockType::Air;
        return voxels[x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE];
    }
};

} // namespace P3
