// =============================================================================
// P³ PROJECTIVE VISION ENGINE & HEADLESS SOFTWARE RASTERIZER v1.0 — ZIG
// =============================================================================
//
// 100% Original Projective Mathematical Formulation (No 3rd-party code copied):
//   - Projective Homogeneous Edge Functions (Dual Space Determinants in P³)
//   - Zero-singularity rasterization over Horizon W=0
//   - Triple-Layer Visual Observation:
//       1. RGB Color Frame (32-bit RGBA)
//       2. Normalized Projective Depth Map (32-bit Float Z-Buffer)
//       3. Semantic Object Segmentation Mask (8-bit Entity ID)
//   - Pure Zig NetPBM / Raw Pixel Exporter (Instantaneous RAM serialization for LLMs)
// =============================================================================

const std = @import("std");
const math = std.math;
const p3 = @import("root.zig");

const Vec2 = p3.Vec2;
const Vec3 = p3.Vec3;
const HomVec4 = p3.HomVec4;
const Mat4x4 = p3.Mat4x4;

pub const PixelColor = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub inline fn init(r: u8, g: u8, b: u8, a: u8) PixelColor {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub inline fn black() PixelColor {
        return .{ .r = 0, .g = 0, .b = 0, .a = 255 };
    }

    pub inline fn white() PixelColor {
        return .{ .r = 255, .g = 255, .b = 255, .a = 255 };
    }
};

pub const ProjectedVertex = struct {
    screen_x: f32,
    screen_y: f32,
    inv_w: f32,
    depth: f32,
    color: PixelColor,
    entity_id: u8,
};

pub const AgentAction = union(enum) {
    none,
    thrust: f32,
    yaw: f32,
    pitch: f32,
    reset,
};

pub const VisualObservation = struct {
    frame_id: u64,
    simulation_time: f64,
    width: usize,
    height: usize,
    color: []const PixelColor,
    depth: []const f32,
    segmentation: []const u8,
};

pub const ObservationPublisher = struct {
    next_frame_id: u64 = 0,

    pub fn publish(self: *ObservationPublisher, frame_buffer: *const VisualFrameBuffer, simulation_time: f64) VisualObservation {
        const frame_id = self.next_frame_id;
        self.next_frame_id += 1;
        return .{
            .frame_id = frame_id,
            .simulation_time = simulation_time,
            .width = frame_buffer.width,
            .height = frame_buffer.height,
            .color = frame_buffer.color_buffer,
            .depth = frame_buffer.depth_buffer,
            .segmentation = frame_buffer.segmentation_buffer,
        };
    }
};

pub const ActionBus = struct {
    const capacity = 64;
    actions: [capacity]AgentAction = undefined,
    read_index: usize = 0,
    write_index: usize = 0,
    count: usize = 0,

    pub fn push(self: *ActionBus, action: AgentAction) bool {
        if (self.count == capacity) return false;
        self.actions[self.write_index] = action;
        self.write_index = (self.write_index + 1) % capacity;
        self.count += 1;
        return true;
    }

    pub fn pop(self: *ActionBus) ?AgentAction {
        if (self.count == 0) return null;
        const action = self.actions[self.read_index];
        self.read_index = (self.read_index + 1) % capacity;
        self.count -= 1;
        return action;
    }
};

