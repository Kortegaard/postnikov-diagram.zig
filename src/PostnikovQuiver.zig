const std = @import("std");
const Quiver = @import("vendor/graph.zig/src/DirectedGraph.zig").Quiver;
const Pos2 = @import("helpers.zig").Pos2;
const Allocator = std.mem.Allocator;
const hashing = @import("hashing.zig");
const LabelCollection = @import("LabelCollection.zig");

pub const PostnikovQuiver = struct {

    pub const PostnikovPlabicGraph = struct {
        plabicGraph: Quiver([]const i32, i32),
    };

    pub const PostnikovQuiverVertexInfo = struct {
        pos: Pos2,
        frozen: bool = false,
    };

    pub const PostnikovQuiverParams = struct {
        center_x: f32 = 200,
        center_y: f32 = 200,
        radius: f32 = 70,
    };

    const Self = @This();
    
    allocator: Allocator,
    quiver: Quiver([]const i32, i32),
    vertex_info: hashing.SliceHashMap(i32, PostnikovQuiverVertexInfo),
    //labelCollection: ?LabelCollection = null,
    conf: PostnikovQuiverParams = .{},

    pub fn init(allocator: Allocator) Self {
        const quiv = Quiver([]const i32, i32).init(allocator);
        const vert_info = hashing.SliceHashMap(i32, PostnikovQuiverVertexInfo).init(allocator);
        return .{
            .allocator = allocator,
            .quiver = quiv,
            .vertex_info = vert_info,
        };
    }

    pub fn initFromLabelCollection(allocator: Allocator, label_collection: LabelCollection, conf: PostnikovQuiverParams) !Self {
        var prng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        const rand = prng.random();

        var p_quiver = PostnikovQuiver.init(allocator);
        //p_quiver.labelCollection = label_collection;
        p_quiver.conf = conf;

        for (label_collection.collection.items) |label| {
            try p_quiver.quiver.addVertex(label);
            const x = rand.float(f32) * conf.radius * std.math.cos(rand.float(f32) * (2 * std.math.pi)) + conf.center_x;
            const y = rand.float(f32) * conf.radius * std.math.sin(rand.float(f32) * (2 * std.math.pi)) + conf.center_y;
            try p_quiver.vertex_info.put(label, .{ .pos = .{ .x = x, .y = y } });
        }

        var curr_lab: i32 = 0;
        const white_cliques = try label_collection.getWhiteCliquesSorted();
        for (white_cliques.items) |clique| {
            for (0..clique.items.len) |i| {
                const next_i = if (i >= clique.items.len - 1) 0 else i + 1;
                try p_quiver.quiver.addArrow(clique.items[i], clique.items[next_i], curr_lab);
                curr_lab += 1;
            }
        }

        const black_cliques = try label_collection.getBlackCliquesSorted();
        for (black_cliques.items) |clique| {
            for (0..clique.items.len) |i| {
                const next_i = if (i >= clique.items.len - 1) 0 else i + 1;
                try p_quiver.quiver.addArrow(clique.items[i], clique.items[next_i], curr_lab);
                curr_lab += 1;
            }
        }

        var lab = try label_collection.allocator.alloc(i32, label_collection.k);
        for (0..label_collection.n) |i| {
            for (0..label_collection.k) |j| {
                lab[j] = @intCast(@mod(i + j, label_collection.n));
                if (lab[j] == 0) lab[j] = @intCast(label_collection.n);
            }
            std.mem.sort(i32, lab, {}, comptime std.sort.asc(i32));

            if (p_quiver.vertex_info.getPtr(lab)) |info| {
                const x = conf.radius * std.math.cos(@as(f32, @floatFromInt(i)) * (2 * std.math.pi) / @as(f32, @floatFromInt(label_collection.n))) + conf.center_x;
                const y = conf.radius * std.math.sin(@as(f32, @floatFromInt(i)) * (2 * std.math.pi) / @as(f32, @floatFromInt(label_collection.n))) + conf.center_y;
                info.pos = .{ .x = x, .y = y };
                info.frozen = true;
            }
        }
        return p_quiver;
    }

    pub fn deinit(self: *Self) void {
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

    fn spring_F(self: *Self, vertex: []const i32, c0: f32, c1: f32, l: f32) Pos2 {
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

    pub fn apply_spring_step(self: *Self, delta: f32, c0: f32, c1: f32, l: f32) !f32 {
        _ = .{ self, delta, c0, c1 };
        var map = hashing.SliceHashMap(i32, Pos2).init(self.allocator);
        defer map.deinit();
        var total: f32 = 0;
        var num: usize = 0;
        var vert_it = self.quiver.vertexIterator();
        while (vert_it.next()) |v| {
            if (self.vertex_info.get(v)) |info| {
                if (!info.frozen) {
                    const sp_f = self.spring_F(v, c0, c1, l);
                    try map.put(v, sp_f);
                    num += 1;
                    total += sp_f.norm();
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
        return total / @as(f32, @floatFromInt(num));
    }
};
