const std = @import("std");

pub const Pos2 = struct {
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
