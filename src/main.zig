const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const hashing = @import("hashing.zig");
const Quiver = @import("vendor/graph.zig/src/DirectedGraph.zig").Quiver;

const that = @This();

pub fn getAllocator() Allocator {
    if (builtin.os.tag == .emscripten)
        return std.heap.c_allocator;
    if (builtin.target.isWasm())
        return std.heap.wasm_allocator;
    return std.heap.page_allocator;
}

/// a < b
// TODO: Find a way to ensure T is of type slice, and that the type insside T has <, >.
// NOTE: Potentially breaking if used in a bad way
pub fn isLessThanAlphabeticallyFct(comptime T: type) fn (void, a: T, b: T) bool {
    return struct {
        pub fn inner(_: void, a: T, b: T) bool {
            for (a, 0..) |item_a, i| {
                if (i >= b.len) return false;
                if (item_a < b[i]) return true;
                if (item_a > b[i]) return false;
            }
            return a.len != b.len;
        }
    }.inner;
}

/// a < b
pub fn isLessThanAlphabetically(a: []const i32, b: []const i32) bool {
    for (a, 0..) |item_a, i| {
        if (i >= b.len) return false;
        if (item_a < b[i]) return true;
        if (item_a > b[i]) return false;
    }
    return a.len != b.len;
}

test "fct: isLessThanAlphabetically" {
    // Test euals not given less than
    try std.testing.expectEqual(isLessThanAlphabetically(&[_]i32{ 1, 2, 3 }, &[_]i32{ 1, 2, 3 }), false);

    // Test subsets should be smaller
    try std.testing.expectEqual(isLessThanAlphabetically(&[_]i32{ 1, 2, 3 }, &[_]i32{ 1, 2, 3, 4 }), true);

    // Test basic functionality - True
    try std.testing.expectEqual(isLessThanAlphabetically(&[_]i32{ 1, 1, 3 }, &[_]i32{ 1, 2, 3 }), true);
    try std.testing.expectEqual(isLessThanAlphabetically(&[_]i32{ 1, 2, 3 }, &[_]i32{ 2, 3, 4, 5 }), true);

    // Test basic functionality - False
    try std.testing.expectEqual(isLessThanAlphabetically(&[_]i32{ 3, 2, 1 }, &[_]i32{ 1, 2, 3 }), false);
    try std.testing.expectEqual(isLessThanAlphabetically(&[_]i32{ 1, 2, 3 }, &[_]i32{ 1, 1, 3 }), false);

    // Test slice length cases
    try std.testing.expectEqual(isLessThanAlphabetically(&[_]i32{}, &[_]i32{ 1, 1, 3 }), true);
    try std.testing.expectEqual(isLessThanAlphabetically(&[_]i32{ 1, 2, 3 }, &[_]i32{ 1, 3 }), true);

    try std.testing.expectEqual(isLessThanAlphabetically(&[_]i32{1}, &[_]i32{}), false);
    try std.testing.expectEqual(isLessThanAlphabetically(&[_]i32{ 1, 2, 3 }, &[_]i32{ 1, 2 }), false);
}

pub fn isSubsetAssumeSorted(comptime T: type, subset: []const T, set: []const T) bool {
    if (subset.len > set.len) return false;
    if (subset.len == 0) return true;

    var subset_index: usize = 0;

    for (0..set.len) |i| {
        if (set[i] == subset[subset_index])
            subset_index += 1;
        if (subset_index == subset.len)
            return true;
    }

    return false;
}

test "fct: isSubsetAssumeSorted" {
    try std.testing.expectEqual(isSubsetAssumeSorted(i32, &[_]i32{ 1, 2, 3 }, &[_]i32{ 1, 2, 3, 4 }), true);
    try std.testing.expectEqual(isSubsetAssumeSorted(i32, &[_]i32{ 1, 2, 3 }, &[_]i32{ 1, 2, 4, 5 }), false);

    // Test need matches in end of array
    try std.testing.expectEqual(isSubsetAssumeSorted(i32, &[_]i32{ 1, 4, 5 }, &[_]i32{ 1, 2, 4, 5 }), true);

    // Test length special cases
    try std.testing.expectEqual(isSubsetAssumeSorted(i32, &[_]i32{}, &[_]i32{ 1, 2, 4, 5 }), true);
    try std.testing.expectEqual(isSubsetAssumeSorted(i32, &[_]i32{}, &[_]i32{}), true);
    try std.testing.expectEqual(isSubsetAssumeSorted(i32, &[_]i32{ 1, 2, 3, 4 }, &[_]i32{ 1, 2 }), false);

    // Test problem when not sorted
    try std.testing.expectEqual(isSubsetAssumeSorted(i32, &[_]i32{ 1, 2, 3 }, &[_]i32{ 3, 2, 1, 4 }), false);
}

