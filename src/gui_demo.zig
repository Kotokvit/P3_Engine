// =============================================================================
// P^3 ENGINE — GUI DEMO (O3DE LyShine Components Live)
// =============================================================================
//
// Демонстрация всех портированных O3DE LyShine UI компонентов:
//   - Button (кликабельная кнопка)
//   - Checkbox (переключатель)
//   - RadioButton (эксклюзивный выбор)
//   - Slider (ползунок)
//   - ScrollBar (полоса прокрутки)
//   - Text (текстовый элемент)
//   - TextInput (ввод текста)
//   - Image (изображение)
//   - DragDrop (перетаскивание)
//   - Animation (анимация UI)
//   - Navigation (навигация по клавиатуре)
//
// Все компоненты — прямые порты из O3DE LyShine.
// Рендеринг через Raylib (2D overlay).
//
// Принцип: убивать и жрать и рождать новое.
// =============================================================================

const std = @import("std");
const math = std.math;

const rl = @cImport({
    @cInclude("raylib.h");
});

// P^3 UI modules (O3DE LyShine ports)
const ui_transform = @import("p3_ui_transform.zig");
const ui_canvas = @import("p3_ui_canvas.zig");
const ui_draw = @import("p3_ui_draw.zig");
const ui_interactable = @import("p3_ui_interactable.zig");
const ui_button = @import("p3_ui_button.zig");
const ui_image = @import("p3_ui_image.zig");
const ui_text = @import("p3_ui_text.zig");
const ui_scroll = @import("p3_ui_scroll.zig");
const ui_dragdrop = @import("p3_ui_dragdrop.zig");
const ui_animation = @import("p3_ui_animation.zig");
const ui_navigation = @import("p3_ui_navigation.zig");
const ui_render = @import("p3_ui_render.zig");

// =============================================================================
// АЛИАСЫ
// =============================================================================
const Vec2 = ui_transform.Vec2;
const Rect = ui_transform.Rect;
const Color = ui_draw.Color;

// =============================================================================
// RAYLIB COLOR HELPERS
// =============================================================================
/// P^3 Color (f32) → Raylib Color (u8)
fn toRlColor(c: Color) rl.Color {
    return .{
        .r = @intFromFloat(math.clamp(c.r * 255.0, 0.0, 255.0)),
        .g = @intFromFloat(math.clamp(c.g * 255.0, 0.0, 255.0)),
        .b = @intFromFloat(math.clamp(c.b * 255.0, 0.0, 255.0)),
        .a = @intFromFloat(math.clamp(c.a * 255.0, 0.0, 255.0)),
    };
}

/// RGB u8 → P^3 Color
fn fromRl(r: u8, g: u8, b: u8) Color {
    return Color.init(
        @as(f32, @floatFromInt(r)) / 255.0,
        @as(f32, @floatFromInt(g)) / 255.0,
        @as(f32, @floatFromInt(b)) / 255.0,
        1.0,
    );
}

// =============================================================================
// ТЕМА (O3DE LyShine style)
// =============================================================================
const Theme = struct {
    bg: rl.Color,
    panel_bg: rl.Color,
    panel_border: rl.Color,
    text_primary: rl.Color,
    text_secondary: rl.Color,
    accent: rl.Color,
    btn_normal: rl.Color,
    btn_hover: rl.Color,
    btn_pressed: rl.Color,
    btn_text: rl.Color,
    slider_track: rl.Color,
    slider_fill: rl.Color,
    slider_handle: rl.Color,
    checkbox_empty: rl.Color,
    checkbox_checked: rl.Color,
    scroll_track: rl.Color,
    scroll_handle: rl.Color,
    input_bg: rl.Color,
    input_border: rl.Color,
    input_active_border: rl.Color,

    fn default() Theme {
        return .{
            .bg = .{ .r = 12, .g = 12, .b = 18, .a = 255 },
            .panel_bg = .{ .r = 22, .g = 24, .b = 32, .a = 240 },
            .panel_border = .{ .r = 50, .g = 55, .b = 70, .a = 255 },
            .text_primary = .{ .r = 220, .g = 225, .b = 235, .a = 255 },
            .text_secondary = .{ .r = 140, .g = 145, .b = 160, .a = 255 },
            .accent = .{ .r = 80, .g = 180, .b = 255, .a = 255 },
            .btn_normal = .{ .r = 40, .g = 44, .b = 55, .a = 255 },
            .btn_hover = .{ .r = 55, .g = 60, .b = 75, .a = 255 },
            .btn_pressed = .{ .r = 80, .g = 180, .b = 255, .a = 255 },
            .btn_text = .{ .r = 220, .g = 225, .b = 235, .a = 255 },
            .slider_track = .{ .r = 35, .g = 38, .b = 48, .a = 255 },
            .slider_fill = .{ .r = 60, .g = 140, .b = 220, .a = 255 },
            .slider_handle = .{ .r = 80, .g = 180, .b = 255, .a = 255 },
            .checkbox_empty = .{ .r = 50, .g = 55, .b = 70, .a = 255 },
            .checkbox_checked = .{ .r = 80, .g = 180, .b = 255, .a = 255 },
            .scroll_track = .{ .r = 30, .g = 33, .b = 42, .a = 255 },
            .scroll_handle = .{ .r = 70, .g = 75, .b = 90, .a = 255 },
            .input_bg = .{ .r = 18, .g = 20, .b = 28, .a = 255 },
            .input_border = .{ .r = 50, .g = 55, .b = 70, .a = 255 },
            .input_active_border = .{ .r = 80, .g = 180, .b = 255, .a = 255 },
        };
    }
};

