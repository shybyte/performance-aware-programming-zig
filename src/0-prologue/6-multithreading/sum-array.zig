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

const MIN_ARRAY_SIZE = 4096;
const MAX_ARRAY_SIZE = ARRAY_SIZE_MAIN_MEM;

fn sumArraySingleScalar(array: []const u32) u64 {
    var result: u64 = 0;

    for (array) |elem| {
        result += elem;
    }

    return result;
}

fn sumArraySingleScalarU64(array: []const u64) u64 {
    var result: u64 = 0;

    for (array) |elem| {
        result += elem;
    }

    return result;
}

fn sumArraySimdThreadWrapper(arr: []const u32, result: *u64) void {
    result.* = sumArraySingleScalar(arr);
}

fn sumArraySimdMultithreaded(arr: []const u32) u64 {
    const num_threads = 4;
    var threads: [num_threads]std.Thread = undefined;
    var thread_results: [num_threads]u64 = [1]u64{0} ** num_threads;

    const chunk_size = arr.len / num_threads;
    for (0..num_threads) |i| {
        const input_start_index = i * chunk_size;
        const input_end_index = (i + 1) * chunk_size;
        const thread = std.Thread.spawn(.{}, sumArraySimdThreadWrapper, .{ arr[input_start_index..input_end_index], &thread_results[i] }) catch {
            return 0;
        };
        threads[i] = thread;
    }

    for (threads) |thread| {
        thread.join();
    }

    return sumArraySingleScalarU64(&thread_results);
}

var wg = std.Thread.WaitGroup{};
var pool: std.Thread.Pool = undefined;

fn sumArraySimdThreadWrapperWaitGroup(arr: []const u32, result: *u64) void {
    result.* = sumArraySingleScalar(arr);
    wg.finish();
}

fn sumArraySimdMultithreadedPool(arr: []const u32) u64 {
    wg.reset();
    const num_threads = 4;
    var thread_results: [num_threads]u64 = [1]u64{0} ** num_threads;

    const chunk_size = arr.len / num_threads;
    for (0..num_threads) |i| {
        const input_start_index = i * chunk_size;
        const input_end_index = (i + 1) * chunk_size;
        wg.start();
        pool.spawn(sumArraySimdThreadWrapperWaitGroup, .{ arr[input_start_index..input_end_index], &thread_results[i] }) catch {
            return 0;
        };
    }

    pool.waitAndWork(&wg);

    return sumArraySingleScalarU64(&thread_results);
}

const SumArrayFuncType = fn (array: []const u32) u64;

fn benchmarkFunction(array: []const u32, name: []const u8, expected_result: u64, f: SumArrayFuncType) f64 {
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
        if (result != expected_result) {
            std.debug.print("Expected is {} but got {} .\n", .{ expected_result, result });
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

const allocator = std.heap.page_allocator;

pub fn main() !u8 {
    const cpu_count = try std.Thread.getCpuCount();
    std.debug.print("CPU-Count: {}\n\n", .{cpu_count});

    const array = try allocator.alloc(u32, MAX_ARRAY_SIZE);

    for (0.., array) |i, elem| {
        _ = elem;
        array[i] = @intCast(i);
    }

    const file = try std.fs.cwd().createFile(
        "tmp/multithreaded-cache-results.csv",
        .{},
    );
    defer file.close();

    const file_writer = file.writer();

    const pool_options: std.Thread.Pool.Options = .{ .allocator = allocator, .n_jobs = 4 };
    std.Thread.Pool.init(&pool, pool_options) catch |err| {
        std.log.err("Failed to initialize thread pool: {}", .{err});
        return err;
    };
    defer pool.deinit();

    // const r = sumArraySimdMultithreadedPool(array[0..MIN_ARRAY_SIZE]);
    // std.debug.print("Result: {}\n", .{r});

    var array_size: usize = MIN_ARRAY_SIZE;
    while (array_size <= MAX_ARRAY_SIZE) {
        const array_slice = array[0..array_size];
        std.debug.print("---- ArraySize: {} = {} kb\n\n", .{ array_size, array_size * 4 / 1024 });

        const expected_result = sumArraySingleScalar(array_slice);
        const add_per_cycle_1 = benchmarkFunction(array_slice, "sumArraySingleScalar", expected_result, sumArraySingleScalar);
        const add_per_cycle_2 = benchmarkFunction(array_slice, "sumArraySimdMultithreaded", expected_result, sumArraySimdMultithreaded);
        const add_per_cycle_3 = benchmarkFunction(array_slice, "sumArraySimdMultithreadedPool", expected_result, sumArraySimdMultithreadedPool);

        std.debug.print("\n{d}, {d}, {d}, {d}, {d}\n", .{ array_size, array_size * 4 / 1024, add_per_cycle_1, add_per_cycle_2, add_per_cycle_3 });
        try file_writer.print("{d}, {d}, {d}, {d}, {d}\n", .{ array_size, array_size * 4 / 1024, add_per_cycle_1, add_per_cycle_2, add_per_cycle_3 });
        array_size *= 2;
    }

    return 0;
}
