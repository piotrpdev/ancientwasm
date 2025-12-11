#!/bin/bash
cobc -x -C main.cbl -K r_
#emcc main.c -I/root/gmp-6.3.0/ -I/root/gnucobol-3.2/ -I/root/libf2c -L/root/gmp-6.3.0/.libs/ -L/root/gnucobol-3.2/libcob/.libs/ -lgmp -lcob -o example.js
emcc main.c -std=c17 -Wno-deprecated-non-prototype -lgmp -lcob -o demo.js
