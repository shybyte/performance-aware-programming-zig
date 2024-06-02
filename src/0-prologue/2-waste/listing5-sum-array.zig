const std = @import("std");

const CPU_MAX_GHZ = 3.6;
const TRY_COUNT = 100_000;

const ARRAY_SIZE = 4096;
const EXPECTED_RESULT = 8386560;

// const ARRAY_SIZE = 8192;
// const EXPECTED_RESULT = 33550336;

fn sumArray(array: []const u32) u32 {
    var result: u32 = 0;

    for (array) |elem| {
        result += elem;
    }

    return result;
}

pub fn main() !u8 {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    const allocator = std.heap.page_allocator;

    const array = try allocator.alloc(u32, ARRAY_SIZE);

    const start_time_1 = std.time.milliTimestamp();
    const delta = std.time.milliTimestamp() - start_time_1;

    for (0.., array) |i, elem| {
        _ = elem;
        array[i] = @intCast(i);
        array[i] += @intCast(delta);
    }

    var min_time: i128 = 1_000_000;

    for (0..TRY_COUNT) |try_i| {
        _ = try_i;

        const start_time = std.time.nanoTimestamp();

        const result = sumArray(array);
        if (result != EXPECTED_RESULT) {
            std.debug.print("Expected {} bot got {} .\n", .{ EXPECTED_RESULT, result });
            return 1;
        }

        const duration = std.time.nanoTimestamp() - start_time;
        if (duration < min_time) {
            min_time = duration;
        }
    }

    const cycles = @as(f64, @floatFromInt(min_time)) * CPU_MAX_GHZ;
    const cycles_per_add = cycles / ARRAY_SIZE;
    const adds_per_cycle = 1 / cycles_per_add;

    std.debug.print("Time: {} nanoseconds\n", .{min_time});
    std.debug.print("Cycles: {d}\n", .{cycles});
    std.debug.print("Cycles/add: {d}\n", .{cycles_per_add});
    std.debug.print("Adds/cycle: {d}\n", .{adds_per_cycle});

    return 0;
}
