///|
fn[T] partition(
  a : Slice[T],
  first : Int,
  last : Int,
  pivot_index : Int,
  less : (T, T) -> Bool,
) -> Int {
  a.swap(first, pivot_index) // move it to beginning
  let mut left = first + 1
  let mut right = last
  while left <= right {
    while left <= last && less(a[left], a[first]) {
      left += 1
    }
    while right >= first && less(a[first], a[right]) {
      right -= 1
    }
    if left <= right {
      a.swap(left, right)
      left += 1
      right -= 1
    }
  }
  a.swap(first, right) // swap into right place
  return right
}

///|
fn[T] quicksort_helper(
  a : Slice[T],
  first : Int,
  last : Int,
  less : (T, T) -> Bool,
) -> Unit {
  if first >= last {
    return
  }
  let pivot_index = partition(a, first, last, (last + first) / 2, less)
  quicksort_helper(a, first, pivot_index - 1, less)
  quicksort_helper(a, pivot_index + 1, last, less)
}

///|
fn[T] quicksort(a : Slice[T], less : (T, T) -> Bool) -> Unit {
  quicksort_helper(a, 0, a.length() - 1, less)
}

///|
fn minimum(x : Int, y : Int) -> Int {
  if x > y {
    y
  } else {
    x
  }
}
