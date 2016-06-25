//+build !noasm !appengine

//
// Copyright 2016 Frank Wessels <fwessels@xs4all.nl>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

//
// Based on SSE implementation from https://github.com/BLAKE2/BLAKE2/blob/master/sse/blake2b.c
//
// Use github.com/fwessels/asm2plan9s on this file to assemble instructions to their Plan9 equivalent
//
// Assembly code below essentially follows the ROUND macro (see blake2b-round.h) which is defined as:
//   #define ROUND(r) \
//     LOAD_MSG_ ##r ##_1(b0, b1); \
//     G1(row1l,row2l,row3l,row4l,row1h,row2h,row3h,row4h,b0,b1); \
//     LOAD_MSG_ ##r ##_2(b0, b1); \
//     G2(row1l,row2l,row3l,row4l,row1h,row2h,row3h,row4h,b0,b1); \
//     DIAGONALIZE(row1l,row2l,row3l,row4l,row1h,row2h,row3h,row4h); \
//     LOAD_MSG_ ##r ##_3(b0, b1); \
//     G1(row1l,row2l,row3l,row4l,row1h,row2h,row3h,row4h,b0,b1); \
//     LOAD_MSG_ ##r ##_4(b0, b1); \
//     G2(row1l,row2l,row3l,row4l,row1h,row2h,row3h,row4h,b0,b1); \
//     UNDIAGONALIZE(row1l,row2l,row3l,row4l,row1h,row2h,row3h,row4h);
//
// as well as the go equivalent in https://github.com/dchest/blake2b/blob/master/block.go
//
// As in the macro, G1/G2 in the 1st and 2nd half are identical (so literal copy of assembly)
//
// Rounds are also the same, except for the loading of the message (and rounds 1 & 11 and
// rounds 2 & 12 are identical)
//


