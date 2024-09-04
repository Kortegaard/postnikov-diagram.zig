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
// NOTE: Potentially breaking if used in a bad way, i.e. not passing in a slice
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
pub const LabelCollection = struct {
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

    const Pos2 = struct {
        x: f32 = 0,
        y: f32 = 0,

        pub fn normSquared(self: Pos2) f32 {
            return self.x * self.x + self.y * self.y;
        }

        pub fn norm(self: Pos2) f32 {
            return std.math.sqrt(self.normSquared());
        }

        pub fn add(self: Pos2, other: Pos2) Pos2 {
            return .{
                .x = self.x + other.x,
                .y = self.y + other.y,
            };
        }

        pub fn subtract(self: Pos2, other: Pos2) Pos2 {
            return .{
                .x = self.x - other.x,
                .y = self.y - other.y,
            };
        }
        pub fn div(self: Pos2, scalar: f32) Pos2 {
            return .{
                .x = self.x / scalar,
                .y = self.y / scalar,
            };
        }

        pub fn mult(self: Pos2, scalar: f32) Pos2 {
            return .{
                .x = self.x * scalar,
                .y = self.y * scalar,
            };
        }

        pub fn normalize(self: Pos2) Pos2 {
            const _norm = self.norm();
            return .{
                .x = self.x / _norm,
                .y = self.y / _norm,
            };
        }

        pub fn normalize_c(self: *Pos2) void {
            const _norm = self.norm();
            self.x = self.x / _norm;
            self.y = self.y / _norm;
        }
    };

    pub const PostnikovQuiverVertexInfo = struct {
        pos: Pos2,
        frozen: bool = false,
    };
    pub const PostnikovQuiver = struct {
        const PQSelf = @This();
        quiver: Quiver([]const i32, i32),
        vertex_info: hashing.SliceHashMap(i32, PostnikovQuiverVertexInfo),
        allocator: Allocator,

        pub fn init(allocator: Allocator) PQSelf {
            const quiv = Quiver([]const i32, i32).init(allocator);
            const vert_info = hashing.SliceHashMap(i32, PostnikovQuiverVertexInfo).init(allocator);
            return .{
                .allocator = allocator,
                .quiver = quiv,
                .vertex_info = vert_info,
            };
        }
        pub fn deinit(self: *PQSelf) void {
            self.quiver.deinit();
            self.vertex_info.deinit();
        }

        fn spring_F0(u: Pos2, v: Pos2, c0: f32) Pos2 {
            const div_factor = v.subtract(u).normSquared() / c0;
            return v.subtract(u).normalize().div(div_factor);
        }

        fn spring_F1(u: Pos2, v: Pos2, c1: f32, l: f32) Pos2 {
            const mul_factor = -c1 * (v.subtract(u).norm() - l);
            return v.subtract(u).normalize().mult(mul_factor);
        }

        fn spring_F(self: *PQSelf, vertex: []const i32, c0: f32, c1: f32, l: f32) Pos2 {
            const info_vert = self.vertex_info.get(vertex) orelse unreachable;
            const pos_vert = info_vert.pos;

            var Force: Pos2 = .{ .x = 0, .y = 0 };

            var vert_it = self.quiver.vertexIterator();
            while (vert_it.next()) |vertex_u| {
                if (std.mem.eql(i32, vertex, vertex_u)) continue;
                const info_vert_u = self.vertex_info.get(vertex_u) orelse unreachable;
                const pos_vert_u = info_vert_u.pos;
                Force = Force.add(spring_F0(pos_vert_u, pos_vert, c0));
            }

            const arrows_out = self.quiver.getArrowsOut(vertex);
            for (arrows_out) |arr| {
                const info_vert_u = self.vertex_info.get(arr.to) orelse unreachable;
                const pos_vert_u = info_vert_u.pos;
                Force = Force.add(spring_F1(pos_vert_u, pos_vert, c1, l));
            }

            const arrows_in = self.quiver.getArrowsIn(vertex);
            for (arrows_in) |arr| {
                const info_vert_u = self.vertex_info.get(arr.from) orelse unreachable;
                const pos_vert_u = info_vert_u.pos;
                Force = Force.add(spring_F1(pos_vert_u, pos_vert, c1, l));
            }
            return Force;
        }

        pub fn apply_spring_step(self: *PQSelf, delta: f32, c0: f32, c1: f32, l: f32) !void {
            _ = .{ self, delta, c0, c1 };
            var map = hashing.SliceHashMap(i32, Pos2).init(self.allocator);
            defer map.deinit();
            var vert_it = self.quiver.vertexIterator();
            while (vert_it.next()) |v| {
                if (self.vertex_info.get(v)) |info| {
                    if (!info.frozen) {
                        try map.put(v, self.spring_F(v, c0, c1, l));
                    }
                }
            }

            vert_it = self.quiver.vertexIterator();
            while (vert_it.next()) |v| {
                if (map.get(v)) |map_val| {
                    if (self.vertex_info.getPtr(v)) |vertex_info| {
                        vertex_info.pos = vertex_info.pos.add(map_val.mult(delta));
                    }
                }
            }
        }
    };

    pub const PostnikovQuiverParams = struct {
        center_x: f32 = 200,
        center_y: f32 = 200,
        radius: f32 = 70,
    };

    //function F0(u::Vector{Float64}, v::Vector{Float64}, c0::Float64)
    //    return (normalize(v-u)/(norm(v - u)^2/c0))
    //end
    //
    //function F0(u::Vector{Float64}, v::Vector{Float64})
    //    return F0(u,v,1);
    //end
    //
    //function F1(u::Vector{Float64}, v::Vector{Float64}, c1::Float64)
    //    #natural length
    //    l = 0.001
    //    return normalize(v-u)*(-c1 * (norm(v-u)-l))
    //end
    //
    //function F1(u::Vector{Float64}, v::Vector{Float64})
    //    return F1(u,v,1);
    //end
    //
    //function F(q::Quiver, v::Vertex, c0::Float64, c1::Float64)
    //    Force = [0.0,0.0]
    //
    //    for u in vertices(q)
    //        if u == v
    //            continue
    //        end
    //        Force = Force + F0(u.data["position"], v.data["position"], c0)
    //    end
    //    for arr in v.termination_arrows
    //        Force = Force + F1(arr.start.data["position"], v.data["position"], c1)
    //    end
    //    for arr in v.start_arrows
    //        Force = Force + F1(arr.termination.data["position"], v.data["position"], c1)
    //    end
    //    return Force
    //end
    //
    //function F(q::Quiver, v::Vertex)
    //    return F(q,v,1,1);
    //end

    // function spring_step(q::Quiver,delta::Float64, c0::Float64 ,c1::Float64)
    //     c = Dict{Vertex, Vector{Float64}}()
    //     for v in vertices(q)
    //         if !get(v.data, "springFrozen", false)
    //             c[v] = F(q, v, c0, c1)
    //         end
    //     end
    //     for v in vertices(q)
    //         if haskey(c, v)
    //             v.data["position"] = v.data["position"] + delta * c[v];
    //         end
    //     end
    // end

    pub fn getPostnikovQuiver(self: Self, conf: PostnikovQuiverParams) !PostnikovQuiver {
        var prng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        const rand = prng.random();

        var p_quiver = PostnikovQuiver.init(self.allocator);
        for (self.collection.items) |label| {
            try p_quiver.quiver.addVertex(label);
            const x = rand.float(f32) * conf.radius * std.math.cos(rand.float(f32) * (2 * std.math.pi)) + conf.center_x;
            const y = rand.float(f32) * conf.radius * std.math.sin(rand.float(f32) * (2 * std.math.pi)) + conf.center_y;
            try p_quiver.vertex_info.put(label, .{ .pos = .{ .x = x, .y = y } });
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

        var lab = try self.allocator.alloc(i32, self.k);
        for (0..self.n) |i| {
            for (0..self.k) |j| {
                lab[j] = @intCast(@mod(i + j, self.n));
                if (lab[j] == 0) lab[j] = @intCast(self.n);
            }
            std.mem.sort(i32, lab, {}, comptime std.sort.asc(i32));
            std.debug.print("out here {any}\n", .{lab});

            if (p_quiver.vertex_info.getPtr(lab)) |info| {
                std.debug.print("in here {any}\n", .{lab});
                const x = conf.radius * std.math.cos(@as(f32, @floatFromInt(i)) * (2 * std.math.pi) / @as(f32, @floatFromInt(self.n))) + conf.center_x;
                const y = conf.radius * std.math.sin(@as(f32, @floatFromInt(i)) * (2 * std.math.pi) / @as(f32, @floatFromInt(self.n))) + conf.center_y;
                info.pos = .{ .x = x, .y = y };
                info.frozen = true;
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

const r = @import("./raylibFct.zig");
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

    //try a.addLabel(&[3]i32{ 1, 25, 22 });
    //try a.addLabel(&[3]i32{ 1, 3, 4 });
    //try a.addLabel(&[_]i32{ 25, 4, 1 });
    //try a.addLabel(&[_]i32{ 22, 4, 1 });
    //try a.addLabel(&.{ 3, 5, 1 });
    //try a.addLabel(&[_]i32{ 1, 2, 3 });
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
    var p_quiver = try a.getPostnikovQuiver(.{ .center_x = 200, .center_y = 200, .radius = 190 });
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

    try r.raylibShowPostnikovQuiver(allocator, &p_quiver);
}
