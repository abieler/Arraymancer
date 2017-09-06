# Copyright 2017 Mamy André-Ratsimbazafy
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

proc check_nested_elements(shape: seq[int], len: int) {.noSideEffect.}=
  ## Compare the detected shape from flatten with the real length of the data
  ## Input:
  ##   -- A shape (sequence of int)
  ##   -- A length (int)
  if (shape.product != len):
    raise newException(IndexError, "Each nested sequence at the same level must have the same number of elements")


template tensor[T](out_shape: openarray[int], t: Tensor[T]): untyped =
  t.shape = @out_shape
  t.strides = shape_to_strides(t.shape)
  t.offset = 0

proc newTensor*(shape: openarray[int], T: typedesc, backend: static[Backend]): auto {.noSideEffect.} =
  ## Creates a new Tensor
  ## Input:
  ##      - Shape of the Tensor
  ##      - Type of its elements
  ##      - Backend
  ## Result:
  ##      - A Tensor of the proper shape initialized with
  ##        the default type value (0 for numeric types)

  # TODO: Cpu backend as default, pending: https://github.com/nim-lang/Nim/issues/6339

  when backend == Cpu:
    var t: Tensor[T]
    tensor(shape, t)
    t.data = newSeq[T](t.shape.product)
    return t

template toTensorCpu(s: typed): untyped =
  let shape = s.shape
  let data = toSeq(flatIter(s))

  when compileOption("boundChecks"): check_nested_elements(shape, data.len)

  var t: Tensor[type(data[0])]
  tensor(shape, t)
  t.data = data
  return t

proc toTensor*(s:openarray, backend: static[Backend]): auto {.noSideEffect.} =
  ## Convert an openarray to a Tensor
  # TODO: have Backend.Cpu as default. pending https://github.com/nim-lang/Nim/issues/6339
  when backend == Cpu:
    toTensorCpu(s)

proc toTensor*(s:string, backend: static[Backend]): auto {.noSideEffect.} =
  ## Convert an openarray to a Tensor
  ##
  ## Handle string specifically (otherwise they are interpreted as openarray[char])
  when backend == Cpu:
    toTensorCpu(s)

# TODO add tests for zeros, ones and randomTensor
proc zeros*[T: SomeNumber](shape: openarray[int], typ: typedesc[T], backend: static[Backend]): auto {.noSideEffect, inline.} =
  ## Creates a new Tensor filled with 0
  ## Input:
  ##      - Shape of the Tensor
  ##      - Type of its elements
  ##      - Backend
  ## Result:
  ##      - A zero-ed Tensor of the input shape
  return newTensor(shape, typ, backend)

proc zeros_like*[T: SomeNumber](t: AnyTensor[T]): auto {.noSideEffect, inline.} =
  ## Creates a new Tensor filled with 0 with the same shape as the input
  ## Input:
  ##      - Shape of the Tensor
  ##      - Type of its elements
  ##      - Backend
  ## Result:
  ##      - A zero-ed Tensor of the same shape
  when t is Tensor:
    return zeros(t.shape, T, Cpu)
  elif t is CudaTensor:
    return zeros(t.shape, T, Cuda)

proc ones*[T: SomeNumber](shape: openarray[int], typ: typedesc[T], backend: static[Backend]): auto {.noSideEffect.} =
  ## Creates a new Tensor filled with 1
  ## Input:
  ##      - Shape of the Tensor
  ##      - Type of its elements
  ##      - Backend
  ## Result:
  ##      - A one-ed Tensor of the same shape
  when backend == Cpu:
    var t: Tensor[T]
    tensor(shape, t)
    t.data = newSeqWith(t.shape.product, 1.T)

proc ones_like*[T: SomeNumber](t: AnyTensor[T]): auto {.noSideEffect, inline.} =
  ## Creates a new Tensor filled with 0 with the same shape as the input
  ## and filled with 1
  ## Input:
  ##      - Tensor
  ## Result:
  ##      - A one-ed Tensor of the same shape
  when t is Tensor:
    return ones(t.shape, T, Cpu)
  elif t is CudaTensor:
    return ones(t.shape, T, Cuda)

template randomTensorCpu[T](t: Tensor[T], shape: openarray[int], max_or_range: typed): untyped =
  tensor(shape, t)
  t.data = newSeqWith(t.shape.product, random(max_or_range))

proc randomTensor*(shape: openarray[int], max: float, backend: static[Backend]): auto =
  ## Creates a new float Tensor filled with values between 0 and max
  ## Random seed can be set by importing ``random`` and ``randomize(seed)``
  ## Input:
  ##      - a shape
  ##      - the max value possible (float)
  ##      - a tensor backend
  ## Result:
  ##      - A tensor of the input shape filled with random value between 0 and max input value
  when backend == Cpu:
    var t: Tensor[float]
    randomTensorCpu(t, shape, max)
    return t

proc randomTensor*(shape: openarray[int], max: int, backend: static[Backend]): auto =
  ## Creates a new int Tensor filled with values between 0 and max-1
  ## Random seed can be set by importing ``random`` and ``randomize(seed)``
  ## Input:
  ##      - a shape
  ##      - the max value possible (integer, exclusive)
  ##      - a tensor backend
  ## Result:
  ##      - A tensor of the input shape filled with random value between 0 and max input value (excluded)
  when backend == Cpu:
    var t: Tensor[int]
    randomTensorCpu(t, shape, max)
    return t

proc randomTensor*[T](shape: openarray[int], slice: Slice[T], B: static[Backend]): auto =
  ## Creates a new int Tensor filled with values in the Slice range.
  ## Random seed can be set by importing ``random`` and ``randomize(seed)``
  ## Input:
  ##      - a shape
  ##      - a range/slice
  ##      - a tensor backend
  ## Result:
  ##      - A tensor of the input shape filled with random value in the slice range
  when backend == Cpu:
    var t: Tensor[T]
    randomTensorCpu(t, shape, slice)
    return t