pub fn isCyclicOrdered(a: i32, b: i32, c: i32) bool {
    const diff_b = b - a;
    const diff_c = c - a;
    if (diff_b > 0 and diff_c > 0) {
        return diff_b < diff_c;
    } else if (diff_b < 0 and diff_c < 0) {
        return diff_b < diff_c;
    } else if (diff_c < 0) {
        return true;
    }
    return false;
}

test "cyclic ordered" {
    try std.testing.expectEqual(isCyclicOrdered(1, 2, 3), true);
    try std.testing.expectEqual(isCyclicOrdered(3, 2, 1), false);
    try std.testing.expectEqual(isCyclicOrdered(4, 8, 1), true);
    try std.testing.expectEqual(isCyclicOrdered(9, 8, 1), false);
    try std.testing.expectEqual(isCyclicOrdered(1, 5, 4), false);
    try std.testing.expectEqual(isCyclicOrdered(6, 1, 2), true);

    // Ensure that the inequalities are sharp
    try std.testing.expectEqual(isCyclicOrdered(1, 1, 1), false);
    try std.testing.expectEqual(isCyclicOrdered(1, 1, 2), false);
    try std.testing.expectEqual(isCyclicOrdered(1, 2, 2), false);
    try std.testing.expectEqual(isCyclicOrdered(1, 2, 1), false);
}

// Best case (no overlaps) : O(|c1| + |c2|)
// worst case (Total overlap) : O(n^2)
pub fn isNonCrossing(c1: []const i32, c2: []const i32) bool {
    if (c1.len <= 1 or c2.len <= 1) return true;

    var i: usize = 0;
    var closest_clockwise: ?i32 = null; // Closest over
    var closest_anticlockwise: ?i32 = null; // closest under

    // Given an objects c2[i], find the closest elements to either side
    // We need the while loop in the case that c2[0] == c1[j] for some j
    while_loop: while (i < c2.len) : (i += 1) {
        closest_clockwise = null;
        closest_anticlockwise = null;

        for (c1) |c1_el| {
            if (c1_el == c2[i]) continue :while_loop;

            if (closest_clockwise == null or isCyclicOrdered(c2[i], c1_el, closest_clockwise.?)) {
                closest_clockwise = c1_el;
            }
            if (closest_anticlockwise == null or isCyclicOrdered(closest_anticlockwise.?, c1_el, c2[i])) {
                closest_anticlockwise = c1_el;
            }
        }
        break;
    }

    // It should theoretically be imposible for these to be null
    // Thus if they are not, the implementation above is wrong.
    std.debug.assert(closest_anticlockwise != null);
    std.debug.assert(closest_clockwise != null);

    // Check if every element in c2 is on the same side of closest_anticlockwise, and closest_clockwise,
    // as c2[i] is.
    while_loop: while (i < c2.len) : (i += 1) {
        if (isCyclicOrdered(closest_anticlockwise.?, c2[i], closest_clockwise.?)) {
            continue;
        }
        for (c1) |c1_el| {
            if (c1_el == c2[i]) continue :while_loop;
        }
        return false;
    }
    return true;
}

test "is non crossing" {
    // Basic case
    try std.testing.expectEqual(isNonCrossing(&[_]i32{ 1, 2, 3 }, &[_]i32{ 5, 6, 7 }), true);

    // Basic fail
    try std.testing.expectEqual(isNonCrossing(&[_]i32{ 1, 3, 4 }, &[_]i32{ 2, 5, 7 }), false);
    try std.testing.expectEqual(isNonCrossing(&[_]i32{ 1, 3, 4 }, &[_]i32{ 5, 2, 7 }), false);

    //Overlapping
    try std.testing.expectEqual(isNonCrossing(&[_]i32{ 1, 3, 4 }, &[_]i32{ 5, 3, 7 }), true);
    try std.testing.expectEqual(isNonCrossing(&[_]i32{ 1, 3, 5 }, &[_]i32{ 4, 1, 7 }), false);

    // Different size
    try std.testing.expectEqual(isNonCrossing(&[_]i32{ 3, 14 }, &[_]i32{ 1, 2, 5, 7, 9 }), false);
    try std.testing.expectEqual(isNonCrossing(&[_]i32{ 1, 3, 5, 14 }, &[_]i32{ 6, 13, 9 }), true);
}

