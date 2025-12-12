#!/bin/bash
cobc -x -C main.cbl
emcc main.c -std=gnu17 -Wno-deprecated-non-prototype -lgmp -lcob -o demo.js
