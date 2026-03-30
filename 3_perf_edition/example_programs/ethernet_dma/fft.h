#ifndef FFT_H
#define FFT_H

#include <stdint.h>

#define FFT_N     256
#define FFT_BITS  8      // log2(256)

// run in-place FFT on re[], im[] arrays of length FFT_N
// input:  re[] = your samples (Q1.15 scaled), im[] = all zeros
// output: re[], im[] contain the complex spectrum
void fft(int32_t* re, int32_t* im);

// compute magnitude squared for first FFT_N/2 bins into out[]
void fft_magnitude(int32_t* re, int32_t* im, int32_t* out);

#endif