const std = @import("std");

const CPU_MAX_GHZ = 3.6;
const TRY_COUNT = 100_000;

const ARRAY_SIZE = 4096;
const EXPECTED_RESULT = 8386560;

// const ARRAY_SIZE = 8192;
// const EXPECTED_RESULT = 33550336;

fn sumArraySingleScalar(array: []const u32) u32 {
    var result: u32 = 0;

    for (array) |elem| {
        result += elem;
    }

    return result;
}

fn sumArraySingleScalarWhile(array: []const u32) u32 {
    var result: u32 = 0;

    var i: usize = 0;
    while (i < array.len) {
        result += array[i];
        i += 1;
    }

    return result;
}

fn sumArrayUnroll2Scalar(array: []const u32) u32 {
    var result: u32 = 0;

    var i: usize = 0;
    while (i < array.len) {
        result += array[i];
        result += array[i + 1];
        i += 2;
    }

    return result;
}

fn sumArrayUnroll4Scalar(array: []const u32) u32 {
    var result: u32 = 0;

    var i: usize = 0;
    while (i < array.len) {
        result += array[i];
        result += array[i + 1];
        result += array[i + 2];
        result += array[i + 3];
        i += 4;
    }

    return result;
}

fn sumArrayDualScalar(array: []const u32) u32 {
    var sum1: u32 = 0;
    var sum2: u32 = 0;

    var i: usize = 0;
    while (i < array.len) {
        sum1 += array[i];
        sum2 += array[i + 1];
        i += 2;
    }

    return sum1 + sum2;
}

fn sumArrayQuadScalar(array: []const u32) u32 {
    var sum1: u32 = 0;
    var sum2: u32 = 0;
    var sum3: u32 = 0;
    var sum4: u32 = 0;

    var i: usize = 0;
    while (i < array.len) {
        sum1 += array[i];
        sum2 += array[i + 1];
        sum3 += array[i + 2];
        sum4 += array[i + 3];
        i += 4;
    }

    return sum1 + sum2 + sum3 + sum4;
}

fn sumArray8Scalar(array: []const u32) u32 {
    var sum1: u32 = 0;
    var sum2: u32 = 0;
    var sum3: u32 = 0;
    var sum4: u32 = 0;
    var sum5: u32 = 0;
    var sum6: u32 = 0;
    var sum7: u32 = 0;
    var sum8: u32 = 0;

    var i: usize = 0;
    while (i < array.len) {
        sum1 += array[i];
        sum2 += array[i + 1];
        sum3 += array[i + 2];
        sum4 += array[i + 3];
        sum5 += array[i + 4];
        sum6 += array[i + 5];
        sum7 += array[i + 6];
        sum8 += array[i + 7];
        i += 8;
    }

    return sum1 + sum2 + sum3 + sum4 + sum5 + sum6 + sum7 + sum8;
}

const SumArrayFuncType = fn (array: []const u32) u32;

fn benchmarkFunction(array: []const u32, name: []const u8, f: SumArrayFuncType) void {
    std.time.sleep(1_000_000);
    _ = f(array);

    std.debug.print("Benchmarking \"{s}\" ...\n", .{name});
    var min_time: i128 = 1_000_000;
    var time_sum: i128 = 0;

    const benchmark_start_time = std.time.microTimestamp();

    for (0..TRY_COUNT) |try_i| {
        _ = try_i;

        const start_time = std.time.nanoTimestamp();

        const result = @call(.never_inline, f, .{array});
        if (result != EXPECTED_RESULT) {
            std.debug.print("Expected {} bot got {} .\n", .{ EXPECTED_RESULT, result });
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
    const adds_per_cycle = 1 / cycles_per_add;

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
    benchmarkFunction(array, "sumArraySingleScalarWhile", sumArraySingleScalarWhile);
    benchmarkFunction(array, "sumArrayUnroll2Scalar", sumArrayUnroll2Scalar);
    benchmarkFunction(array, "sumArrayDualScalar", sumArrayDualScalar);
    benchmarkFunction(array, "sumArrayQuadScalar", sumArrayQuadScalar);
    benchmarkFunction(array, "sumArray8Scalar", sumArray8Scalar);
    benchmarkFunction(array, "sumArrayUnroll4Scalar", sumArrayUnroll4Scalar);

    return 0;
}
