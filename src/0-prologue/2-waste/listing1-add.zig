export fn addNumber(A: i32, B: i32) i32 {
    return A + B;
}

export fn main() i32 {
    return @call(.never_inline, addNumber, .{ 1234, 5678 });
}
