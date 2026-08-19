// =============================================================================
// P³ SCALE — ПЛАНЕТАРНЫЙ МАСШТАБ И КАЛИБРОВКА S³
// =============================================================================
//
// ФИЗИЧЕСКАЯ МОДЕЛЬ:
//
//   Сферический мир — 3-сфера S³ с радиусом R.
//   W-калибровка: W(s) = cos(s / 2R)
//
//   s — расстояние от «полюса» (северного полюса S³)
//   W — 4-я однородная координата, определяющая афинную карту
//
//   При s = 0:   W = 1     (северный полюс, «здесь»)
//   При s = πR:  W = 0     (экватор, переход на другую карту!)
//   При s = 2πR: W = −1    (южный полюс, антипод)
//
//   Это ФУНДАМЕНТАЛЬНО отличается от R³:
//   - В R³: W не существует, нет перехода между картами
//   - В P³: W → 0 — это РЕАЛЬНЫЙ геометрический эффект (смена аффинной карты)
//
// ПАРАМЕТРЫ МАСШТАБА:
//   R = 5,838,400 m      — базовый радиус планеты S³
//   g = 5.844 m/s²       — поверхностная гравитация
//   K_aniso = 9/7        — коэффициент анизотропии
//
// ТРАЕКТОРИИ:
//   1. s < πR:   W > 0 — траектория в пределах текущей карты
//   2. s = πR:   W = 0 — переход через экватор (смена карты)
//   3. s > πR:   W < 0 — антиподная траектория (противоположная карта)
// =============================================================================

const std = @import("std");
const math = std.math;
const p3_kernel = @import("p3_kernel.zig");

pub const HomVec4 = p3_kernel.HomVec4;

// =============================================================================
// 1. ПЛАНЕТАРНЫЕ КОНСТАНТЫ
// =============================================================================

