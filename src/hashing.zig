const std = @import("std");

pub fn SliceHashMapContext(T: type) type {
    return struct {
        pub fn hash(_: @This(), el: []const T) u32 {
            var hasher = std.hash.Wyhash.init(0);
            hasher.update(std.mem.asBytes(el[0..]));
            return @truncate(hasher.final());
        }

        pub fn eql(_: @This(), a: []const T, b: []const T, _: usize) bool {
            return std.mem.eql(T, a, b);
        }
    };
}

pub const i32SliceHashContext = SliceHashMapContext(i32);

pub fn SliceHashMap(K: type, V: type) type {
    return std.ArrayHashMap([]const K, V, SliceHashMapContext(K), false);
}