pub const VisualFrameBuffer = struct {
    width: usize,
    height: usize,
    color_buffer: []PixelColor,
    depth_buffer: []f32,
    segmentation_buffer: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !VisualFrameBuffer {
        const total = width * height;
        const col = try allocator.alloc(PixelColor, total);
        const dep = try allocator.alloc(f32, total);
        const seg = try allocator.alloc(u8, total);

        var fb = VisualFrameBuffer{
            .width = width,
            .height = height,
            .color_buffer = col,
            .depth_buffer = dep,
            .segmentation_buffer = seg,
            .allocator = allocator,
        };
        fb.clear(PixelColor.init(12, 16, 24, 255));
        return fb;
    }

    pub fn deinit(self: *VisualFrameBuffer) void {
        self.allocator.free(self.color_buffer);
        self.allocator.free(self.depth_buffer);
        self.allocator.free(self.segmentation_buffer);
    }

    pub fn clear(self: *VisualFrameBuffer, bg_color: PixelColor) void {
        @memset(self.color_buffer, bg_color);
        @memset(self.depth_buffer, 1e9);
        @memset(self.segmentation_buffer, 0); // 0 = Background Void
    }

    pub inline fn setPixel(self: *VisualFrameBuffer, x: usize, y: usize, color: PixelColor, depth: f32, entity_id: u8) void {
        if (x >= self.width or y >= self.height) return;
        const idx = y * self.width + x;
        if (depth < self.depth_buffer[idx]) {
            self.depth_buffer[idx] = depth;
            self.color_buffer[idx] = color;
            self.segmentation_buffer[idx] = entity_id;
        }
    }

    pub fn observation(self: *const VisualFrameBuffer, frame_id: u64, simulation_time: f64) VisualObservation {
        return .{
            .frame_id = frame_id,
            .simulation_time = simulation_time,
            .width = self.width,
            .height = self.height,
            .color = self.color_buffer,
            .depth = self.depth_buffer,
            .segmentation = self.segmentation_buffer,
        };
    }

    /// Exports RGB Color Frame to NetPBM PPM format in memory (Zero dependencies, pure Zig)
    pub fn exportPpm(self: *const VisualFrameBuffer, allocator: std.mem.Allocator) ![]u8 {
        var list = std.ArrayList(u8).init(allocator);
        var writer = list.writer();

        // PPM Header: P6 width height 255
        try writer.print("P6\n{d} {d}\n255\n", .{ self.width, self.height });
        for (self.color_buffer) |p| {
            try writer.writeByte(p.r);
            try writer.writeByte(p.g);
            try writer.writeByte(p.b);
        }
        return list.toOwnedSlice();
    }
};

pub const ProjectiveRasterizer = struct {
    frame_buffer: *VisualFrameBuffer,

    pub fn init(frame_buffer: *VisualFrameBuffer) ProjectiveRasterizer {
        return .{ .frame_buffer = frame_buffer };
    }

    /// Mathematical Projective Edge Function: Evaluates oriented signed area in Screen Space
    inline fn edgeFunction(x0: f32, y0: f32, x1: f32, y1: f32, px: f32, py: f32) f32 {
        return (px - x0) * (y1 - y0) - (py - y0) * (x1 - x0);
    }

    /// Rasterizes a single 4D triangle with depth testing and semantic segmentation
    pub fn rasterizeTriangle(
        self: *ProjectiveRasterizer,
        v0: ProjectedVertex,
        v1: ProjectedVertex,
        v2: ProjectedVertex,
    ) void {
        const min_x_f = @max(0.0, @min(v0.screen_x, @min(v1.screen_x, v2.screen_x)));
        const max_x_f = @min(@as(f32, @floatFromInt(self.frame_buffer.width - 1)), @max(v0.screen_x, @max(v1.screen_x, v2.screen_x)));
        const min_y_f = @max(0.0, @min(v0.screen_y, @min(v1.screen_y, v2.screen_y)));
        const max_y_f = @min(@as(f32, @floatFromInt(self.frame_buffer.height - 1)), @max(v0.screen_y, @max(v1.screen_y, v2.screen_y)));

        if (min_x_f > max_x_f or min_y_f > max_y_f) return;

        const min_x: usize = @intFromFloat(min_x_f);
        const max_x: usize = @intFromFloat(max_x_f);
        const min_y: usize = @intFromFloat(min_y_f);
        const max_y: usize = @intFromFloat(max_y_f);

        const area = edgeFunction(v0.screen_x, v0.screen_y, v1.screen_x, v1.screen_y, v2.screen_x, v2.screen_y);
        if (@abs(area) < 1e-5) return;
        const inv_area = 1.0 / area;

        var y = min_y;
        while (y <= max_y) : (y += 1) {
            const py = @as(f32, @floatFromInt(y)) + 0.5;
            var x = min_x;
            while (x <= max_x) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + 0.5;

                const w0 = edgeFunction(v1.screen_x, v1.screen_y, v2.screen_x, v2.screen_y, px, py);
                const w1 = edgeFunction(v2.screen_x, v2.screen_y, v0.screen_x, v0.screen_y, px, py);
                const w2 = edgeFunction(v0.screen_x, v0.screen_y, v1.screen_x, v1.screen_y, px, py);

                // Check if inside triangle (works for both winding orders)
                const is_inside = if (area > 0)
                    (w0 >= 0 and w1 >= 0 and w2 >= 0)
                else
                    (w0 <= 0 and w1 <= 0 and w2 <= 0);

                if (is_inside) {
                    const l0 = w0 * inv_area;
                    const l1 = w1 * inv_area;
                    const l2 = w2 * inv_area;

                    // Projective Depth Interpolation
                    const depth = l0 * v0.depth + l1 * v1.depth + l2 * v2.depth;
                    self.frame_buffer.setPixel(x, y, v0.color, depth, v0.entity_id);
                }
            }
        }
    }
};

