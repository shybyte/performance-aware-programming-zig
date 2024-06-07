import { readFileSync } from 'fs';
import { performance, createHistogram } from 'perf_hooks';

// lscpu | grep MHz
const CPU_MAX_GHZ = 3.6

const ARRAY_SIZE = 4096; // 0x1000
const TRY_COUNT = 100_000;

const EXPECTED_RESULT = 8386560;

function generateNumberArray(size) {
  const result = new Uint32Array(size);

  for (let i = 0; i < size; i++) {
    result[i] = i;
  }

  return result;
}

const array = generateNumberArray(ARRAY_SIZE);


function sumArrayJsForIndex(array) {
  let result = 0;

  for (let i = 0; i < array.length; i++) {
    result += array[i];
  }

  return result;
}


console.log('Sum of Array (JS):', sumArrayJsForIndex(array));


function measureSpeed(expectedResult, callback) {
  const histogram = createHistogram();

  for (let i = 0; i < TRY_COUNT; i++) {
    const start = performance.now();
    const result = callback();
    if(expectedResult != undefined && expectedResult != result) {
    throw new Error(`Invalid result ${result} instead of expected result ${expectedResult}`)
    }
    const duration = performance.now() - start;
    histogram.record(Math.floor(duration * 1_000_000)); //nano seconds
  }

  return histogram;
}

async function main() {
  const source = readFileSync("./math.wasm");
  const typedArray = new Uint8Array(source);

  const myWasmLib = await WebAssembly.instantiate(typedArray, {
    env: {
      print: (result) => { console.log(`The result is ${result}`); }
    }
  }).then(result => result.instance.exports);

  // Allocate memory for the array in the WASM instance
  const memory = myWasmLib.memory;
  const view = new Uint32Array(memory.buffer);
  view.set(array);

  // Call the sumArrayZig function
  const sum = myWasmLib.sumArrayZig(view.byteOffset / 4, array.length); // Divide byteOffset by 4 for Uint32Array
  console.log("Sum of array:", sum);
  
  const benchmarkResults = [];

  const sumWasm = () => myWasmLib.sumArrayZig(view.byteOffset / 4, array.length);
  const sumWasmSimd = () => myWasmLib.sumArraySimd(view.byteOffset / 4, array.length);
  const sumArray8Scalar = () => myWasmLib.sumArray8Scalar(view.byteOffset / 4, array.length);
  const sumJS = () => sumArrayJsForIndex(array);
  
  const functionsToTest = [sumJS, sumWasm, sumWasmSimd, sumArray8Scalar];
  
  for (const functionToTest of functionsToTest) {
    const histogram = measureSpeed(EXPECTED_RESULT, () => functionToTest());
  
    const timeNanoSeconds = histogram.min;
    const cycles = timeNanoSeconds * CPU_MAX_GHZ;
    const cyclesPerAdd = cycles / ARRAY_SIZE;
    const addsPerCycle = 1 / cyclesPerAdd;
  
    const functionToTestName = functionToTest.name;
    console.log(`FunctionToTest: ${functionToTestName}`) ;
    console.log(`Time: ${timeNanoSeconds} nanoseconds`);
    console.log(`Cycles: ${cycles} cycles`);
    console.log(`Cycles/add: ${cyclesPerAdd}`);
    console.log(`Adds/cycle: ${addsPerCycle}`);
    console.log(``);
  
    benchmarkResults.push({ name: functionToTestName, timeNanoSeconds, cycles, cyclesPerAdd, addsPerCicle: addsPerCycle });
  
  }
  
  console.table(benchmarkResults);
}


main();