/// Параметры планетарного масштаба S³
pub const PlanetScale = struct {
    /// Радиус S³ (метры)
    radius: f64 = 5_838_400.0,
    /// Масса тела (кг)
    mass: f64 = 2.9861e24,
    /// Средняя плотность (кг/м³)
    density: f64 = 3580.0,
    /// Поверхностная гравитация (m/s²)
    gravity: f64 = 5.844,
    /// Коэффициент анизотропии (K_aniso = 9/7)
    k_aniso: f64 = 9.0 / 7.0,
    /// Частота φ-поля (THz → Hz)
    f_phi: f64 = 1.4e12,
    /// Частота χ-поля / резонанса (Hz)
    f_chi: f64 = 18.7,
    /// Золотое сечение (для угла транзита)
    golden_ratio: f64 = 1.618033988749895,

    // Вычисленные
    /// Двойной радиус
    two_r: f64,
    /// Длина окружности S³ (2πR)
    circumference: f64,
    /// Половина окружности (πR — расстояние до экватора)
    half_circumference: f64,

    /// Создать с базовыми параметрами по умолчанию
    pub fn defaultSphere() PlanetScale {
        const r: f64 = 5_838_400.0;
        return .{
            .radius = r,
            .two_r = 2.0 * r,
            .circumference = 2.0 * math.pi * r,
            .half_circumference = math.pi * r,
        };
    }

    /// Алиас для совместимости
    pub const etheria = defaultSphere;

    /// Создать сферу на основе массы (кг) и плотности (кг/м³): R = (3M / (4πρ))^(1/3)
    pub fn fromMassAndDensity(mass_kg: f64, density_kg_m3: f64, resonance_hz: f64) PlanetScale {
        const G: f64 = 6.67430e-11;
        const volume_factor = (3.0 * mass_kg) / (4.0 * math.pi * density_kg_m3);
        const r = math.pow(f64, volume_factor, 1.0 / 3.0);
        const g = (G * mass_kg) / (r * r);
        return .{
            .radius = r,
            .mass = mass_kg,
            .density = density_kg_m3,
            .gravity = g,
            .f_chi = resonance_hz,
            .two_r = 2.0 * r,
            .circumference = 2.0 * math.pi * r,
            .half_circumference = math.pi * r,
        };
    }

    /// Создать сферу на основе радиуса (м) и гравитации (м/с²)
    pub fn fromRadiusAndGravity(radius_m: f64, gravity_m_s2: f64, resonance_hz: f64) PlanetScale {
        const G: f64 = 6.67430e-11;
        const mass_kg = (gravity_m_s2 * radius_m * radius_m) / G;
        const volume = (4.0 / 3.0) * math.pi * math.pow(f64, radius_m, 3.0);
        const density_kg_m3 = mass_kg / volume;
        return .{
            .radius = radius_m,
            .mass = mass_kg,
            .density = density_kg_m3,
            .gravity = gravity_m_s2,
            .f_chi = resonance_hz,
            .two_r = 2.0 * radius_m,
            .circumference = 2.0 * math.pi * radius_m,
            .half_circumference = math.pi * radius_m,
        };
    }

    /// Создать с параметрами Земли (R = 6,378,100 m, g = 9.80665 m/s², f_chi = 7.83 Hz)
    pub fn earth() PlanetScale {
        const r: f64 = 6_378_100.0;
        return .{
            .radius = r,
            .mass = 5.9722e24,
            .density = 5515.0,
            .gravity = 9.80665,
            .k_aniso = 1.0,
            .f_phi = 0.0,
            .f_chi = 7.83, // Резонанс Шумана
            .two_r = 2.0 * r,
            .circumference = 2.0 * math.pi * r,
            .half_circumference = math.pi * r,
        };
    }

    /// Создать с произвольным радиусом
    pub fn initWithRadius(r: f64) PlanetScale {
        return .{
            .radius = r,
            .two_r = 2.0 * r,
            .circumference = 2.0 * math.pi * r,
            .half_circumference = math.pi * r,
        };
    }

    /// Вторая космическая скорость (скорость освобождения) v_esc = √(2GM/R)
    pub fn escapeVelocity(self: PlanetScale) f64 {
        const G: f64 = 6.67430e-11;
        if (self.mass > 0) {
            return @sqrt((2.0 * G * self.mass) / self.radius);
        }
        return @sqrt(2.0 * self.gravity * self.radius);
    }

    /// Первая космическая (круговая орбитальная) скорость v_orb = √(GM/R)
    pub fn orbitalVelocity(self: PlanetScale, altitude_m: f64) f64 {
        const G: f64 = 6.67430e-11;
        const r_total = self.radius + altitude_m;
        if (self.mass > 0) {
            return @sqrt((G * self.mass) / r_total);
        }
        return @sqrt((self.gravity * self.radius * self.radius) / r_total);
    }

    /// Периодическое фазовое колебание среды на резонансной частоте f_chi
    pub fn phaseOscillation(self: PlanetScale, t: f64, amplitude: f64) f64 {
        return amplitude * @sin(2.0 * math.pi * self.f_chi * t);
    }

    // =================================================================
    // W-КАЛИБРОВКА
    // =================================================================

    /// W(s) = cos(s / 2R)
    /// W-координата как функция расстояния от полюса
    pub fn wFromDistance(self: PlanetScale, s: f64) f64 {
        return @cos(s / self.two_r);
    }

    /// Обратная: s(W) = 2R · arccos(W)
    /// Расстояние от полюса по W-координате
    pub fn distanceFromW(self: PlanetScale, w: f64) f64 {
        return self.two_r * math.acos(std.math.clamp(w, -1.0, 1.0));
    }

    /// Производная: dW/ds = −sin(s / 2R) / (2R)
    pub fn dWds(self: PlanetScale, s: f64) f64 {
        return -@sin(s / self.two_r) / self.two_r;
    }

    // =================================================================
    // ТРАЕКТОРИИ
    // =================================================================

    /// Класс траектории по расстоянию от полюса
    pub const TrajectoryClass = enum {
        normal, // W > 0 (та же карта)
        equatorial, // W ≈ 0 (переход между картами)
        antipodal, // W < 0 (другая карта)
    };

    /// Определить класс траектории
    pub fn trajectoryClass(self: PlanetScale, s: f64) TrajectoryClass {
        const w = self.wFromDistance(s);
        if (@abs(w) < 0.01) return .equatorial;
        if (w > 0) return .normal;
        return .antipodal;
    }

    /// Определить класс траектории по W
    pub fn trajectoryClassFromW(w: f64) TrajectoryClass {
        if (@abs(w) < 0.01) return .equatorial;
        if (w > 0) return .normal;
        return .antipodal;
    }

    // =================================================================
    // УГОЛ ТРАНЗИТА И МИКРО-СДВИГА
    // =================================================================

    /// Базовый квантовый угол транзита/микросдвига (радианы)
    /// λ = π × 10⁻¹⁰ rad
    pub fn transitAngle(self: PlanetScale) f64 {
        _ = self;
        return math.pi * 1e-10;
    }

    /// Расстояние транзита (метры)
    pub fn transitDistance(self: PlanetScale) f64 {
        return self.radius * self.transitAngle();
    }

    // =================================================================
    // FS-МЕТРИКА НА ПЛАНЕТАРНОМ МАСШТАБЕ
    // =================================================================

    /// FS-расстояние в метрах (а не в радианах)
    pub fn fsDistanceMeters(self: PlanetScale, p1: HomVec4, p2: HomVec4) f64 {
        const dist_rad = p3_kernel.fsDistance(p1, p2);
        return dist_rad * self.radius;
    }

    /// «Эффективное» расстояние с учётом голономии
    /// Для точек на разных картах — расстояние через экватор
    pub fn effectiveDistance(self: PlanetScale, s: f64) f64 {
        _ = self;
        // Планковская геодезическая: d_eff ≈ 2·ℓ_P
        // Минимальное разрешение масштаба
        const min_dist = 2.0 * 1.616255e-35; // 2 × ℓ_P (метры)
        return @max(s, min_dist);
    }
};

