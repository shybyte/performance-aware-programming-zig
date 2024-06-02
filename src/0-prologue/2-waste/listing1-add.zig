export fn addNumber(a: i32, b: i32) i32 {
    return a + b;
}

export fn main() i32 {
    return @call(.never_inline, addNumber, .{ 1234, 5678 });
}
