const std = @import("std");
const Spline2 = @import("helpers.zig").Spline2;
const rl = @import("raylib");
const Allocator = std.mem.Allocator;
//const PostnikovQuiver = @import("./main.zig").LabelCollection.PostnikovQuiver;
const PostnikovQuiver = @import("./PostnikovQuiver.zig").PostnikovQuiver;
const PostnikovPlabicGraph = @import("./PostnikovPlabicGraph.zig").PostnikovPlabicGraph;

var isPressed: bool = false;

var cl = rl.Color.red;
var alloc: Allocator = std.heap.c_allocator;

const MState = struct {
    plabic_graph: PostnikovPlabicGraph,
    // Clique color
    white_clique_color: rl.Color = rl.Color.light_gray,
    black_clique_color: rl.Color = rl.Color.black,
    clique_edge_color: rl.Color = rl.Color.light_gray,

    clique_vertex_size: f32 = 5,
    clique_vertex_marked_size: f32 = 8,

    // Label collection color
    label_color: rl.Color = rl.Color.red,
    frozen_label_color: rl.Color = rl.Color.blue,
    strand_color: rl.Color = rl.Color.black,
    arrow_color: rl.Color = rl.Color.green,
    label_vertex_size: f32 = 5,
    label_vertex_marked_size: f32 = 8,

    //
    postnikov_quiver: PostnikovQuiver,
};
var p_state: MState = undefined;

pub fn init(allocator: Allocator, p_quiver: PostnikovQuiver, plabic: PostnikovPlabicGraph) void {
    alloc = allocator;
    p_state = .{
        .plabic_graph = plabic,
        .postnikov_quiver = p_quiver,
    };
}

pub fn deinit() void {
    p_state.postnikov_quiver.deinit();
    p_state.plabic_graph.deinit();
}

pub export fn updateLabelCollection(text: [*c]const u8) void {
    const as_slice: [:0]const u8 = std.mem.span(text);
    const parsed_json = std.json.parseFromSlice([][]i32, alloc, as_slice, .{}) catch {
        std.debug.print("Json need to be on for [][]i32\n", .{});
        return;
    };
    defer parsed_json.deinit();
    const json = parsed_json.value;
    if (json.len == 0) {
        std.debug.print("length 0\n", .{});
        return;
    }
    const guessed_k: usize = json[0].len;
    if (guessed_k == 0) {
        std.debug.print("All labels must have length >= 1\n", .{});
        return;
    }
    var guessed_n: usize = 0;
    for (json) |label| {
        if (label.len != guessed_k) {
            std.debug.print("mixed length\n", .{});
            return;
        }
        for (label) |val| {
            if (val <= 0) {
                std.debug.print("numbers must be possitive\n", .{});
                return;
            }
            if (val >= guessed_n) {
                guessed_n = @intCast(val);
            }
        }
    }
    if (guessed_k >= guessed_n) {
        std.debug.print("must have that k < n\n", .{});
        return;
    }
    std.debug.print("k: {d}, n:{d}, json {any}\n", .{ guessed_k, guessed_n, json });
}

pub fn raylibShowPostnikovQuiver() !void {
    const screenWidth = 400;
    const screenHeight = 400;

    rl.setConfigFlags(.{
        //.window_resizable = true,
        .window_highdpi = true,
        //.vsync_hint = true,
    });
    rl.initWindow(screenWidth, screenHeight, "Postnikov App");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(120); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    const num = alloc.create(u8) catch {
        return;
    };
    num.* = 100;
    // Main game loop
    var num2: i32 = 0;
    var splines: ?std.ArrayList(Spline2) = null;
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        try p_state.postnikov_quiver.apply_spring_step(0.1, 0.4, 0.4, 50);
        if (num2 < 300) num2 += 1;
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        if (!isPressed and rl.isMouseButtonDown(.mouse_button_left)) {
            isPressed = true;
        }
        if (isPressed and rl.isMouseButtonReleased(.mouse_button_left)) {
            isPressed = false;
            var vert_it = p_state.postnikov_quiver.quiver.vertexIterator();
            while (vert_it.next()) |v| {
                if (p_state.postnikov_quiver.vertex_info.get(v)) |inf| {
                    if (rl.checkCollisionPointCircle(rl.getMousePosition(), rl.Vector2{ .x = inf.pos.x, .y = inf.pos.y }, 8)) {
                        std.debug.print("{any}\n", .{v});
                    }
                }
            }
            var vert_it2 = p_state.plabic_graph.quiver.vertexIterator();
            while (vert_it2.next()) |v| {
                if (p_state.plabic_graph.vertex_info.get(v)) |inf| {
                    if (rl.checkCollisionPointCircle(rl.getMousePosition(), rl.Vector2{ .x = inf.pos.x, .y = inf.pos.y }, 8)) {
                        std.debug.print("{any}\n", .{inf.clique.items});
                        //std.debug.print("{any}\n", .{p_state.plabic_graph.quiver.getArrowsOut(v)});
                    }
                }
            }
        }

        drawPlabicGraph(&p_state.plabic_graph);
        drawPostnikovQuiver(&p_state.postnikov_quiver);
        p_state.plabic_graph.setLocationBasedOnPostnikovQuiver(p_state.postnikov_quiver);
        if (num2 > 160 and splines == null) {
            splines = try p_state.plabic_graph.getPostnikovDiagramSplines(p_state.postnikov_quiver);
        }
        if (splines) |spls| {
            for (spls.items, 0..) |spl, i| {
                drawSpline(spl);
                for (0..spl.points.items.len - 3) |j| {
                    const p1 = rl.getSplinePointCatmullRom(spl.points.items[j], spl.points.items[j + 1], spl.points.items[j + 2], spl.points.items[j + 3], 0.5);
                    const p2 = rl.getSplinePointCatmullRom(spl.points.items[j], spl.points.items[j + 1], spl.points.items[j + 2], spl.points.items[j + 3], 0.51);
                    const angl = p1.lineAngle(p2);

                    drawStandardTriangleCentered(p1, 10, angl);
                }

                //rl.drawCircle(@intFromFloat(pp3.x), @intFromFloat(pp3.y), 5, rl.Color.purple);

                if (i == 8) {
                    _ = .{};
                }
            }
        }
        rl.drawFPS(0, 0);
    }
    //for (splines.items) |*s| {
    //    s.deinit();
    //}
    //splines.deinit();
    alloc.destroy(num);
}