pub fn rotateSet_c(n: i32, rotation_amount: i32, set: []i32) void {
    for (set) |*el| {
        el.* = @mod(el.* + rotation_amount, n);
        if (el.* == 0) {
            el.* = n;
        }
    }
}

test "fct: rotationSet_c" {
    // Standard use
    var a = [_]i32{ 1, 2, 3, 4 };
    rotateSet_c(10, 3, &a);
    try std.testing.expectEqualSlices(i32, &[_]i32{ 4, 5, 6, 7 }, &a);

    // Rotate array further that wrap + keep same order + don't mod to 0
    a = [_]i32{ 1, 2, 3, 4 };
    rotateSet_c(10, 8, &a);
    try std.testing.expectEqualSlices(i32, &[_]i32{ 9, 10, 1, 2 }, &a);
}

pub fn rotateSet(comptime size: usize, n: i32, rotation_amount: i32, set: [size]i32) [size]i32 {
    var new_arr: [size]i32 = undefined;
    for (set, 0..) |el, i| {
        new_arr[i] = @mod(el + rotation_amount, n);
        if (new_arr[i] == 0) {
            new_arr[i] = n;
        }
    }
    return new_arr;
}

test "fct: rotationSet" {
    // Standard use
    var a = rotateSet(4, 10, 3, .{ 1, 2, 3, 4 });
    try std.testing.expectEqualSlices(i32, &[_]i32{ 4, 5, 6, 7 }, &a);

    // Rotate array further that wrap + keep same order + don't mod to 0
    a = rotateSet(4, 10, 8, .{ 1, 2, 3, 4 });
    try std.testing.expectEqualSlices(i32, &[_]i32{ 9, 10, 1, 2 }, &a);
}

