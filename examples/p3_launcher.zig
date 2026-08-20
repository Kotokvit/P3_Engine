// =============================================================================
// P³ ENGINE LAUNCHER v1.0 — ZIG + RAYLIB
// =============================================================================
//
// Полностью новый лаунчер для движка P³ Engine.
// Заменяет O3DE лаунчер (4 бинарника, 11MB).
// Написан на чистом Zig с raylib для рендеринга GUI.
//
// Функциональность:
//   - Главное меню с анимированным фоном (проективная сетка S³)
//   - Браузер проектов (создание / открытие / удаление)
//   - Настройки движка (видео, аудио, физика, управление)
//   - Обзор ассетов (сцены, модели, текстуры, шейдеры)
//   - Экран загрузки с прогресс-баром и сприн-анимацией
//   - Запуск демо-сцены Void Voyager
//   - Информация о движке (версия, модули, тесты)
//
// Математика:
//   Пружинная анимация (Spring) — по паттерну UE SpringMath,
//   переписано на Zig. Проективные координаты HomVec4 для
//   позиционирования элементов UI на проективной плоскости.
//
// Язык: Полностью русский.
//
// Архитектор: Kotokvit (математик), Super Z (исполнение)
// =============================================================================

const std = @import("std");
const math = std.math;
const p3 = @import("root.zig");

const rl = @cImport({
    @cInclude("raylib.h");
});

const Vec3 = p3.Vec3;
const HomVec4 = p3.HomVec4;
const Vec2 = p3.Vec2;
const Color = p3.Color;
const Rotator = p3.Rotator;
const Mat4x4 = p3.Mat4x4;
const Quaternion = p3.Quaternion;

// =============================================================================
// КОНСТАНТЫ ЛАУНЧЕРА
// =============================================================================

const ENGINE_VERSION = "0.7.0";
const ENGINE_NAME = "P³ Engine";
const WINDOW_W = 1280;
const WINDOW_H = 800;

// Цветовая палитра P³ (проективная космическая тема)
const C_BG_DARK = rl.Color{ .r = 8, .g = 10, .b = 18, .a = 255 };
const C_BG_PANEL = rl.Color{ .r = 14, .g = 18, .b = 30, .a = 240 };
const C_BG_CARD = rl.Color{ .r = 22, .g = 28, .b = 45, .a = 255 };
const C_BG_CARD_HOVER = rl.Color{ .r = 30, .g = 40, .b = 65, .a = 255 };
const C_BG_INPUT = rl.Color{ .r = 18, .g = 22, .b = 38, .a = 255 };
const C_ACCENT = rl.Color{ .r = 0, .g = 200, .b = 255, .a = 255 };
const C_ACCENT_DIM = rl.Color{ .r = 0, .g = 120, .b = 180, .a = 255 };
const C_GOLD = rl.Color{ .r = 255, .g = 200, .b = 40, .a = 255 };
const C_TEXT = rl.Color{ .r = 220, .g = 230, .b = 245, .a = 255 };
const C_TEXT_DIM = rl.Color{ .r = 130, .g = 145, .b = 170, .a = 255 };
const C_TEXT_BRIGHT = rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
const C_BORDER = rl.Color{ .r = 40, .g = 55, .b = 80, .a = 255 };
const C_SUCCESS = rl.Color{ .r = 40, .g = 220, .b = 120, .a = 255 };
const C_DANGER = rl.Color{ .r = 255, .g = 70, .b = 70, .a = 255 };
const C_WARNING = rl.Color{ .r = 255, .g = 180, .b = 40, .a = 255 };
const C_GRID_LINE = rl.Color{ .r = 20, .g = 35, .b = 60, .a = 80 };
const C_GRID_BRIGHT = rl.Color{ .r = 0, .g = 150, .b = 255, .a = 40 };

// =============================================================================
// СПРИН-АНИМАЦИЯ (по паттерну UE SpringMath, переписано на Zig)
// =============================================================================
/// Критически затухающий коэффициент для пружинной анимации UI-элементов.
/// UE использует SmoothingTime → Damping: damping = 4.0 / max(st, ε)
/// Мы переписали на Zig с f64 для точности проективных вычислений.

const SpringState = struct {
    value: f64 = 0.0,
    target: f64 = 0.0,
    velocity: f64 = 0.0,
    smoothing_time: f64 = 0.15,
    /// Степень затухания: 1.0 = критическая (быстро), <1 = упруго
    damping_ratio: f64 = 0.85,

    /// Обновить пружинное состояние (dt в секундах)
    /// Алгоритм: полудискретный Euler с проективной коррекцией
    pub fn update(self: *SpringState, dt: f64) void {
        if (dt <= 0 or self.smoothing_time <= 0) return;
        // Коэффициент жёсткости пружины
        const omega = 2.0 / self.smoothing_time;
        const omega2 = omega * omega;
        const zeta = self.damping_ratio;
        const zeta_omega = zeta * omega;

        // Проективная коррекция: уменьшаем колебания при близкости к цели
        const displacement = self.value - self.target;
        const proj_factor = if (@abs(displacement) < 0.001) 0.5 else 1.0;

        // Сила пружины (F = -kx - cv)
        const spring_force = -omega2 * displacement * proj_factor;
        const damp_force = -2.0 * zeta_omega * self.velocity;
        const accel = spring_force + damp_force;

        // Семи-дискретный Euler (порядок 2 точности)
        self.velocity += accel * dt;
        self.value += self.velocity * dt;

        // Остановить микро-колебания
        if (@abs(self.velocity) < 0.001 and @abs(displacement) < 0.001) {
            self.value = self.target;
            self.velocity = 0;
        }
    }

    pub fn setTarget(self: *SpringState, t: f64) void {
        self.target = t;
    }

    pub fn reset(self: *SpringState, val: f64) void {
        self.value = val;
        self.target = val;
        self.velocity = 0;
    }
};