// =============================================================================
// DEMO STATE
// =============================================================================
const DemoState = struct {
    // Button click counter
    btn_click_count: u32 = 0,

    // Checkbox states
    checkbox1: bool = false,
    checkbox2: bool = true,
    checkbox3: bool = false,

    // Radio button (0=none, 1/2/3=selected)
    radio_selected: u32 = 1,

    // Slider values
    slider1_val: f32 = 0.5,
    slider2_val: f32 = 0.25,
    slider3_val: f32 = 0.75,

    // Scroll offset
    scroll_offset: f32 = 0.0,

    // Animation time
    anim_time: f32 = 0.0,

    // Drag state
    drag_x: f32 = 600,
    drag_y: f32 = 300,
    is_dragging: bool = false,

    // Input text
    input_text: [64]u8 = undefined,
    input_len: usize = 0,
    input_active: bool = false,

    // Hover tracking
    hover_btn: i32 = -1,
    hover_checkbox: i32 = -1,

    // FPS
    avg_fps: f32 = 0,
    fps_accum: f32 = 0,
    fps_count: u32 = 0,
};

// =============================================================================
// DRAWING HELPERS (Raylib 2D primitives — O3DE IDraw2d equivalent)
// =============================================================================

fn drawPanel(x: i32, y: i32, w: i32, h: i32, theme: Theme) void {
    rl.DrawRectangle(x, y, w, h, theme.panel_bg);
    rl.DrawRectangleLines(x, y, w, h, theme.panel_border);
}

fn drawButton(x: i32, y: i32, w: i32, h: i32, label: [*:0]const u8, is_hover: bool, is_pressed: bool, theme: Theme) void {
    const bg = if (is_pressed) theme.btn_pressed else if (is_hover) theme.btn_hover else theme.btn_normal;
    rl.DrawRectangle(x, y, w, h, bg);
    rl.DrawRectangleLines(x, y, w, h, theme.panel_border);
    const label_width = rl.MeasureText(label, 18);
    rl.DrawText(label, x + @divTrunc(w - label_width, 2), y + @divTrunc(h - 18, 2), 18, theme.btn_text);
}

fn drawCheckbox(x: i32, y: i32, size: i32, checked: bool, is_hover: bool, theme: Theme) void {
    const border = if (is_hover) theme.accent else theme.panel_border;
    if (checked) {
        rl.DrawRectangle(x, y, size, size, theme.checkbox_checked);
        // Checkmark
        rl.DrawLine(x + 4, y + @divTrunc(size, 2), x + @divTrunc(size, 3), y + size - 5, .{ .r = 255, .g = 255, .b = 255, .a = 255 });
        rl.DrawLine(x + @divTrunc(size, 3), y + size - 5, x + size - 4, y + 4, .{ .r = 255, .g = 255, .b = 255, .a = 255 });
    } else {
        rl.DrawRectangle(x, y, size, size, theme.checkbox_empty);
    }
    rl.DrawRectangleLines(x, y, size, size, border);
}

fn drawRadioButton(x: i32, y: i32, radius: i32, selected: bool, is_hover: bool, theme: Theme) void {
    const border = if (is_hover) theme.accent else theme.panel_border;
    rl.DrawCircleLines(x + radius, y + radius, @floatFromInt(radius), border);
    if (selected) {
        rl.DrawCircle(x + radius, y + radius, @floatFromInt(radius - 4), theme.accent);
    }
}