// func compressSSE(compressSSE(p []uint8, in, iv, t, f, shffle, out []uint64)
TEXT ·compressSSE(SB), 7, $0

    // REGISTER USE
    //  X0 -  X7: v0 - v15
    //  X8 - X11: m[0] - m[7]
    //       X12: shuffle value
    // X13 - X15: temp registers

    // Load digest
    MOVQ   in+24(FP),  SI     // SI: &in
    MOVOU   0(SI), X0         // X0 = in[0]+in[1]      /* row1l = LOAD( &S->h[0] ); */
    MOVOU  16(SI), X1         // X1 = in[2]+in[3]      /* row1h = LOAD( &S->h[2] ); */
    MOVOU  32(SI), X2         // X2 = in[4]+in[5]      /* row2l = LOAD( &S->h[4] ); */
    MOVOU  48(SI), X3         // X3 = in[6]+in[7]      /* row2h = LOAD( &S->h[6] ); */

    // Load initialization vector
    MOVQ iv+48(FP), DX        // DX: &iv
    MOVOU   0(DX), X4         // X4 = iv[0]+iv[1]      /* row3l = LOAD( &blake2b_IV[0] ); */
    MOVOU  16(DX), X5         // X5 = iv[2]+iv[3]      /* row3h = LOAD( &blake2b_IV[2] ); */
    MOVQ t+72(FP), SI         // SI: &t
    MOVOU  32(DX), X6         // X6 = iv[4]+iv[5]      /*                        LOAD( &blake2b_IV[4] )                      */
    MOVOU   0(SI), X7         // X7 = t[0]+t[1]        /*                                                LOAD( &S->t[0] )    */
    PXOR       X7, X6         // X6 = X6 ^ X7          /* row4l = _mm_xor_si128(                       ,                  ); */
    MOVQ t+96(FP), SI         // SI: &f
    MOVOU  48(DX), X7         // X7 = iv[6]+iv[7]      /*                        LOAD( &blake2b_IV[6] )                      */
    MOVOU   0(SI), X8         // X8 = f[0]+f[1]        /*                                                LOAD( &S->f[0] )    */
    PXOR       X8, X7         // X7 = X7 ^ X8          /* row4h = _mm_xor_si128(                       ,                  ); */

    ///////////////////////////////////////////////////////////////////////////
    // R O U N D   1
    ///////////////////////////////////////////////////////////////////////////

    // LOAD_MSG_ ##r ##_1(b0, b1);
    // LOAD_MSG_ ##r ##_2(b0, b1);
    //   (X12 used as additional temp register)
    MOVQ   message+0(FP), DX  // DX: &p (message)
    MOVOU   0(DX), X12        // X12 = m[0]+m[1]
    MOVOU  16(DX), X13        // X13 = m[2]+m[3]
    MOVOU  32(DX), X14        // X14 = m[4]+m[5]
    MOVOU  48(DX), X15        // X15 = m[6]+m[7]
    BYTE $0xc4; BYTE $0x41; BYTE $0x19; BYTE $0x6c; BYTE $0xc5   // VPUNPCKLQDQ  XMM8, XMM12, XMM13  /* m[0], m[2] */
    BYTE $0xc4; BYTE $0x41; BYTE $0x09; BYTE $0x6c; BYTE $0xcf   // VPUNPCKLQDQ  XMM9, XMM14, XMM15  /* m[4], m[6] */
    BYTE $0xc4; BYTE $0x41; BYTE $0x19; BYTE $0x6d; BYTE $0xd5   // VPUNPCKHQDQ XMM10, XMM12, XMM13  /* m[1], m[3] */
    BYTE $0xc4; BYTE $0x41; BYTE $0x09; BYTE $0x6d; BYTE $0xdf   // VPUNPCKHQDQ XMM11, XMM14, XMM15  /* m[5], m[7] */

    // Load shuffle value
    MOVQ   shffle+120(FP), SI // SI: &shuffle
    MOVOU  0(SI), X12         // X12 = 03040506 07000102 0b0c0d0e 0f08090a

    // G1(row1l,row2l,row3l,row4l,row1h,row2h,row3h,row4h,b0,b1);
    BYTE $0xc4; BYTE $0xc1; BYTE $0x79; BYTE $0xd4; BYTE $0xc0   // VPADDQ  XMM0,XMM0,XMM8   /* v0 += m[0], v1 += m[2] */
    BYTE $0xc4; BYTE $0xc1; BYTE $0x71; BYTE $0xd4; BYTE $0xc9   // VPADDQ  XMM1,XMM1,XMM9   /* v2 += m[4], v3 += m[6] */
    BYTE $0xc5; BYTE $0xf9; BYTE $0xd4; BYTE $0xc2               // VPADDQ  XMM0,XMM0,XMM2   /* v0 += v4, v1 += v5 */
    BYTE $0xc5; BYTE $0xf1; BYTE $0xd4; BYTE $0xcb               // VPADDQ  XMM1,XMM1,XMM3   /* v2 += v6, v3 += v7 */
    BYTE $0xc5; BYTE $0xc9; BYTE $0xef; BYTE $0xf0               // VPXOR   XMM6,XMM6,XMM0   /* v12 ^= v0, v13 ^= v1 */
    BYTE $0xc5; BYTE $0xc1; BYTE $0xef; BYTE $0xf9               // VPXOR   XMM7,XMM7,XMM1   /* v14 ^= v2, v15 ^= v3 */
    BYTE $0xc5; BYTE $0xf9; BYTE $0x70; BYTE $0xf6; BYTE $0xb1   // VPSHUFD XMM6,XMM6,0xb1   /* v12 = v12<<(64-32) | v12>>32, v13 = v13<<(64-32) | v13>>32 */
    BYTE $0xc5; BYTE $0xf9; BYTE $0x70; BYTE $0xff; BYTE $0xb1   // VPSHUFD XMM7,XMM7,0xb1   /* v14 = v14<<(64-32) | v14>>32, v15 = v15<<(64-32) | v15>>32 */
    BYTE $0xc5; BYTE $0xd9; BYTE $0xd4; BYTE $0xe6               // VPADDQ  XMM4,XMM4,XMM6   /* v8 += v12, v9 += v13  */
    BYTE $0xc5; BYTE $0xd1; BYTE $0xd4; BYTE $0xef               // VPADDQ  XMM5,XMM5,XMM7   /* v10 += v14, v11 += v15 */
    BYTE $0xc5; BYTE $0xe9; BYTE $0xef; BYTE $0xd4               // VPXOR   XMM2,XMM2,XMM4   /* v4 ^= v8, v5 ^= v9 */
    BYTE $0xc5; BYTE $0xe1; BYTE $0xef; BYTE $0xdd               // VPXOR   XMM3,XMM3,XMM5   /* v6 ^= v10, v7 ^= v11 */
    BYTE $0xc4; BYTE $0xc2; BYTE $0x69; BYTE $0x00; BYTE $0xd4   // VPSHUFB XMM2,XMM2,XMM12  /* v4 = v4<<(64-24) | v4>>24, v5 = v5<<(64-24) | v5>>24 */
    BYTE $0xc4; BYTE $0xc2; BYTE $0x61; BYTE $0x00; BYTE $0xdc   // VPSHUFB XMM3,XMM3,XMM12  /* v6 = v6<<(64-24) | v6>>24, v7 = v7<<(64-24) | v7>>24 */

    // G2(row1l,row2l,row3l,row4l,row1h,row2h,row3h,row4h,b0,b1);
    BYTE $0xc4; BYTE $0xc1; BYTE $0x79; BYTE $0xd4; BYTE $0xc2   // VPADDQ  XMM0,XMM0,XMM10  /* v0 += m[1], v1 += m[3] */
    BYTE $0xc4; BYTE $0xc1; BYTE $0x71; BYTE $0xd4; BYTE $0xcb   // VPADDQ  XMM1,XMM1,XMM11  /* v2 += m[5], v3 += m[7] */
    BYTE $0xc5; BYTE $0xf9; BYTE $0xd4; BYTE $0xc2               // VPADDQ  XMM0,XMM0,XMM2   /* v0 += v4, v1 += v5 */
    BYTE $0xc5; BYTE $0xf1; BYTE $0xd4; BYTE $0xcb               // VPADDQ  XMM1,XMM1,XMM3   /* v2 += v6, v3 += v7 */
    BYTE $0xc5; BYTE $0xc9; BYTE $0xef; BYTE $0xf0               // VPXOR   XMM6,XMM6,XMM0   /* v12 ^= v0, v13 ^= v1 */
    BYTE $0xc5; BYTE $0xc1; BYTE $0xef; BYTE $0xf9               // VPXOR   XMM7,XMM7,XMM1   /* v14 ^= v2, v15 ^= v3 */
    BYTE $0xc5; BYTE $0xfb; BYTE $0x70; BYTE $0xf6; BYTE $0x39   // VPSHUFLW XMM6,XMM6,0x39  /* combined with next ... */
    BYTE $0xc5; BYTE $0xfa; BYTE $0x70; BYTE $0xf6; BYTE $0x39   // VPSHUFHW XMM6,XMM6,0x39  /* v12 = v12<<(64-16) | v12>>16, v13 = v13<<(64-16) | v13>>16 */
    BYTE $0xc5; BYTE $0xfb; BYTE $0x70; BYTE $0xff; BYTE $0x39   // VPSHUFLW XMM7,XMM7,0x39  /* combined with next ... */
    BYTE $0xc5; BYTE $0xfa; BYTE $0x70; BYTE $0xff; BYTE $0x39   // VPSHUFHW XMM7,XMM7,0x39  /* v14 = v14<<(64-16) | v14>>16, v15 = v15<<(64-16) | v15>>16 */
    BYTE $0xc5; BYTE $0xd9; BYTE $0xd4; BYTE $0xe6               // VPADDQ  XMM4,XMM4,XMM6   /* v8 += v12, v9 += v13 */
    BYTE $0xc5; BYTE $0xd1; BYTE $0xd4; BYTE $0xef               // VPADDQ  XMM5,XMM5,XMM7   /* v10 += v14, v11 += v15 */
    BYTE $0xc5; BYTE $0xe9; BYTE $0xef; BYTE $0xd4               // VPXOR   XMM2,XMM2,XMM4   /* v4 ^= v8, v5 ^= v9 */
    BYTE $0xc5; BYTE $0xe1; BYTE $0xef; BYTE $0xdd               // VPXOR   XMM3,XMM3,XMM5   /* v6 ^= v10, v7 ^= v11 */
    BYTE $0xc5; BYTE $0x69; BYTE $0xd4; BYTE $0xfa               // VPADDQ  XMM15,XMM2,XMM2  /* temp reg = reg*2   */
    BYTE $0xc5; BYTE $0xe9; BYTE $0x73; BYTE $0xd2; BYTE $0x3f   // VPSRLQ  XMM2,XMM2,0x3f   /*      reg = reg>>63 */
    BYTE $0xc4; BYTE $0xc1; BYTE $0x69; BYTE $0xef; BYTE $0xd7   // VPXOR   XMM2,XMM2,XMM15  /* ORed together: v4 = v4<<(64-63) | v4>>63, v5 = v5<<(64-63) | v5>>63 */
    BYTE $0xc5; BYTE $0x61; BYTE $0xd4; BYTE $0xfb               // VPADDQ XMM15,XMM3,XMM3   /* temp reg = reg*2   */
    BYTE $0xc5; BYTE $0xe1; BYTE $0x73; BYTE $0xd3; BYTE $0x3f   // VPSRLQ XMM3,XMM3,0x3f    /*      reg = reg>>63 */
    BYTE $0xc4; BYTE $0xc1; BYTE $0x61; BYTE $0xef; BYTE $0xdf   // VPXOR  XMM3,XMM3,XMM15   /* ORed together: v6 = v6<<(64-63) | v6>>63, v7 = v7<<(64-63) | v7>>63 */

    // DIAGONALIZE(row1l,row2l,row3l,row4l,row1h,row2h,row3h,row4h);
    MOVOU  X6, X13                                                                                   /*  t0 = row4l;\                                                           */
    MOVOU  X2, X14                                                                                   /*  t1 = row2l;\                                                           */
    MOVOU  X4, X6                                                                                    /*  row4l = row3l;\                                                        */
    MOVOU  X5, X4                                                                                    /*  row3l = row3h;\                                                        */
    MOVOU  X6, X5                                                                                    /*  row3h = row4l;\                                                        */
    BYTE $0xc4; BYTE $0x41; BYTE $0x11; BYTE $0x6c; BYTE $0xfd   // VPUNPCKLQDQ XMM15, XMM13, XMM13  /*                                    _mm_unpacklo_epi64(t0, t0)           */
    BYTE $0xc4; BYTE $0xc1; BYTE $0x41; BYTE $0x6d; BYTE $0xf7   // VPUNPCKHQDQ  XMM6,  XMM7, XMM15  /*  row4l = _mm_unpackhi_epi64(row4h,                           ); \       */
    BYTE $0xc5; BYTE $0x41; BYTE $0x6c; BYTE $0xff               // VPUNPCKLQDQ XMM15,  XMM7,  XMM7  /*                                 _mm_unpacklo_epi64(row4h, row4h)        */
    BYTE $0xc4; BYTE $0xc1; BYTE $0x11; BYTE $0x6d; BYTE $0xff   // VPUNPCKHQDQ  XMM7, XMM13, XMM15  /*  row4h = _mm_unpackhi_epi64(t0,                                 ); \    */
    BYTE $0xc5; BYTE $0x61; BYTE $0x6c; BYTE $0xfb               // VPUNPCKLQDQ XMM15,  XMM3,  XMM3  /*                                    _mm_unpacklo_epi64(row2h, row2h)     */
    BYTE $0xc4; BYTE $0xc1; BYTE $0x69; BYTE $0x6d; BYTE $0xd7   // VPUNPCKHQDQ  XMM2,  XMM2, XMM15  /*  row2l = _mm_unpackhi_epi64(row2l,                                 ); \ */
    BYTE $0xc4; BYTE $0x41; BYTE $0x09; BYTE $0x6c; BYTE $0xfe   // VPUNPCKLQDQ XMM15, XMM14, XMM14  /*                                    _mm_unpacklo_epi64(t1, t1)           */
    BYTE $0xc4; BYTE $0xc1; BYTE $0x61; BYTE $0x6d; BYTE $0xdf   // VPUNPCKHQDQ  XMM3,  XMM3, XMM15  /*  row2h = _mm_unpackhi_epi64(row2h,                           )          */

    // LOAD_MSG_ ##r ##_3(b0, b1);
    // LOAD_MSG_ ##r ##_4(b0, b1);
    //   (X12 used as additional temp register)
    MOVQ   message+0(FP), DX  // DX: &p (message)
    MOVOU  64(DX), X12        // X12 =  m[8]+ m[9]
    MOVOU  80(DX), X13        // X13 = m[10]+m[11]
    MOVOU  96(DX), X14        // X14 = m[12]+m[13]
    MOVOU 112(DX), X15        // X15 = m[14]+m[15]
    BYTE $0xc4; BYTE $0x41; BYTE $0x19; BYTE $0x6c; BYTE $0xc5   // VPUNPCKLQDQ  XMM8, XMM12, XMM13  /*  m[8],m[10] */
    BYTE $0xc4; BYTE $0x41; BYTE $0x09; BYTE $0x6c; BYTE $0xcf   // VPUNPCKLQDQ  XMM9, XMM14, XMM15  /* m[12],m[14] */

    // Load shuffle value
    MOVQ   shffle+120(FP), SI // SI: &shuffle
    MOVOU  0(SI), X12         // X12 = 03040506 07000102 0b0c0d0e 0f08090a

    // G1(row1l,row2l,row3l,row4l,row1h,row2h,row3h,row4h,b0,b1);
    BYTE $0xc4; BYTE $0xc1; BYTE $0x79; BYTE $0xd4; BYTE $0xc0   // VPADDQ  XMM0,XMM0,XMM8   /* v0 +=  m[8], v1 += m[10] */
    BYTE $0xc4; BYTE $0xc1; BYTE $0x71; BYTE $0xd4; BYTE $0xc9   // VPADDQ  XMM1,XMM1,XMM9   /* v2 += m[12], v3 += m[14] */
    BYTE $0xc5; BYTE $0xf9; BYTE $0xd4; BYTE $0xc2               // VPADDQ  XMM0,XMM0,XMM2   /* v0 += v4, v1 += v5 */
    BYTE $0xc5; BYTE $0xf1; BYTE $0xd4; BYTE $0xcb               // VPADDQ  XMM1,XMM1,XMM3   /* v2 += v6, v3 += v7 */
    BYTE $0xc5; BYTE $0xc9; BYTE $0xef; BYTE $0xf0               // VPXOR   XMM6,XMM6,XMM0   /* v12 ^= v0, v13 ^= v1 */
    BYTE $0xc5; BYTE $0xc1; BYTE $0xef; BYTE $0xf9               // VPXOR   XMM7,XMM7,XMM1   /* v14 ^= v2, v15 ^= v3 */
    BYTE $0xc5; BYTE $0xf9; BYTE $0x70; BYTE $0xf6; BYTE $0xb1   // VPSHUFD XMM6,XMM6,0xb1   /* v12 = v12<<(64-32) | v12>>32, v13 = v13<<(64-32) | v13>>32 */
    BYTE $0xc5; BYTE $0xf9; BYTE $0x70; BYTE $0xff; BYTE $0xb1   // VPSHUFD XMM7,XMM7,0xb1   /* v14 = v14<<(64-32) | v14>>32, v15 = v15<<(64-32) | v15>>32 */
    BYTE $0xc5; BYTE $0xd9; BYTE $0xd4; BYTE $0xe6               // VPADDQ  XMM4,XMM4,XMM6   /* v8 += v12, v9 += v13  */
    BYTE $0xc5; BYTE $0xd1; BYTE $0xd4; BYTE $0xef               // VPADDQ  XMM5,XMM5,XMM7   /* v10 += v14, v11 += v15 */
    BYTE $0xc5; BYTE $0xe9; BYTE $0xef; BYTE $0xd4               // VPXOR   XMM2,XMM2,XMM4   /* v4 ^= v8, v5 ^= v9 */
    BYTE $0xc5; BYTE $0xe1; BYTE $0xef; BYTE $0xdd               // VPXOR   XMM3,XMM3,XMM5   /* v6 ^= v10, v7 ^= v11 */
    BYTE $0xc4; BYTE $0xc2; BYTE $0x69; BYTE $0x00; BYTE $0xd4   // VPSHUFB XMM2,XMM2,XMM12  /* v4 = v4<<(64-24) | v4>>24, v5 = v5<<(64-24) | v5>>24 */
    BYTE $0xc4; BYTE $0xc2; BYTE $0x61; BYTE $0x00; BYTE $0xdc   // VPSHUFB XMM3,XMM3,XMM12  /* v6 = v6<<(64-24) | v6>>24, v7 = v7<<(64-24) | v7>>24 */

    // UNDIAGONALIZE(row1l,row2l,row3l,row4l,row1h,row2h,row3h,row4h);
    MOVOU  X4, X13                                                                                   /* t0 = row3l;\                                                            */
    MOVOU  X5, X4                                                                                    /* row3l = row3h;\                                                         */
    MOVOU X13, X5                                                                                    /* row3h = t0;\                                                            */
    MOVOU  X2, X13                                                                                   /* t0 = row2l;\                                                            */
    MOVOU  X6, X14                                                                                   /* t1 = row4l;\                                                            */
    BYTE $0xc5; BYTE $0x69; BYTE $0x6c; BYTE $0xfa               // VPUNPCKLQDQ XMM15,  XMM2,  XMM2  /*                                    _mm_unpacklo_epi64(row2l, row2l)     */
    BYTE $0xc4; BYTE $0xc1; BYTE $0x61; BYTE $0x6d; BYTE $0xd7   // VPUNPCKHQDQ  XMM2,  XMM3, XMM15  /*  row2l = _mm_unpackhi_epi64(row2h,                                 ); \ */
    BYTE $0xc5; BYTE $0x61; BYTE $0x6c; BYTE $0xfb               // VPUNPCKLQDQ XMM15,  XMM3,  XMM3  /*                                 _mm_unpacklo_epi64(row2h, row2h)        */
    BYTE $0xc4; BYTE $0xc1; BYTE $0x11; BYTE $0x6d; BYTE $0xdf   // VPUNPCKHQDQ  XMM3, XMM13, XMM15  /*  row2h = _mm_unpackhi_epi64(t0,                                 ); \    */
    BYTE $0xc5; BYTE $0x41; BYTE $0x6c; BYTE $0xff               // VPUNPCKLQDQ XMM15,  XMM7,  XMM7  /*                                    _mm_unpacklo_epi64(row4h, row4h)     */
    BYTE $0xc4; BYTE $0xc1; BYTE $0x49; BYTE $0x6d; BYTE $0xf7   // VPUNPCKHQDQ  XMM6,  XMM6, XMM15  /*  row4l = _mm_unpackhi_epi64(row4l,                                 ); \ */
    BYTE $0xc4; BYTE $0x41; BYTE $0x09; BYTE $0x6c; BYTE $0xfe   // VPUNPCKLQDQ XMM15, XMM14, XMM14  /*                                    _mm_unpacklo_epi64(t1, t1)           */
    BYTE $0xc4; BYTE $0xc1; BYTE $0x41; BYTE $0x6d; BYTE $0xff   // VPUNPCKHQDQ  XMM7,  XMM7, XMM15  /*  row4h = _mm_unpackhi_epi64(row4h,                           )          */

    // Reload digest
    MOVQ   in+24(FP),  SI     // SI: &in
    MOVOU   0(SI), X12        // X12 = in[0]+in[1]      /* row1l = LOAD( &S->h[0] ); */
    MOVOU  16(SI), X13        // X13 = in[2]+in[3]      /* row1h = LOAD( &S->h[2] ); */
    MOVOU  32(SI), X14        // X14 = in[4]+in[5]      /* row2l = LOAD( &S->h[4] ); */
    MOVOU  48(SI), X15        // X15 = in[6]+in[7]      /* row2h = LOAD( &S->h[6] ); */

    // Final computations and prepare for storing
    PXOR   X4,  X0           // X0 = X0 ^ X4          /* row1l = _mm_xor_si128( row3l, row1l ); */
    PXOR   X5,  X1           // X1 = X1 ^ X5          /* row1h = _mm_xor_si128( row3h, row1h ); */
    PXOR   X12, X0           // X0 = X0 ^ X12         /*  STORE( &S->h[0], _mm_xor_si128( LOAD( &S->h[0] ), row1l ) ); */
    PXOR   X13, X1           // X1 = X1 ^ X13         /*  STORE( &S->h[2], _mm_xor_si128( LOAD( &S->h[2] ), row1h ) ); */
    PXOR   X6,  X2           // X2 = X2 ^ X6          /*  row2l = _mm_xor_si128( row4l, row2l ); */
    PXOR   X7,  X3           // X3 = X3 ^ X7          /*  row2h = _mm_xor_si128( row4h, row2h ); */
    PXOR   X14, X2           // X2 = X2 ^ X14         /*  STORE( &S->h[4], _mm_xor_si128( LOAD( &S->h[4] ), row2l ) ); */
    PXOR   X15, X3           // X3 = X3 ^ X15         /*  STORE( &S->h[6], _mm_xor_si128( LOAD( &S->h[6] ), row2h ) ); */

    // Store digest
    MOVQ  out+144(FP), DX     // DX: &out
    MOVOU  X0,  0(DX)         // out[0]+out[1] = X0
    MOVOU  X1, 16(DX)         // out[2]+out[3] = X1
    MOVOU  X2, 32(DX)         // out[4]+out[5] = X2
    MOVOU  X3, 48(DX)         // out[6]+out[7] = X3

    RET
