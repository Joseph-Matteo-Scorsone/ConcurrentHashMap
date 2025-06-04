const std = @import("std");
const ConcurrentHashMap = @import("concurrent_HashMap").ConcurrentHashMap;
const testing = std.testing;

test "basic put and get functionality" {
    const gpa = testing.allocator;
    var map = try ConcurrentHashMap(u64, u64, std.hash_map.AutoContext(u64)).init(gpa, 16, .{});
    defer map.deinit();

    try map.put(1, 100);
    try map.put(2, 200);

    try testing.expectEqual(100, map.get(1).?);
    try testing.expectEqual(200, map.get(2).?);
    try testing.expectEqual(null, map.get(3));
}

test "put overwrite existing key" {
    const gpa = testing.allocator;
    var map = try ConcurrentHashMap(u64, u64, std.hash_map.AutoContext(u64)).init(gpa, 16, .{});
    defer map.deinit();

    try map.put(1, 100);
    try testing.expectEqual(100, map.get(1).?);

    try map.put(1, 200); // Overwrite
    try testing.expectEqual(200, map.get(1).?);
    try testing.expectEqual(1, map.count.load(.seq_cst)); // Count should not increase
}

test "remove functionality" {
    const gpa = testing.allocator;
    var map = try ConcurrentHashMap(u64, u64, std.hash_map.AutoContext(u64)).init(gpa, 16, .{});
    defer map.deinit();

    try map.put(1, 100);
    try map.put(2, 200);

    try testing.expect(map.remove(1));
    try testing.expectEqual(null, map.get(1));
    try testing.expectEqual(200, map.get(2).?);
    try testing.expectEqual(1, map.count.load(.seq_cst));

    try testing.expect(!map.remove(3)); // Non-existent key
    try testing.expectEqual(1, map.count.load(.seq_cst));
}

test "resize on high load factor" {
    const gpa = testing.allocator;
    var map = try ConcurrentHashMap(u64, u64, std.hash_map.AutoContext(u64)).init(gpa, 4, .{}); // Small size to trigger resize early
    defer map.deinit();

    // Insert enough to exceed load factor of 0.75 (4 * 0.75 = 3 entries)
    try map.put(1, 100);
    try map.put(2, 200);
    try map.put(3, 300);
    try map.put(4, 400); // Should trigger resize

    try testing.expect(@as(i32, @intCast(map.size.load(.seq_cst))) > 4); // Verify resize occurred

    try testing.expectEqual(100, map.get(1).?);
    try testing.expectEqual(200, map.get(2).?);
    try testing.expectEqual(300, map.get(3).?);
    try testing.expectEqual(400, map.get(4).?);
    try testing.expectEqual(4, map.count.load(.seq_cst));
}

test "many insertions and retrievals" {
    const gpa = testing.allocator;
    var map = try ConcurrentHashMap(u64, u64, std.hash_map.AutoContext(u64)).init(gpa, 16, .{});
    defer map.deinit();

    const count = 1000;
    for (0..count) |i| {
        try map.put(@intCast(i), i * 100);
    }

    for (0..count) |i| {
        try testing.expectEqual(@as(u64, i * 100), map.get(@intCast(i)).?);
    }

    try testing.expectEqual(count, map.count.load(.seq_cst));
}

test "memory management" {
    const gpa = testing.allocator;
    var map = try ConcurrentHashMap(u64, u64, std.hash_map.AutoContext(u64)).init(gpa, 16, .{});
    defer map.deinit();

    // Repeated put and remove to check for memory leaks
    for (0..100) |i| {
        try map.put(@intCast(i), i * 100);
        try testing.expect(map.remove(@intCast(i)));
        try testing.expectEqual(null, map.get(@intCast(i)));
    }

    try testing.expectEqual(0, map.count.load(.seq_cst));
}

test "concurrent put and get" {
    const gpa = testing.allocator;
    var map = try ConcurrentHashMap(u64, u64, std.hash_map.AutoContext(u64)).init(gpa, 16, .{});
    defer map.deinit();

    const ThreadCount = 4;
    const OpsPerThread = 1000;

    var handles: [ThreadCount]std.Thread = undefined;

    // Spawn threads to put values concurrently
    for (0..ThreadCount) |t| {
        handles[t] = try std.Thread.spawn(.{}, struct {
            fn run(m: *ConcurrentHashMap(u64, u64, std.hash_map.AutoContext(u64)), tid: usize) void {
                const base = tid * OpsPerThread;
                for (0..OpsPerThread) |i| {
                    m.put(@intCast(base + i), (base + i) * 100) catch unreachable;
                }
            }
        }.run, .{ &map, t });
    }

    // Wait for all threads to finish
    for (handles) |h| h.join();

    // Verify all values
    for (0..ThreadCount) |t| {
        const base = t * OpsPerThread;
        for (0..OpsPerThread) |i| {
            try testing.expectEqual(@as(u64, (base + i) * 100), map.get(@intCast(base + i)).?);
        }
    }

    try testing.expectEqual(ThreadCount * OpsPerThread, map.count.load(.seq_cst));
}

