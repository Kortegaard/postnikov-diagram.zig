const std = @import("std");
const rl = @import("raylib");

pub const Pos2 = struct {
    x: f32 = 0,
    y: f32 = 0,

    pub fn normSquared(self: Pos2) f32 {
        return self.x * self.x + self.y * self.y;
    }

    pub fn norm(self: Pos2) f32 {
        return std.math.sqrt(self.normSquared());
    }
    pub fn eql(self: Pos2, other: Pos2) bool {
        return self.x == other.x and self.y == other.y;
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

    pub fn projectToCircleBoundary(self: Pos2, center: Pos2, radius: f32) Pos2 {
        if (self.eql(center)) return self.add(.{ .x = radius, .y = 0 });
        const moved_point = self.subtract(center);
        return moved_point.mult(radius).div(moved_point.norm()).add(center);
    }

    pub fn angleAroundOrigin(self: Pos2) f32 {
        if (self.x == 0 and self.y == 0) return 0;
        if (self.y == 0 and self.x <= 0) return std.math.pi;
        if (self.y == 0 and self.x >= 0) return 0;
        if (self.x == 0 and self.y >= 0) return std.math.pi / 2.0;
        if (self.x == 0 and self.y <= 0) return 3.0 * std.math.pi / 2.0;

        const arctan = std.math.atan(@abs(self.y) / @abs(self.x));
        if (self.y >= 0 and self.x >= 0) return arctan;
        if (self.y <= 0 and self.x >= 0) return 2 * std.math.pi - arctan;
        if (self.y >= 0 and self.x <= 0) return std.math.pi - arctan;
        if (self.y <= 0 and self.x <= 0) return std.math.pi + arctan;

        unreachable;
    }

    pub fn angle(self: Pos2, a: Pos2, b: Pos2) f32 {
        const a1 = self.subtract(a).angleAroundOrigin();
        const a2 = b.subtract(a).angleAroundOrigin();
        return a2 - a1;
    }

    pub fn toVector(self: Pos2) rl.Vector2 {
        return rl.Vector2{ .x = self.x, .y = self.y };
    }
};

pub const Spline2 = struct {
    const Self = @This();

    points: std.ArrayList(rl.Vector2),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .points = std.ArrayList(rl.Vector2).init(allocator),
        };
    }

    pub fn appendPos(self: *Self, pos: Pos2) !void {
        try self.points.append(pos.toVector());
    }

    pub fn deinit(self: *Self) void {
        self.points.deinit();
    }
};
