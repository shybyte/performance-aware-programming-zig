const std = @import("std");
const testing = std.testing;

// extern fn print(i32) void;

// export fn add(a: i32, b: i32) void {
//     print(a + b);
// }

export fn mul(a: i32, b: i32) i32 {
    return a * b;
}

export fn sumArrayZig(arr: [*]const u32, len: usize) u32 {
    var sum: u32 = 0;
    for (0..len) |i| {
        sum += arr[i];
    }
    return sum;
}

export fn sumArraySimd(arr: [*]const u32, len: usize) u32 {
    // AVX/AVX2 = 256 bit = 8 u32
    const width = 128; // best on my machine in small and fast mode
    const Vector = @Vector(width, u32);
    var sum: Vector = @splat(0);
    var i: usize = 0;

    // Main SIMD loop
    while (i + width <= len) {
        const vec: Vector = arr[i..][0..width].*;
        sum += vec;
        i += width;
    }

    // Reduce the SIMD vector to a scalar sum
    var scalar_sum: u32 = @reduce(.Add, sum);

    // Handle remaining elements
    while (i < len) {
        scalar_sum += arr[i];
        i += 1;
    }

    return scalar_sum;
}

export fn sumArray8Scalar(array: [*]const u32, len: usize) u32 {
    var sum1: u32 = 0;
    var sum2: u32 = 0;
    var sum3: u32 = 0;
    var sum4: u32 = 0;
    var sum5: u32 = 0;
    var sum6: u32 = 0;
    var sum7: u32 = 0;
    var sum8: u32 = 0;

    var i: usize = 0;
    while (i < len) {
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

test "sumArrayZig" {
    const array = [_]u32{ 1, 2, 3, 4, 5 };
    const sum = sumArrayZig(&array, array.len);
    try testing.expect(sum == 15);
}

test "sumArraySimd" {
    const array = [_]u32{ 1, 2, 3, 4, 5 };
    const sum = sumArraySimd(&array, array.len);
    try testing.expect(sum == 15);
}