test "string keys with integer values" {
    const gpa = testing.allocator;
    var map = try ConcurrentHashMap([]const u8, i32, std.hash_map.StringContext).init(gpa, 16, .{});
    defer map.deinit();

    try map.put("one", 1);
    try map.put("two", 2);
    try map.put("three", 3);

    try testing.expectEqual(1, map.get("one").?);
    try testing.expectEqual(2, map.get("two").?);
    try testing.expectEqual(3, map.get("three").?);
    try testing.expectEqual(null, map.get("four"));

    try testing.expect(map.remove("two"));
    try testing.expectEqual(null, map.get("two"));
    try testing.expectEqual(2, map.count.load(.seq_cst));
}

test "multiple resizes" {
    const gpa = testing.allocator;
    var map = try ConcurrentHashMap(u64, u64, std.hash_map.AutoContext(u64)).init(gpa, 4, .{});
    defer map.deinit();

    // Trigger multiple resizes (4 -> 8 -> 16)
    for (0..10) |i| {
        try map.put(@intCast(i), i * 100);
    }

    for (0..10) |i| {
        try testing.expectEqual(@as(u64, i * 100), map.get(@intCast(i)).?);
    }
    try testing.expect(@as(i32, @intCast(map.size.load(.seq_cst))) >= 16);
    try testing.expectEqual(10, map.count.load(.seq_cst));
}

test "iterate u64 keys and values" {
    const gpa = testing.allocator;
    var map = try ConcurrentHashMap(u64, u64, std.hash_map.AutoContext(u64)).init(gpa, 16, .{});
    defer map.deinit();

    // Insert some key-value pairs
    try map.put(1, 100);
    try map.put(2, 200);
    try map.put(3, 300);

    // Iterate and collect entries
    var entries = std.ArrayList(struct { key: u64, value: u64 }).init(gpa);
    defer entries.deinit();

    var iter = map.iterator();
    defer iter.deinit();

    while (iter.next()) |entry| {
        try entries.append(.{ .key = entry.key, .value = entry.value });
    }

    // Verify entries (order is not guaranteed due to hashing)
    try testing.expectEqual(3, entries.items.len);
    var found = [_]bool{ false, false, false };
    for (entries.items) |entry| {
        switch (entry.key) {
            1 => {
                try testing.expectEqual(100, entry.value);
                found[0] = true;
            },
            2 => {
                try testing.expectEqual(200, entry.value);
                found[1] = true;
            },
            3 => {
                try testing.expectEqual(300, entry.value);
                found[2] = true;
            },
            else => unreachable,
        }
    }
    try testing.expect(found[0] and found[1] and found[2]);
}

test "iterate string keys with integer values" {
    const gpa = testing.allocator;
    var map = try ConcurrentHashMap([]const u8, i32, std.hash_map.StringContext).init(gpa, 16, .{});
    defer map.deinit();

    // Insert some key-value pairs
    try map.put("one", 1);
    try map.put("two", 2);
    try map.put("three", 3);

    // Iterate and collect entries
    var entries = std.ArrayList(struct { key: []const u8, value: i32 }).init(gpa);
    defer entries.deinit();

    var iter = map.iterator();
    defer iter.deinit();

    while (iter.next()) |entry| {
        try entries.append(.{ .key = entry.key, .value = entry.value });
    }

    // Verify entries
    try testing.expectEqual(3, entries.items.len);
    var found = [_]bool{ false, false, false };
    for (entries.items) |entry| {
        if (std.mem.eql(u8, entry.key, "one")) {
            try testing.expectEqual(1, entry.value);
            found[0] = true;
        } else if (std.mem.eql(u8, entry.key, "two")) {
            try testing.expectEqual(2, entry.value);
            found[1] = true;
        } else if (std.mem.eql(u8, entry.key, "three")) {
            try testing.expectEqual(3, entry.value);
            found[2] = true;
        } else {
            unreachable;
        }
    }
    try testing.expect(found[0] and found[1] and found[2]);
}
