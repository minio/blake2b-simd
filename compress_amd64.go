//+build !noasm
//+build !appengine

/*
 * Copyright 2016 Frank Wessels <fwessels@xs4all.nl>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package blake2b

//go:noescape
func compressSSE(p []uint8, in, iv, t, f, out []uint64)

func compress(d *digest, p []uint8) {
	h0, h1, h2, h3, h4, h5, h6, h7 := d.h[0], d.h[1], d.h[2], d.h[3], d.h[4], d.h[5], d.h[6], d.h[7]

	in := make([]uint64, 8, 8)
	out := make([]uint64, 8, 8)

	for len(p) >= BlockSize {
		// Increment counter.
		d.t[0] += BlockSize
		if d.t[0] < BlockSize {
			d.t[1]++
		}

		in[0], in[1], in[2], in[3], in[4], in[5], in[6], in[7] = h0, h1, h2, h3, h4, h5, h6, h7

		compressSSE(p, in, iv[:], d.t[:], d.f[:], out)

		h0, h1, h2, h3, h4, h5, h6, h7 = out[0], out[1], out[2], out[3], out[4], out[5], out[6], out[7]

		p = p[BlockSize:]
	}

	d.h[0], d.h[1], d.h[2], d.h[3], d.h[4], d.h[5], d.h[6], d.h[7] = h0, h1, h2, h3, h4, h5, h6, h7
}
