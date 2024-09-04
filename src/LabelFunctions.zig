const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const hashing = @import("hashing.zig");
const Quiver = @import("vendor/graph.zig/src/DirectedGraph.zig").Quiver;
const Pos2 = @import("helpers.zig").Pos2;
const PostnikovQuiver = @import("PostnikovData.zig").PostnikovQuiver;

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
