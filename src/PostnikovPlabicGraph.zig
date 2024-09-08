const std = @import("std");
const Quiver = @import("vendor/graph.zig/src/DirectedGraph.zig").Quiver;
const Pos2 = @import("helpers.zig").Pos2;
const Spline2 = @import("helpers.zig").Spline2;
const Allocator = std.mem.Allocator;
const hashing = @import("hashing.zig");
const LabelCollection = @import("LabelCollection.zig");
const LabelFct = @import("LabelFunctions.zig");
const PostnikovQuiver = @import("PostnikovQuiver.zig").PostnikovQuiver;

const Helpers = @import("vendor/graph.zig/src/helpers.zig");

pub const PostnikovPlabicGraph = struct {
    pub const PostnikovPlabicGraphVertexInfo = struct {
        pos: Pos2,
        color: enum { edge, black, white },
        clique: std.ArrayList([]const i32),
    };

    pub const PostnikovPlabicGraphParams = struct {
        center_x: f32 = 200,
        center_y: f32 = 200,
        radius: f32 = 70,
    };

    const Self = @This();

    allocator: Allocator,
    quiver: Quiver([]const u8, i32),
    vertex_info: hashing.SliceHashMap(u8, PostnikovPlabicGraphVertexInfo),
    labelCollection: ?LabelCollection = null,

    pub fn init(allocator: Allocator) Self {
        const quiv = Quiver([]const u8, i32).init(allocator);
        const vert_info = hashing.SliceHashMap(u8, PostnikovPlabicGraphVertexInfo).init(allocator);
        return .{
            .allocator = allocator,
            .quiver = quiv,
            .vertex_info = vert_info,
        };
    }
    pub fn deinit(self: *Self) void {
        for (self.vertex_info.keys()) |key| {
            self.allocator.free(key);
        }
        self.vertex_info.deinit();
        self.quiver.deinit();
    }

    pub fn initFromLabelCollection(allocator: Allocator, label_collection: LabelCollection, conf: PostnikovPlabicGraphParams) !Self {
        var prng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        const rand = prng.random();
        _ = .{ rand, conf };

        var p_quiver = Self.init(allocator);
        p_quiver.labelCollection = label_collection;

        const white_cliques: std.ArrayList(std.ArrayList([]const i32)) = try label_collection.getWhiteCliquesSorted();
        const black_cliques: std.ArrayList(std.ArrayList([]const i32)) = try label_collection.getBlackCliquesSorted();
        for (white_cliques.items, 0..) |clique, i| {
            const name: []const u8 = try std.fmt.allocPrint(allocator, "w{d}", .{i});
            try p_quiver.quiver.addVertex(name);
            try p_quiver.vertex_info.put(name, .{
                .pos = .{ .x = 0, .y = 0 },
                .color = .white,
                .clique = clique,
            });
        }
        for (black_cliques.items, 0..) |clique, i| {
            const name: []const u8 = try std.fmt.allocPrint(allocator, "b{d}", .{i});
            try p_quiver.quiver.addVertex(name);
            try p_quiver.vertex_info.put(name, .{
                .pos = .{ .x = 0, .y = 0 },
                .color = .black,
                .clique = clique,
            });
        }

        var arr_num: i32 = 0;
        var vert_it1 = p_quiver.quiver.vertexIterator();
        while (vert_it1.next()) |v1| {
            var vert_it2 = p_quiver.quiver.vertexIterator();
            while (vert_it2.next()) |v2| {
                if (std.mem.eql(u8, v1, v2)) continue;
                const info1 = p_quiver.vertex_info.get(v1) orelse unreachable;
                const c1 = info1.clique;
                const info2 = p_quiver.vertex_info.get(v2) orelse unreachable;
                const c2 = info2.clique;
                if (LabelFct.boundaryIntersectionSize([]const i32, c1.items, c2.items) > 0) {
                    try p_quiver.quiver.addArrow(v1, v2, arr_num);
                    arr_num += 1;
                }
            }
        }

        for (0..label_collection.n) |i| {
            const name: []const u8 = try std.fmt.allocPrint(allocator, "{d}", .{i});
            try p_quiver.quiver.addVertex(name);
            var m_clique = std.ArrayList([]const i32).init(allocator);
            try m_clique.append(try label_collection.getProjectivePtrStartingAt(@as(i32, @intCast(i)) + 2) orelse continue);
            try m_clique.append(try label_collection.getProjectivePtrStartingAt(@as(i32, @intCast(i)) + 1) orelse continue);
            std.mem.sort([]const i32, m_clique.items, {}, LabelFct.isLessThanAlphabeticallyFct([]const i32));
            try p_quiver.vertex_info.put(name, .{
                .pos = .{ .x = 0, .y = 0 },
                .color = .edge,
                .clique = m_clique,
            });
        }

        var vert_num: usize = 0;
        var projs = try label_collection.getProjectiveLabels();
        defer projs.deinit();
        var proj_bound_iterator = LabelFct.boundaryOfSliceIterator([]const i32).init(projs.items);
        while (proj_bound_iterator.next()) |bound| {
            std.mem.sort([]const i32, @constCast(&bound), {}, LabelFct.isLessThanAlphabeticallyFct([]const i32));
            var plabic_vert_it = p_quiver.quiver.vertexIterator();
            while (plabic_vert_it.next()) |v| {
                const v_info = p_quiver.vertex_info.get(v) orelse continue;
                if (v_info.clique.items.len > 2 and LabelFct.isSubsetAssumeSorted([]const i32, &bound, v_info.clique.items)) {
                    const name: []const u8 = try std.fmt.allocPrint(allocator, "{d}", .{vert_num});

                    defer allocator.free(name);
                    try p_quiver.quiver.addArrow(name, v, arr_num);
                    vert_num += 1;
                    arr_num += 1;
                }
            }
        }

        return p_quiver;
    }

    pub fn setLocationBasedOnPostnikovQuiver(self: *Self, postnikov_quiver: PostnikovQuiver) void {
        var vert_it = self.quiver.vertexIterator();
        while (vert_it.next()) |v| {
            var vert_info = self.vertex_info.getPtr(v) orelse continue;

            var num: f32 = 0;
            var pos = Pos2{ .x = 0, .y = 0 };
            for (vert_info.clique.items) |label| {
                const q_info = postnikov_quiver.vertex_info.get(label) orelse continue;
                pos = pos.add(q_info.pos);
                num += 1;
            }
            if (num > 0) {
                pos = pos.div(num);
                vert_info.pos = pos;
            }
            if (num == 2) {
                vert_info.pos = pos.projectToCircleBoundary(.{ .x = postnikov_quiver.conf.center_x, .y = postnikov_quiver.conf.center_y }, postnikov_quiver.conf.radius);
            }
        }
    }

    pub fn getPostnikovDiagramSplines(self: *Self, postnikov_quiver: PostnikovQuiver) !std.ArrayList(Spline2) {
        var vert_it = self.quiver.vertexIterator();
        var splines = std.ArrayList(Spline2).init(self.allocator);
        while (vert_it.next()) |v| {
            var spline = Spline2.init(self.allocator);
            // Starting the spline with the boundary point plus the unique other clique attached to it.
            const v_info = self.vertex_info.get(v) orelse continue;
            if (v_info.color != .edge) continue;
            const arr_out = self.quiver.getArrowsOut(v);
            if (arr_out.len != 1) @panic("Should not be possible to land here");
            var curr_vertex: []const u8 = arr_out[0].to;
            const v2_info = self.vertex_info.get(curr_vertex) orelse continue;
            var curr_info: PostnikovPlabicGraphVertexInfo = v2_info;

            var prev_vertex: []const u8 = v;
            var prev_info: PostnikovPlabicGraphVertexInfo = v_info;
            // Adding two due to the interpolation algorithm for later TODO: Remove the need for this
            try spline.appendPos(prev_info.pos);
            try spline.appendPos(prev_info.pos);

            while (true) {
                // Adding a new point to splice, in the middle of the postnikov quiver arrow the cliques intersect.
                const intersection_of_cliques = try LabelFct.intersection(self.allocator, []const i32, curr_info.clique.items, prev_info.clique.items);

                // FIX: we need to deinit this, however, that creates problems later.
                // Are they deallocated anywhere?
                //defer intersection_of_cliques.deinit();

                if (intersection_of_cliques.items.len < 2) continue;
                const info1 = postnikov_quiver.vertex_info.get(intersection_of_cliques.items[0]) orelse continue;
                const info2 = postnikov_quiver.vertex_info.get(intersection_of_cliques.items[1]) orelse continue;
                if (prev_info.clique.items.len > 2 and curr_info.clique.items.len > 2) {
                    try spline.appendPos(info1.pos.add(info2.pos).div(2));
                }
                if (curr_info.color == .edge) {
                    try spline.appendPos(curr_info.pos);
                    try spline.appendPos(curr_info.pos);
                    break;
                }

                // Setup for finding next clique
                var smallest_angle: f32 = 2 * std.math.pi;
                var smallest_angle_vertex: []const u8 = undefined;
                var smallest_angle_info: PostnikovPlabicGraphVertexInfo = undefined;
                var largest_angle: f32 = -2 * std.math.pi;
                var largest_angle_vertex: []const u8 = undefined;
                var largest_angle_info: PostnikovPlabicGraphVertexInfo = undefined;

                // TODO: Can be cleaned up by adding a adjecentVertexIterator to the graph
                //
                // Finding the neighbour clique with with smallest and largest angle w.r.t. previous clique
                const arr_ir1 = self.quiver.getArrowsOut(curr_vertex);
                for (arr_ir1) |arr| {
                    if (std.mem.eql(u8, prev_vertex, arr.to)) continue;
                    const to_info = self.vertex_info.get(arr.to) orelse continue;
                    var angle = prev_info.pos.angle(curr_info.pos, to_info.pos);
                    if (angle < 0) angle += 2 * std.math.pi;
                    if (angle < smallest_angle) {
                        smallest_angle = angle;
                        smallest_angle_vertex = arr.to;
                        smallest_angle_info = to_info;
                    }
                    if (angle > largest_angle) {
                        largest_angle = angle;
                        largest_angle_vertex = arr.to;
                        largest_angle_info = to_info;
                    }
                }
                //
                const arr_ir2 = self.quiver.getArrowsIn(curr_vertex);
                for (arr_ir2) |arr| {
                    if (std.mem.eql(u8, prev_vertex, arr.from)) continue;
                    const to_info = self.vertex_info.get(arr.from) orelse continue;
                    var angle = prev_info.pos.angle(curr_info.pos, to_info.pos);
                    if (angle < 0) angle += 2 * std.math.pi;
                    if (angle < smallest_angle) {
                        smallest_angle = angle;
                        smallest_angle_vertex = arr.from;
                        smallest_angle_info = to_info;
                    }
                    if (angle > largest_angle) {
                        largest_angle = angle;
                        largest_angle_vertex = arr.from;
                        largest_angle_info = to_info;
                    }
                }

                // Updating the step
                prev_vertex = curr_vertex;
                prev_info = curr_info;
                if (curr_info.color == .white) {
                    curr_vertex = smallest_angle_vertex;
                    curr_info = smallest_angle_info;
                } else if (curr_info.color == .black) {
                    curr_vertex = largest_angle_vertex;
                    curr_info = largest_angle_info;
                }
            }
            try splines.append(spline);
        }
        return splines;
    }
};
