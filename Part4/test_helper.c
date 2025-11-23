// ESE 507 Stony Brook University
// Peter Milder
// You may not redistribute this code.
// This file contains the DPI functions used in conv_tb testbench.


#include <svdpi.h>
#include <stdio.h>
#include <time.h>
#include <stdlib.h>

// Given two matrices, compute the 2d convolution and store the result in outmat.
void calcOutput(svOpenArrayHandle matrixX, svOpenArrayHandle matrixW, svBitVecVal R, svBitVecVal C, svBitVecVal K, svBitVecVal B, svOpenArrayHandle outmat, svBitVecVal OUTW) {


    // Min and max values, used to check that the results don't overflow the number of bits
    long min = -1*(1l<<(OUTW-1));
    long max = (1l<<(OUTW-1))-1;

    int Rout = R-K+1;
    int Cout = C-K+1;

    for (int out_row = 0; out_row < Rout; out_row++) {
        for (int out_col = 0; out_col < Cout; out_col++) {
            
            long int bias = (int)B;

            long int out = bias;
            
            for (int weight_row = 0; weight_row < K; weight_row++) {
                for (int weight_col = 0; weight_col < K; weight_col++) {
        
                    // get the appropriate values            
                    int aVal = *(int*)(svGetArrElemPtr1(matrixX, (out_row+weight_row)*C + (out_col+weight_col)));
                    int bVal = *(int*)(svGetArrElemPtr1(matrixW, weight_row*K + weight_col));
                
                    // Compute the multiply and accumulate.
                    // Note: we need to cast these to long ints so that "out" doesn't
                    // overflow on this line.
                    long prod = (long)aVal * (long)bVal;
                    long old_accum = out;
                    out += prod;

                    // Check for overflow.
                    //    - special case if output takes up the full 64 bits available in long 
                    if (OUTW == 64) {
                        if ((old_accum > 0) && (prod > 0) && (out < 0)) {
                            printf("ERROR: Overflow. Computed %ld * %ld + %ld. Expected %ld. Got %ld\n", (long)aVal, (long)bVal, old_accum, out); 
                            return;
                        }
                        else if ((old_accum < 0) && (prod < 0) && (out > 0)) {
                            printf("ERROR: Overflow. Computed %ld * %ld + %ld. Expected %ld. Got %ld\n", (long)aVal, (long)bVal, old_accum, out); 
                            return;
                        }
                    }
                    else {   // if OUTW < 64, we can just check min and max
                        if (out < min) {
                            printf("ERROR: Overflow. Computed %ld * %ld + %ld. Expected %ld. Got %ld\n", (long)aVal, (long)bVal, old_accum, out); 
                            return;
                        }
                        else if (out > max) {
                            printf("ERROR: Overflow. Computed %ld * %ld + %ld. Expected %ld. Got %ld\n", (long)aVal, (long)bVal, old_accum, out); 
                            return;          
                        }              
                    }


                }
            }
            // Save the matrix output value
            *(long int*)(svGetArrElemPtr1(outmat, out_row * Cout + out_col)) = out;
            
        }
    }
}
