const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const hashing = @import("hashing.zig");
const Quiver = @import("vendor/graph.zig/src/DirectedGraph.zig").Quiver;
const Pos2 = @import("helpers.zig").Pos2;
const PostnikovQuiver = @import("PostnikovQuiver.zig").PostnikovQuiver;
const LabelFct = @import("LabelFunctions.zig");
const PostnikovPlabicGraph = @import("PostnikovPlabicGraph.zig").PostnikovPlabicGraph;
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
    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //const allocator = gpa.allocator();
    //_ = allocatorr;

    const allocator = getAllocator();

    var a = try LabelCollection.initWithDefaultSeed(allocator, 4, 8);
    //var a = LabelCollection.init(allocator, 4, 8);
    defer a.deinit();
    //try a.addLabel(&[_]i32{ 1, 2, 3, 4 });
    //try a.addLabel(&[_]i32{ 2, 3, 4, 5 });
    //try a.addLabel(&[_]i32{ 3, 4, 5, 6 });
    //try a.addLabel(&[_]i32{ 4, 5, 6, 7 });
    //try a.addLabel(&[_]i32{ 5, 6, 7, 8 });
    //try a.addLabel(&[_]i32{ 1, 6, 7, 8 });
    //try a.addLabel(&[_]i32{ 1, 2, 7, 8 });
    //try a.addLabel(&[_]i32{ 1, 2, 3, 8 });

    //try a.addLabel(&[_]i32{ 2, 6, 4, 5 });
    //try a.addLabel(&[_]i32{ 1, 2, 4, 5 });
    //try a.addLabel(&[_]i32{ 1, 2, 4, 6 });
    //try a.addLabel(&[_]i32{ 1, 4, 5, 6 });
    //try a.addLabel(&[_]i32{ 1, 2, 5, 6 });
    //try a.addLabel(&[_]i32{ 1, 2, 3, 6 });
    //try a.addLabel(&[_]i32{ 1, 5, 6, 7 });
    //try a.addLabel(&[_]i32{ 1, 2, 6, 7 });
    //try a.addLabel(&[_]i32{ 1, 2, 3, 7 });

    //try a.addLabel(&[_]i32{ 1, 2, 3, 4 });
    //try a.addLabel(&[_]i32{ 2, 3, 4, 5 });
    //try a.addLabel(&[_]i32{ 2, 6, 4, 5 });
    //try a.addLabel(&[_]i32{ 1, 2, 4, 5 });
    //try a.addLabel(&[_]i32{ 1, 2, 4, 6 });
    //try a.addLabel(&[_]i32{ 3, 4, 5, 6 });
    //try a.addLabel(&[_]i32{ 1, 4, 5, 6 });
    //try a.addLabel(&[_]i32{ 1, 2, 5, 6 });
    //try a.addLabel(&[_]i32{ 1, 2, 3, 6 });
    //try a.addLabel(&[_]i32{ 4, 5, 6, 7 });
    //try a.addLabel(&[_]i32{ 1, 5, 6, 7 });
    //try a.addLabel(&[_]i32{ 1, 2, 6, 7 });
    //try a.addLabel(&[_]i32{ 1, 2, 3, 7 });
    //try a.addLabel(&[_]i32{ 5, 6, 7, 8 });
    //try a.addLabel(&[_]i32{ 1, 6, 7, 8 });
    //try a.addLabel(&[_]i32{ 1, 2, 7, 8 });
    //try a.addLabel(&[_]i32{ 1, 2, 3, 8 });

    //try a.addLabel(&[_]i32{ 5, 6, 7, 8, 9 });

    //try a.addLabel(&[_]i32{ 6, 7, 8, 9, 10 });
    //try a.addLabel(&[_]i32{ 1, 7, 8, 9, 10 });
    //try a.addLabel(&[_]i32{ 1, 2, 8, 9, 10 });
    //try a.addLabel(&[_]i32{ 1, 2, 3, 9, 10 });
    //try a.addLabel(&[_]i32{ 1, 2, 3, 4, 10 });

    try r.init(allocator, a);
    try r.raylibShowPostnikovQuiver();
}
