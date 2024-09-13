const std = @import("std");
const Spline2 = @import("helpers.zig").Spline2;
const rl = @import("raylib");
const Allocator = std.mem.Allocator;
//const PostnikovQuiver = @import("./main.zig").LabelCollection.PostnikovQuiver;
const PostnikovQuiver = @import("./PostnikovQuiver.zig").PostnikovQuiver;
const PostnikovPlabicGraph = @import("./PostnikovPlabicGraph.zig").PostnikovPlabicGraph;

var isPressed: bool = false;

var cl = rl.Color.red;

const MState = struct {
    // Clique color
    white_clique_color: rl.Color = rl.Color.light_gray,
    black_clique_color: rl.Color = rl.Color.black,
    clique_edge_color: rl.Color = rl.Color.light_gray,

    // Label collection color
    label_color: rl.Color = rl.Color.red,
    frozen_label_color: rl.Color = rl.Color.blue,
    strand_color: rl.Color = rl.Color.black,
    arrow_color: rl.Color = rl.Color.green,
};

var p_state: MState = .{};

pub export fn mytest(testpar: [*c]const u8) void {
    std.debug.print("TEt {any}\n", .{testpar[1]});
    p_state.label_color = rl.Color.blue;
}

pub fn raylibShowPostnikovQuiver(allocator: Allocator, p_quiver: *PostnikovQuiver, plabic: *PostnikovPlabicGraph) !void {
    const screenWidth = 700;
    const screenHeight = 400;

    rl.setConfigFlags(.{
        //.window_resizable = true,
        .window_highdpi = true,
        //.vsync_hint = true,
    });
    rl.initWindow(screenWidth, screenHeight, "raylib-zig [shapes] example - raylib logo using shapes");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(120); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    const num = allocator.create(u8) catch {
        return;
    };
    num.* = 100;
    // Main game loop
    var num2: i32 = 0;
    var splines: ?std.ArrayList(Spline2) = null;
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        try p_quiver.apply_spring_step(0.1, 0.4, 0.4, 50);
        if (num2 < 300) num2 += 1;
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.ray_white);

        if (!isPressed and rl.isMouseButtonDown(.mouse_button_left)) {
            isPressed = true;
        }
        if (isPressed and rl.isMouseButtonReleased(.mouse_button_left)) {
            isPressed = false;
            var vert_it = p_quiver.quiver.vertexIterator();
            while (vert_it.next()) |v| {
                if (p_quiver.vertex_info.get(v)) |inf| {
                    if (rl.checkCollisionPointCircle(rl.getMousePosition(), rl.Vector2{ .x = inf.pos.x, .y = inf.pos.y }, 8)) {
                        std.debug.print("{any}\n", .{v});
                    }
                }
            }
            var vert_it2 = plabic.quiver.vertexIterator();
            while (vert_it2.next()) |v| {
                if (plabic.vertex_info.get(v)) |inf| {
                    if (rl.checkCollisionPointCircle(rl.getMousePosition(), rl.Vector2{ .x = inf.pos.x, .y = inf.pos.y }, 8)) {
                        std.debug.print("{any}\n", .{inf.clique.items});
                        std.debug.print("{any}\n", .{plabic.quiver.getArrowsOut(v)});
                    }
                }
            }
        }

        drawPlabicGraph(plabic);
        drawPostnikovQuiver(p_quiver);
        plabic.setLocationBasedOnPostnikovQuiver(p_quiver.*);
        if (num2 > 160 and splines == null) {
            splines = try plabic.getPostnikovDiagramSplines(p_quiver.*);
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
    allocator.destroy(num);
}

pub fn drawStandardTriangle(pos: rl.Vector2, scale: f32, rotation: f32) void {
    const p1 = rl.Vector2{ .x = 0.0, .y = -0.5 };
    const p2 = rl.Vector2{ .x = 0.0, .y = 0.5 };
    const p3 = rl.Vector2{ .x = 1.0, .y = 0.0 };
    //std.debug.print("{d}\n", .{p1.lineAngle(p2)});
    rl.drawTriangle(p1.scale(scale).rotate(-rotation).add(pos), p2.scale(scale).rotate(-rotation).add(pos), p3.scale(scale).rotate(-rotation).add(pos), p_state.strand_color);
}

pub fn drawStandardTriangleCentered(pos: rl.Vector2, scale: f32, rotation: f32) void {
    const p1 = rl.Vector2{ .x = 0.0, .y = -0.5 };
    const p2 = rl.Vector2{ .x = 0.0, .y = 0.5 };
    const p3 = rl.Vector2{ .x = 1.0, .y = 0.0 };
    const center = rl.Vector2{ .x = 0.3, .y = 0.0 };

    //std.debug.print("{d}\n", .{p1.lineAngle(p2)});
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
            var radius: f32 = 5;
            if (rl.checkCollisionPointCircle(rl.getMousePosition(), rl.Vector2{ .x = inf.pos.x, .y = inf.pos.y }, 8)) {
                radius = 8;
            }
            rl.drawCircle(@intFromFloat(inf.pos.x), @intFromFloat(inf.pos.y), radius, if (inf.frozen) p_state.frozen_label_color else p_state.label_color);
        }
    }
}
pub fn drawPlabicGraph(plabic: *PostnikovPlabicGraph) void {
    var arr_it2 = plabic.quiver.arrowIterator();
    while (arr_it2.next()) |ar| {
        const from_info = plabic.vertex_info.get(ar.from) orelse {
            //std.debug.print("from: '{s}', to: '{s}'\n", .{ ar.from, ar.to });
            @panic("hej");
        };
        const to_info = plabic.vertex_info.get(ar.to) orelse @panic("hej");
        rl.drawLine(@intFromFloat(from_info.pos.x), @intFromFloat(from_info.pos.y), @intFromFloat(to_info.pos.x), @intFromFloat(to_info.pos.y), p_state.clique_edge_color);
    }
    var vert_it2 = plabic.quiver.vertexIterator();
    while (vert_it2.next()) |v| {
        if (plabic.vertex_info.get(v)) |inf| {
            var radius: f32 = 5;
            if (rl.checkCollisionPointCircle(rl.getMousePosition(), rl.Vector2{ .x = inf.pos.x, .y = inf.pos.y }, 8)) {
                radius = 8;
            }
            rl.drawCircle(@intFromFloat(inf.pos.x), @intFromFloat(inf.pos.y), radius, if (inf.color == .white) p_state.white_clique_color else p_state.black_clique_color);
        }
    }
}
