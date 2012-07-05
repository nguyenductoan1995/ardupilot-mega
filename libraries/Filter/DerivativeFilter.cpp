// -*- tab-width: 4; Mode: C++; c-basic-offset: 4; indent-tabs-mode: nil -*-
//
// This is free software; you can redistribute it and/or modify it under
// the terms of the GNU Lesser General Public License as published by the
// Free Software Foundation; either version 2.1 of the License, or (at
// your option) any later version.
//

/// @file	Derivative.cpp
/// @brief	A class to implement a derivative (slope) filter
/// See http://www.holoborodko.com/pavel/numerical-methods/numerical-derivative/smooth-low-noise-differentiators/

#include <FastSerial.h>
#include <inttypes.h>
#include <Filter.h>
#include <DerivativeFilter.h>

template <class T,  uint8_t FILTER_SIZE>
float DerivativeFilter<T,FILTER_SIZE>::apply(T sample, uint32_t timestamp)
{
	float result = 0;

    // add timestamp before we apply to FilterWithBuffer
    _timestamps[FilterWithBuffer<T,FILTER_SIZE>::sample_index] = timestamp;

	// call parent's apply function to get the sample into the array
	FilterWithBuffer<T,FILTER_SIZE>::apply(sample);

    // use f() to make the code match the maths a bit better. Note
    // that unlike an average filter, we care about the order of the elements
    #define f(i) FilterWithBuffer<T,FILTER_SIZE>::samples[(((FilterWithBuffer<T,FILTER_SIZE>::sample_index-1)+i)+3*FILTER_SIZE/2) % FILTER_SIZE]
    #define x(i) _timestamps[(((FilterWithBuffer<T,FILTER_SIZE>::sample_index-1)+i)+3*FILTER_SIZE/2) % FILTER_SIZE]

    if (_timestamps[FILTER_SIZE-1] == _timestamps[FILTER_SIZE-2]) {
        // we haven't filled the buffer yet - assume zero derivative
        return 0;
    }

    // N in the paper is FILTER_SIZE
    switch (FILTER_SIZE) {
    case 5:
        result = 2*2*(f(1) - f(-1)) / (x(1) - x(-1))
               + 4*1*(f(2) - f(-2)) / (x(2) - x(-2));
        result /= 8;
        break;
    case 7:
        result = 2*5*(f(1) - f(-1)) / (x(1) - x(-1))
               + 4*4*(f(2) - f(-2)) / (x(2) - x(-2)) 
               + 6*1*(f(3) - f(-3)) / (x(3) - x(-3));
        result /= 32;
        break;
    case 9:
        result = 2*14*(f(1) - f(-1)) / (x(1) - x(-1))
               + 4*14*(f(2) - f(-2)) / (x(2) - x(-2)) 
               + 6* 6*(f(3) - f(-3)) / (x(3) - x(-3));
               + 8* 1*(f(4) - f(-4)) / (x(4) - x(-4));
        result /= 128;
        break;
    case 11:
        result =  2*42*(f(1) - f(-1)) / (x(1) - x(-1))
               +  4*48*(f(2) - f(-2)) / (x(2) - x(-2)) 
               +  6*27*(f(3) - f(-3)) / (x(3) - x(-3))
               +  8* 8*(f(4) - f(-4)) / (x(4) - x(-4))
               + 10* 1*(f(5) - f(-5)) / (x(5) - x(-5));
        result /= 512;
        break;
    default:
        result = 0;
        break;
    }

    return result;
}

// reset - clear all samples
template <class T, uint8_t FILTER_SIZE>
void DerivativeFilter<T,FILTER_SIZE>::reset(void)
{
	// call parent's apply function to get the sample into the array
	FilterWithBuffer<T,FILTER_SIZE>::reset();
}

// add new instances as needed here
template float DerivativeFilter<float,5>::apply(float sample, uint32_t timestamp);
template void DerivativeFilter<float,5>::reset(void);

template float DerivativeFilter<float,7>::apply(float sample, uint32_t timestamp);
template void DerivativeFilter<float,7>::reset(void);

template float DerivativeFilter<float,9>::apply(float sample, uint32_t timestamp);
template void DerivativeFilter<float,9>::reset(void);