pub fn drawStandardTriangle(pos: rl.Vector2, scale: f32, rotation: f32) void {
    const p1 = rl.Vector2{ .x = 0.0, .y = -0.5 };
    const p2 = rl.Vector2{ .x = 0.0, .y = 0.5 };
    const p3 = rl.Vector2{ .x = 1.0, .y = 0.0 };
    rl.drawTriangle(p1.scale(scale).rotate(-rotation).add(pos), p2.scale(scale).rotate(-rotation).add(pos), p3.scale(scale).rotate(-rotation).add(pos), p_state.strand_color);
}

pub fn drawStandardTriangleCentered(pos: rl.Vector2, scale: f32, rotation: f32) void {
    const p1 = rl.Vector2{ .x = 0.0, .y = -0.5 };
    const p2 = rl.Vector2{ .x = 0.0, .y = 0.5 };
    const p3 = rl.Vector2{ .x = 1.0, .y = 0.0 };
    const center = rl.Vector2{ .x = 0.3, .y = 0.0 };

    rl.drawTriangle(
        p1.subtract(center).scale(scale).rotate(-rotation).add(pos),
        p2.subtract(center).scale(scale).rotate(-rotation).add(pos),
        p3.subtract(center).scale(scale).rotate(-rotation).add(pos),
        p_state.strand_color,
    );
}

pub fn drawSpline(spline: Spline2) void {
    rl.drawSplineCatmullRom(spline.points.items, 2, p_state.strand_color);
}

pub fn drawPostnikovQuiver(p_quiver: *PostnikovQuiver) void {
    var arr_it = p_quiver.quiver.arrowIterator();
    while (arr_it.next()) |ar| {
        const from_info = p_quiver.vertex_info.get(ar.from) orelse continue;
        const to_info = p_quiver.vertex_info.get(ar.to) orelse continue;
        rl.drawLine(@intFromFloat(from_info.pos.x), @intFromFloat(from_info.pos.y), @intFromFloat(to_info.pos.x), @intFromFloat(to_info.pos.y), rl.Color.green);
    }

    var vert_it = p_quiver.quiver.vertexIterator();
    while (vert_it.next()) |v| {
        if (p_quiver.vertex_info.get(v)) |inf| {
            var radius: f32 = p_state.clique_vertex_size;
            if (rl.checkCollisionPointCircle(rl.getMousePosition(), rl.Vector2{ .x = inf.pos.x, .y = inf.pos.y }, p_state.label_vertex_marked_size)) {
                radius = p_state.clique_vertex_marked_size;
            }
            rl.drawCircle(@intFromFloat(inf.pos.x), @intFromFloat(inf.pos.y), radius, if (inf.frozen) p_state.frozen_label_color else p_state.label_color);
        }
    }
}
pub fn drawPlabicGraph(plabic: *PostnikovPlabicGraph) void {
    var arr_it2 = plabic.quiver.arrowIterator();
    while (arr_it2.next()) |ar| {
        const from_info = plabic.vertex_info.get(ar.from) orelse {
            @panic("hej");
        };
        const to_info = plabic.vertex_info.get(ar.to) orelse @panic("hej");
        rl.drawLine(@intFromFloat(from_info.pos.x), @intFromFloat(from_info.pos.y), @intFromFloat(to_info.pos.x), @intFromFloat(to_info.pos.y), p_state.clique_edge_color);
    }
    var vert_it2 = plabic.quiver.vertexIterator();
    while (vert_it2.next()) |v| {
        if (plabic.vertex_info.get(v)) |inf| {
            var radius: f32 = p_state.clique_vertex_size;
            if (rl.checkCollisionPointCircle(rl.getMousePosition(), rl.Vector2{ .x = inf.pos.x, .y = inf.pos.y }, p_state.clique_vertex_marked_size)) {
                radius = p_state.clique_vertex_marked_size;
            }
            rl.drawCircle(@intFromFloat(inf.pos.x), @intFromFloat(inf.pos.y), radius, if (inf.color == .white) p_state.white_clique_color else p_state.black_clique_color);
        }
    }
}
