//! =============================================================================
//! P³ PROCEDURAL ROAD GENERATOR & SPLINE RACING TRACK
//! =============================================================================
//!
//! Generates smooth racing track curves, road banking, and surface elevation
//! on the P³ projective manifold.
//!

const std = @import("std");
const math = std.math;
const p3_kernel = @import("p3_kernel.zig");

pub const HomVec4 = p3_kernel.HomVec4;

pub const RoadPoint = struct {
    pos: HomVec4, // [X : Y : Z : W]
    tangent: [3]f64, // Normalized heading vector
    banking_rad: f64 = 0.0, // Road camber/banking angle
    width: f64 = 8.0, // 8 meters standard road width
};

pub const Track = struct {
    points: [128]RoadPoint = undefined,
    count: usize = 0,
    is_loop: bool = true,

    pub fn generateOval(self: *Track, radius: f64, straight_len: f64) void {
        self.count = 0;
        const num_curve_pts = 16;

        // Straight 1 (going +Y)
        var i: usize = 0;
        while (i < 8) : (i += 1) {
            const frac = @as(f64, @floatFromInt(i)) / 8.0;
            self.points[self.count] = .{
                .pos = HomVec4.init(radius, frac * straight_len, 0.0, 1.0),
                .tangent = .{ 0.0, 1.0, 0.0 },
                .banking_rad = 0.0,
                .width = 10.0,
            };
            self.count += 1;
        }

        // Turn 1 (North 180 deg)
        i = 0;
        while (i < num_curve_pts) : (i += 1) {
            const angle = (@as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(num_curve_pts))) * math.pi;
            const x = @cos(angle) * radius;
            const y = straight_len + @sin(angle) * radius;
            self.points[self.count] = .{
                .pos = HomVec4.init(x, y, 0.0, 1.0),
                .tangent = .{ -@sin(angle), @cos(angle), 0.0 },
                .banking_rad = 0.15, // 8.5 deg banked turn
                .width = 10.0,
            };
            self.count += 1;
        }

        // Straight 2 (going -Y)
        i = 0;
        while (i < 8) : (i += 1) {
            const frac = @as(f64, @floatFromInt(i)) / 8.0;
            self.points[self.count] = .{
                .pos = HomVec4.init(-radius, straight_len * (1.0 - frac), 0.0, 1.0),
                .tangent = .{ 0.0, -1.0, 0.0 },
                .banking_rad = 0.0,
                .width = 10.0,
            };
            self.count += 1;
        }

        // Turn 2 (South 180 deg)
        i = 0;
        while (i < num_curve_pts) : (i += 1) {
            const angle = math.pi + (@as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(num_curve_pts))) * math.pi;
            const x = @cos(angle) * radius;
            const y = @sin(angle) * radius;
            self.points[self.count] = .{
                .pos = HomVec4.init(x, y, 0.0, 1.0),
                .tangent = .{ -@sin(angle), @cos(angle), 0.0 },
                .banking_rad = 0.15,
                .width = 10.0,
            };
            self.count += 1;
        }
    }

    /// Find distance from arbitrary (x, y) to the nearest road center line
    pub fn distanceToTrack(self: *const Track, x: f64, y: f64) f64 {
        var min_dist_sq: f64 = 1e9;
        for (self.points[0..self.count]) |pt| {
            const dx = pt.pos.x - x;
            const dy = pt.pos.y - y;
            const d_sq = dx * dx + dy * dy;
            if (d_sq < min_dist_sq) min_dist_sq = d_sq;
        }
        return @sqrt(min_dist_sq);
    }
};

test "Track: Generate Oval Circuit" {
    var track = Track{};
    track.generateOval(30.0, 60.0);
    try std.testing.expect(track.count > 30);

    // Point on first straight is (30, 0..60)
    const dist_on_track = track.distanceToTrack(30.0, 0.0);
    try std.testing.expect(dist_on_track < 1.0);
}
