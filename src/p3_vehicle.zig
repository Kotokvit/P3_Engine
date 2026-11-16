//! =============================================================================
//! P³ VEHICLE DYNAMICS & COMPONENT HIERARCHY — ZIG
//! =============================================================================
//!
//! Modular vehicle physics engine built upon P³ homogeneous coordinates [X:Y:Z:W],
//! kinematic joints, Pacejka tire slip model, and detailed mechanical components
//! (engine, pistons, crankshaft, doors, suspension, wheels).
//!

const std = @import("std");
const math = std.math;
const p3_kernel = @import("p3_kernel.zig");
const p3_dual_quat = @import("p3_dual_quat.zig");

pub const HomVec4 = p3_kernel.HomVec4;
pub const DualQuat = p3_dual_quat.DualQuat;

/// Piston component inside an internal combustion engine
pub const Piston = struct {
    index: u8,
    stroke: f64 = 0.085, // 85mm stroke
    bore: f64 = 0.080, // 80mm bore
    position: f64 = 0.0, // normalized travel [0.0..1.0] (TDC to BDC)
    pressure_bar: f64 = 1.0, // Cylinder gas pressure in bars
    wear: f64 = 0.0, // 0.0 = mint, 1.0 = destroyed

    pub fn update(self: *Piston, crank_angle_rad: f64, is_power_stroke: bool) void {
        // Crank-slider kinematic calculation
        const offset_angle = crank_angle_rad + (@as(f64, @floatFromInt(self.index)) * math.pi * 0.5);
        self.position = (1.0 - @cos(offset_angle)) * 0.5;

        if (is_power_stroke and self.position < 0.3) {
            self.pressure_bar = 45.0 * (1.0 - self.position * 2.0); // Expansion combustion spike
        } else {
            self.pressure_bar = 1.0 + (1.0 - self.position) * 9.0; // Compression / exhaust
        }
    }
};

/// Modular Engine with internal pistons, crankshaft, and flywheel
pub const Engine = struct {
    num_cylinders: u8 = 4,
    pistons: [8]Piston = undefined,
    rpm: f64 = 800.0, // Idle RPM
    max_rpm: f64 = 7500.0,
    idle_rpm: f64 = 800.0,
    crank_angle: f64 = 0.0, // Radians
    throttle: f64 = 0.0, // [0.0..1.0]
    torque_nm: f64 = 0.0,
    running: bool = true,

    pub fn init(cylinders: u8) Engine {
        var eng = Engine{
            .num_cylinders = @min(cylinders, 8),
        };
        for (0..eng.num_cylinders) |i| {
            eng.pistons[i] = .{
                .index = @intCast(i),
            };
        }
        return eng;
    }

    pub fn update(self: *Engine, dt: f64, load_torque: f64) void {
        if (!self.running) {
            self.rpm = @max(0.0, self.rpm - 500.0 * dt);
            return;
        }

        // Update crank angle and pistons
        const rad_per_sec = (self.rpm * 2.0 * math.pi) / 60.0;
        self.crank_angle = @mod(self.crank_angle + rad_per_sec * dt, 4.0 * math.pi); // 4-stroke cycle = 720 deg

        for (0..self.num_cylinders) |i| {
            const is_power = (self.crank_angle >= @as(f64, @floatFromInt(i)) * math.pi * 0.5) and
                (self.crank_angle < (@as(f64, @floatFromInt(i)) + 1.0) * math.pi * 0.5);
            self.pistons[i].update(self.crank_angle, is_power);
        }

        // Torque curve synthesis based on RPM and throttle
        const rpm_norm = self.rpm / self.max_rpm;
        const base_torque = 280.0 * (4.0 * rpm_norm * (1.0 - rpm_norm)); // Peak torque at mid RPM
        self.torque_nm = @max(0.0, base_torque * (0.1 + 0.9 * self.throttle));

        // Engine acceleration: dRPM/dt = (T_engine - T_load) / Inertia
        const engine_inertia = 0.25; // kg*m^2
        const net_torque = self.torque_nm - load_torque - (self.rpm * 0.02);
        self.rpm += (net_torque / engine_inertia) * (60.0 / (2.0 * math.pi)) * dt;
        self.rpm = std.math.clamp(self.rpm, self.idle_rpm, self.max_rpm);
    }
};