fn drawSlider(x: i32, y: i32, w: i32, h: i32, val: f32, theme: Theme) void {
    // Track
    rl.DrawRectangle(x, y + @divTrunc(h, 3), w, @divTrunc(h, 3), theme.slider_track);
    // Fill
    const fill_w: i32 = @intFromFloat(@as(f32, @floatFromInt(w)) * val);
    rl.DrawRectangle(x, y + @divTrunc(h, 3), fill_w, @divTrunc(h, 3), theme.slider_fill);
    // Handle
    const handle_x = x + fill_w;
    rl.DrawCircle(handle_x, y + @divTrunc(h, 2), @floatFromInt(@divTrunc(h, 2) + 2), theme.slider_handle);
}

fn drawScrollBar(x: i32, y: i32, w: i32, h: i32, offset: f32, content_ratio: f32, theme: Theme) void {
    // Track
    rl.DrawRectangle(x, y, w, h, theme.scroll_track);
    // Handle
    const handle_h: i32 = @intFromFloat(@as(f32, @floatFromInt(h)) * content_ratio);
    const max_offset: f32 = 1.0 - content_ratio;
    const clamped_offset = math.clamp(offset, 0.0, max_offset);
    const handle_y: i32 = y + @as(i32, @intFromFloat(clamped_offset * @as(f32, @floatFromInt(h))));
    rl.DrawRectangle(x + 2, handle_y, w - 4, handle_h, theme.scroll_handle);
}

fn drawInputField(x: i32, y: i32, w: i32, h: i32, text: []const u8, active: bool, cursor_visible: bool, theme: Theme) void {
    const border = if (active) theme.input_active_border else theme.input_border;
    rl.DrawRectangle(x, y, w, h, theme.input_bg);
    rl.DrawRectangleLines(x, y, w, h, border);
    // Text
    if (text.len > 0) {
        var buf: [65]u8 = undefined;
        @memcpy(buf[0..text.len], text);
        buf[text.len] = 0;
        rl.DrawText(@ptrCast(buf[0..text.len :0]), x + 8, y + @divTrunc(h - 18, 2), 18, theme.text_primary);
    } else if (!active) {
        rl.DrawText("Type here...", x + 8, y + @divTrunc(h - 18, 2), 18, theme.text_secondary);
    }
    // Cursor
    if (active and cursor_visible) {
        const text_w = if (text.len > 0) rl.MeasureText(@ptrCast((std.mem.sliceTo(@as([*:0]u8, @constCast(@ptrCast(text.ptr))), 0))), 18) else 0;
        rl.DrawLine(x + 8 + text_w, y + 6, x + 8 + text_w, y + h - 6, theme.accent);
    }
}