// All labels will be sorted to make implementation easier
//pub fn LabelCollection(k: i32, n: i32) type {
const LabelCollection = struct {
    const Self = @This();

    k: usize = 0,
    n: usize = 0,
    allocator: Allocator,
    collection: std.ArrayList([]i32),

    pub fn init(allocator: Allocator, k: usize, n: usize) Self {
        return .{
            .k = k,
            .n = n,
            .collection = std.ArrayList([]i32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Self) void {
        for (self.collection.items) |label| {
            self.allocator.free(label);
        }
        self.collection.deinit();
    }

    // Sorting the labels makes other calculations way simpler
    pub fn addLabel(self: *Self, label: []const i32) !void {
        if (label.len != self.k) return; // TODO: SHOULD BE ERROR

        // Copy and sort label
        var new_label = try self.allocator.alloc(i32, self.k);
        @memcpy(new_label[0..self.k], label[0..self.k]);
        std.mem.sort(i32, new_label[0..self.k], {}, comptime std.sort.asc(i32));

        //
        try self.collection.append(new_label);
    }

    pub fn print(self: Self) void {
        std.debug.print("LabelCollection({d},{d}){{", .{ self.k, self.n });
        for (self.collection.items, 0..) |it, i| {
            std.debug.print("{any}", .{it});
            if (i != self.collection.items.len - 1)
                std.debug.print(", ", .{});
        }
        std.debug.print("}}\n", .{});
    }

    // TODO: TEST
    pub fn rotate(self: *Self, rotation_amount: i32) void {
        for (self.collection.items) |*set| {
            rotateSet_c(self.n, rotation_amount, set);
        }
    }

    pub fn prettyPrint(self: Self) void {
        std.debug.print("LabelCollection({d},{d}){{", .{ self.k, self.n });
        for (self.collection.items) |it| {
            std.debug.print("  {any},\n", .{it});
        }
        std.debug.print("}}\n", .{});
    }

    pub fn isNonCrossing(self: Self) bool {
        for (0..self.collection.items.len) |i| {
            for (i + 1..self.collection.items.len) |j| {
                if (!that.isNonCrossing(&self.collection.items[i], &self.collection.items[j]))
                    return false;
            }
        }
        return true;
    }

    // TODO: Test
    pub fn isMaximalNonCrossing(self: Self) bool {
        return self.collection.len == self.k * (self.n - self.k) + 1 and self.isNonCrossing();
    }

    // TODO: Test
    pub fn isMaximalNonCrossingExcludeProjectives(self: Self) bool {
        return self.collection.len == self.k * (self.n - self.k) + 1 - self.n and self.isNonCrossing();
    }

    // TODO: Test
    pub fn containsLabel(self: Self, label: []i32) !bool {
        if (label.len != self.k) return false;

        var label_copy = try self.allocator.alloc(i32, self.k);
        defer self.allocator.free(label_copy);
        @memcpy(label_copy[0..self.k], label[0..self.k]);
        std.mem.sort(i32, label_copy[0..self.k], {}, comptime std.sort.asc(i32));

        const res = self.containsSortedLabel(label_copy);
        return res;
    }

    // TODO: Test
    pub fn containsSortedLabel(self: Self, label: []i32) bool {
        // Creating a sorted version of label

        outer_loop: for (self.collection.items) |l| {
            for (label, 0..) |num, index| {
                if (num != l[index]) continue :outer_loop;
            }
            return true;
        }
        return false;
    }

    pub fn sort(self: *Self) void {
        for (self.collection.items) |*label| {
            std.mem.sort(i32, label, {}, comptime std.sort.asc(i32));
        }
    }

    /// requires label.len = k-1
    ///  items inside return is NOT changing ownership
    pub fn getWhiteCliqueContaining(self: Self, label: []const i32) !std.ArrayList([]const i32) {
        var clique = std.ArrayList([]const i32).init(self.allocator);
        for (self.collection.items) |l| {
            if (isSubsetAssumeSorted(i32, label, l)) {
                try clique.append(l);
            }
        }
        return clique;
    }

    pub fn getWhiteCliquesSorted(self: Self) !std.ArrayList(std.ArrayList([]const i32)) {
        const cliques = try self.getWhiteCliques();
        for (cliques.items) |clique| {
            std.mem.sort([]const i32, clique.items, {}, isLessThanAlphabeticallyFct([]const i32));
        }
        return cliques;
    }

    pub fn getWhiteCliques(self: Self) !std.ArrayList(std.ArrayList([]const i32)) {
        var cliques = std.ArrayList(std.ArrayList([]const i32)).init(self.allocator);
        var labels_done = LabelCollection.init(self.allocator, self.k - 1, self.n);
        defer labels_done.deinit();
        errdefer labels_done.deinit();

        for (self.collection.items) |label| {
            for (0..self.k) |i| {
                var l = try self.allocator.alloc(i32, self.k - 1);
                //var l: [k - 1]i32 = undefined;
                @memcpy(l[0..i], label[0..i]);
                @memcpy(l[i..], label[i + 1 .. self.k]);

                if (try labels_done.containsLabel(l)) continue;
                try labels_done.addLabel(l);
                const white_clique = try self.getWhiteCliqueContaining(l);
                if (white_clique.items.len > 2) {
                    try cliques.append(white_clique);
                } else {
                    white_clique.deinit();
                }
            }
        }
        return cliques;
    }

    // label should be of length k+1
    pub fn getBlackCliqueContainedIn(self: Self, label: []const i32) !std.ArrayList([]const i32) {
        var clique = std.ArrayList([]const i32).init(self.allocator);
        for (self.collection.items) |l| {
            if (isSubsetAssumeSorted(i32, l, label)) {
                try clique.append(l);
            }
        }
        return clique;
    }

    pub fn getBlackCliquesSorted(self: Self) !std.ArrayList(std.ArrayList([]const i32)) {
        const cliques = try self.getBlackCliques();
        for (cliques.items) |clique| {
            std.mem.sort([]const i32, clique.items, {}, isLessThanAlphabeticallyFct([]const i32));
        }
        return cliques;
    }

    // TODO: Rewrite
    pub fn getBlackCliques(self: Self) !std.ArrayList(std.ArrayList([]const i32)) {
        var cliques = std.ArrayList(std.ArrayList([]const i32)).init(self.allocator);
        var labels_done = LabelCollection.init(self.allocator, self.k + 1, self.n);
        defer labels_done.deinit();
        errdefer labels_done.deinit();

        for (self.collection.items) |label| {
            for_i: for (0..self.n) |i| {
                for (label) |label_i| {
                    if (i == label_i) continue :for_i;
                }

                // Copy, add and sort
                var l = try self.allocator.alloc(i32, self.k + 1);
                @memcpy(l[0..self.k], label[0..self.k]);
                l[self.k] = @intCast(i);
                std.mem.sort(i32, l, {}, comptime std.sort.asc(i32));

                //
                if (try labels_done.containsLabel(l)) continue;
                try labels_done.addLabel(l);
                const black_clique = try self.getBlackCliqueContainedIn(l);

                // Ensure non trivial
                if (black_clique.items.len > 2) {
                    try cliques.append(black_clique);
                } else {
                    black_clique.deinit();
                }
            }
        }
        return cliques;
    }

    pub const PostnikovQuiver = struct {
        const PQSelf = @This();
        quiver: Quiver([]const i32, i32),

        pub fn init(allocator: Allocator) PQSelf {
            const quiv = Quiver([]const i32, i32).init(allocator);
            return .{
                .quiver = quiv,
            };
        }
        pub fn deinit(self: *PQSelf) void {
            self.quiver.deinit();
        }
    };

    pub fn getPostnikovQuiver(self: Self) !PostnikovQuiver {
        var p_quiver = PostnikovQuiver.init(self.allocator);

        for (self.collection.items) |label| {
            try p_quiver.quiver.addVertex(label);
        }

        var curr_lab: i32 = 0;
        const white_cliques = try self.getWhiteCliquesSorted();
        for (white_cliques.items) |clique| {
            for (0..clique.items.len) |i| {
                const next_i = if (i >= clique.items.len - 1) 0 else i + 1;
                try p_quiver.quiver.addArrow(clique.items[i], clique.items[next_i], curr_lab);
                curr_lab += 1;
            }
        }

        const black_cliques = try self.getBlackCliquesSorted();
        for (black_cliques.items) |clique| {
            for (0..clique.items.len) |i| {
                const next_i = if (i >= clique.items.len - 1) 0 else i + 1;
                try p_quiver.quiver.addArrow(clique.items[i], clique.items[next_i], curr_lab);
                curr_lab += 1;
            }
        }
        return p_quiver;
    }
};

test "Label collection - isNonCrossing" {
    const allocator = std.testing.allocator;
    {
        var a = LabelCollection(3, 6).init(allocator);
        defer a.deinit();
        try a.addLabel(.{ 3, 5, 8 });
        try a.addLabel(.{ 8, 10, 12 });
        try a.addLabel(.{ 14, 8, 15 });
        try std.testing.expectEqual(a.isNonCrossing(), true);
    }

    {
        var a = LabelCollection(3, 6).init(allocator);
        defer a.deinit();
        try a.addLabel(.{ 3, 5, 8 });
        try a.addLabel(.{ 7, 10, 12 });
        try a.addLabel(.{ 14, 8, 15 });
        try std.testing.expectEqual(a.isNonCrossing(), false);
    }

    {
        var a = LabelCollection(3, 6).init(allocator);
        defer a.deinit();
        try a.addLabel(.{ 3, 5, 8 });
        try a.addLabel(.{ 9, 10, 12 });
        try a.addLabel(.{ 14, 8, 1 });
        try std.testing.expectEqual(a.isNonCrossing(), true);
    }
}

pub fn main() !void {
    //
    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //const allocatorr = gpa.allocator();
    //_ = allocatorr;
    const allocator = getAllocator();
    const input = "3";
    //const stdin = std.io.getStdIn().reader();
    //const stdout = std.io.getStdOut().writer();

    //_ = try stdin.readUntilDelimiter(&input, '\n');

    const integer = try std.fmt.parseInt(usize, input, 10);
    std.debug.print("The user entered number: {d}\n", .{integer});

    var a = LabelCollection.init(allocator, integer, 6);
    defer a.deinit();
    try a.addLabel(&[3]i32{ 1, 25, 22 });
    try a.addLabel(&[3]i32{ 1, 3, 4 });
    try a.addLabel(&[_]i32{ 25, 4, 1 });
    try a.addLabel(&[_]i32{ 22, 4, 1 });
    try a.addLabel(&.{ 3, 5, 1 });
    try a.addLabel(&[_]i32{ 1, 2, 3 });
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
    var p_quiver = try a.getPostnikovQuiver();
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

    try stdout.print("Run `zig build test` to run the tests.\n", .{});
    try bw.flush(); // don't forget to flush!
    try raylibRun(allocator);
}

const rl = @import("raylib");

pub fn raylibRun(allocator: Allocator) !void {
    const screenWidth = 800;
    const screenHeight = 450;

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

        rl.drawRectangle(screenWidth / 2 - 128, screenHeight / 2 - 128, 256, 256, raylib_zig);
        rl.drawRectangle(screenWidth / 2 - 112, screenHeight / 2 - 112, 224, 224, rl.Color.ray_white);
        rl.drawText("raylib-zig", screenWidth / 2 - 96, screenHeight / 2 + 57, 41, raylib_zig);
        //----------------------------------------------------------------------------------
    }
    allocator.destroy(num);
}
