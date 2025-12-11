#!/bin/bash
cobc -x -C main.cbl
gcc main.c -std=c17 -Wno-deprecated-non-prototype -lgmp -lcob -o demo
