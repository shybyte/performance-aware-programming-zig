const std = @import("std");
const testing = std.testing;
const Mutex = std.Thread.Mutex;
const Condition = std.Thread.Condition;
const ResetEvent = std.Thread.ResetEvent;

const allocator = std.heap.page_allocator;

const CPU_MAX_GHZ = 3.6;

const MAX_TRY_COUNT = 100_000;

const EXPECTED_RESULT = 8386560;

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

const MILLISECOND_IN_NANOSECONDS = 1_000_000;

const THREAD_NUMBER = 4;
var threads: [THREAD_NUMBER]std.Thread = undefined;
const thread_results: [THREAD_NUMBER]u64 = [1]u64{0} ** THREAD_NUMBER;

var my_thread_pool_workers: [THREAD_NUMBER]Worker = undefined;

var wait_group = std.Thread.WaitGroup{};

const EMPTY_ARRAY: [0]u32 = .{};

const Worker = struct {
    index: usize,
    shutdown_flag: bool = false,
    mutex: Mutex = .{},
    condition: Condition = .{},
    reset_event: ResetEvent = .{},
    input_array: []const u32 = &EMPTY_ARRAY,
    result: u64 = 0,
};

fn sumArraySingleScalarThreadWorker(worker: *Worker) void {
    while (true) {
        // worker.mutex.lock();
        // defer worker.mutex.unlock();

        // std.debug.print("Worker {d} waits for condition\n", .{worker.index});
        // if (worker.shutdown_flag) {
        //     std.debug.print("Shutdown worker {d}\n", .{worker.index});
        //     break;
        // }
        // worker.condition.wait(&worker.mutex);
        worker.reset_event.wait();
        worker.reset_event.reset();
        if (worker.shutdown_flag) {
            // std.debug.print("Shutdown worker {d}\n", .{worker.index});
            break;
        }

        // std.debug.print("==> Start work {d}: {d}\n", .{ worker.index, worker.input_array.len });
        worker.result = sumArraySingleScalar(worker.input_array);
        // std.debug.print("Finished work {d} 1\n", .{worker.index});
        wait_group.finish();
        // std.debug.print("Finished work {d} 2\n", .{worker.index});
    }
}

fn sumArrayMulti(array: []const u32) u64 {
    wait_group.reset();
    const chunk_size = array.len / THREAD_NUMBER;
    for (&my_thread_pool_workers) |*worker| {
        wait_group.start();
        worker.input_array = array[worker.index * chunk_size .. (worker.index + 1) * chunk_size];
        worker.reset_event.set();
    }

    // std.debug.print("Waiting for results...\n", .{});
    // std.time.sleep(MILLISECOND_IN_NANOSECONDS);
    wait_group.wait();

    var sum: u64 = 0;
    for (&my_thread_pool_workers) |*worker| {
        sum += worker.result;
    }

    return sum;
}

fn initThreads() !void {
    for (0..THREAD_NUMBER) |thread_index| {
        my_thread_pool_workers[thread_index] = Worker{ .index = thread_index };
        const thread = try std.Thread.spawn(.{}, sumArraySingleScalarThreadWorker, .{&my_thread_pool_workers[thread_index]});
        threads[thread_index] = thread;
    }
}

fn cleanUpThreads() void {
    for (&my_thread_pool_workers) |*worker| {
        worker.shutdown_flag = true;
        worker.reset_event.set();
    }

    for (threads) |thread| {
        thread.join();
    }
}

test "sumArrayMulti" {
    std.debug.print("\nRunning .... \n\n", .{});
    const array = try testing.allocator.alloc(u32, MAX_ARRAY_SIZE);
    defer testing.allocator.free(array);

    for (0.., array) |i, elem| {
        _ = elem;
        array[i] = @intCast(i);
    }

    try testing.expect(sumArraySingleScalar(array) == EXPECTED_RESULT);
    try initThreads();
    defer cleanUpThreads();

    std.debug.print("Sum = {}\n", .{sumArrayMulti(array)});
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

pub fn main() !u8 {
    const cpu_count = try std.Thread.getCpuCount();
    std.debug.print("CPU-Count: {}\n\n", .{cpu_count});

    const array = try allocator.alloc(u32, MAX_ARRAY_SIZE);

    for (0.., array) |i, elem| {
        _ = elem;
        array[i] = @intCast(i);
    }

    const file = try std.fs.cwd().createFile(
        "tmp/multithreaded-cache-results-2.csv",
        .{},
    );
    defer file.close();

    const file_writer = file.writer();

    try initThreads();
    defer cleanUpThreads();

    var array_size: usize = MIN_ARRAY_SIZE;
    while (array_size <= MAX_ARRAY_SIZE) {
        const array_slice = array[0..array_size];
        std.debug.print("---- ArraySize: {} = {} kb\n\n", .{ array_size, array_size * 4 / 1024 });

        const expected_result = sumArraySingleScalar(array_slice);
        const add_per_cycle_1 = benchmarkFunction(array_slice, "sumArraySingleScalar", expected_result, sumArraySingleScalar);
        const add_per_cycle_2 = benchmarkFunction(array_slice, "sumArrayMulti", expected_result, sumArrayMulti);

        std.debug.print("\n{d}, {d}, {d}, {d}\n", .{ array_size, array_size * 4 / 1024, add_per_cycle_1, add_per_cycle_2 });
        try file_writer.print("{d}, {d}, {d}, {d}\n", .{ array_size, array_size * 4 / 1024, add_per_cycle_1, add_per_cycle_2 });
        array_size *= 2;
    }

    return 0;
}
