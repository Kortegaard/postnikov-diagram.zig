const std = @import("std");
const Allocator = std.mem.Allocator;
const LabelFct = @import("LabelFunctions.zig");

const LabelCollectionError = error{
    SliceNotFound,
    CannotMutate,
};

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

pub fn initWithDefaultSeed(allocator: Allocator, k: usize, n: usize) !Self {
    var lc = Self.init(allocator, k, n);

    var label = try allocator.alloc(i32, k);
    defer allocator.free(label);
    for (1..n + 1 - k + 1) |m| {
        for (0..k + 1) |l| {
            var ind: usize = 0;
            for (1..l + 1) |v| {
                label[ind] = @intCast(v);
                ind += 1;
            }
            for (l + m..k + m) |v| {
                label[ind] = @intCast(v);
                ind += 1;
            }
            // TODO: get rid of this check by eliminating overlapping labels above
            if (!try lc.containsLabel(label)) {
                try lc.addLabel(label);
            }
        }
    }

    //for (1..n + 1) |i| {
    //    for (0..k) |j| {
    //        label[j] = @intCast(@mod(i + j, n));
    //        if (label[j] == 0) {
    //            label[j] = @intCast(n);
    //        }
    //    }
    //    try lc.addLabel(label);
    //}
    return lc;
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

pub fn mutateInLabel(self: *Self, label: []const i32) ![]i32 {
    const label_slice = try self.getLabelSlice(label) orelse return LabelCollectionError.SliceNotFound;

    var bcs = try self.getBlackCliquesSorted();
    var wcs = try self.getWhiteCliquesSorted();
    defer {
        for (bcs.items) |i| {
            i.deinit();
        }
        bcs.deinit();
    }
    defer {
        for (wcs.items) |i| {
            i.deinit();
        }
        wcs.deinit();
    }

    // remove cliques not containing label
    var i = wcs.items.len - 1; // TODO : problem is length is 0
    while (i > 0) {
        i -= 1;
        std.debug.print("{d}\n", .{i});
        if (!LabelFct.inSlice([]const i32, wcs.items[i].items, label)) {
            wcs.items[i].deinit();
            _ = wcs.swapRemove(i);
        }
    }

    i = bcs.items.len - 1; // TODO : problem is length is 0
    while (i > 0) {
        i -= 1;
        if (!LabelFct.inSlice([]const i32, bcs.items[i].items, label)) {
            bcs.items[i].deinit();
            _ = bcs.swapRemove(i);
        }
    }
    const it = LabelFct.boundaryOfSliceIterator([]const i32);

    var adj_labels = std.ArrayList([]const i32).init(self.allocator);
    defer adj_labels.deinit();

    for (bcs.items) |bc| {
        var bit = it.init(bc.items);
        while (bit.next()) |bound| {
            if (LabelFct.isEqual([]const i32, label, bound[0])) {
                try adj_labels.append(bound[1]);
            }
            if (LabelFct.isEqual([]const i32, label, bound[1])) {
                try adj_labels.append(bound[0]);
            }
        }
    }
    if (adj_labels.items.len != 4) return label_slice; //return eroro TODO:

    var new: [2]i32 = [_]i32{ -1, -1 };

    for (adj_labels.items) |adj_lab| {
        for (adj_lab) |num| {
            if (!LabelFct.inSlice(i32, label, num)) {
                var ind: usize = 0;
                if (new[0] != -1) {
                    ind = 1;
                }
                new[ind] = num;
            }
        }
    }
    std.debug.assert(new[1] != -1);

    //const label_slice = try self.getLabelSlice(label) orelse return LabelCollectionError.SliceNotFound;
    var m: usize = 0;
    out: for (label_slice, 0..) |num, k| {
        for (adj_labels.items) |adj_lab| {
            if (!LabelFct.inSlice(i32, adj_lab, num)) {
                std.debug.assert(m <= 1);
                label_slice[k] = new[m];
                m += 1;
                continue :out;
            }
        }
    }

    return label_slice;
}
pub fn mutateInLabel2(self: *Self, label: []const i32) ![]i32 {
    std.debug.print("1\n", .{});
    var label_slice = try self.getLabelSlice(label) orelse return LabelCollectionError.SliceNotFound;
    std.debug.print("2\n", .{});

    var _union = std.ArrayList(i32).init(self.allocator);
    defer _union.deinit();
    var intersection = std.ArrayList(i32).init(self.allocator);
    defer intersection.deinit();

    var count: usize = 0;

    std.debug.print("3\n", .{});
    for (self.collection.items) |lab| {
        if (LabelFct.intersectionSize(i32, lab, label) == self.k - 1) {
            std.debug.print("item {any}\n", .{lab});
            count += 1;
            for (lab) |n| {
                if (!LabelFct.inSlice(i32, _union.items, n)) try _union.append(n);
                const inlen = intersection.items.len;
                for (0..inlen) |i| {
                    if (intersection.items[inlen - 1 - i] == n) {
                        _ = intersection.orderedRemove(inlen - 1 - i);
                    }
                }
            }
        }
    }
    std.debug.print("count {d}\n", .{count});
    //if (count != 4) {
    //    return LabelCollectionError.CannotMutate;
    //}
    std.debug.print("5\n", .{});
    // calculate union\label, putting result in union
    const unlen = _union.items.len;
    for (0..unlen) |i| {
        if (LabelFct.inSlice(i32, label, _union.items[unlen - 1 - i])) {
            _ = _union.orderedRemove(unlen - 1 - i);
        }
    }

    std.debug.print("6\n", .{});
    for (intersection.items) |v| {
        try _union.append(v);
    }
    // Now union is the new label

    std.mem.copyForwards(i32, label_slice, _union.items);
    std.mem.sort(i32, label_slice[0..self.k], {}, comptime std.sort.asc(i32));

    return label_slice;
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
        LabelFct.rotateSet_c(self.n, rotation_amount, set);
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
            if (!LabelFct.isNonCrossing(self.collection.items[i], self.collection.items[j])) {
                std.debug.print("{any}  {any},\n", .{ self.collection.items[i], self.collection.items[j] });
                return false;
            }
        }
    }
    return true;
}

