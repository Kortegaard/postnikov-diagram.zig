const std = @import("std");
const rl = @import("raylib");
const Allocator = std.mem.Allocator;
const PostnikovQuiver = @import("./main.zig").LabelCollection.PostnikovQuiver;

pub fn raylibShowPostnikovQuiver(allocator: Allocator, p_quiver: *PostnikovQuiver) !void {
    const screenWidth = 400;
    const screenHeight = 400;

    rl.setConfigFlags(.{
        //.window_resizable = true,
        .window_highdpi = true,
        .vsync_hint = true,
    });
    rl.initWindow(screenWidth, screenHeight, "raylib-zig [shapes] example - raylib logo using shapes");
    defer rl.closeWindow(); // Close window and OpenGL context

    //rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    const num = allocator.create(u8) catch {
        return;
    };
    num.* = 100;
    //const raylib_zig = rl.Color.init(num.*, 164, 29, 255);

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.ray_white);

        var vert_it = p_quiver.quiver.vertexIterator();
        while (vert_it.next()) |v| {
            if (p_quiver.vertex_info.get(v)) |inf| {
                rl.drawCircle(@intFromFloat(inf.pos.x), @intFromFloat(inf.pos.y), 5, if (inf.frozen) rl.Color.blue else rl.Color.red);
            }
        }
        var arr_it = p_quiver.quiver.arrowIterator();
        while (arr_it.next()) |ar| {
            //pub fn drawLine(self: *Image, startPosX: i32, startPosY: i32, endPosX: i32, endPosY: i32, color: Color) void {

            const from_info = p_quiver.vertex_info.get(ar.from) orelse continue;
            const to_info = p_quiver.vertex_info.get(ar.to) orelse continue;
            rl.drawLine(@intFromFloat(from_info.pos.x), @intFromFloat(from_info.pos.y), @intFromFloat(to_info.pos.x), @intFromFloat(to_info.pos.y), rl.Color.green);
        }
        rl.drawFPS(0, 0);

        //rl.drawRectangle(screenWidth / 2 - 128, screenHeight / 2 - 128, 256, 256, raylib_zig);
        //----------------------------------------------------------------------------------
    }
    allocator.destroy(num);
}
