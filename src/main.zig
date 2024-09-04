const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const hashing = @import("hashing.zig");
const Quiver = @import("vendor/graph.zig/src/DirectedGraph.zig").Quiver;
const Pos2 = @import("helpers.zig").Pos2;
const PostnikovQuiver = @import("PostnikovData.zig").PostnikovQuiver;
const PostnikovPlabicGraph = @import("PostnikovData.zig").PostnikovPlabicGraph;
const LabelFct = @import("LabelFunctions.zig");
const LabelCollection = @import("LabelCollection.zig");

const that = @This();

pub fn getAllocator() Allocator {
    if (builtin.os.tag == .emscripten)
        return std.heap.c_allocator;
    if (builtin.target.isWasm())
        return std.heap.wasm_allocator;
    return std.heap.page_allocator;
}

const r = @import("./raylibFct.zig");
pub fn main() !void {
    //
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    //_ = allocatorr;
    //const allocator = getAllocator();
    const input = "3";

    const integer = try std.fmt.parseInt(usize, input, 10);
    std.debug.print("The user entered number: {d}\n", .{integer});

    var a = LabelCollection.init(allocator, 5, 10);
    defer a.deinit();
    try a.addLabel(&[_]i32{ 1, 2, 3, 4, 6 });
    try a.addLabel(&[_]i32{ 1, 6, 7, 8, 9 });
    try a.addLabel(&[_]i32{ 1, 2, 3, 4, 7 });
    try a.addLabel(&[_]i32{ 2, 6, 7, 8, 9 });
    try a.addLabel(&[_]i32{ 1, 2, 3, 4, 9 });
    try a.addLabel(&[_]i32{ 4, 6, 7, 8, 9 });
    try a.addLabel(&[_]i32{ 1, 2, 3, 7, 9 });
    try a.addLabel(&[_]i32{ 2, 4, 6, 7, 8 });
    try a.addLabel(&[_]i32{ 1, 2, 3, 8, 9 });
    try a.addLabel(&[_]i32{ 3, 4, 6, 7, 8 });
    try a.addLabel(&[_]i32{ 1, 2, 4, 7, 9 });
    try a.addLabel(&[_]i32{ 2, 4, 6, 7, 9 });
    try a.addLabel(&[_]i32{ 1, 2, 7, 8, 9 });
    try a.addLabel(&[_]i32{ 2, 3, 4, 6, 7 });
    try a.addLabel(&[_]i32{ 2, 3, 4, 7, 9 });
    try a.addLabel(&[_]i32{ 2, 4, 7, 8, 9 });
    try a.addLabel(&[_]i32{ 1, 2, 3, 4, 5 });
    try a.addLabel(&[_]i32{ 2, 3, 4, 5, 6 });
    try a.addLabel(&[_]i32{ 3, 4, 5, 6, 7 });
    try a.addLabel(&[_]i32{ 4, 5, 6, 7, 8 });
    try a.addLabel(&[_]i32{ 5, 6, 7, 8, 9 });
    try a.addLabel(&[_]i32{ 6, 7, 8, 9, 10 });
    try a.addLabel(&[_]i32{ 1, 7, 8, 9, 10 });
    try a.addLabel(&[_]i32{ 1, 2, 8, 9, 10 });
    try a.addLabel(&[_]i32{ 1, 2, 3, 9, 10 });
    try a.addLabel(&[_]i32{ 1, 2, 3, 4, 10 });

    std.debug.print("k = {any}\n", .{a.collection.items[0].len});

    a.print();
    a.prettyPrint();

    const white_cliques = try a.getWhiteCliquesSorted();
    defer {
        for (white_cliques.items) |wc| {
            wc.deinit();
        }
        white_cliques.deinit();
    }

    std.debug.print("\n\n\nWhite Cliques:\n", .{});
    for (white_cliques.items) |wc| {
        std.debug.print("{any}\n", .{wc.items});
    }

    const black_cliques = try a.getBlackCliquesSorted();
    defer {
        for (black_cliques.items) |wc| {
            wc.deinit();
        }
        black_cliques.deinit();
    }

    std.debug.print("\n\n\nBlack Cliques:\n", .{});
    for (black_cliques.items) |wc| {
        std.debug.print("{any}\n", .{wc.items});
    }

    std.debug.print("\n" ** 4, .{});
    var map = hashing.SliceHashMap(i32, i32).init(allocator);
    defer map.deinit();
    try map.put(&[_]i32{ 1, 2, 3 }, -7);
    try map.put(&[_]i32{ 1, 2, 4 }, -6);
    std.debug.print("{any}\n", .{map.get(&[_]i32{ 1, 2, 3 })});
    std.debug.print("{any}\n", .{map.get(&[_]i32{ 1, 2, 4 })});
    std.debug.print("{any}\n", .{map.get(&[_]i32{ 1, 4, 2 })});

    std.debug.print("\n" ** 4, .{});

    //var p_quiver = try a.getPostnikovQuiver(.{ .center_x = 200, .center_y = 200, .radius = 190 });
    var p_quiver = try PostnikovQuiver.initFromLabelCollection(allocator, a, .{ .center_x = 200, .center_y = 200, .radius = 190 });
    defer p_quiver.deinit();

    var v_it = p_quiver.quiver.vertexIterator();
    while (v_it.next()) |vert| {
        std.debug.print("{any}\n", .{vert});
    }

    std.debug.print("\n" ** 1, .{});
    var a_it = p_quiver.quiver.arrowIterator();
    while (a_it.next()) |arrow| {
        std.debug.print("{any} -- {any} --> {any}\n", .{ arrow.from, arrow.label, arrow.to });
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("stdout\n", .{});
    try bw.flush(); // don't forget to flush!

    var plabicGraph = try PostnikovPlabicGraph.initFromLabelCollection(allocator, a, .{});
    defer plabicGraph.deinit();

    std.debug.print("\n----PROJECTIVES\n", .{});
    const projs = try a.getProjectiveLabels();
    defer projs.deinit();
    for (projs.items) |proj| {
        std.debug.print("{any}\n", .{proj});
    }

    plabicGraph.setLocationBasedOnPostnikovQuiver(p_quiver);

    try r.raylibShowPostnikovQuiver(allocator, &p_quiver, &plabicGraph);
}
