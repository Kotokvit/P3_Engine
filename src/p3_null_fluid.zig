// =============================================================================
// P³ NULL-FLUID v1.0 — ZIG (GENERIC)
// =============================================================================
//
// Нуль-жидкость L_∅ и проективная оптика на P³.
//
// РЕФАКТОРИНГ: убрана хардкод-привязка к конкретному лору.
// Все физические параметры — аргументы структур/функций.
// Пользователь сам определяет: критический угол, константы,
// химический состав, спектральные классы.
//
// L_∅ = Ω ∩ χ | θ > θ_crit в P³ — фрустрированная критическая точка.
//
// Ключевые концепты:
//   ρ_∅(θ) = sin²(θ − θ_crit) · H(θ − θ_crit) — проективная плотность
//   n_∅ = i · n_Ω · √κ_φ — мнимый показатель преломления
//   δ_opt = λ/(2π·|Im(n_∅)|) — глубина проникновения
//   T_op/T_norm = (1 + κ·ρ_∅) / dΣ — спектр операционного времени
//   d_n = d_0·(n+½) — квантование погружения
//   n² = ε(ω) = 1 − ω_p²/[ω(ω + i·γ_coll)] — оптика Чёрного Зеркала
//
// Архитектор: Kotokvit (математик), Super Z (исполнение)
// =============================================================================

const std = @import("std");
const math = std.math;

/// Degrees to radians conversion constant
const deg_to_rad: f64 = math.pi / 180.0;

// =============================================================================
// 1. NULL-FLUID CONFIGURATION — ПОЛЬЗОВАТЕЛЬ САМ ЗАДАЁТ ПАРАМЕТРЫ
// =============================================================================

/// Конфигурация нуль-жидкости — все параметры задаёт пользователь.
///
/// Нет хардкода: движок не знает про конкретные миры,
/// он предоставляет математику, пользователь — данные.
pub const NullFluidConfig = struct {
    /// Критический угол (градусы) — порог L_∅
    theta_crit_deg: f64,
    /// Ширина фрустрированной зоны (градусы)
    delta_deg: f64,
    /// Показатель преломления Ω-среды
    n_omega: f64,
    /// Диэлектрическая проницаемость Ω
    eps_omega: f64,
    /// |Диэлектрическая проницаемость χ|
    eps_chi: f64,
    /// Скорость света (м/с)
    c_light: f64,
    /// Частота φ-поля (Гц)
    f_phi: f64,
    /// Фундаментальный шаг квантования погружения (м)
    d_k: f64,
    /// Константа связи для T_op спектра
    kappa: f64,

    /// Конфигурация по умолчанию (универсальная, не привязана к лору)
    pub fn initDefault() NullFluidConfig {
        return .{
            .theta_crit_deg = 85.0,
            .delta_deg = 5.0,
            .n_omega = 2.05,
            .eps_omega = 4.2,
            .eps_chi = 1.8,
            .c_light = 2.998e8,
            .f_phi = 1.4e12,
            .d_k = 0.02,
            .kappa = 7.2,
        };
    }

    /// Анизотропный коэффициент: κ_φ = |ε_χ| / ε_Ω
    pub inline fn kappaPhi(self: NullFluidConfig) f64 {
        return self.eps_chi / self.eps_omega;
    }

    /// Фундаментальный шаг: d_0 = d_K / 1.5
    pub inline fn d0(self: NullFluidConfig) f64 {
        return self.d_k / 1.5;
    }

    /// Скорость φ-информации: c_φ = c/√n_Ω (м/с)
    pub inline fn cPhi(self: NullFluidConfig) f64 {
        return self.c_light / @sqrt(self.n_omega);
    }

    /// Время релаксации: τ = 1/f_φ (с)
    pub inline fn tauRelax(self: NullFluidConfig) f64 {
        return 1.0 / self.f_phi;
    }
};

// =============================================================================
// 2. ПРОЕКТИВНАЯ ПЛОТНОСТЬ ρ_∅
// =============================================================================

