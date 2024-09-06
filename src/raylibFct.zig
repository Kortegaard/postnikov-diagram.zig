const std = @import("std");
const rl = @import("raylib");
const Allocator = std.mem.Allocator;
//const PostnikovQuiver = @import("./main.zig").LabelCollection.PostnikovQuiver;
const PostnikovQuiver = @import("./PostnikovData.zig").PostnikovQuiver;
const PostnikovPlabicGraph = @import("./PostnikovData.zig").PostnikovPlabicGraph;

var isPressed: bool = false;
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

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    const num = allocator.create(u8) catch {
        return;
    };
    num.* = 100;
    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        try p_quiver.apply_spring_step(0.1, 0.4, 0.4, 50);
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
                    }
                }
            }
        }

        drawPlabicGraph(plabic);
        drawPostnikovQuiver(p_quiver);
        plabic.setLocationBasedOnPostnikovQuiver(p_quiver.*);
        rl.drawFPS(0, 0);
    }
    allocator.destroy(num);
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
            rl.drawCircle(@intFromFloat(inf.pos.x), @intFromFloat(inf.pos.y), radius, if (inf.frozen) rl.Color.blue else rl.Color.red);
        }
    }
}
pub fn drawPlabicGraph(plabic: *PostnikovPlabicGraph) void {
    var arr_it2 = plabic.quiver.arrowIterator();
    while (arr_it2.next()) |ar| {
        const from_info = plabic.vertex_info.get(ar.from) orelse continue;
        const to_info = plabic.vertex_info.get(ar.to) orelse continue;
        rl.drawLine(@intFromFloat(from_info.pos.x), @intFromFloat(from_info.pos.y), @intFromFloat(to_info.pos.x), @intFromFloat(to_info.pos.y), rl.Color.light_gray);
    }
    var vert_it2 = plabic.quiver.vertexIterator();
    while (vert_it2.next()) |v| {
        if (plabic.vertex_info.get(v)) |inf| {
            var radius: f32 = 5;
            if (rl.checkCollisionPointCircle(rl.getMousePosition(), rl.Vector2{ .x = inf.pos.x, .y = inf.pos.y }, 8)) {
                radius = 8;
            }
            rl.drawCircle(@intFromFloat(inf.pos.x), @intFromFloat(inf.pos.y), radius, if (inf.color == .white) rl.Color.light_gray else rl.Color.black);
        }
    }
}
