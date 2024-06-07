const std = @import("std");

const CPU_MAX_GHZ = 3.6;
const TRY_COUNT = 1_000;

// L1 128 KiB = 32_768 u32
const ARRAY_SIZE_L1 = 32_768;

// L2 1 MiB =  262_144 u32
const ARRAY_SIZE_L2 = 262_144;

// L3 6MiB = 1_572_864 u32
const ARRAY_SIZE_L3 = 1_572_864;

const ARRAY_SIZE_MAIN_MEM = 10 * ARRAY_SIZE_L3;

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

fn benchmarkFunction(array: []const u32, name: []const u8, f: SumArrayFuncType) void {
    std.time.sleep(1_000_000);
    _ = f(array);

    std.debug.print("Benchmarking \"{s}\" ...\n", .{name});
    var min_time: i128 = 1_000_000_000;
    var time_sum: i128 = 0;

    const benchmark_start_time = std.time.microTimestamp();

    for (0..TRY_COUNT) |try_i| {
        _ = try_i;

        const start_time = std.time.nanoTimestamp();

        const result = @call(.never_inline, f, .{array});
        if (result == 0) {
            std.debug.print("Expected value >0 but got {} .\n", .{result});
            return;
        }

        const duration = std.time.nanoTimestamp() - start_time;
        time_sum += duration;
        if (duration < min_time) {
            min_time = duration;
        }
    }

    const mean_time = @divFloor(time_sum, TRY_COUNT);
    const benchmark_time = std.time.microTimestamp() - benchmark_start_time;

    const cycles = @as(f64, @floatFromInt(min_time)) * CPU_MAX_GHZ;
    const cycles_per_add = cycles / ARRAY_SIZE;
    const adds_per_cycle = 1.0 / cycles_per_add;

    std.debug.print("BenchmarkTime: {} milliseconds\n", .{benchmark_time});
    std.debug.print("MeanTime: {} nanoseconds\n", .{mean_time});
    std.debug.print("Time: {} nanoseconds\n", .{min_time});
    std.debug.print("Cycles: {d}\n", .{cycles});
    std.debug.print("Cycles/add: {d}\n", .{cycles_per_add});
    std.debug.print("Adds/cycle: {d}\n", .{adds_per_cycle});
    std.debug.print("\n", .{});
}

pub fn main() !u8 {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    const allocator = std.heap.page_allocator;

    const array = try allocator.alloc(u32, ARRAY_SIZE);

    for (0.., array) |i, elem| {
        _ = elem;
        array[i] = @intCast(i);
    }

    benchmarkFunction(array, "sumArraySingleScalar", sumArraySingleScalar);
    benchmarkFunction(array, "sumArraySimd", sumArraySimd);

    return 0;
}
