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

import (
	"fmt"
	"testing"
)

func TestCompress(t *testing.T) {

	in := make([]byte, 128)
	for i := range in {
		in[i] = byte(i)
	}
	good := "2319e3789c47e2daa5fe807f61bec2a1a6537fa03f19ff32e87eecbfd64b7e0e8ccff439ac333b040f19b0c4ddd11a61e24ac1fe0f10a039806c5dcc0da3d115"
	if good != fmt.Sprintf("%x", Sum512([]byte(in))) {
		digest := fmt.Sprintf("%x", Sum512([]byte(in)))
		t.Errorf("Sum512(): \nexpected %s\ngot      %s", good, digest)
	}
}