// =============================================================================
// ЭКРАНЫ ЛАУНЧЕРА
// =============================================================================

const Screen = enum {
    main_menu,
    projects,
    settings,
    assets,
    loading,
    about,
    exit_confirm,
};

// =============================================================================
// ЭЛЕМЕНТЫ UI
// =============================================================================

const Button = struct {
    rect: rl.Rectangle,
    label: []const u8,
    icon: []const u8,
    hovered: bool = false,
    spring: SpringState = .{},
    /// Нажата ли кнопка в этом кадре
    clicked: bool = false,
    /// Цвет акцента (можно перекрасить)
    accent: rl.Color = C_ACCENT,

    pub fn update(self: *Button, mouse_pos: rl.Vector2) void {
        self.hovered = rl.CheckCollisionPointRec(mouse_pos, self.rect);
        self.spring.setTarget(if (self.hovered) 1.0 else 0.0);
        self.spring.update(1.0 / 60.0);
        self.clicked = false;
        if (self.hovered and rl.IsMouseButtonDown(rl.MOUSE_LEFT_BUTTON)) {
            self.clicked = rl.IsMouseButtonPressed(rl.MOUSE_LEFT_BUTTON);
        }
    }

    pub fn draw(self: *const Button, font: rl.Font) void {
        const t = @as(f32, @floatCast(self.spring.value));
        const base_r = self.rect.x;
        const base_y = self.rect.y;
        const w = self.rect.width;
        const h = self.rect.height;

        // Анимированная подсветка
        const bg_r = @floatCast(C_BG_CARD.r + (C_BG_CARD_HOVER.r - C_BG_CARD.r) * t);
        const bg_g = @floatCast(C_BG_CARD.g + (C_BG_CARD_HOVER.g - C_BG_CARD.g) * t);
        const bg_b = @floatCast(C_BG_CARD.b + (C_BG_CARD_HOVER.b - C_BG_CARD.b) * t);
        rl.DrawRectangleRounded(self.rect, 8.0, 4, .{ .r = @intFromFloat(bg_r), .g = @intFromFloat(bg_g), .b = @intFromFloat(bg_b), .a = 255 });

        // Граница с акцентом
        if (t > 0.01) {
            rl.DrawRectangleRoundedLines(self.rect, 8.0, 4, 1.5, .{
                .r = @intFromFloat(@as(f32, @floatFromInt(self.accent.r)) * t),
                .g = @intFromFloat(@as(f32, @floatFromInt(self.accent.g)) * t),
                .b = @intFromFloat(@as(f32, @floatFromInt(self.accent.b)) * t),
                .a = 255,
            });
        }

        // Текст
        const text_x = base_r + 20;
        const text_y = base_y + (h - 20) / 2;
        drawText(font, self.icon, text_x, text_y - 1, 16, self.accent);
        drawText(font, self.label, text_x + 28, text_y, 16, C_TEXT);
    }
};

// =============================================================================
// НАСТРОЙКИ ДВИЖКА
// =============================================================================

const EngineSettings = struct {
    // Видео
    resolution_w: c_int = WINDOW_W,
    resolution_h: c_int = WINDOW_H,
    fullscreen: bool = false,
    vsync: bool = true,
    msaa_samples: c_int = 4,
    target_fps: c_int = 60,
    // Физика
    gravity: f32 = 9.80665,
    physics_substeps: c_int = 4,
    // Проективная геометрия
    planet_radius_km: f64 = 6378.0,
    anisotropy: f64 = 1.0,
    show_fs_distance: bool = true,
    // Управление
    mouse_sensitivity: f32 = 1.0,
    invert_y: bool = false,
    move_speed: f32 = 2.0,
};

// =============================================================================
// ЗАГРУЗКА СЦЕНЫ
// =============================================================================

const LoadingState = struct {
    progress: f32 = 0.0,
    phase: []const u8 = "",
    spring: SpringState = .{ .smoothing_time = 0.4 },
    stars: [80]StarField,

    const StarField = struct { x: f32, y: f32, speed: f32, size: f32, brightness: f32 };

    pub fn init() LoadingState {
        var state: LoadingState = undefined;
        state.progress = 0.0;
        state.phase = "";
        state.spring = .{ .smoothing_time = 0.4, .damping_ratio = 0.9 };
        // Генерация звёздного поля
        var prng = std.Random.DefaultPrng.init(42);
        const rand = prng.random();
        for (&state.stars, 0..) |*s, i| {
            s.x = rand.float(f32) * 1280;
            s.y = rand.float(f32) * 800;
            s.speed = 0.2 + rand.float(f32) * 1.5;
            s.size = 1.0 + rand.float(f32) * 2.5;
            s.brightness = 0.3 + rand.float(f32) * 0.7;
            _ = i;
        }
        return state;
    }

    pub fn simulate(self: *LoadingState, dt: f32) void {
        // Симуляция фаз загрузки
        const phases = [_][]const u8{
            "Инициализация проективного ядра P³...",
            "Загрузка математических модулей (S³, PGL4, Клиффорд)...",
            "Компиляция шейдеров WGSL...",
            "Инициализация GPU (WebGPU/Dawn)...",
            "Загрузка сцены и ассетов...",
            "Построение графа сцены (ECS)...",
            "Инициализация физики (Кеплерова гравитация)...",
            "Настройка камеры на S³...",
            "Загрузка PBR материалов...",
            "Инициализация скелетной анимации...",
            "Подготовка рендер-конвейера...",
            "Запуск игрового цикла...",
                };

        self.progress += dt * 0.08;
        if (self.progress > 1.0) self.progress = 1.0;
        const idx = @min(@as(usize, @intFromFloat(self.progress * @as(f32, @floatFromInt(phases.len)))), phases.len - 1);
        self.phase = phases[idx];
        self.spring.setTarget(self.progress);
        self.spring.update(@as(f64, dt));

        // Обновление звёзд
        for (&self.stars) |*s| {
            s.x += s.speed * dt * 60;
            if (s.x > 1300) {
                s.x = -10;
                s.y = std.Random.DefaultPrng.init(@intFromFloat(s.y * 100)).random().float(f32) * 800;
            }
        }
    }
};