pub fn getProjectivePtrStartingAt(self: Self, point: i32) !?[]const i32 {
    const tmp = try self.allocator.alloc(i32, self.k);
    defer self.allocator.free(tmp);
    for (0..self.k) |i| {
        const curr_point = LabelFct.modPlusOne(point + @as(i32, @intCast(i)), @intCast(self.n));
        tmp[i] = @as(i32, @intCast(curr_point));
    }
    std.mem.sort(i32, tmp[0..self.k], {}, comptime std.sort.asc(i32));
    for (self.collection.items) |el| {
        if (std.mem.eql(i32, tmp[0..], el)) {
            return el;
        }
    }
    return null;
}

// TODO: Test
pub fn isMaximalNonCrossing(self: Self) bool {
    return self.collection.items.len == self.k * (self.n - self.k) + 1 and self.isNonCrossing();
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

pub fn getLabelSliceSorted(self: Self, label: []const i32) ?[]i32 {
    // Creating a sorted version of label

    outer_loop: for (self.collection.items) |l| {
        for (label, 0..) |num, index| {
            if (num != l[index]) continue :outer_loop;
        }
        return l;
    }
    return null;
}

pub fn getLabelSlice(self: Self, label: []const i32) !?[]i32 {
    if (label.len != self.k) return null;

    var label_copy = try self.allocator.alloc(i32, self.k);
    defer self.allocator.free(label_copy);
    @memcpy(label_copy[0..self.k], label[0..self.k]);
    std.mem.sort(i32, label_copy[0..self.k], {}, comptime std.sort.asc(i32));

    return self.getLabelSliceSorted(label_copy);
}

pub fn sort(self: *Self) void {
    for (self.collection.items) |*label| {
        std.mem.sort(i32, label, {}, comptime std.sort.asc(i32));
    }
}

pub fn getProjectiveLabels(self: Self) !std.ArrayList([]const i32) {
    var list = std.ArrayList([]const i32).init(self.allocator);
    for (self.collection.items) |label| {
        if (LabelFct.isProjectiveAssumeSorted(label, self.n))
            try list.append(label);
    }

    std.mem.sort([]const i32, list.items, {}, LabelFct.ProjectiveCyclicLessThanStartingAt1);
    return list;
}

/// requires label.len = k-1
///  items inside return is NOT changing ownership
pub fn getWhiteCliqueContaining(self: Self, label: []const i32) !std.ArrayList([]const i32) {
    var clique = std.ArrayList([]const i32).init(self.allocator);
    for (self.collection.items) |l| {
        if (LabelFct.isSubsetAssumeSorted(i32, label, l)) {
            try clique.append(l);
        }
    }
    return clique;
}

pub fn getWhiteCliquesSorted(self: Self) !std.ArrayList(std.ArrayList([]const i32)) {
    const cliques = try self.getWhiteCliques();
    for (cliques.items) |clique| {
        std.mem.sort([]const i32, clique.items, {}, LabelFct.isLessThanAlphabeticallyFct([]const i32));
    }
    return cliques;
}

pub fn getWhiteCliques(self: Self) !std.ArrayList(std.ArrayList([]const i32)) {
    var cliques = std.ArrayList(std.ArrayList([]const i32)).init(self.allocator);
    var labels_done = Self.init(self.allocator, self.k - 1, self.n);
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
        if (LabelFct.isSubsetAssumeSorted(i32, l, label)) {
            try clique.append(l);
        }
    }
    return clique;
}

pub fn getBlackCliquesSorted(self: Self) !std.ArrayList(std.ArrayList([]const i32)) {
    const cliques = try self.getBlackCliques();
    for (cliques.items) |clique| {
        std.mem.sort([]const i32, clique.items, {}, LabelFct.isLessThanAlphabeticallyFct([]const i32));
    }
    return cliques;
}

// TODO: Rewrite
pub fn getBlackCliques(self: Self) !std.ArrayList(std.ArrayList([]const i32)) {
    var cliques = std.ArrayList(std.ArrayList([]const i32)).init(self.allocator);
    var labels_done = Self.init(self.allocator, self.k + 1, self.n);
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

test "Label collection - isNonCrossing" {
    const allocator = std.testing.allocator;
    {
        var a = Self(3, 6).init(allocator);
        defer a.deinit();
        try a.addLabel(.{ 3, 5, 8 });
        try a.addLabel(.{ 8, 10, 12 });
        try a.addLabel(.{ 14, 8, 15 });
        try std.testing.expectEqual(a.isNonCrossing(), true);
    }

    {
        var a = Self(3, 6).init(allocator);
        defer a.deinit();
        try a.addLabel(.{ 3, 5, 8 });
        try a.addLabel(.{ 7, 10, 12 });
        try a.addLabel(.{ 14, 8, 15 });
        try std.testing.expectEqual(a.isNonCrossing(), false);
    }

    {
        var a = Self(3, 6).init(allocator);
        defer a.deinit();
        try a.addLabel(.{ 3, 5, 8 });
        try a.addLabel(.{ 9, 10, 12 });
        try a.addLabel(.{ 14, 8, 1 });
        try std.testing.expectEqual(a.isNonCrossing(), true);
    }
}