// =============================================================================
// 2. ФАЗОВЫЙ ПЕРЕХОД И ПЛОТНОСТЬ ГРАНИЦЫ
// =============================================================================
//
// Квадратичная активация плотности границы при превышении порогового угла:
// ρ(θ, θ_thresh) = sin²(θ − θ_thresh) · H(θ − θ_thresh)
// H — функция Хевисайда

/// Плотность фазового перехода с настраиваемым пороговым углом
pub fn criticalBoundaryDensityWithThreshold(theta_deg: f64, threshold_deg: f64) f64 {
    if (theta_deg <= threshold_deg) return 0.0;
    const diff = theta_deg - threshold_deg;
    const diff_rad = diff * math.pi / 180.0;
    return diff_rad * diff_rad; // sin²(x) ≈ x² для малых x
}

/// Плотность фазового перехода со стандартным порогом 85°
pub fn criticalBoundaryDensity(theta_deg: f64) f64 {
    return criticalBoundaryDensityWithThreshold(theta_deg, 85.0);
}

pub const nullFluidDensity = criticalBoundaryDensity; // Backwards compatibility alias

/// Угол между координатными гиперплоскостями W (W=1) и Z (Z=0) в P³
pub fn projectiveSubspaceAngle(point: HomVec4) f64 {
    const p = point.normalize();
    const w_abs = @abs(p.w);
    const z_abs = @abs(p.z);
    if (w_abs < 1e-15 and z_abs < 1e-15) return 45.0;
    // Угол в градусах
    const angle_rad = math.atan2(z_abs, w_abs);
    return angle_rad * 180.0 / math.pi;
}

pub const orderChaosAngle = projectiveSubspaceAngle; // Backwards compatibility alias

// =============================================================================
// 3. ОПЕРАЦИОННОЕ ВРЕМЯ T = c · dI/dΣ
// =============================================================================
//
// Т — время переноса/эволюции = константа × (скорость изменения информации) / (скорость изменения структуры)

/// Операционное время переноса/эволюции
/// T = c · dI / dΣ
/// c — константа связи, dI — изменение информации, dΣ — изменение структуры
pub fn operationalTime(c: f64, dI: f64, d_sigma: f64) f64 {
    if (@abs(d_sigma) < 1e-15) return 0.0;
    return c * dI / d_sigma;
}

// =============================================================================
// 4. ТЕСТЫ
// =============================================================================

test "Scale: PlanetScale.defaultSphere radius" {
    const ps = PlanetScale.defaultSphere();
    try std.testing.expectApproxEqAbs(ps.radius, 5_838_400.0, 1e-3);
}

test "Scale: W at pole = 1" {
    const ps = PlanetScale.defaultSphere();
    try std.testing.expectApproxEqAbs(ps.wFromDistance(0), 1.0, 1e-10);
}