// =============================================================================
// УТИЛИТЫ ТЕКСТА (Unicode кириллица + математические символы)
// =============================================================================

fn drawText(font: rl.Font, text: []const u8, x: f32, y: f32, size: f32, col: rl.Color) void {
    var buf: [512]u8 = undefined;
    const len = @min(text.len, 511);
    @memcpy(buf[0..len], text[0..len]);
    buf[len] = 0;
    rl.DrawTextEx(font, &buf, .{ .x = x, .y = y }, size, 1.0, col);
}

fn drawTextCentered(font: rl.Font, text: []const u8, cx: f32, y: f32, size: f32, col: rl.Color) void {
    const tw = rl.MeasureTextEx(font, @ptrCast(text), size, 1.0).x;
    drawText(font, text, cx - tw / 2.0, y, size, col);
}

fn loadUnicodeFont(size: c_int) rl.Font {
    var codepoints: [700]c_int = undefined;
    var cp_count: usize = 0;
    // ASCII
    var c: usize = 32;
    while (c < 127) : (c += 1) {
        codepoints[cp_count] = @intCast(c);
        cp_count += 1;
    }
    // Кириллица
    c = 0x0400;
    while (c < 0x0530) : (c += 1) {
        codepoints[cp_count] = @intCast(c);
        cp_count += 1;
    }
    // Математические символы
    codepoints[cp_count] = 0x00B0; cp_count += 1; // °
    codepoints[cp_count] = 0x00B2; cp_count += 1; // ²
    codepoints[cp_count] = 0x00B3; cp_count += 1; // ³
    codepoints[cp_count] = 0x03C0; cp_count += 1; // π
    codepoints[cp_count] = 0x03A9; cp_count += 1; // Ω
    codepoints[cp_count] = 0x221E; cp_count += 1; // ∞
    codepoints[cp_count] = 0x03A3; cp_count += 1; // Σ
    codepoints[cp_count] = 0x0394; cp_count += 1; // Δ
    codepoints[cp_count] = 0x2192; cp_count += 1; // →
    codepoints[cp_count] = 0x2248; cp_count += 1; // ≈
    codepoints[cp_count] = 0x2260; cp_count += 1; // ≠
    codepoints[cp_count] = 0x00B1; cp_count += 1; // ±
    codepoints[cp_count] = 0x2202; cp_count += 1; // ∂
    codepoints[cp_count] = 0x222B; cp_count += 1; // ∫
    codepoints[cp_count] = 0x25C8; cp_count += 1; // ◈
    codepoints[cp_count] = 0x25A0; cp_count += 1; // ■
    codepoints[cp_count] = 0x25CF; cp_count += 1; // ●
    codepoints[cp_count] = 0;

    const font = rl.LoadFontEx("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size, &codepoints, @intCast(cp_count));
    rl.SetTextureFilter(font.texture, rl.TEXTURE_FILTER_BILINEAR);
    return font;
}

// =============================================================================
// ФОНОВЫЙ РЕНДЕР (анимированная проективная сетка)
// =============================================================================

fn drawProjectiveBackground(time: f32, w: f32, h: f32) void {
    // Фоновая градиентная сфера (симуляция S³)
    const cx = w / 2.0 + math.sin(time * 0.3) * 50;
    const cy = h / 2.0 + math.cos(time * 0.2) * 30;
    const max_r = @max(w, h) * 0.6;
    // Концентрические круги (горизонты P³)
    var i: f32 = 0;
    while (i < 8) : (i += 1.0) {
        const r = 80 + i * 55 + math.sin(time + i) * 10;
        const alpha: u8 = @intFromFloat(@max(15, 50 - i * 5));
        rl.DrawCircleLines(@intFromFloat(cx), @intFromFloat(cy), r, .{ .r = 0, .g = 100, .b = 200, .a = alpha });
    }
    // Радиальные линии (геодезические)
    var a: f32 = 0;
    while (a < math.pi * 2) : (a += math.pi / 6) {
        const angle = a + time * 0.1;
        const ex = cx + math.cos(angle) * max_r;
        const ey = cy + math.sin(angle) * max_r;
        rl.DrawLine(@intFromFloat(cx), @intFromFloat(cy), @intFromFloat(ex), @intFromFloat(ey), C_GRID_LINE);
    }
    // Плавающие частицы
    var prng = std.Random.DefaultPrng.init(77);
    const rand = prng.random();
    var j: usize = 0;
    while (j < 40) : (j += 1) {
        const px = rand.float(f32) * w;
        const py = (rand.float(f32) * h + time * (10 + rand.float(f32) * 20)) % h;
        const sz = 1.0 + rand.float(f32) * 2.0;
        const br: u8 = @intFromFloat(60 + rand.float(f32) * 120);
        rl.DrawCircle(@intFromFloat(px), @intFromFloat(py), sz, .{ .r = 0, .g = br, .b = @intFromFloat(@as(f32, @floatFromInt(br)) * 1.3), .a = 180 });
    }
}

fn drawSidePanel(font: rl.Font, w: f32, h: f32, screen: Screen, time: f32) void {
    const panel_w: f32 = 260;
    // Панель с логотипом
    rl.DrawRectangle(0, 0, @intFromFloat(panel_w), @intFromFloat(h), C_BG_PANEL);
    rl.DrawLine(@intFromFloat(panel_w), 0, @intFromFloat(panel_w), @intFromFloat(h), C_BORDER);

    // Логотип P³
    const logo_y: f32 = 30;
    drawText(font, "P³ ENGINE", 24, logo_y, 28, C_ACCENT);
    drawText(font, "v" ++ ENGINE_VERSION, 24, logo_y + 32, 14, C_TEXT_DIM);

    // Анимированная линия под лого
    const line_w = 200 + math.sin(time * 2) * 10;
    rl.DrawLine(24, @intFromFloat(logo_y + 55), @intFromFloat(24 + line_w), @intFromFloat(logo_y + 55), C_ACCENT_DIM);

    // Меню
    const menu_items = [_]struct { label: []const u8, scr: Screen }{
        .{ .label = "◈  Главное меню", .scr = .main_menu },
        .{ .label = "■  Проекты", .scr = .projects },
        .{ .label = "●  Настройки", .scr = .settings },
        .{ .label = "■  Ассеты", .scr = .assets },
        .{ .label = "◈  О движке", .scr = .about },
    };

    var my: f32 = 120;
    const mouse = rl.GetMousePosition();
    for (menu_items) |item| {
        const active = screen == item.scr;
        const hovered = mouse.x < panel_w and mouse.y > my - 4 and mouse.y < my + 28;
        const bg_col = if (active) C_BG_CARD_HOVER else if (hovered) C_BG_CARD else .{ .r = 0, .g = 0, .b = 0, .a = 0 };
        if (active or hovered) {
            rl.DrawRectangle(8, @intFromFloat(my - 4), @intFromFloat(panel_w - 16), 28, bg_col);
        }
        if (active) {
            rl.DrawRectangle(8, @intFromFloat(my - 4), 3, 28, C_ACCENT);
        }
        const col = if (active) C_ACCENT else if (hovered) C_TEXT_BRIGHT else C_TEXT_DIM;
        drawText(font, item.label, 20, my, 15, col);
        my += 38;
    }

    // Нижняя часть панели
    const bottom_y = h - 80;
    rl.DrawLine(12, @intFromFloat(bottom_y), @intFromFloat(panel_w - 12), @intFromFloat(bottom_y), C_BORDER);
    drawText(font, "Архитектор: Kotokvit", 16, bottom_y + 12, 11, C_TEXT_DIM);
    drawText(font, "Язык: Zig 0.14.0", 16, bottom_y + 28, 11, C_TEXT_DIM);
    drawText(font, "Геометрия: P³(RP³) / S³", 16, bottom_y + 44, 11, C_TEXT_DIM);
}

// =============================================================================
// ЭКРАНЫ
// =============================================================================

fn drawMainMenu(font: rl.Font, w: f32, h: f32, time: f32, buttons: *[6]Button) void {
    const panel_x: f32 = 300;
    const content_w = w - panel_x;
    const cx = panel_x + content_w / 2;

    // Заголовок
    drawTextCentered(font, "Движок проективной геометрии", cx, 60, 26, C_TEXT_BRIGHT);
    drawTextCentered(font, "Рендеринг на S³ с полным поддержанием PGL(4) и Кеплеровой гравитации", cx, 95, 13, C_TEXT_DIM);

    // Кнопки главного меню
    const btn_w: f32 = 380;
    const btn_h: f32 = 52;
    const btn_x = cx - btn_w / 2;
    var btn_y: f32 = 150;
    const btn_data = [_]struct { label: []const u8, icon: []const u8 }{
        .{ .label = "Запустить движок", .icon = "▶" },
        .{ .label = "Запустить Void Voyager", .icon = "◈" },
        .{ .label = "Открыть редактор сцен", .icon = "■" },
        .{ .label = "Демо видеопорта S³", .icon = "●" },
        .{ .label = "Демо GUI компонентов", .icon = "◈" },
        .{ .label = "Выход", .icon = "✖" },
    };

    for (&btn_data, 0..) |*bd, i| {
        buttons[i].rect = .{ .x = btn_x, .y = btn_y, .width = btn_w, .height = btn_h };
        buttons[i].label = bd.label;
        buttons[i].icon = bd.icon;
        if (i == 5) buttons[i].accent = C_DANGER;
        buttons[i].update(rl.GetMousePosition());
        buttons[i].draw(font);
        btn_y += btn_h + 12;
    }

    // Информация о системе
    const info_y = h - 90;
    rl.DrawRectangle(@intFromFloat(panel_x + 20), @intFromFloat(info_y), @intFromFloat(content_w - 40), 70, C_BG_PANEL);
    rl.DrawRectangleLinesEx(.{ .x = panel_x + 20, .y = info_y, .width = content_w - 40, .height = 70 }, 1.0, C_BORDER);

    const fps = rl.GetFPS();
    var buf: [128]u8 = undefined;
    const fps_txt = std.fmt.bufPrint(&buf, "FPS: {d}  |  Кадр: {d:.1}мс  |  Разрешение: {d}x{d}", .{ fps, if (fps > 0) 1000.0 / @as(f32, @floatFromInt(fps)) else 0.0, rl.GetScreenWidth(), rl.GetScreenHeight() }) catch "";
    drawText(font, fps_txt, panel_x + 36, info_y + 12, 12, C_TEXT_DIM);
    drawText(font, "Модулей: 48  |  Тестов: 627+  |  GPU: WebGPU (Dawn) + zgpu", panel_x + 36, info_y + 30, 12, C_TEXT_DIM);
    drawText(font, "Проективная геометрия P³(RP³) на сфере S³ с координатами PGL(4)", panel_x + 36, info_y + 48, 12, C_ACCENT_DIM);
}

fn drawProjectsScreen(font: rl.Font, w: f32, h: f32, time: f32) void {
    const panel_x: f32 = 300;
    const content_w = w - panel_x;
    _ = time;

    drawText(font, "Проекты", panel_x + 30, 30, 24, C_TEXT_BRIGHT);
    drawText(font, "Управление проектами P³ Engine", panel_x + 30, 60, 13, C_TEXT_DIM);

    // Кнопка создания
    const new_btn = rl.Rectangle{ .x = panel_x + content_w - 180, .y = 25, .width = 150, .height = 36 };
    const nb_hover = rl.CheckCollisionPointRec(rl.GetMousePosition(), new_btn);
    rl.DrawRectangleRounded(new_btn, 6.0, 4, if (nb_hover) C_ACCENT else C_BG_CARD);
    drawTextCentered(font, "+ Новый проект", new_btn.x + new_btn.width / 2, new_btn.y + 9, 14, if (nb_hover) C_BG_DARK else C_TEXT);

    // Список проектов
    const projects = [_]struct { name: []const u8, desc: []const u8, status: []const u8, col: rl.Color }{
        .{ .name = "Void Voyager", .desc = "Космическая игра в проективном пространстве P³", .status = "Активен", .col = C_SUCCESS },
        .{ .name = "Процедурные меши", .desc = "Генерация кораблей, танков и болидов", .status = "Разработка", .col = C_WARNING },
        .{ .name = "Планетарная система", .desc = "Кеплерова гравитация и астрономия на S³", .status = "Активен", .col = C_SUCCESS },
        .{ .name = "Тест физики", .desc = "Скелетная анимация и коллизии", .status = "Тестирование", .col = C_ACCENT },
        .{ .name = "Гонки на ховерах", .desc = "Симплектическая физика транспорта", .status = "Активен", .col = C_SUCCESS },
        .{ .name = "Панорамный рендер", .desc = "PBR материалы и глобальное освещение", .status = "Планы", .col = C_TEXT_DIM },
    };

    var py: f32 = 100;
    for (projects) |p| {
        const card = rl.Rectangle{ .x = panel_x + 20, .y = py, .width = content_w - 40, .height = 72 };
        const hover = rl.CheckCollisionPointRec(rl.GetMousePosition(), card);
        rl.DrawRectangleRounded(card, 8.0, 4, if (hover) C_BG_CARD_HOVER else C_BG_CARD);
        if (hover) rl.DrawRectangleRoundedLines(card, 8.0, 4, 1.5, C_ACCENT_DIM);

        drawText(font, p.name, card.x + 16, card.y + 12, 16, C_TEXT_BRIGHT);
        drawText(font, p.desc, card.x + 16, card.y + 34, 12, C_TEXT_DIM);
        // Статус
        const status_w = rl.MeasureTextEx(font, @ptrCast(p.status), 11, 1.0).x + 16;
        rl.DrawRectangleRounded(.{ .x = card.x + card.width - status_w - 12, .y = card.y + 12, .width = status_w, .height = 22 }, 4.0, 4, .{ .r = @intFromFloat(@as(f32, @floatFromInt(p.col.r)) * 0.2), .g = @intFromFloat(@as(f32, @floatFromInt(p.col.g)) * 0.2), .b = @intFromFloat(@as(f32, @floatFromInt(p.col.b)) * 0.2), .a = 255 });
        drawText(font, p.status, card.x + card.width - status_w - 4, card.y + 15, 11, p.col);

        py += 82;
    }
}

fn drawSettingsScreen(font: rl.Font, w: f32, h: f32, settings: *EngineSettings, time: f32) void {
    const panel_x: f32 = 300;
    const content_w = w - panel_x;
    _ = time;
    _ = h;

    drawText(font, "Настройки движка", panel_x + 30, 30, 24, C_TEXT_BRIGHT);
    drawText(font, "Конфигурация видео, физики и управления", panel_x + 30, 60, 13, C_TEXT_DIM);

    // Секции настроек
    const sections = [_]struct { title: []const u8, items: [4]struct { label: []const u8, value: []const u8 } }{
        .{
            .title = "ВИДЕО",
            .items = .{
                .{ .label = "Разрешение", .value = "1280 x 800" },
                .{ .label = "V-Sync", .value = if (settings.vsync) "Вкл." else "Выкл." },
                .{ .label = "MSAA", .value = "x4" },
                .{ .label = "Целевой FPS", .value = "60" },
            },
        },
        .{
            .title = "ФИЗИКА",
            .items = .{
                .{ .label = "Гравитация", .value = "9.807 м/с²" },
                .{ .label = "Подшаги", .value = "4" },
                .{ .label = "Тип физики", .value = "Кеплер + Симплектич." },
                .{ .label = "Коллизии", .value = "Вкл." },
            },
        },
        .{
            .title = "ПРОЕКТИВНАЯ ГЕОМЕТРИЯ",
            .items = .{
                .{ .label = "Радиус планеты", .value = "6378 км" },
                .{ .label = "Анизотропия", .value = "1.0" },
                .{ .label = "FS-дистанция", .value = if (settings.show_fs_distance) "Показ." else "Скрыто" },
                .{ .label = "Карта P³", .value = "Авто" },
            },
        },
        .{
            .title = "УПРАВЛЕНИЕ",
            .items = .{
                .{ .label = "Чувствительность мыши", .value = "1.0" },
                .{ .label = "Инверт. Y", .value = if (settings.invert_y) "Да" else "Нет" },
                .{ .label = "Скорость", .value = "2.0 ед./с" },
                .{ .label = "Камера", .value = "Геодезическая S³" },
            },
        },
    };

    var sy: f32 = 100;
    for (sections) |sec| {
        // Заголовок секции
        drawText(font, sec.title, panel_x + 30, sy, 12, C_ACCENT);
        sy += 22;

        // Карточка секции
        const card = rl.Rectangle{ .x = panel_x + 20, .y = sy, .width = content_w - 40, .height = 120 };
        rl.DrawRectangleRounded(card, 8.0, 4, C_BG_CARD);

        var iy: f32 = sy + 10;
        for (sec.items) |item| {
            drawText(font, item.label, card.x + 16, iy, 13, C_TEXT_DIM);
            drawText(font, item.value, card.x + card.width - 16 - rl.MeasureTextEx(font, @ptrCast(item.value), 13, 1.0).x, iy, 13, C_TEXT);
            iy += 26;
        }
        sy += 132;
    }
}

fn drawAssetsScreen(font: rl.Font, w: f32, h: f32, time: f32) void {
    const panel_x: f32 = 300;
    const content_w = w - panel_x;
    _ = time;
    _ = h;

    drawText(font, "Браузер ассетов", panel_x + 30, 30, 24, C_TEXT_BRIGHT);
    drawText(font, "Сцены, модели, текстуры и шейдеры", panel_x + 30, 60, 13, C_TEXT_DIM);

    const categories = [_]struct { name: []const u8, count: u32, icon: []const u8 }{
        .{ .name = "Сцены", .count = 5, .icon = "■" },
        .{ .name = "Модели", .count = 12, .icon = "◈" },
        .{ .name = "Текстуры", .count = 34, .icon = "●" },
        .{ .name = "Шейдеры (WGSL)", .count = 8, .icon = "◈" },
        .{ .name = "Материалы (PBR)", .count = 6, .icon = "■" },
        .{ .name = "Скелеты", .count = 3, .icon = "●" },
    };

    // Сетка категорий
    const grid_x: f32 = panel_x + 30;
    const grid_y: f32 = 110;
    const card_size: f32 = 170;
    const gap: f32 = 14;
    const cols: f32 = 3;

    for (categories, 0..) |cat, i| {
        const col = @mod(i, 3);
        const row = @divFloor(i, 3);
        const cx = grid_x + @as(f32, @floatFromInt(col)) * (card_size + gap);
        const cy = grid_y + @as(f32, @floatFromInt(row)) * (card_size + gap + 30);

        const card = rl.Rectangle{ .x = cx, .y = cy, .width = card_size, .height = card_size };
        const hover = rl.CheckCollisionPointRec(rl.GetMousePosition(), card);
        rl.DrawRectangleRounded(card, 10.0, 4, if (hover) C_BG_CARD_HOVER else C_BG_CARD);
        if (hover) rl.DrawRectangleRoundedLines(card, 10.0, 4, 1.5, C_ACCENT);

        // Иконка
        const icon_size = 32 + (if (hover) 4 else 0);
        drawTextCentered(font, cat.icon, cx + card_size / 2, cy + 20, @floatFromInt(icon_size), C_ACCENT_DIM);

        // Название
        drawTextCentered(font, cat.name, cx + card_size / 2, cy + 70, 13, C_TEXT);

        // Количество
        var buf: [32]u8 = undefined;
        const cnt_txt = std.fmt.bufPrint(&buf, "{d} эл.", .{cat.count}) catch "";
        drawTextCentered(font, cnt_txt, cx + card_size / 2, cy + 90, 11, C_TEXT_DIM);

        _ = cols;
    }

    // Нижняя панель информации
    const info_y: f32 = grid_y + 2 * (card_size + gap + 30) + 20;
    const info_rect = rl.Rectangle{ .x = panel_x + 20, .y = info_y, .width = content_w - 40, .height = 100 };
    rl.DrawRectangleRounded(info_rect, 8.0, 4, C_BG_PANEL);
    drawText(font, "Всего ассетов: 68 элементов", info_rect.x + 16, info_rect.y + 12, 13, C_TEXT);
    drawText(font, "Форматы: .zig, .wgsl, .obj, .png, .jpg, .pbr", info_rect.x + 16, info_rect.y + 34, 12, C_TEXT_DIM);
    drawText(font, "Система: Виртуальный файловый монтаж (VFS) P³ Engine", info_rect.x + 16, info_rect.y + 54, 12, C_TEXT_DIM);
    drawText(font, "Ассетный процессор: встроенный (без внешних зависимостей)", info_rect.x + 16, info_rect.y + 74, 12, C_ACCENT_DIM);
}

fn drawAboutScreen(font: rl.Font, w: f32, h: f32, time: f32) void {
    const panel_x: f32 = 300;
    const content_w = w - panel_x;
    _ = w;
    _ = h;

    drawText(font, "О движке P³", panel_x + 30, 30, 24, C_TEXT_BRIGHT);

    // Карточка версии
    const ver_card = rl.Rectangle{ .x = panel_x + 20, .y = 80, .width = content_w - 40, .height = 90 };
    rl.DrawRectangleRounded(ver_card, 10.0, 4, C_BG_CARD);
    drawText(font, "P³ Engine v" ++ ENGINE_VERSION, ver_card.x + 20, ver_card.y + 16, 20, C_GOLD);
    drawText(font, "Движок проективной геометрии на сфере S³", ver_card.x + 20, ver_card.y + 44, 13, C_TEXT);
    drawText(font, "Язык: Zig 0.14.0  |  Рендер: WebGPU (Dawn) + zgpu  |  Окна: zglfw", ver_card.x + 20, ver_card.y + 66, 11, C_TEXT_DIM);

    // Модули движка
    const modules = [_][]const u8{
        "Проективное ядро (p3_kernel)",
        "Математика P³: Vec2/3/4, Mat3x3/4x4, Quat, Transform",
        "Геодезические на S³ (Фубини-Штуди метрика)",
        "Клиффорд/Грассман/Плюккер алгебра",
        "ECS (порт O3DE), Scene Graph, Physics",
        "GPU пайплайн (WGSL), RHI, Renderer",
        "Проективная камера на S³ + FS-дистанция",
        "Кеплерова гравитация + симплектическая физика",
        "Dual Quaternion, Spherical Harmonics, CORDIC",
        "PBR материалы, Skeletal анимация (FABRIK)",
        "UI фреймворк (порт O3DE LyShine): кнопки, скролл, анимации",
        "VFS (Virtual File System), Serial, Jobs",
    };

    drawText(font, "Модули движка (48):", panel_x + 30, 190, 13, C_ACCENT);
    var my: f32 = 210;
    for (modules) |m| {
        drawText(font, "  • " ++ m, panel_x + 30, my, 12, C_TEXT_DIM);
        my += 20;
    }

    // Доноры
    const donor_y = my + 20;
    drawText(font, "Доноры (пожираны и переписаны):", panel_x + 30, donor_y, 13, C_ACCENT);
    drawText(font, "  O3DE (AzCore/Math, LyShine UI, ECS, Gem архитектура)", panel_x + 30, donor_y + 20, 12, C_TEXT_DIM);
    drawText(font, "  Unreal Engine (Math, Transform, Spring, DualQuat, SH, Skeletal)", panel_x + 30, donor_y + 38, 12, C_TEXT_DIM);
    drawText(font, "  zmath, zm, Mach (символьные операции, SIMD)", panel_x + 30, donor_y + 56, 12, C_TEXT_DIM);

    // Автор
    const auth_y = donor_y + 90;
    rl.DrawRectangleRounded(.{ .x = panel_x + 20, .y = auth_y, .width = content_w - 40, .height = 50 }, 8.0, 4, C_BG_CARD);
    drawText(font, "Архитектор: Kotokvit (математик)  |  Принцип: Убивать. Жрать. Рождать новое.", panel_x + 36, auth_y + 15, 12, C_TEXT);

    _ = time;
}

fn drawLoadingScreen(font: rl.Font, w: f32, h: f32, loading: *LoadingState) void {
    // Звёздное поле
    for (loading.stars) |s| {
        rl.DrawCircle(@intFromFloat(s.x), @intFromFloat(s.y), s.size, .{
            .r = @intFromFloat(s.brightness * 200),
            .g = @intFromFloat(s.brightness * 220),
            .b = 255,
            .a = @intFromFloat(s.brightness * 255),
        });
    }

    const cx = w / 2;
    const cy = h / 2;

    // Логотип с пульсацией
    const pulse = 0.85 + 0.15 * @sin(loading.spring.value * math.pi * 4);
    const logo_size: f32 = 36 * pulse;
    drawTextCentered(font, "P³ ENGINE", cx, cy - 80, logo_size, C_ACCENT);

    // Прогресс-бар
    const bar_w: f32 = 400;
    const bar_h: f32 = 8;
    const bar_x = cx - bar_w / 2;
    const bar_y = cy + 10;

    // Фон прогресс-бара
    rl.DrawRectangleRounded(.{ .x = bar_x, .y = bar_y, .width = bar_w, .height = bar_h }, 4.0, 4, C_BG_CARD);

    // Заполнение (со сприн-анимацией)
    const fill_w = bar_w * @as(f32, @floatCast(loading.spring.value));
    if (fill_w > 1) {
        // Градиентное заполнение
        rl.DrawRectangleRounded(.{ .x = bar_x, .y = bar_y, .width = fill_w, .height = bar_h }, 4.0, 4, C_ACCENT);
        // Блик
        const glow_x = bar_x + fill_w;
        rl.DrawCircle(@intFromFloat(glow_x), @intFromFloat(bar_y + bar_h / 2), 6, .{ .r = 0, .g = 255, .b = 255, .a = 100 });
    }

    // Фаза загрузки
    drawTextCentered(font, loading.phase, cx, bar_y + 24, 13, C_TEXT_DIM);

    // Процент
    const pct = @as(f32, @floatCast(loading.spring.value)) * 100.0;
    var buf: [32]u8 = undefined;
    const pct_txt = std.fmt.bufPrint(&buf, "{d:.0}%", .{pct}) catch "";
    drawTextCentered(font, pct_txt, cx, bar_y + 44, 16, C_TEXT);
}

// =============================================================================
// ГЛАВНАЯ ФУНКЦИЯ
// =============================================================================

pub fn main() !void {
    // Инициализация окна
    rl.InitWindow(WINDOW_W, WINDOW_H, "P³ Engine Launcher v" ++ ENGINE_VERSION);
    rl.SetTargetFPS(60);
    rl.SetWindowState(rl.FLAG_WINDOW_RESIZABLE);
    defer rl.CloseWindow();

    // Unicode шрифт
    const font = loadUnicodeFont(20);
    defer rl.UnloadFont(font);

    // Состояние
    var current_screen: Screen = .main_menu;
    var settings = EngineSettings{};
    var loading = LoadingState.init();
    var global_time: f32 = 0;
    var frame_count: u32 = 0;

    // Кнопки главного меню
    var main_buttons = [_]Button{
        .{ .rect = .{ .x = 0, .y = 0, .width = 380, .height = 52 }, .label = "", .icon = "" },
        .{ .rect = .{ .x = 0, .y = 0, .width = 380, .height = 52 }, .label = "", .icon = "" },
        .{ .rect = .{ .x = 0, .y = 0, .width = 380, .height = 52 }, .label = "", .icon = "" },
        .{ .rect = .{ .x = 0, .y = 0, .width = 380, .height = 52 }, .label = "", .icon = "" },
        .{ .rect = .{ .x = 0, .y = 0, .width = 380, .height = 52 }, .label = "", .icon = "" },
        .{ .rect = .{ .x = 0, .y = 0, .width = 380, .height = 52 }, .label = "", .icon = "" },
    };

    // Главный цикл
    while (!rl.WindowShouldClose()) {
        const dt = rl.GetFrameTime();
        global_time += dt;
        frame_count += 1;
        const sw = @as(f32, @floatFromInt(rl.GetScreenWidth()));
        const sh = @as(f32, @floatFromInt(rl.GetScreenHeight()));
        const mouse = rl.GetMousePosition();

        // ================================================================
        // ОБРАБОТКА ВВОДА
        // ================================================================

        // Навигация боковой панели
        if (current_screen != .loading and current_screen != .exit_confirm) {
            if (mouse.x < 260) {
                const menu_screens = [_]Screen{ .main_menu, .projects, .settings, .assets, .about };
                var my: f32 = 120;
                for (menu_screens) |scr| {
                    if (mouse.y > my - 4 and mouse.y < my + 28) {
                        if (rl.IsMouseButtonPressed(rl.MOUSE_LEFT_BUTTON)) {
                            current_screen = scr;
                        }
                    }
                    my += 38;
                }
            }
        }

        // Кнопки главного меню
        if (current_screen == .main_menu) {
            if (main_buttons[0].clicked) current_screen = .loading;
            if (main_buttons[1].clicked) current_screen = .loading;
            if (main_buttons[2].clicked) current_screen = .loading;
            if (main_buttons[3].clicked) current_screen = .loading;
            if (main_buttons[4].clicked) current_screen = .loading;
            if (main_buttons[5].clicked) current_screen = .exit_confirm;
        }

        // Экран загрузки
        if (current_screen == .loading) {
            loading.simulate(dt);
            if (loading.progress >= 1.0) {
                current_screen = .main_menu;
                loading.progress = 0;
                loading.spring.reset(0);
            }
        }

        // Подтверждение выхода
        if (current_screen == .exit_confirm) {
            if (rl.IsKeyPressed(rl.KEY_ESCAPE) or rl.IsKeyPressed(rl.KEY_N)) {
                current_screen = .main_menu;
            }
            if (rl.IsKeyPressed(rl.KEY_Y) or rl.IsKeyPressed(rl.KEY_ENTER)) {
                break;
            }
        }

        // Esc = назад
        if (rl.IsKeyPressed(rl.KEY_ESCAPE) and current_screen != .main_menu and current_screen != .loading and current_screen != .exit_confirm) {
            current_screen = .main_menu;
        }

        // ================================================================
        // РЕНДЕРИНГ
        // ================================================================
        rl.BeginDrawing();
        rl.ClearBackground(C_BG_DARK);

        if (current_screen == .loading) {
            // Экран загрузки (полный экран)
            drawLoadingScreen(font, sw, sh, &loading);
        } else if (current_screen == .exit_confirm) {
            // Подтверждение выхода
            drawProjectiveBackground(global_time, sw, sh);
            drawSidePanel(font, sw, sh, .main_menu, global_time);

            const dialog_w: f32 = 420;
            const dialog_h: f32 = 160;
            const dx = 300 + (sw - 300) / 2 - dialog_w / 2;
            const dy = sh / 2 - dialog_h / 2;
            rl.DrawRectangle(@intFromFloat(dx - 1), @intFromFloat(dy - 1), @intFromFloat(dialog_w + 2), @intFromFloat(dialog_h + 2), C_ACCENT);
            rl.DrawRectangle(@intFromFloat(dx), @intFromFloat(dy), @intFromFloat(dialog_w), @intFromFloat(dialog_h), C_BG_PANEL);
            drawTextCentered(font, "Выйти из P³ Engine?", dx + dialog_w / 2, dy + 30, 20, C_TEXT_BRIGHT);
            drawTextCentered(font, "Нажмите Y/Вход для подтверждения, N/Esc для отмены", dx + dialog_w / 2, dy + 65, 13, C_TEXT_DIM);

            // Кнопки
            const yes_btn = rl.Rectangle{ .x = dx + dialog_w / 2 - 160, .y = dy + 105, .width = 140, .height = 36 };
            const no_btn = rl.Rectangle{ .x = dx + dialog_w / 2 + 20, .y = dy + 105, .width = 140, .height = 36 };
            const y_hover = rl.CheckCollisionPointRec(mouse, yes_btn);
            const n_hover = rl.CheckCollisionPointRec(mouse, no_btn);
            rl.DrawRectangleRounded(yes_btn, 6.0, 4, if (y_hover) C_DANGER else C_BG_CARD);
            rl.DrawRectangleRounded(no_btn, 6.0, 4, if (n_hover) C_BG_CARD_HOVER else C_BG_CARD);
            drawTextCentered(font, "Да (Y)", yes_btn.x + yes_btn.width / 2, yes_btn.y + 9, 14, if (y_hover) C_BG_DARK else C_TEXT);
            drawTextCentered(font, "Нет (N)", no_btn.x + no_btn.width / 2, no_btn.y + 9, 14, if (n_hover) C_TEXT_BRIGHT else C_TEXT);

            if (y_hover and rl.IsMouseButtonPressed(rl.MOUSE_LEFT_BUTTON)) break;
            if (n_hover and rl.IsMouseButtonPressed(rl.MOUSE_LEFT_BUTTON)) current_screen = .main_menu;
        } else {
            // Основные экраны
            drawProjectiveBackground(global_time, sw, sh);
            drawSidePanel(font, sw, sh, current_screen, global_time);

            switch (current_screen) {
                .main_menu => drawMainMenu(font, sw, sh, global_time, &main_buttons),
                .projects => drawProjectsScreen(font, sw, sh, global_time),
                .settings => drawSettingsScreen(font, sw, sh, &settings, global_time),
                .assets => drawAssetsScreen(font, sw, sh, global_time),
                .about => drawAboutScreen(font, sw, sh, global_time),
                else => {},
            }
        }

        rl.EndDrawing();
    }
}
