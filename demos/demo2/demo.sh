#!/bin/bash
cobc -x -C main.cbl -K emscripten_run_script
emcc main.c -std=c17 -Wno-deprecated-non-prototype -lgmp -lcob -o demo.js
echo "Running demo..."
node demo.js
