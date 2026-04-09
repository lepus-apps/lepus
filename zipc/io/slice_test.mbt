// Copyright 2024 International Digital Economy Academy
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

///|
test "array_as_view" {
  inspect(Slice::new([1, 2, 3]).length(), content="3")
}

///|
test "slice capacity" {
  inspect(Slice::new([1, 2, 3]).cap(), content="3")
}

///|
test "op_get" {
  inspect(Slice::new([1, 2, 3])[1], content="2")
  inspect(Slice::new([1, 2, 3])[2], content="3")
}

///|
test "op_set" {
  let v = Slice::new([1, 2, 3])
  inspect(v[1], content="2")
  v[1] = 4
  inspect(v[1], content="4")
}

///|
test "swap" {
  let v = Slice::new([1, 2, 3])
  inspect(v[1], content="2")
  v.swap(1, 2)
  inspect(v[1], content="3")
}

///|
test "panic array_as_view_start_index_error 1" {
  Slice::new([1, 2, 3])[-1:0] |> ignore
}

///|
test "panic array_as_view_start_index_error 2" {
  Slice::new([1, 2, 3])[-1:0] |> ignore
}

///|
test "panic array_as_view_end_index_error 1" {
  Slice::new([1, 2, 3])[:-1] |> ignore
}

///|
test "panic array_as_view_end_index_error 2" {
  Slice::new([1, 2, 3])[:-1] |> ignore
}

///|
test "panic array_as_view_length_index_error" {
  Slice::new([1, 2, 3])[:4] |> ignore
}

///|
test "panic view_as_view_start_index_error 1" {
  Slice::new([1, 2, 3])[-1:0] |> ignore
}

///|
test "panic view_as_view_start_index_error 2" {
  Slice::new([1, 2, 3])[-1:0] |> ignore
}

///|
test "panic view_as_view_end_index_error 1" {
  Slice::new([1, 2, 3])[:-1] |> ignore
}

///|
test "panic view_as_view_end_index_error 2" {
  Slice::new([1, 2, 3])[:-1] |> ignore
}

///|
test "panic view_as_view_length_index_error" {
  Slice::new([1, 2, 3])[:4] |> ignore
}

///|
test "panic array_as_view_get_index_error" {
  Slice::new([1, 2, 3])[5] |> ignore
}

///|
test "panic array_as_view_set_index_error" {
  Slice::new([1, 2, 3])[5] = 0
}

///|
test "panic array_as_view_swap_index_error" {
  Slice::new([1, 2, 3]).swap(1, 9)
}

///|
test "iter" {
  let array = Slice::new([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
  inspect(array.iter().to_array(), content="[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]")
  inspect(array[5:].iter().to_array(), content="[5, 6, 7, 8, 9, 10]")
  inspect(array[5:9].iter().to_array(), content="[5, 6, 7, 8]")
}

// test "to_string" {
//   let arr = Slice::new([0, 1, 2, 3, 4])
//   inspect!(arr[1:3].to_string(), content="[1, 2]")
//   inspect!("\{arr[1:3]}!", content="[1, 2]!")
// }

///|
test "slice_fold" {
  let arr = Slice::new([1, 2, 3])
  let sum = arr.fold(fn(acc, x) { acc + x }, init=0)
  inspect(sum, content="6")
}

///|
test "slice_rev_fold" {
  let arr = Slice::new([1, 2, 3])
  let sum = arr.rev_fold(fn(acc, x) { acc + x }, init=0)
  inspect(sum, content="6")
}

///|
test "slice_foldi" {
  let arr = Slice::new([1, 2, 3])
  let sum = arr.foldi(fn(i, acc, x) { acc + i + x }, init=0)
  inspect(sum, content="9")
}

///|
test "slice_rev_foldi" {
  let arr = Slice::new([1, 2, 3])
  let sum = arr.rev_foldi(fn(i, acc, x) { acc + i + x }, init=0)
  inspect(sum, content="9")
}

///|
test "slice grows within larger array" {
  let arr = Slice::new([1, 2, 3, 4, 5, 6])[2:4]
  inspect(arr, content="[3, 4]")
  inspect(arr.length(), content="2")
  inspect(arr.cap(), content="4")
  let arr = arr[:3]
  inspect(arr, content="[3, 4, 5]")
  inspect(arr.length(), content="3")
  inspect(arr.cap(), content="4")
  let arr = arr[:4]
  inspect(arr, content="[3, 4, 5, 6]")
  inspect(arr.length(), content="4")
  inspect(arr.cap(), content="4")
  let arr = arr[-1:4]
  inspect(arr, content="[2, 3, 4, 5, 6]")
  inspect(arr.length(), content="5")
  inspect(arr.cap(), content="5")
  let arr = arr[-1:5]
  inspect(arr, content="[1, 2, 3, 4, 5, 6]")
  inspect(arr.length(), content="6")
  inspect(arr.cap(), content="6")
}

///|
test "slice append grows beyond capacity" {
  let arr = Slice::new([1, 2, 3, 4, 5, 6])[2:4]
  inspect(arr, content="[3, 4]")
  inspect(arr.length(), content="2")
  inspect(arr.cap(), content="4")
  let arr2 = arr.append(Slice::new([7, 8, 9, 10]))
  inspect(arr2, content="[3, 4, 7, 8, 9, 10]")
  inspect(arr2.length(), content="6")
  inspect(arr2.cap(), content="6")
  // ensure that the original slice was not modified (so that a copy happened)
  inspect(arr, content="[3, 4]")
  inspect(arr.length(), content="2")
  inspect(arr.cap(), content="4")
  // Now append just two elements so that a copy does _not_ need to happen:
  let arr3 = arr.append(Slice::new([11, 12]))
  inspect(arr3, content="[3, 4, 11, 12]")
  inspect(arr3.length(), content="4")
  inspect(arr3.cap(), content="4")
  // Note that because of the immutability of the Slice struct, a new slice
  // was returned anyway, so `arr` is still unmodified (although the underlying
  // Array is now shared). Users of `append` should never rely on this behavior,
  // however, and should not reuse a slice that has been appended to.
  inspect(arr, content="[3, 4]")
  inspect(arr.length(), content="2")
  inspect(arr.cap(), content="4")
}
