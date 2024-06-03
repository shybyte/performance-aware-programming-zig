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

test "basic add functionality" {
    const array = [_]u32{ 1, 2, 3, 4, 5 };
    const sum = sumArrayZig(&array, array.len);
    try testing.expect(sum == 15);
}
