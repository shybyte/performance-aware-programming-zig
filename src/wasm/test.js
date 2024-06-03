import { readFileSync } from 'fs';
const source = readFileSync("./math.wasm");
const typedArray = new Uint8Array(source);

// WebAssembly.instantiate(typedArray, {
//   env: {
//     print: (result) => { console.log(`The result is ${result}`); }
//   }}).then(result => {
//   const add = result.instance.exports.add;
//   add(1, 2);
// });

async function main() {
  const myWasmLib = await WebAssembly.instantiate(typedArray, {
    env: {
      print: (result) => { console.log(`The result is ${result}`); }
    }
  }).then(result => result.instance.exports);

  const mul = myWasmLib.mul;
  const result = mul(1, 2);
  console.log('Result of mul:', result);

  // Define an array and its length
  const array = new Uint32Array([1, 2, 3, 4, 5]);
  const len = array.length;

  // Allocate memory for the array in the WASM instance
  const memory = myWasmLib.memory;
  const view = new Uint32Array(memory.buffer);
  view.set(array);

  // Call the sum_array function
  const sum = myWasmLib.sumArrayZig(view.byteOffset / 4, len); // Divide byteOffset by 4 for Int32Array
  console.log("Sum of array:", sum);
}


main();