/// Проективная плотность нуль-жидкости.
///
/// ρ_∅(θ) = sin²(θ − θ_crit) · H(θ − θ_crit)
///
/// Exact формула (без малых углов): sin² вместо x².
pub fn nullFluidDensityExact(theta_deg: f64, theta_crit_deg: f64) f64 {
    if (theta_deg <= theta_crit_deg) return 0.0;
    const diff_rad = deg_to_rad * (theta_deg - theta_crit_deg);
    const s = math.sin(diff_rad);
    return s * s;
}

/// Проективная плотность — малые углы (для GPU).
///
/// Для θ − θ_crit ≪ 1: sin²(x) ≈ x²
pub fn nullFluidDensitySmallAngle(theta_deg: f64, theta_crit_deg: f64) f64 {
    if (theta_deg <= theta_crit_deg) return 0.0;
    const diff_rad = deg_to_rad * (theta_deg - theta_crit_deg);
    return diff_rad * diff_rad;
}

// =============================================================================
// 3. ПРОЕКТИВНАЯ ОПТИКА
// =============================================================================

/// Результат проективной оптики.
///
/// n_∅ = i · n_Ω · √κ_φ — мнимый показатель преломления.
/// Физически: поле не распространяется как волна в L_∅,
/// а экспоненциально затухает (evanescent).
pub const ProjectiveOptics = struct {
    /// κ_φ = |ε_χ| / ε_Ω — анизотропный коэффициент
    kappa_phi: f64,
    /// |Im(n_∅)| = n_Ω · √κ_φ — модуль мнимого показателя
    n_null_abs: f64,
    /// Длина волны φ-поля (м)
    lambda_phi: f64,
    /// Глубина проникновения δ_opt = λ / (2π·|Im(n_∅)|) (м)
    delta_opt: f64,

    /// Вычислить проективную оптику из конфигурации
    pub fn compute(cfg: NullFluidConfig) ProjectiveOptics {
        const kp = cfg.kappaPhi();
        const sqrt_kp = @sqrt(kp);
        const n_abs = cfg.n_omega * sqrt_kp;
        const lambda = cfg.c_light / cfg.f_phi;
        const delta = lambda / (2.0 * math.pi * n_abs);
        return .{
            .kappa_phi = kp,
            .n_null_abs = n_abs,
            .lambda_phi = lambda,
            .delta_opt = delta,
        };
    }
};

// =============================================================================
// 4. СПЕКТР ОПЕРАЦИОННОГО ВРЕМЕНИ T_op
// =============================================================================

/// Спектр операционного времени T_op в L_∅.
///
/// T_op/T_norm = (1 + κ·ρ_∅) / (sin²(δ·r/r_0) / sin²(δ))
///
/// При r → 0: T_op → ∞ (центр L_∅ — горизонт операций)
/// При r → r_0: T_op → конечное (граница L_∅)
pub fn operationalTimeSpectrum(r_ratio: f64, cfg: NullFluidConfig) f64 {
    const theta_r = 90.0 - cfg.delta_deg * r_ratio;
    const rho_r = nullFluidDensityExact(theta_r, cfg.theta_crit_deg);

    const delta_rad = deg_to_rad * cfg.delta_deg;
    const sin2_delta = math.sin(delta_rad) * math.sin(delta_rad);
    const arg = delta_rad * r_ratio;
    const sin2_arg = math.sin(arg) * math.sin(arg);
    const d_sigma = sin2_arg / sin2_delta;

    if (d_sigma < 1e-10) return std.math.floatMax(f64);
    return (1.0 + cfg.kappa * rho_r) / d_sigma;
}

// =============================================================================
// 5. КВАНТОВАНИЕ ПОГРУЖЕНИЯ
// =============================================================================

/// Квантованные глубины погружения в L_∅.
///
/// d_n = d_0 · (n + ½), где d_0 = d_K / 1.5
pub fn immersionDepth(n: u32, cfg: NullFluidConfig) f64 {
    return cfg.d0() * (@as(f64, @floatFromInt(n)) + 0.5);
}

// =============================================================================
// 6. СПЕКТРАЛЬНЫЕ КЛАССЫ — ПОЛЬЗОВАТЕЛЬ САМ ОПРЕДЕЛЯЕТ
// =============================================================================