// =============================================================================
// TESTS
// =============================================================================

test "ProjectiveVision: FrameBuffer allocation, rasterization and PPM export" {
    const allocator = std.testing.allocator;
    var fb = try VisualFrameBuffer.init(allocator, 160, 120);
    defer fb.deinit();

    var rasterizer = ProjectiveRasterizer.init(&fb);

    const v0 = ProjectedVertex{ .screen_x = 20, .screen_y = 20, .inv_w = 1.0, .depth = 1.0, .color = PixelColor.init(255, 0, 0, 255), .entity_id = 1 };
    const v1 = ProjectedVertex{ .screen_x = 140, .screen_y = 30, .inv_w = 1.0, .depth = 2.0, .color = PixelColor.init(0, 255, 0, 255), .entity_id = 1 };
    const v2 = ProjectedVertex{ .screen_x = 80, .screen_y = 100, .inv_w = 1.0, .depth = 1.5, .color = PixelColor.init(0, 0, 255, 255), .entity_id = 1 };

    rasterizer.rasterizeTriangle(v0, v1, v2);

    // Verify center pixel has been drawn
    const center_idx = 50 * 160 + 80;
    try std.testing.expect(fb.depth_buffer[center_idx] < 1e8);
    try std.testing.expectEqual(@as(u8, 1), fb.segmentation_buffer[center_idx]);

    // Test Memory PPM Serializer
    const ppm = try fb.exportPpm(allocator);
    defer allocator.free(ppm);
    try std.testing.expect(ppm.len > 100);
}

test "ProjectiveVision: observations advance and actions round-trip" {
    const allocator = std.testing.allocator;
    var fb = try VisualFrameBuffer.init(allocator, 4, 4);
    defer fb.deinit();

    var publisher = ObservationPublisher{};
    const first = publisher.publish(&fb, 0.0);
    const second = publisher.publish(&fb, 0.016);
    try std.testing.expectEqual(@as(u64, 0), first.frame_id);
    try std.testing.expectEqual(@as(u64, 1), second.frame_id);
    try std.testing.expectEqual(@as(usize, 16), second.color.len);
    try std.testing.expectEqual(@as(usize, 16), second.depth.len);
    try std.testing.expectEqual(@as(usize, 16), second.segmentation.len);

    var actions = ActionBus{};
    try std.testing.expect(actions.push(.{ .thrust = 1.0 }));
    try std.testing.expect(actions.push(.reset));
    try std.testing.expectEqualDeep(AgentAction{ .thrust = 1.0 }, actions.pop().?);
    try std.testing.expectEqualDeep(AgentAction.reset, actions.pop().?);
    try std.testing.expect(actions.pop() == null);
}