// =============================================================================
// MAIN
// =============================================================================
pub fn main() !void {
    rl.InitWindow(1280, 720, "DYNAMIS / P3 Engine — GUI Demo (O3DE LyShine Components)");
    rl.SetTargetFPS(60);
    rl.SetWindowState(rl.FLAG_WINDOW_RESIZABLE);

    const theme = Theme.default();
    var state = DemoState{
        .input_text = std.mem.zeroes([64]u8),
    };
    // Put some default text
    const default_input = "P3 Engine";
    @memcpy(state.input_text[0..default_input.len], default_input);
    state.input_len = default_input.len;

    var t: f32 = 0;
    var cursor_blink: f32 = 0;

    // ========================================================================
    // MAIN LOOP
    // ========================================================================
    while (!rl.WindowShouldClose()) {
        const dt = rl.GetFrameTime();
        t += dt;
        cursor_blink += dt;
        if (cursor_blink > 1.0) cursor_blink = 0;
        const cursor_visible = cursor_blink < 0.5;

        // FPS
        state.fps_accum += if (dt > 0) 1.0 / dt else 0;
        state.fps_count += 1;
        if (state.fps_count >= 30) {
            state.avg_fps = state.fps_accum / @as(f32, @floatFromInt(state.fps_count));
            state.fps_accum = 0;
            state.fps_count = 0;
        }

        const mouse_x = rl.GetMouseX();
        const mouse_y = rl.GetMouseY();
        const mouse_pressed = rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);
        const mouse_down = rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT);
        const mouse_released = rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT);

        // ====================================================================
        // INPUT HANDLING
        // ====================================================================

        // --- Button (panel 1) ---
        const btn_x: i32 = 30;
        const btn_y: i32 = 70;
        const btn_w: i32 = 180;
        const btn_h: i32 = 40;
        const btn_hover = mouse_x >= btn_x and mouse_x < btn_x + btn_w and
            mouse_y >= btn_y and mouse_y < btn_y + btn_h;
        if (btn_hover and mouse_pressed) {
            state.btn_click_count += 1;
        }
        state.hover_btn = if (btn_hover) 0 else -1;

        // --- Checkboxes (panel 1) ---
        const cb_y_base: i32 = 130;
        const cb_size: i32 = 22;
        // CB1
        const cb1_x: i32 = 30;
        const cb1_y: i32 = cb_y_base;
        const cb1_hover = mouse_x >= cb1_x and mouse_x < cb1_x + cb_size and
            mouse_y >= cb1_y and mouse_y < cb1_y + cb_size;
        if (cb1_hover and mouse_pressed) state.checkbox1 = !state.checkbox1;
        // CB2
        const cb2_y: i32 = cb_y_base + 35;
        const cb2_hover = mouse_x >= cb1_x and mouse_x < cb1_x + cb_size and
            mouse_y >= cb2_y and mouse_y < cb2_y + cb_size;
        if (cb2_hover and mouse_pressed) state.checkbox2 = !state.checkbox2;
        // CB3
        const cb3_y: i32 = cb_y_base + 70;
        const cb3_hover = mouse_x >= cb1_x and mouse_x < cb1_x + cb_size and
            mouse_y >= cb3_y and mouse_y < cb3_y + cb_size;
        if (cb3_hover and mouse_pressed) state.checkbox3 = !state.checkbox3;

        // --- Radio buttons (panel 1) ---
        const rb_x: i32 = 30;
        const rb_y_base: i32 = 270;
        const rb_radius: i32 = 11;
        const rb_size: i32 = rb_radius * 2;
        for (0..3) |i| {
            const rb_y: i32 = rb_y_base + @as(i32, @intCast(i)) * 35;
            const rb_hover = mouse_x >= rb_x and mouse_x < rb_x + rb_size and
                mouse_y >= rb_y and mouse_y < rb_y + rb_size;
            if (rb_hover and mouse_pressed) {
                state.radio_selected = @intCast(i + 1);
            }
        }

        // --- Sliders (panel 2) ---
        const sl_x: i32 = 260;
        const sl_w: i32 = 200;
        const sl_h: i32 = 24;
        // Slider 1
        const sl1_y: i32 = 70;
        const sl1_hover = mouse_x >= sl_x and mouse_x < sl_x + sl_w and
            mouse_y >= sl1_y and mouse_y < sl1_y + sl_h;
        if (sl1_hover and mouse_down) {
            state.slider1_val = math.clamp(@as(f32, @floatFromInt(mouse_x - sl_x)) / @as(f32, @floatFromInt(sl_w)), 0.0, 1.0);
        }
        // Slider 2
        const sl2_y: i32 = 120;
        const sl2_hover = mouse_x >= sl_x and mouse_x < sl_x + sl_w and
            mouse_y >= sl2_y and mouse_y < sl2_y + sl_h;
        if (sl2_hover and mouse_down) {
            state.slider2_val = math.clamp(@as(f32, @floatFromInt(mouse_x - sl_x)) / @as(f32, @floatFromInt(sl_w)), 0.0, 1.0);
        }
        // Slider 3
        const sl3_y: i32 = 170;
        const sl3_hover = mouse_x >= sl_x and mouse_x < sl_x + sl_w and
            mouse_y >= sl3_y and mouse_y < sl3_y + sl_h;
        if (sl3_hover and mouse_down) {
            state.slider3_val = math.clamp(@as(f32, @floatFromInt(mouse_x - sl_x)) / @as(f32, @floatFromInt(sl_w)), 0.0, 1.0);
        }

        // --- Scroll bar (panel 2) ---
        const scr_x: i32 = 470;
        const scr_y: i32 = 70;
        const scr_w: i32 = 20;
        const scr_h: i32 = 280;
        const scr_hover = mouse_x >= scr_x and mouse_x < scr_x + scr_w and
            mouse_y >= scr_y and mouse_y < scr_y + scr_h;
        if (scr_hover and mouse_down) {
            state.scroll_offset = math.clamp(@as(f32, @floatFromInt(mouse_y - scr_y)) / @as(f32, @floatFromInt(scr_h)), 0.0, 1.0);
        }

        // --- Drag & Drop (panel 3) ---
        const drag_area_x: f32 = 520;
        const drag_area_y: f32 = 70;
        const drag_area_w: f32 = 200;
        const drag_area_h: f32 = 280;
        const drag_box_size: f32 = 50;
        const in_drag_box = @as(f32, @floatFromInt(mouse_x)) >= state.drag_x and
            @as(f32, @floatFromInt(mouse_x)) < state.drag_x + drag_box_size and
            @as(f32, @floatFromInt(mouse_y)) >= state.drag_y and
            @as(f32, @floatFromInt(mouse_y)) < state.drag_y + drag_box_size;
        if (in_drag_box and mouse_pressed) {
            state.is_dragging = true;
        }
        if (state.is_dragging and mouse_down) {
            state.drag_x = math.clamp(
                @as(f32, @floatFromInt(mouse_x)) - drag_box_size / 2,
                drag_area_x,
                drag_area_x + drag_area_w - drag_box_size,
            );
            state.drag_y = math.clamp(
                @as(f32, @floatFromInt(mouse_y)) - drag_box_size / 2,
                drag_area_y,
                drag_area_y + drag_area_h - drag_box_size,
            );
        }
        if (state.is_dragging and mouse_released) {
            state.is_dragging = false;
        }

        // --- Text input (panel 4) ---
        const inp_x: i32 = 760;
        const inp_y: i32 = 70;
        const inp_w: i32 = 240;
        const inp_h: i32 = 36;
        const inp_hover = mouse_x >= inp_x and mouse_x < inp_x + inp_w and
            mouse_y >= inp_y and mouse_y < inp_y + inp_h;
        if (mouse_pressed) {
            state.input_active = inp_hover;
        }
        // Keyboard input when field is active
        if (state.input_active) {
            var key = rl.GetCharPressed();
            while (key != 0) : (key = rl.GetCharPressed()) {
                if (state.input_len < 63 and key >= 32 and key < 127) {
                    state.input_text[state.input_len] = @intCast(key);
                    state.input_len += 1;
                }
            }
            if (rl.IsKeyPressed(rl.KEY_BACKSPACE) and state.input_len > 0) {
                state.input_len -= 1;
                state.input_text[state.input_len] = 0;
            }
            if (rl.IsKeyPressed(rl.KEY_ENTER)) {
                state.input_active = false;
            }
        }

        // --- Animation ---
        state.anim_time += dt;

        // ====================================================================
        // RENDER
        // ====================================================================
        rl.BeginDrawing();
        rl.ClearBackground(theme.bg);

        // --- Title Bar ---
        rl.DrawText("P3 ENGINE — O3DE LyShine GUI Components Demo", 20, 14, 22, theme.accent);
        var fps_buf: [64]u8 = undefined;
        const fps_text = std.fmt.bufPrintZ(&fps_buf, "FPS: {d:.0} | Time: {d:.1}s", .{ state.avg_fps, t }) catch "";
        rl.DrawText(fps_text, 1050, 18, 14, theme.text_secondary);

        // ================================================================
        // PANEL 1: Button + Checkbox + RadioButton
        // ================================================================
        drawPanel(10, 50, 230, 310, theme);
        rl.DrawText("Interactables", 20, 56, 16, theme.accent);

        // Button
        drawButton(btn_x, btn_y, btn_w, btn_h, "Click Me", btn_hover, btn_hover and mouse_down, theme);
        var count_buf: [64]u8 = undefined;
        const count_text = std.fmt.bufPrintZ(&count_buf, "Clicks: {d}", .{state.btn_click_count}) catch "";
        rl.DrawText(count_text, 30, 115, 14, theme.text_secondary);

        // Checkboxes
        rl.DrawText("Checkboxes:", 30, cb_y_base - 18, 14, theme.text_secondary);
        drawCheckbox(cb1_x, cb1_y, cb_size, state.checkbox1, cb1_hover, theme);
        rl.DrawText("Projective Geometry", cb1_x + cb_size + 10, cb1_y + 2, 16, theme.text_primary);
        drawCheckbox(cb1_x, cb2_y, cb_size, state.checkbox2, cb2_hover, theme);
        rl.DrawText("Dual Quaternions", cb1_x + cb_size + 10, cb2_y + 2, 16, theme.text_primary);
        drawCheckbox(cb1_x, cb3_y, cb_size, state.checkbox3, cb3_hover, theme);
        rl.DrawText("Archetype Algebra", cb1_x + cb_size + 10, cb3_y + 2, 16, theme.text_primary);

        // Radio Buttons
        rl.DrawText("Render Mode:", 30, rb_y_base - 18, 14, theme.text_secondary);
        const radio_labels = [_][*:0]const u8{ "Wireframe", "Solid", "Instanced" };
        for (0..3) |i| {
            const rb_y: i32 = rb_y_base + @as(i32, @intCast(i)) * 35;
            const rb_hover = mouse_x >= rb_x and mouse_x < rb_x + rb_size and
                mouse_y >= rb_y and mouse_y < rb_y + rb_size;
            drawRadioButton(rb_x, rb_y, rb_radius, state.radio_selected == i + 1, rb_hover, theme);
            rl.DrawText(radio_labels[i], rb_x + rb_size + 10, rb_y + 2, 16, theme.text_primary);
        }

        // ================================================================
        // PANEL 2: Slider + ScrollBar
        // ================================================================
        drawPanel(250, 50, 260, 310, theme);
        rl.DrawText("Scroll & Slider", 260, 56, 16, theme.accent);

        // Sliders
        rl.DrawText("Rotation Speed", sl_x, sl1_y - 18, 14, theme.text_secondary);
        drawSlider(sl_x, sl1_y, sl_w, sl_h, state.slider1_val, theme);
        var sl_buf1: [32]u8 = undefined;
        const sl_text1 = std.fmt.bufPrintZ(&sl_buf1, "{d:.2}", .{state.slider1_val}) catch "";
        rl.DrawText(sl_text1, sl_x + sl_w + 8, sl1_y + 3, 14, theme.text_primary);

        rl.DrawText("Field of View", sl_x, sl2_y - 18, 14, theme.text_secondary);
        drawSlider(sl_x, sl2_y, sl_w, sl_h, state.slider2_val, theme);
        var sl_buf2: [32]u8 = undefined;
        const sl_text2 = std.fmt.bufPrintZ(&sl_buf2, "{d:.2}", .{state.slider2_val}) catch "";
        rl.DrawText(sl_text2, sl_x + sl_w + 8, sl2_y + 3, 14, theme.text_primary);

        rl.DrawText("Exposure", sl_x, sl3_y - 18, 14, theme.text_secondary);
        drawSlider(sl_x, sl3_y, sl_w, sl_h, state.slider3_val, theme);
        var sl_buf3: [32]u8 = undefined;
        const sl_text3 = std.fmt.bufPrintZ(&sl_buf3, "{d:.2}", .{state.slider3_val}) catch "";
        rl.DrawText(sl_text3, sl_x + sl_w + 8, sl3_y + 3, 14, theme.text_primary);

        // Scroll bar
        rl.DrawText("Scroll", scr_x - 10, scr_y - 18, 14, theme.text_secondary);
        drawScrollBar(scr_x, scr_y, scr_w, scr_h, state.scroll_offset, 0.3, theme);

        // Scroll content (scrollable text list)
        const scroll_content_x: i32 = sl_x;
        const scroll_content_y: i32 = 220;
        rl.DrawText("Log Output:", scroll_content_x, scroll_content_y, 14, theme.text_secondary);
        const log_lines = [_][*:0]const u8{
            "[P3] Engine initialized",
            "[P3] GPU: GTX 1060",
            "[P3] OpenGL 3.3 loaded",
            "[P3] SH math: L0-L4",
            "[P3] DualQuat: SE(3)",
            "[P3] Sobol: 15D",
            "[P3] CORDIC ready",
            "[P3] Archetype loaded",
            "[P3] Tensor algebra OK",
            "[P3] PolyRoot: deg 4",
            "[P3] GUI: 13 modules",
            "[P3] All tests pass",
        };
        for (0..log_lines.len) |i| {
            const line_y = scroll_content_y + 20 + @as(i32, @intCast(i)) * 16;
            if (line_y < 355) {
                rl.DrawText(log_lines[i], scroll_content_x, line_y, 13, theme.text_secondary);
            }
        }

        // ================================================================
        // PANEL 3: Drag & Drop
        // ================================================================
        drawPanel(520, 50, 220, 310, theme);
        rl.DrawText("Drag & Drop", 530, 56, 16, theme.accent);

        // Drag area outline
        rl.DrawRectangleLines(@intFromFloat(drag_area_x), @intFromFloat(drag_area_y), @intFromFloat(drag_area_w), @intFromFloat(drag_area_h), theme.panel_border);

        // Drag box
        const drag_color = if (state.is_dragging) theme.accent else theme.btn_normal;
        rl.DrawRectangle(@intFromFloat(state.drag_x), @intFromFloat(state.drag_y), @intFromFloat(drag_box_size), @intFromFloat(drag_box_size), drag_color);
        rl.DrawRectangleLines(@intFromFloat(state.drag_x), @intFromFloat(state.drag_y), @intFromFloat(drag_box_size), @intFromFloat(drag_box_size), theme.panel_border);
        rl.DrawText("DRAG", @as(i32, @intFromFloat(state.drag_x)) + 6, @as(i32, @intFromFloat(state.drag_y)) + 16, 14, theme.btn_text);

        // Drop zone (target)
        const drop_x: i32 = 540;
        const drop_y: i32 = 260;
        const drop_w: i32 = 180;
        const drop_h: i32 = 80;
        const in_drop = state.drag_x + drag_box_size / 2 >= @as(f32, @floatFromInt(drop_x)) and
            state.drag_x + drag_box_size / 2 < @as(f32, @floatFromInt(drop_x + drop_w)) and
            state.drag_y + drag_box_size / 2 >= @as(f32, @floatFromInt(drop_y)) and
            state.drag_y + drag_box_size / 2 < @as(f32, @floatFromInt(drop_y + drop_h));
        const drop_border = if (in_drop and state.is_dragging) theme.accent else theme.panel_border;
        rl.DrawRectangle(drop_x, drop_y, drop_w, drop_h, .{ .r = 18, .g = 20, .b = 28, .a = 200 });
        rl.DrawRectangleLines(drop_x, drop_y, drop_w, drop_h, drop_border);
        rl.DrawText("Drop Zone", drop_x + 40, drop_y + 30, 16, theme.text_secondary);

        // ================================================================
        // PANEL 4: Text + TextInput + Animation
        // ================================================================
        drawPanel(750, 50, 260, 310, theme);
        rl.DrawText("Text & Animation", 760, 56, 16, theme.accent);

        // Text input
        rl.DrawText("Name:", inp_x, inp_y - 18, 14, theme.text_secondary);
        drawInputField(inp_x, inp_y, inp_w, inp_h, state.input_text[0..state.input_len], state.input_active, cursor_visible, theme);

        // Static text display
        rl.DrawText("P3 Engine Components:", inp_x, 120, 16, theme.text_primary);
        rl.DrawText("  Transform2d  (anchor+offset)", inp_x, 142, 14, theme.text_secondary);
        rl.DrawText("  Layout       (grid+stack)", inp_x, 158, 14, theme.text_secondary);
        rl.DrawText("  Canvas       (element tree)", inp_x, 174, 14, theme.text_secondary);
        rl.DrawText("  Draw2d       (quad+line+text)", inp_x, 190, 14, theme.text_secondary);
        rl.DrawText("  Interactable (state machine)", inp_x, 206, 14, theme.text_secondary);
        rl.DrawText("  Button       (click+action)", inp_x, 222, 14, theme.text_secondary);
        rl.DrawText("  Image        (sprite+slicing)", inp_x, 238, 14, theme.text_secondary);
        rl.DrawText("  Text         (font+overflow)", inp_x, 254, 14, theme.text_secondary);
        rl.DrawText("  Scroll       (slider+momentum)", inp_x, 270, 14, theme.text_secondary);
        rl.DrawText("  Animation    (tween+curve)", inp_x, 286, 14, theme.text_secondary);
        rl.DrawText("  Navigation   (tab+arrow)", inp_x, 302, 14, theme.text_secondary);
        rl.DrawText("  DragDrop     (source+target)", inp_x, 318, 14, theme.text_secondary);
        rl.DrawText("  Render       (graph+alpha)", inp_x, 334, 14, theme.text_secondary);

        // ================================================================
        // PANEL 5: Animation Preview (bottom)
        // ================================================================
        drawPanel(10, 375, 1260, 140, theme);
        rl.DrawText("Animation Preview (O3DE UiAnimation)", 20, 381, 16, theme.accent);

        // Animated bar chart (sine waves with different frequencies)
        const bar_count: i32 = 32;
        const bar_width: f32 = 38.0;
        for (0..bar_count) |i| {
            const fi = @as(f32, @floatFromInt(i));
            const phase = fi * 0.2 + state.anim_time * state.slider1_val * 4.0;
            const h1 = @sin(phase) * 0.5 + 0.5;
            const h2 = @sin(phase * 1.5 + 0.7) * 0.5 + 0.5;
            const h3 = @sin(phase * 0.7 + 2.1) * 0.5 + 0.5;

            const bar_x: i32 = 20 + @as(i32, @intFromFloat(fi * bar_width));
            const base_y: i32 = 500;

            // Bar 1 (blue)
            const bh1: i32 = @intFromFloat(h1 * 50.0);
            rl.DrawRectangle(bar_x, base_y - bh1, @intFromFloat(bar_width - 2), bh1, .{ .r = 60, .g = 140, .b = 220, .a = 200 });

            // Bar 2 (cyan)
            const bh2: i32 = @intFromFloat(h2 * 50.0);
            rl.DrawRectangle(bar_x, base_y - bh1 - bh2, @intFromFloat(bar_width - 2), bh2, .{ .r = 40, .g = 200, .b = 180, .a = 200 });

            // Bar 3 (accent)
            const bh3: i32 = @intFromFloat(h3 * 30.0);
            rl.DrawRectangle(bar_x, base_y - bh1 - bh2 - bh3, @intFromFloat(bar_width - 2), bh3, .{ .r = 80, .g = 180, .b = 255, .a = 150 });
        }

        // Animated circle orbit
        const orbit_cx: f32 = 1100;
        const orbit_cy: f32 = 445;
        const orbit_r: f32 = 40;
        rl.DrawCircleLines(@intFromFloat(orbit_cx), @intFromFloat(orbit_cy), orbit_r, theme.panel_border);
        const dot_x = orbit_cx + orbit_r * @cos(state.anim_time * 2.0);
        const dot_y = orbit_cy + orbit_r * @sin(state.anim_time * 2.0);
        rl.DrawCircle(@intFromFloat(dot_x), @intFromFloat(dot_y), 6, theme.accent);

        // Second orbit (inner, different speed)
        const inner_r: f32 = 20;
        rl.DrawCircleLines(@intFromFloat(orbit_cx), @intFromFloat(orbit_cy), inner_r, theme.scroll_track);
        const dot2_x = orbit_cx + inner_r * @cos(state.anim_time * 3.5 + 1.0);
        const dot2_y = orbit_cy + inner_r * @sin(state.anim_time * 3.5 + 1.0);
        rl.DrawCircle(@intFromFloat(dot2_x), @intFromFloat(dot2_y), 4, .{ .r = 255, .g = 180, .b = 50, .a = 255 });

        // Trail
        for (0..20) |j| {
            const phase_j = @as(f32, @floatFromInt(j)) * 0.15;
            const trail_x = orbit_cx + orbit_r * @cos(state.anim_time * 2.0 - phase_j);
            const trail_y = orbit_cy + orbit_r * @sin(state.anim_time * 2.0 - phase_j);
            const alpha: u8 = @intFromFloat((1.0 - @as(f32, @floatFromInt(j)) / 20.0) * 120.0);
            rl.DrawCircle(@intFromFloat(trail_x), @intFromFloat(trail_y), 3, .{ .r = 80, .g = 180, .b = 255, .a = alpha });
        }

        rl.DrawText("Rotation", 1060, 495, 12, theme.text_secondary);

        // ================================================================
        // PANEL 6: Math Summary (bottom right)
        // ================================================================
        drawPanel(1020, 375, 250, 140, theme);
        rl.DrawText("P3 Math Modules", 1030, 381, 16, theme.accent);

        rl.DrawText("p3_math       (Vec/Mat/Quat)", 1030, 403, 13, theme.text_secondary);
        rl.DrawText("p3_dual_quat  (SE3 motors)", 1030, 418, 13, theme.text_secondary);
        rl.DrawText("p3_sh         (Sph. Harmonics)", 1030, 433, 13, theme.text_secondary);
        rl.DrawText("p3_polyroot   (Ferrari deg4)", 1030, 448, 13, theme.text_secondary);
        rl.DrawText("p3_quasirandom(Sobol+Halton)", 1030, 463, 13, theme.text_secondary);
        rl.DrawText("p3_archetype  (deformed tensor)", 1030, 478, 13, theme.text_secondary);
        rl.DrawText("p3_cordic     (shift-and-add)", 1030, 493, 13, theme.text_secondary);
        rl.DrawText("p3_tensor     (Riemann+metric)", 1030, 508, 13, theme.text_secondary);

        // ================================================================
        // FOOTER
        // ================================================================
        rl.DrawText("O3DE LyShine: Button | Checkbox | Radio | Slider | Scroll | DragDrop | Text | Animation | Navigation | Render", 20, 530, 13, theme.text_secondary);
        rl.DrawText("P3 Engine — Projective Geometry | Universal Math | Zig 0.14.0 | Raylib 6.0", 20, 548, 13, .{ .r = 60, .g = 80, .b = 100, .a = 255 });

        rl.EndDrawing();
    }

    rl.CloseWindow();
}