/// Спектральный класс для неэрмитова гамильтониана.
///
/// Пользователь сам определяет, какие классы нужны.
/// Стандартные три: α (метастабильный), β (резидентный), γ (мгновенный).
pub const SpectralClass = enum(u2) {
    /// E < 0, Γ ≈ 0, τ → ∞ — метастабильный
    alpha = 0,
    /// E < 0, Γ > 0, τ > threshold — резидентный
    beta = 1,
    /// E > 0, τ ≈ мгновенный — распад
    gamma = 2,
};

/// Параметры спектрального класса — пользователь задаёт пороги.
pub const SpectralClassConfig = struct {
    /// Порог для Γ (ширина резонанса)
    gamma_threshold: f64,
    /// Порог для τ (время жизни, секунды)
    tau_threshold: f64,
    /// Порог энергии: E < 0 → bound, E > 0 → continuum
    energy_threshold: f64,

    pub fn initDefault() SpectralClassConfig {
        return .{
            .gamma_threshold = 1e-3,
            .tau_threshold = 4.0,
            .energy_threshold = 0.0,
        };
    }

    /// Классифицировать состояние по энергии, ширине и времени жизни
    pub fn classify(self: SpectralClassConfig, energy: f64, gamma_width: f64, tau: f64) SpectralClass {
        if (energy > self.energy_threshold) return .gamma;
        if (gamma_width < self.gamma_threshold) return .alpha;
        if (tau > self.tau_threshold) return .beta;
        return .gamma;
    }
};

// =============================================================================
// 7. ОПТИКА ЧЁРНОГО ЗЕРКАЛА (DRUDE-LORENZ)
// =============================================================================

/// Оптика Чёрного Зеркала — плазменная металлизация.
///
/// n² = ε(ω) = 1 − ω_p² / [ω · (ω + i·γ_coll)]
///
/// При γ_coll → 0: ε → чисто мнимый → 100% отражение без дисперсии.
pub const BlackMirrorOptics = struct {
    /// Плазменная частота (рад/с)
    omega_p: f64,
    /// Частота рассеяния (рад/с)
    gamma_coll: f64,
    /// Частота наблюдения (рад/с)
    omega: f64,

    /// Вычислить диэлектрическую проницаемость ε(ω) = ε_real + i·ε_imag
    pub fn dielectric(self: BlackMirrorOptics) struct { re: f64, im: f64 } {
        const w = self.omega;
        const wp2 = self.omega_p * self.omega_p;
        const gc = self.gamma_coll;

        const denom = w * (w * w + gc * gc);
        if (@abs(denom) < 1e-30) return .{ .re = 1.0, .im = 0.0 };

        const re = 1.0 - wp2 * w / denom;
        const im = wp2 * gc / denom;
        return .{ .re = re, .im = im };
    }

    /// Коэффициент отражения R ≈ ((|n| - 1) / (|n| + 1))²
    pub fn reflectivity(self: BlackMirrorOptics) f64 {
        const eps = self.dielectric();
        const eps_abs = @sqrt(eps.re * eps.re + eps.im * eps.im);
        const n_abs = @sqrt(eps_abs);
        const ratio = (n_abs - 1.0) / (n_abs + 1.0);
        return ratio * ratio;
    }
};

// =============================================================================
// 8. ХИМИЧЕСКАЯ СИСТЕМА — ПОЛЬЗОВАТЕЛЬ САМ ЗАДАЁТ
// =============================================================================

/// Химический элемент/соединение — параметризуемый, без хардкода.
pub const ChemicalSpecies = struct {
    /// Название
    name: []const u8,
    /// Проводимость σ_e
    sigma_e: f64,
    /// Порог CNED
    cned_threshold: f64,

    /// CNED-риск: σ_e < threshold → высокий риск
    pub inline fn cnedRisk(self: ChemicalSpecies) bool {
        return self.sigma_e < self.cned_threshold;
    }
};