/// Vehicle Door with hinge kinematics and latch state
pub const Door = struct {
    name: [16]u8,
    name_len: usize,
    open_angle: f64 = 0.0, // Radians [0.0..1.2] (~70 deg)
    target_angle: f64 = 0.0,
    open_speed: f64 = 2.5,
    is_latched: bool = true,
    is_detached: bool = false, // True if ripped off in a crash

    pub fn init(name: []const u8) Door {
        var d = Door{
            .name = undefined,
            .name_len = @min(name.len, 16),
        };
        @memcpy(d.name[0..d.name_len], name[0..d.name_len]);
        return d;
    }

    pub fn update(self: *Door, dt: f64) void {
        if (self.is_detached) return;
        if (self.open_angle < self.target_angle) {
            self.open_angle = @min(self.target_angle, self.open_angle + self.open_speed * dt);
        } else if (self.open_angle > self.target_angle) {
            self.open_angle = @max(self.target_angle, self.open_angle - self.open_speed * dt);
        }
        self.is_latched = (self.open_angle < 0.01);
    }
};

/// Wheel and Suspension with Pacejka Magic Formula Tire model
pub const Wheel = struct {
    id: u8,
    rel_pos: [3]f64, // Position relative to chassis center
    radius: f64 = 0.33, // 330mm tire radius
    suspension_travel: f64 = 0.15, // Max compression travel
    compression: f64 = 0.0, // Current compression [0.0..1.0]
    spring_stiffness: f64 = 35000.0, // N/m
    damper_rate: f64 = 2500.0, // N*s/m
    steer_angle: f64 = 0.0, // Radians
    angular_velocity: f64 = 0.0, // rad/s
    slip_ratio: f64 = 0.0,
    slip_angle: f64 = 0.0,
    is_powered: bool = false,
    is_steered: bool = false,

    /// Pacejka Magic Formula: F = D * sin(C * atan(B*s - E*(B*s - atan(B*s))))
    pub fn calcPacejkaForce(slip: f64, normal_force: f64) f64 {
        const B: f64 = 10.0; // Stiffness factor
        const C: f64 = 1.65; // Shape factor
        const D: f64 = normal_force * 1.0; // Peak friction factor (mu = 1.0)
        const E: f64 = -0.5; // Curvature factor

        const Bs = B * slip;
        const inner = Bs - E * (Bs - math.atan(Bs));
        return D * @sin(C * math.atan(inner));
    }
};

