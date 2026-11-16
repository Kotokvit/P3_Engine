#include "p3_voxel_kernel.hpp"
#include <raylib.h>
#include <raymath.h>
#include <vector>
#include <string>
#include <sstream>

// Voxel Chunk in Outer World (W = 1.0)
struct WorldChunk {
    static constexpr int SIZE = 16;
    static constexpr int HEIGHT = 16;
    P3::BlockType blocks[SIZE][SIZE][HEIGHT]{};
    int chunk_x = 0;
    int chunk_y = 0;

    void generate() {
        for (int x = 0; x < SIZE; ++x) {
            for (int y = 0; y < SIZE; ++y) {
                blocks[x][y][0] = P3::BlockType::Stone;
                blocks[x][y][1] = P3::BlockType::Dirt;
                blocks[x][y][2] = P3::BlockType::Grass;
                for (int z = 3; z < HEIGHT; ++z) {
                    blocks[x][y][z] = P3::BlockType::Air;
                }
            }
        }
        // Place one HyperDimensionBlock in the middle of the spawn chunk
        if (chunk_x == 0 && chunk_y == 0) {
            blocks[8][8][3] = P3::BlockType::HyperDimensionBlock;
        }
    }
};

int main() {
    constexpr int SCREEN_WIDTH = 1280;
    constexpr int SCREEN_HEIGHT = 720;

    SetConfigFlags(FLAG_MSAA_4X_HINT | FLAG_VSYNC_HINT);
    InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "P3 Engine C++20 — Pocket Dimension Voxel Sandbox");
    SetTargetFPS(60);
    DisableCursor(); // Capture mouse for FPS camera

    // Initialize Outer World & Inner Pocket Dimension
    WorldChunk main_chunk;
    main_chunk.generate();

    P3::PocketDimension pocket_dim;
    pocket_dim.generateInnerWorld();

    // Player position in P³ space [X : Y : Z : W]
    P3::HomVec4 player_pos(8.0, 5.0, 4.0, 1.0); // Outside facing the block
    Camera3D camera{};
    camera.position = Vector3{ 8.0f, 5.0f, 4.5f };
    camera.target = Vector3{ 8.0f, 8.0f, 3.5f };
    camera.up = Vector3{ 0.0f, 0.0f, 1.0f };
    camera.fovy = 65.0f;
    camera.projection = CAMERA_PERSPECTIVE;

    bool is_inside_pocket = false;
    double current_w_scale = 1.0;

    while (!WindowShouldClose()) {
        float dt = GetFrameTime();

        // 1. First-Person Camera Mouse & Keyboard Controls
        UpdateCameraPro(&camera,
            Vector3{
                (IsKeyDown(KEY_W) || IsKeyDown(KEY_UP)) * 6.0f * dt - (IsKeyDown(KEY_S) || IsKeyDown(KEY_DOWN)) * 6.0f * dt,
                (IsKeyDown(KEY_D) || IsKeyDown(KEY_RIGHT)) * 6.0f * dt - (IsKeyDown(KEY_A) || IsKeyDown(KEY_LEFT)) * 6.0f * dt,
                (IsKeyDown(KEY_SPACE)) * 4.0f * dt - (IsKeyDown(KEY_LEFT_SHIFT)) * 4.0f * dt
            },
            Vector3{
                GetMouseDelta().x * 0.15f,
                GetMouseDelta().y * 0.15f,
                0.0f
            },
            0.0f
        );

        player_pos.x = camera.position.x;
        player_pos.y = camera.position.y;
        player_pos.z = camera.position.z;

        // 2. Check Distance to HyperDimensionBlock (located at 8, 8, 3 in main world)
        P3::HomVec4 hyper_block_pos(8.5, 8.5, 3.5, 1.0);
        double dist_to_portal = player_pos.distanceFubiniStudy(hyper_block_pos);

        // Seamless P³ Dimension Transition (Press E when looking at the block)
        if (IsKeyPressed(KEY_E) && dist_to_portal < 0.25) {
            is_inside_pocket = !is_inside_pocket;
            if (is_inside_pocket) {
                // Transition to Pocket Dimension (Inner scale W = 0.0625)
                current_w_scale = 0.0625;
                camera.position = Vector3{ 8.0f, 2.0f, 4.0f };
                camera.target = Vector3{ 8.0f, 8.0f, 5.0f };
            } else {
                // Return to Outer World (W = 1.0)
                current_w_scale = 1.0;
                camera.position = Vector3{ 8.0f, 5.0f, 4.0f };
                camera.target = Vector3{ 8.0f, 8.0f, 3.5f };
            }
        }

        // 3. Render 3D Scene
        BeginDrawing();
        ClearBackground(is_inside_pocket ? Color{ 20, 15, 35, 255 } : Color{ 135, 206, 235, 255 }); // Void purple vs Sky blue

        BeginMode3D(camera);

        if (!is_inside_pocket) {
            // --- RENDER MAIN OUTER VOXEL WORLD (W = 1.0) ---
            for (int x = 0; x < WorldChunk::SIZE; ++x) {
                for (int y = 0; y < WorldChunk::SIZE; ++y) {
                    for (int z = 0; z < WorldChunk::HEIGHT; ++z) {
                        auto type = main_chunk.blocks[x][y][z];
                        if (type == P3::BlockType::Air) continue;

                        Vector3 pos{ (float)x + 0.5f, (float)y + 0.5f, (float)z + 0.5f };

                        if (type == P3::BlockType::Grass) {
                            DrawCube(pos, 1.0f, 1.0f, 1.0f, Color{ 86, 176, 56, 255 });
                            DrawCubeWires(pos, 1.0f, 1.0f, 1.0f, Color{ 60, 130, 40, 255 });
                        } else if (type == P3::BlockType::Dirt) {
                            DrawCube(pos, 1.0f, 1.0f, 1.0f, Color{ 134, 96, 67, 255 });
                        } else if (type == P3::BlockType::Stone) {
                            DrawCube(pos, 1.0f, 1.0f, 1.0f, Color{ 120, 120, 120, 255 });
                        } else if (type == P3::BlockType::HyperDimensionBlock) {
                            // Glowing Obsidian/Crystal Hyper-Block (The Portal Cube)
                            DrawCube(pos, 1.0f, 1.0f, 1.0f, Color{ 160, 32, 240, 200 }); // Translucent Purple
                            DrawCubeWires(pos, 1.05f, 1.05f, 1.05f, Color{ 0, 255, 255, 255 }); // Neon Cyan Edges
                        }
                    }
                }
            }
        } else {
            // --- RENDER INNER POCKET DIMENSION (Inside the single cube!) ---
            // Render the inner bounded room (16x16x16)
            for (int x = 0; x < P3::PocketDimension::CHUNK_SIZE; ++x) {
                for (int y = 0; y < P3::PocketDimension::CHUNK_SIZE; ++y) {
                    for (int z = 0; z < P3::PocketDimension::CHUNK_HEIGHT; ++z) {
                        auto type = pocket_dim.getVoxel(x, y, z);
                        if (type == P3::BlockType::Air) continue;

                        Vector3 pos{ (float)x + 0.5f, (float)y + 0.5f, (float)z + 0.5f };

                        if (type == P3::BlockType::Grass) {
                            DrawCube(pos, 1.0f, 1.0f, 1.0f, Color{ 120, 220, 90, 255 });
                        } else if (type == P3::BlockType::Wood) {
                            DrawCube(pos, 1.0f, 1.0f, 1.0f, Color{ 160, 110, 60, 255 });
                        } else if (type == P3::BlockType::Leaves) {
                            DrawCube(pos, 1.0f, 1.0f, 1.0f, Color{ 40, 190, 80, 255 });
                        } else {
                            DrawCube(pos, 1.0f, 1.0f, 1.0f, Color{ 100, 100, 140, 255 });
                        }
                        DrawCubeWires(pos, 1.0f, 1.0f, 1.0f, Color{ 30, 30, 40, 150 });
                    }
                }
            }

            // Outer bounding barrier of the Pocket Dimension (The inside walls of the cube)
            DrawCubeWires(Vector3{ 8.0f, 8.0f, 8.0f }, 16.0f, 16.0f, 16.0f, Color{ 255, 0, 128, 255 });
        }

        EndMode3D();

        // 4. Crosshair and HUD
        DrawCircle(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, 3.0f, WHITE);

        DrawRectangle(20, 20, 420, 140, Color{ 10, 10, 15, 230 });
        DrawRectangleLines(20, 20, 420, 140, is_inside_pocket ? Color{ 255, 0, 128, 255 } : Color{ 0, 200, 255, 255 });

        DrawText("P³ ENGINE C++20 — POCKET DIMENSION VOXEL", 35, 30, 14, is_inside_pocket ? Color{ 255, 100, 200, 255 } : Color{ 0, 220, 255, 255 });

        std::string mode_str = is_inside_pocket ? "LOCATION: [INSIDE HYPER-BLOCK #1] (W = 0.0625)" : "LOCATION: [OVERWORLD] (W = 1.0)";
        DrawText(mode_str.c_str(), 35, 55, 15, WHITE);

        std::string pos_str = "Pos: (" + std::to_string((int)camera.position.x) + ", " + std::to_string((int)camera.position.y) + ", " + std::to_string((int)camera.position.z) + ")";
        DrawText(pos_str.c_str(), 35, 80, 13, LIGHTGRAY);

        if (!is_inside_pocket && dist_to_portal < 0.25) {
            DrawText(">> PRESS [E] TO ENTER HYPER-BLOCK DIMENSION <<", 35, 105, 13, YELLOW);
        } else if (is_inside_pocket) {
            DrawText(">> PRESS [E] TO EXIT BACK TO OVERWORLD <<", 35, 105, 13, GREEN);
        } else {
            DrawText("Controls: [W/A/S/D] Move | [Space/Shift] Up/Down | [E] Enter", 35, 105, 11, GRAY);
        }

        DrawFPS(SCREEN_WIDTH - 90, 20);

        EndDrawing();
    }

    CloseWindow();
    return 0;
}