/// Зона нуль-жидкости — пользователь определяет состав.
pub const NullFluidZone = struct {
    cfg: NullFluidConfig,
    /// Максимальное расстояние от центра (м)
    r_0: f64,
    /// Проводимость зоны
    sigma_e: f64,
    /// CNED-порог
    cned_threshold: f64,

    /// Время информационного распространения на расстояние L
    pub fn infoTime(self: NullFluidZone, L: f64) f64 {
        return L / self.cfg.cPhi();
    }

    /// CNED-риск
    pub inline fn cnedRisk(self: NullFluidZone) bool {
        return self.sigma_e < self.cned_threshold;
    }
};

// =============================================================================
// 9. КРУГ КОСТЕЙ (χ-Leviathans) — ОБОБЩЁННЫЙ
// =============================================================================

/// Точка на обобщённом «Круге» — N точек на θ = const.
///
/// Point_k = [sin(θ)·cos(φ_k), sin(θ)·sin(φ_k), 0, cos(θ)]
/// где φ_k = 2π·k/N
pub fn circlePoint(k: u32, n: u32, theta_deg: f64) [4]f64 {
    const theta_rad = theta_deg * deg_to_rad;
    const phi_rad = 2.0 * math.pi * @as(f64, @floatFromInt(k)) / @as(f64, @floatFromInt(n));
    const st = math.sin(theta_rad);
    const ct = math.cos(theta_rad);
    return .{
        st * math.cos(phi_rad),
        st * math.sin(phi_rad),
        0.0,
        ct,
    };
}

// =============================================================================
// 10. ТЕСТЫ
// =============================================================================

test "nullFluidDensityExact: zero below θ_crit" {
    const cfg = NullFluidConfig.initDefault();
    try std.testing.expectApproxEqAbs(nullFluidDensityExact(80.0, cfg.theta_crit_deg), 0.0, 1e-10);
    try std.testing.expectApproxEqAbs(nullFluidDensityExact(85.0, cfg.theta_crit_deg), 0.0, 1e-10);
}

test "nullFluidDensityExact: sin² at θ = 90°" {
    const cfg = NullFluidConfig.initDefault();
    const rho = nullFluidDensityExact(90.0, cfg.theta_crit_deg);
    const expected = math.sin(5.0 * deg_to_rad) * math.sin(5.0 * deg_to_rad);
    try std.testing.expectApproxEqAbs(rho, expected, 1e-10);
}

test "nullFluidDensityExact: increases monotonically" {
    const cfg = NullFluidConfig.initDefault();
    const rho_86 = nullFluidDensityExact(86.0, cfg.theta_crit_deg);
    const rho_87 = nullFluidDensityExact(87.0, cfg.theta_crit_deg);
    const rho_88 = nullFluidDensityExact(88.0, cfg.theta_crit_deg);
    try std.testing.expect(rho_86 < rho_87);
    try std.testing.expect(rho_87 < rho_88);
}

test "nullFluidDensityExact vs small-angle: agree near θ_crit" {
    const cfg = NullFluidConfig.initDefault();
    const rho_exact = nullFluidDensityExact(85.5, cfg.theta_crit_deg);
    const rho_small = nullFluidDensitySmallAngle(85.5, cfg.theta_crit_deg);
    try std.testing.expectApproxEqAbs(rho_exact, rho_small, rho_exact * 0.02);
}

test "nullFluidDensityExact: L_∅ is NOT nothing at θ = 90°" {
    const cfg = NullFluidConfig.initDefault();
    const rho = nullFluidDensityExact(90.0, cfg.theta_crit_deg);
    try std.testing.expect(rho > 0.0);
}

test "NullFluidConfig: custom parameters" {
    const cfg = NullFluidConfig{
        .theta_crit_deg = 80.0,
        .delta_deg = 10.0,
        .n_omega = 1.5,
        .eps_omega = 3.0,
        .eps_chi = 1.2,
        .c_light = 3e8,
        .f_phi = 2e12,
        .d_k = 0.01,
        .kappa = 5.0,
    };
    try std.testing.expectApproxEqAbs(cfg.kappaPhi(), 0.4, 1e-10);
    try std.testing.expectApproxEqAbs(cfg.d0(), 0.01 / 1.5, 1e-15);
}