test "Scale: W at equator ≈ 0" {
    const ps = PlanetScale.defaultSphere();
    try std.testing.expectApproxEqAbs(ps.wFromDistance(ps.half_circumference), 0.0, 1e-6);
}

test "Scale: W at antipode = -1" {
    const ps = PlanetScale.defaultSphere();
    try std.testing.expectApproxEqAbs(ps.wFromDistance(ps.circumference), -1.0, 1e-6);
}

test "Scale: trajectoryClass normal" {
    const ps = PlanetScale.defaultSphere();
    try std.testing.expect(ps.trajectoryClass(0) == .normal);
}

test "Scale: trajectoryClass antipodal" {
    const ps = PlanetScale.defaultSphere();
    try std.testing.expect(ps.trajectoryClass(ps.half_circumference * 1.1) == .antipodal);
}

test "Scale: distanceFromW roundtrip" {
    const ps = PlanetScale.defaultSphere();
    const s = 1_000_000.0; // 1000 km
    const w = ps.wFromDistance(s);
    const s2 = ps.distanceFromW(w);
    try std.testing.expectApproxEqAbs(s, s2, 1.0);
}

test "Scale: criticalBoundaryDensity below threshold = 0" {
    try std.testing.expectApproxEqAbs(criticalBoundaryDensity(80.0), 0.0, 1e-10);
}

test "Scale: criticalBoundaryDensity above threshold > 0" {
    try std.testing.expect(criticalBoundaryDensity(87.0) > 0);
}

test "Scale: criticalBoundaryDensity at 90°" {
    // sin²(5°) in radians ≈ (5π/180)² ≈ 0.00762
    const d = criticalBoundaryDensity(90.0);
    try std.testing.expect(d > 0);
    try std.testing.expect(d < 0.01);
}

test "Scale: projectiveSubspaceAngle at W-axis ≈ 0°" {
    const p = HomVec4.init(0, 0, 0, 1); // pure W
    const angle = projectiveSubspaceAngle(p);
    try std.testing.expectApproxEqAbs(angle, 0.0, 1.0);
}

test "Scale: orderChaosAngle at Z-axis ≈ 90°" {
    const p = HomVec4.init(0, 0, 1, 0); // pure Z
    const angle = orderChaosAngle(p);
    try std.testing.expectApproxEqAbs(angle, 90.0, 1.0);
}

test "Scale: operationalTime basic" {
    const t = operationalTime(1.0, 10.0, 2.0);
    try std.testing.expectApproxEqAbs(t, 5.0, 1e-10);
}

test "Scale: transitAngle is tiny" {
    const ps = PlanetScale.etheria();
    try std.testing.expect(ps.transitAngle() < 1e-8);
}

test "Scale: PlanetScale circumference" {
    const ps = PlanetScale.etheria();
    const expected = 2.0 * math.pi * 5_838_400.0;
    try std.testing.expectApproxEqAbs(ps.circumference, expected, 1.0);
}

test "Scale: earth preset and escape velocity" {
    const earth_scale = PlanetScale.earth();
    try std.testing.expectApproxEqAbs(earth_scale.radius, 6_378_100.0, 1.0);
    try std.testing.expectApproxEqAbs(earth_scale.gravity, 9.80665, 0.01);
    const v_esc = earth_scale.escapeVelocity();
    try std.testing.expectApproxEqAbs(v_esc, 11_180.0, 50.0); // ~11.18 km/s
}

test "Scale: fromMassAndDensity astrophysics" {
    // M = 2.9861e24 kg, rho = 3580 kg/m3 -> R ~ 5839.5 km, g ~ 5.844 m/s2
    const custom = PlanetScale.fromMassAndDensity(2.9861e24, 3580.0, 18.7);
    try std.testing.expectApproxEqAbs(custom.radius, 5_839_530.0, 100.0);
    try std.testing.expectApproxEqAbs(custom.gravity, 5.844, 0.01);
    const v_esc = custom.escapeVelocity();
    try std.testing.expectApproxEqAbs(v_esc, 8262.0, 20.0); // ~8.26 km/s
    const osc = custom.phaseOscillation(0.0, 1.0);
    try std.testing.expectApproxEqAbs(osc, 0.0, 1e-6);
}
