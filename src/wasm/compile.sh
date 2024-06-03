zig build-exe math.zig -target wasm32-freestanding -fno-entry --export=mul
zig build-exe math.zig -target wasm32-freestanding -fno-entry -rdynamic -O ReleaseSmall
zig build-exe math.zig -target wasm32-freestanding -fno-entry -rdynamic -O ReleaseFast

# https://ziggit.dev/t/zig-webassembly/2550/7

node --allow-natives-syntax --trace-turbo --no-turbo-inlining benchmark.js