test "ProjectiveOptics: compute values" {
    const cfg = NullFluidConfig.initDefault();
    const optics = ProjectiveOptics.compute(cfg);
    try std.testing.expectApproxEqAbs(optics.kappa_phi, 1.8 / 4.2, 1e-10);
    try std.testing.expect(optics.n_null_abs > 1.0);
    try std.testing.expect(optics.n_null_abs < 2.0);
    try std.testing.expect(optics.delta_opt > 1e-6);
    try std.testing.expect(optics.delta_opt < 1e-3);
}

test "operationalTimeSpectrum: diverges at r=0" {
    const cfg = NullFluidConfig.initDefault();
    const T = operationalTimeSpectrum(0.0, cfg);
    try std.testing.expect(T > 1e10);
}

test "operationalTimeSpectrum: finite at r=r_0" {
    const cfg = NullFluidConfig.initDefault();
    const T = operationalTimeSpectrum(1.0, cfg);
    try std.testing.expect(T < 1e10);
    try std.testing.expect(T > 0);
}

test "immersionDepth: d_0*(n+0.5)" {
    const cfg = NullFluidConfig.initDefault();
    try std.testing.expectApproxEqAbs(immersionDepth(0, cfg), cfg.d0() * 0.5, 1e-15);
    try std.testing.expectApproxEqAbs(immersionDepth(1, cfg), cfg.d_k, 1e-15);
}

test "SpectralClassConfig: classify" {
    const sc = SpectralClassConfig.initDefault();
    // Gamma class: E > 0
    try std.testing.expect(sc.classify(1.0, 0.1, 1.0) == .gamma);
    // Alpha class: E < 0, small gamma
    try std.testing.expect(sc.classify(-1.0, 1e-6, 1e10) == .alpha);
    // Beta class: E < 0, large gamma, long tau
    try std.testing.expect(sc.classify(-1.0, 0.1, 10.0) == .beta);
}

test "BlackMirrorOptics: high reflectivity at low gamma_coll" {
    const bm = BlackMirrorOptics{
        .omega_p = 1e15,
        .gamma_coll = 1e6,
        .omega = 1e15,
    };
    const R = bm.reflectivity();
    try std.testing.expect(R > 0.9);
}

test "BlackMirrorOptics: lower reflectivity at high gamma_coll" {
    const bm = BlackMirrorOptics{
        .omega_p = 1e15,
        .gamma_coll = 1e15,
        .omega = 1e15,
    };
    const R = bm.reflectivity();
    try std.testing.expect(R < 1.0);
}

test "ChemicalSpecies: CNED risk" {
    const species = ChemicalSpecies{
        .name = "element_A",
        .sigma_e = 1.5,
        .cned_threshold = 5.0,
    };
    try std.testing.expect(species.cnedRisk());

    const species2 = ChemicalSpecies{
        .name = "element_B",
        .sigma_e = 7.2,
        .cned_threshold = 5.0,
    };
    try std.testing.expect(!species2.cnedRisk());
}

test "NullFluidZone: info time" {
    const zone = NullFluidZone{
        .cfg = NullFluidConfig.initDefault(),
        .r_0 = 0.5,
        .sigma_e = 4.0,
        .cned_threshold = 5.0,
    };
    const tau = zone.infoTime(100.0);
    try std.testing.expect(tau > 1e-9);
    try std.testing.expect(tau < 1e-5);
    try std.testing.expect(zone.cnedRisk());
}

test "circlePoint: all on S³" {
    const theta = 80.0;
    const n: u32 = 12;
    for (0..n) |k| {
        const p = circlePoint(@intCast(k), n, theta);
        const norm_sq = p[0] * p[0] + p[1] * p[1] + p[2] * p[2] + p[3] * p[3];
        try std.testing.expectApproxEqAbs(norm_sq, 1.0, 1e-10);
    }
}

test "circlePoint: custom N and θ" {
    const p = circlePoint(0, 8, 70.0);
    try std.testing.expectApproxEqAbs(p[3], math.cos(70.0 * deg_to_rad), 1e-10);
}
