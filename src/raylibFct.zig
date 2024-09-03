const std = @import("std");
const rl = @import("raylib");
const Allocator = std.mem.Allocator;
const PostnikovQuiver = @import("./main.zig").LabelCollection.PostnikovQuiver;

pub fn raylibShowPostnikovQuiver(allocator: Allocator, p_quiver: *PostnikovQuiver) !void {
    const screenWidth = 800;
    const screenHeight = 450;

    rl.setConfigFlags(.{
        //.window_resizable = true,
        .window_highdpi = true,
        .vsync_hint = true,
    });
    rl.initWindow(screenWidth, screenHeight, "raylib-zig [shapes] example - raylib logo using shapes");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    const num = allocator.create(u8) catch {
        return;
    };
    num.* = 100;
    const raylib_zig = rl.Color.init(num.*, 164, 29, 255);

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.ray_white);

        var vert_it = p_quiver.quiver.vertexIterator();
        while (vert_it.next()) |v| {
            if (p_quiver.vertex_info.get(v)) |inf| {
                rl.drawCircle(@intFromFloat(inf.pos.x), @intFromFloat(inf.pos.y), 5, rl.Color.red);
            }
        }
        rl.drawFPS(500, 400);

        rl.drawRectangle(screenWidth / 2 - 128, screenHeight / 2 - 128, 256, 256, raylib_zig);
        rl.drawRectangle(screenWidth / 2 - 112, screenHeight / 2 - 112, 224, 224, rl.Color.ray_white);
        rl.drawText("raylib-zig", screenWidth / 2 - 96, screenHeight / 2 + 57, 41, raylib_zig);
        //----------------------------------------------------------------------------------
    }
    allocator.destroy(num);
}
