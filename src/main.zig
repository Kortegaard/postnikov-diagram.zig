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

var gpa: ?std.heap.GeneralPurposeAllocator(.{}) = null;

pub fn getAllocator() Allocator {
    if (builtin.os.tag == .emscripten)
        return std.heap.c_allocator;
    if (builtin.target.isWasm())
        return std.heap.wasm_allocator;
    gpa = std.heap.GeneralPurposeAllocator(.{}){};
    return gpa.?.allocator();
}


const r = @import("./raylibFct.zig");

pub fn main() !void {
    const allocator = getAllocator();

    var a = try LabelCollection.initWithDefaultSeed(allocator, 4, 8);
    defer a.deinit();

    try r.init(allocator, a);
    try r.raylibShowPostnikovQuiver();

    if(gpa)|*g|{
        const check = g.deinit();
        std.debug.print("Data leak check: {any}",  .{check});
    }
}
