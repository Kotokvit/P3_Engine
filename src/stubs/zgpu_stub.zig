// =============================================================================
// STUB: zgpu — минимальный интерфейс для тестов без GPU
// =============================================================================
// Тестам p3_gpu_rt.zig нужен @import("zgpu") для типов.
// Этот стаб предоставляет пустые типы — тесты проверяют layout/WGSL, не GPU.

const std = @import("std");

pub const wgpu = struct {
    pub const ShaderModule = *opaque {};
    pub const ComputePipeline = *opaque {};
    pub const RenderPipeline = *opaque {};
    pub const CommandEncoder = *opaque {};
    pub const ComputePassEncoder = *opaque {};
    pub const RenderPassEncoder = *opaque {};
    pub const CommandBuffer = *opaque {};

    pub const ComputePipelineDescriptor = struct {
        compute: ProgrammableStageDescriptor,
    };
    pub const ProgrammableStageDescriptor = struct {
        module: ShaderModule,
        entry_point: [:0]const u8,
    };
    pub const RenderPipelineDescriptor = struct {
        vertex: VertexState,
        primitive: PrimitiveState,
        depth_stencil: ?*const DepthStencilState = null,
        fragment: ?*const FragmentState = null,
    };
    pub const VertexState = struct {
        module: ShaderModule = undefined,
        entry_point: [:0]const u8 = "",
        buffer_count: u32 = 0,
        buffers: ?[]const VertexBufferLayout = null,
    };
    pub const PrimitiveState = struct {
        front_face: FrontFace = .ccw,
        cull_mode: CullMode = .none,
        topology: PrimitiveTopology = .triangle_list,
    };
    pub const DepthStencilState = struct {
        format: TextureFormat = .depth32_float,
        depth_write_enabled: bool = true,
        depth_compare: CompareFunction = .less,
    };
    pub const FragmentState = struct {
        module: ShaderModule = undefined,
        entry_point: [:0]const u8 = "",
        target_count: u32 = 0,
        targets: ?[]const ColorTargetState = null,
    };
    pub const VertexBufferLayout = struct {
        array_stride: u64 = 0,
        attribute_count: u32 = 0,
        attributes: ?[]const VertexAttribute = null,
    };
    pub const VertexAttribute = struct {
        format: VertexFormat = .float32x4,
        offset: u64 = 0,
        shader_location: u32 = 0,
    };
    pub const ColorTargetState = struct {
        format: TextureFormat = .rgba8_unorm,
    };
    pub const RenderPassDescriptor = struct {
        color_attachment_count: u32 = 0,
        color_attachments: ?[]const RenderPassColorAttachment = null,
        depth_stencil_attachment: ?*const RenderPassDepthStencilAttachment = null,
    };
    pub const RenderPassColorAttachment = struct {
        view: TextureView = undefined,
        load_op: LoadOp = .clear,
        store_op: StoreOp = .store,
        clear_value: Color = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
    };
    pub const RenderPassDepthStencilAttachment = struct {
        view: TextureView = undefined,
        depth_load_op: LoadOp = .clear,
        depth_store_op: StoreOp = .store,
        depth_clear_value: f32 = 1.0,
        stencil_load_op: LoadOp = .undefined,
        stencil_store_op: StoreOp = .undefined,
    };

    pub const FrontFace = enum { ccw, cw };
    pub const CullMode = enum { none, front, back };
    pub const PrimitiveTopology = enum(u8) { triangle_list, line_list, point_list, _ };
    pub const CompareFunction = enum { undefined, never, less, less_equal, greater, greater_equal, equal, not_equal, always };
    pub const VertexFormat = enum(u8) { float32x2, float32x3, float32x4, _ };
    pub const TextureFormat = enum(u8) { undefined, rgba8_unorm, rgba8_srgb, depth32_float, _ };
    pub const LoadOp = enum { undefined, clear, load };
    pub const StoreOp = enum { undefined, discard, store };

    pub const Color = struct { r: f64, g: f64, b: f64, a: f64 };

    pub const TextureView = *opaque {};
};

// Handle types (u32, matching zgpu pattern)
pub const BufferHandle = u32;
pub const TextureHandle = u32;
pub const TextureViewHandle = u32;
pub const BindGroupLayoutHandle = u32;
pub const BindGroupHandle = u32;
pub const PipelineLayoutHandle = u32;
pub const ComputePipelineHandle = u32;
pub const RenderPipelineHandle = u32;

pub const GraphicsContext = struct {
    pub const PresentResult = enum { ok, swap_chain_resized };
    pub const swapchain_format: wgpu.TextureFormat = .rgba8_unorm;
    swapchain_dimensions: Dimensions = .{ .width = 1280, .height = 720 },

    pub const Dimensions = struct { width: u32, height: u32 };
    pub fn deinit(self: *GraphicsContext, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }
    pub fn create(allocator: std.mem.Allocator, desc: anytype, opts: anytype) !GraphicsContext {
        _ = allocator;
        _ = desc;
        _ = opts;
        return .{};
    }
    pub fn present(self: *GraphicsContext) PresentResult {
        _ = self;
        return .ok;
    }
};

pub fn createWgslShaderModule(device: anytype, code: [:0]const u8, label: [:0]const u8) wgpu.ShaderModule {
    _ = device;
    _ = code;
    _ = label;
    return undefined;
}

pub fn addLibraryPathsTo(exe: *std.Build.Step.Compile) void {
    _ = exe;
}

// Stub build dependency
pub fn addLibraryPathsToStep(step: *std.Build.Step) void {
    _ = step;
}

// Resource management stubs
pub fn bufferEntry(binding: u32, visibility: BufferVisibility, ty: BufferType, has_dynamic_offset: bool, min_binding_size: u32) BufferEntry {
    return .{
        .binding = binding,
        .visibility = visibility,
        .ty = ty,
        .has_dynamic_offset = has_dynamic_offset,
        .min_binding_size = min_binding_size,
    };
}

pub const BufferVisibility = struct { storage: bool = false, uniform: bool = false, vertex: bool = false };
pub const BufferType = enum { storage, uniform };
pub const BufferEntry = struct {
    binding: u32 = 0,
    visibility: BufferVisibility = .{},
    ty: BufferType = .storage,
    has_dynamic_offset: bool = false,
    min_binding_size: u32 = 0,
};