/// Full Modular Vehicle assembled with P³ Projective Coordinates
pub const Vehicle = struct {
    // P3 Homogeneous root transform [X : Y : Z : W_mass]
    pos: HomVec4 = HomVec4.init(0, 0, 0.35, 1.0),
    yaw: f64 = 0.0,
    pitch: f64 = 0.0,
    roll: f64 = 0.0,

    velocity: [3]f64 = .{ 0, 0, 0 }, // Local forward, lateral, vertical (m/s)
    angular_vel: [3]f64 = .{ 0, 0, 0 },

    mass_kg: f64 = 1250.0,

    // Modular Components
    engine: Engine,
    doors: [2]Door,
    wheels: [4]Wheel,

    // Controls
    steering: f64 = 0.0, // [-1.0..1.0]
    throttle: f64 = 0.0, // [0.0..1.0]
    brake: f64 = 0.0, // [0.0..1.0]
    gear: i8 = 1, // -1=R, 0=N, 1..6

    pub fn init() Vehicle {
        var v = Vehicle{
            .engine = Engine.init(4),
            .doors = .{
                Door.init("Left Door"),
                Door.init("Right Door"),
            },
            .wheels = undefined,
        };

        // Front Left / Front Right (Steered)
        v.wheels[0] = .{ .id = 0, .rel_pos = .{ -0.85, 1.3, -0.2 }, .is_steered = true, .is_powered = false };
        v.wheels[1] = .{ .id = 1, .rel_pos = .{ 0.85, 1.3, -0.2 }, .is_steered = true, .is_powered = false };
        // Rear Left / Rear Right (Powered RWD)
        v.wheels[2] = .{ .id = 2, .rel_pos = .{ -0.85, -1.3, -0.2 }, .is_steered = false, .is_powered = true };
        v.wheels[3] = .{ .id = 3, .rel_pos = .{ 0.85, -1.3, -0.2 }, .is_steered = false, .is_powered = true };

        return v;
    }

    pub fn speedKmh(self: *const Vehicle) f64 {
        const speed_ms = @sqrt(self.velocity[0] * self.velocity[0] + self.velocity[1] * self.velocity[1]);
        return speed_ms * 3.6;
    }

    pub fn update(self: *Vehicle, dt: f64) void {
        // 1. Update Engine & Controls
        self.engine.throttle = self.throttle;
        _ = self.wheels[2].radius;
        const gear_ratio: f64 = switch (self.gear) {
            1 => 3.5,
            2 => 2.2,
            3 => 1.5,
            4 => 1.1,
            5 => 0.85,
            else => 0.0,
        };
        const load_torque = if (self.gear != 0) (self.velocity[1] * 12.0) else 0.0;
        self.engine.update(dt, load_torque);

        // 2. Update Doors
        self.doors[0].update(dt);
        self.doors[1].update(dt);

        // 3. Update Wheel Steering & Drive forces
        const max_steer_rad: f64 = 0.55; // ~31 deg
        self.wheels[0].steer_angle = self.steering * max_steer_rad;
        self.wheels[1].steer_angle = self.steering * max_steer_rad;

        var total_drive_force: f64 = 0.0;
        if (self.gear > 0 and self.wheels[2].is_powered) {
            const drive_torque = self.engine.torque_nm * gear_ratio * 3.9; // 3.9 final drive
            total_drive_force = drive_torque / self.wheels[2].radius;
        }

        // 4. Resistance forces (Air Drag + Rolling Resistance)
        const v_forward = self.velocity[1];
        const air_drag = 0.5 * 1.225 * 0.32 * 2.2 * v_forward * @abs(v_forward); // 0.5 * rho * Cd * A * v^2
        const roll_resist = self.mass_kg * 9.81 * 0.015;
        const dir_sign: f64 = if (v_forward > 0.0) 1.0 else -1.0;
        const brake_force = self.brake * 6500.0 * dir_sign;

        const net_longitudinal_force = total_drive_force - air_drag - (if (v_forward > 0.1) roll_resist else 0.0) - brake_force;
        const accel_forward = net_longitudinal_force / self.mass_kg;

        self.velocity[1] += accel_forward * dt;
        if (self.velocity[1] < 0 and self.gear >= 0) self.velocity[1] = 0; // Prevent rolling back without reverse gear

        // 5. Yaw Turn Kinematics (Bicycle / Ackermann Model)
        if (@abs(self.velocity[1]) > 0.1) {
            const wheelbase = 2.6; // 2.6m distance between axles
            const yaw_rate = (self.velocity[1] / wheelbase) * @tan(self.wheels[0].steer_angle);
            self.yaw += yaw_rate * dt;
        }

        // 6. World P3 Position Integration
        const cos_y = @cos(self.yaw);
        const sin_y = @sin(self.yaw);
        const dx = self.velocity[1] * sin_y * dt;
        const dy = self.velocity[1] * cos_y * dt;

        self.pos.x += dx;
        self.pos.y += dy;
    }
};

test "Vehicle: Engine idle and throttle rev" {
    var v = Vehicle.init();
    try std.testing.expect(v.engine.rpm >= 799.0);

    v.throttle = 1.0;
    v.update(0.1);
    try std.testing.expect(v.engine.rpm > 800.0);
}

test "Vehicle: Acceleration and speed calculation" {
    var v = Vehicle.init();
    v.throttle = 1.0;
    for (0..50) |_| {
        v.update(0.02);
    }
    try std.testing.expect(v.speedKmh() > 5.0);
}
