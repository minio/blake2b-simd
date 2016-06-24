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

	hGo := New512(false)
	hSSE := New512(true)

	hGo.Write(in)
	sumGo := fmt.Sprintf("%x", hGo.Sum(nil))

	hSSE.Write(in)
	sumSSE := fmt.Sprintf("%x", hSSE.Sum(nil))

	if sumGo != sumSSE {
		t.Errorf("expected %s\ngot      %s", sumGo, sumSSE)
	}
}
