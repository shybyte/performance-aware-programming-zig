const std = @import("std");

const CPU_MAX_GHZ = 3.6;
const MAX_TRY_COUNT = 100_000;

// L1 128 KiB = 32_768 u32
const ARRAY_SIZE_L1 = 32_768;

// L2 1 MiB =  262_144 u32
const ARRAY_SIZE_L2 = 262_144;

// L3 6MiB = 1_572_864 u32
const ARRAY_SIZE_L3 = 1_572_864;

const ARRAY_SIZE_MAIN_MEM = 10 * ARRAY_SIZE_L3;

const MAX_ARRAY_SIZE = ARRAY_SIZE_MAIN_MEM;

// const ARRAY_SIZE = ARRAY_SIZE_L1;
const ARRAY_SIZE = 4096;
const EXPECTED_RESULT = 8386560;

fn sumArraySingleScalar(array: []const u32) u32 {
    var result: u32 = 0;

    for (array) |elem| {
        result += elem;
    }

    return result;
}

fn sumArraySimd(arr: []const u32) u32 {
    // AVX/AVX2 = 256 bit = 8 u32
    const width = 128; // best on my machine in small and fast mode
    const Vector = @Vector(width, u32);
    var sum: Vector = @splat(0);
    var i: usize = 0;

    // Main SIMD loop
    while (i + width <= arr.len) {
        const vec: Vector = arr[i..][0..width].*;
        sum += vec;
        i += width;
    }

    // Reduce the SIMD vector to a scalar sum
    var scalar_sum: u32 = @reduce(.Add, sum);

    // Handle remaining elements
    while (i < arr.len) {
        scalar_sum += arr[i];
        i += 1;
    }

    return scalar_sum;
}

const SumArrayFuncType = fn (array: []const u32) u32;

fn benchmarkFunction(array: []const u32, name: []const u8, f: SumArrayFuncType) f64 {
    std.time.sleep(1_000_000);
    _ = f(array);

    std.debug.print("Benchmarking \"{s}\" ...\n", .{name});
    var min_time: i128 = 1_000_000_000;
    var time_sum: i128 = 0;

    const benchmark_start_time = std.time.microTimestamp();

    var try_count: usize = 0;
    while (try_count < MAX_TRY_COUNT) {
        const start_time = std.time.nanoTimestamp();

        const result = @call(.never_inline, f, .{array});
        if (result == 0) {
            std.debug.print("Expected value > 0 but got {} .\n", .{result});
            return 0;
        }

        const duration = std.time.nanoTimestamp() - start_time;
        time_sum += duration;
        if (duration < min_time) {
            min_time = duration;
        }

        try_count += 1;

        if (std.time.microTimestamp() - benchmark_start_time > 100_000) {
            break;
        }
    }

    const mean_time = @divFloor(time_sum, try_count);
    const benchmark_time = std.time.microTimestamp() - benchmark_start_time;

    const cycles = @as(f64, @floatFromInt(min_time)) * CPU_MAX_GHZ;
    const cycles_per_add = cycles / @as(f64, @floatFromInt(array.len));
    const adds_per_cycle = 1.0 / cycles_per_add;

    std.debug.print("TryCount: {}\n", .{try_count});
    std.debug.print("BenchmarkTime: {} microseconds\n", .{benchmark_time});
    std.debug.print("MeanTime: {} nanoseconds\n", .{mean_time});
    std.debug.print("Time: {} nanoseconds\n", .{min_time});
    std.debug.print("Cycles: {d}\n", .{cycles});
    std.debug.print("Cycles/add: {d}\n", .{cycles_per_add});
    std.debug.print("Adds/cycle: {d}\n", .{adds_per_cycle});
    std.debug.print("\n", .{});

    return adds_per_cycle;
}

pub fn main() !u8 {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    const allocator = std.heap.page_allocator;

    const array = try allocator.alloc(u32, MAX_ARRAY_SIZE);

    for (0.., array) |i, elem| {
        _ = elem;
        array[i] = @intCast(i);
    }

    const file = try std.fs.cwd().createFile(
        "tmp/cache-results.csv",
        .{},
    );
    defer file.close();

    const file_writer = file.writer();

    var array_size: usize = 4096;
    while (array_size <= MAX_ARRAY_SIZE) {
        std.debug.print("---- ArraySize: {} = {} kb\n\n", .{ array_size, array_size * 4 / 1024 });
        const add_per_cycle_1 = benchmarkFunction(array[0..array_size], "sumArraySingleScalar", sumArraySingleScalar);
        const add_per_cycle_2 = benchmarkFunction(array[0..array_size], "sumArraySimd", sumArraySimd);
        try file_writer.print("{d}, {d}, {d}, {d}\n", .{ array_size, array_size * 4 / 1024, add_per_cycle_1, add_per_cycle_2 });
        array_size *= 2;
    }

    return 0;
}
