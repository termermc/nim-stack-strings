##[
The `stack_strings` module provides a string implementation that works with 100% stack memory.

This module is primarily meant for programs that want to avoid any and all heap allocation, such as code for embedded targets.
If you use `--mm:arc` and `-d:useMalloc` in tandem with this module, your program will be able to do string operations without allocating any memory at runtime.

# The `StackString` Type

The [StackString] type is an object with a fixed size buffer and an integer to store its current length.
It works very similarly to `string`, but its internal buffer cannot be resized, and must be known at compile time.

Note that like Nim and C strings, [StackString] is nil-terminated, so its internal buffer size will be your specified size + 1.

To create an empty [StackString], use the [stackStringOfCap] proc:

]##
runnableExamples:
    var emptyStr = stackStringOfCap(10)
##[

Note the lack of `new` in the name; there is no runtime allocation going on here.

Under the hood, a `StackString[10]` object was created and returned, and its length was set to `0`.
Since buffers are fixed-size and known at compile time, the capacity of the [StackString] is encoded as part of its type.

You can add to a [StackString], assuming it has capacity:
]##
runnableExamples:
    var name = "John"

    var greeting = stackStringOfCap(32)

    greeting.add("Hello, ")
    greeting.add(name)
    greeting.add('!')
##[

See: [add], [tryAdd], [addTruncate] and [unsafeAdd].

Since using [stackStringOfCap] for creating [StackString] constants is both annoying and inefficient, there exists a more convenient way of creating [StackString] objects.

If you have a static string (such as a string literal), you can use the [ss] proc to create a [StackString] automatically:

]##
runnableExamples:
    let greeting = ss"Hello, world!"

    doAssert greeting is StackString[13]
##[

The resulting [StackString]'s capacity will be the length of the static string provided.
In the case of the code above, the type of `greeting` is `StackString[13]`.

If you have a runtime string (or anything else that's covered by the [IndexableChars] union type) that you want to convert to a [StackString], you can use [toStackString]:
]##
runnableExamples:
    let someNimString = "The size of this will not be known"

    # A capacity of 64 is more than enough
    var someSs1 = someNimString.toStackString(64)
    doAssert someSs1 == ss"The size of this will not be known"
##[

See also: [unsafeToStackString], [tryToStackString], [toStackStringTruncate].

# Manipulating `StackString` objects

In Nim, `string` is mutable if it is stored in a `var`, as opposed to a `let`. The same applies to [StackString].

You can manipulate a [StackString] by setting individual chars using the same syntax as for `string`:

]##
runnableExamples:
    var str = ss"hello"

    str[0] = 'y'

    doAssert str == "yello"
##[

You can also set length by calling [setLen]. The difference between [StackString]'s [setLen] versus `string`'s `setLen` is that [StackString]'s cannot resize the internal buffer.
For this reason, resizing a [StackString] beyond its capacity will result in an error.

Similarly, you can use [add] to append to a [StackString], but you cannot append beyond its capacity, otherwise you will encounter a runtime error.

# Preventing Accidental Allocations

Due to the implicit nature of Nim, allocating memory is extremely easy to do on accident.

This module provides a few optional compiler flags you can enable to make allocation from this the module's procs impossible:

 - `-d:`[fatalOnStackStringDollar]
 - `-d:`[warnOnStackStringDollar]
 - `-d:`[stackStringsPreventAllocation]

Read the documentation for any of these flags to learn more about them.

The easiest way to open yourself up to surprise allocation (and arguably surprise behavior in general) is triggering exceptions.
Nim exceptions are always heap-allocated, so to avoid the possibility of runtime memory allocation, you must eliminate exceptions.

Most access and mutation procs have try- and unsafe- prefixed variants which do not raise any exceptions.
For example, [`[]`](#[]%2CStackString%2C) has [tryGet]/[unsafeGet], [`[]=`](#[]%3D%2CStackString%2C%2Cchar) has [trySet]/[unsafeSet] and [setLen] has [trySetLen]/[unsafeSetLen].

The flags discussed previously can help you enforce use of these non-exception variants.

# Using `StackString` as an `openArray`

If you want to use a [StackString] object as `openArray[char]`, you can use the [toOpenArray] template.
This template does not copy any memory.

# Using `StackString` with the `unicode` Module

The stdlib's `unicode` module supports `openArray[char]`, so all you have to do to use [StackString] with it is to use the [toOpenArray] template first.

]##

import std/[options]

const warnOnStackStringDollar* {.booldefine.} = false
    ## When `true`, shows a compiler warning when a [StackString] is converted to a string via the `$` proc

const fatalOnStackStringDollar* {.booldefine.} = false
    ## When `true`, shows a compiler fatal error when a [StackString] is converted to a string via the `$` proc

const stackStringsPreventAllocation* {.booldefine.} = false
    ## When `true`, prevents any heap allocations from occuring in this module by showing compiler errors on operations that can allocate memory at runtime

type InsufficientCapacityDefect* = object of Defect
    ## Defect raised when attempting to append to or change the length of a StackString that does not have enough capacity to accomodate the new length

    capacity*: Natural
        ## The [StackString]'s capacity
    
    requestedCapacity*: Natural
        ## The capacity required to successfully complete the operation

proc newInsufficientCapacityDefect*(msg: string, capacity: Natural, requestedCapacity: Natural): ref InsufficientCapacityDefect =
    ## Allocates a new [InsufficientCapacityDefect] relating to the specified [StackString]

    result = new InsufficientCapacityDefect
    result.msg = msg
    result.capacity = capacity
    result.requestedCapacity = requestedCapacity

template raiseInsufficientCapacityDefect(msg: string, capacity: Natural, requestedCapacity: Natural): untyped =
    when defined(danger):
        {.fatal: "Nothing should be able to raise `InsufficientCapacityDefect` when `danger` is defined".}

    when stackStringsPreventAllocation:
        {.fatal: "The `newInsufficientCapacityDefect` proc can allocate memory at runtime, see `stackStringsPreventAllocation`".}

    raise newInsufficientCapacityDefect(msg, capacity, requestedCapacity)

type StackString*[Size: static Natural] = object
    ## A stack-allocated string with a fixed capacity

    lenInternal: Natural
        ## The current string length

    data*: array[Size + 1, char]
        ## The underlying string data.
        ## If you just want to iterate over the string's characters, use the [items] iterator.

type IndexableChars* = cstring | string | openArray[char] | StackString
    ## Indexable data types that contain chars

func toString*(this: StackString): string =
    ## Allocates a new string with the content of the provided [StackString].
    ## Note that this will allocate heap memory and copy the [StackString]'s content.
    ## 
    ## This proc won't generate any compiler warnings or errors, unlike [`$`], which has the possibility of doing so.
    ## See documentation for [StackString]'s [`$`] proc for more info.

    when stackStringsPreventAllocation:
        {.fatal: "The `toString` proc can allocate memory at runtime, see `stackStringsPreventAllocation`".}

    result = newStringOfCap(this.len)

    for c in this.items:
        result.add(c)

func `$`*(this: StackString): string {.inline.} =
    ## Converts the [StackString] to a `string`.
    ## Note that this proc allocates a new string and copies the contents of the StackString into the newly created string.
    ## 
    ## See [warnOnStackStringDollar] and [fatalOnStackStringDollar] for information about compiler warnings errors this may cause.
    ## If you want to avoid any warnings or errors specific to this proc, use [toString] instead (which is intentionally more explicit).
    
    when stackStringsPreventAllocation:
        {.fatal: "The `$` proc can allocate memory at runtime, see `stackStringsPreventAllocation`".}

    const errMsg {.used.} = "Conversion of StackString to string with `$` proc. If this was intentional, use `toString` instead."
    when fatalOnStackStringDollar:
        {.fatal: errMsg.}
    when warnOnStackStringDollar:
        {.warn: errMsg.}

    return this.toString()

func ss*(str: static string): static auto =
    ## Creates a [StackString] object from a static string.
    ## The [StackString]'s capacity will be the string's actual length.
    runnableExamples:
        let name = ss"John Doe"

        doAssert name is StackString[8]

    var data: array[str.len + 1, char]

    for i in 0 ..< str.len:
        data[i] = str[i]

    return StackString[str.len](lenInternal: str.len, data: data)

func stackStringOfCap*(capacity: static Natural): static auto =
    ## Creates a [StackString] with the specified capacity.
    ## This proc does not allocate heap memory.
    runnableExamples:
        var str = stackStringOfCap(10)

        doAssert str is StackString[10]
        doAssert str.len == 0
    
    return StackString[capacity](lenInternal: 0, data: array[capacity + 1, char].default)

func len*(this: StackString): Natural {.inline.} =
    ## The current string length
    
    return this.lenInternal

func high*(this: StackString): int {.inline.} =
    ## Returns the highest index of the [StackString], or `-1` if it is empty
    runnableExamples:
        var str1 = "Hello world"
        var str2 = ""

        doAssert str1.high == 10
        doAssert str2.high == -1

    return this.len - 1

func capacity*(this: StackString): Natural {.inline.} =
    ## Returns the capacity of the [StackString]
    runnableExamples:
        var ssLit = ss"Same capacity"

        doAssert ssLit.capacity == 13

        var extraCap = stackStringOfCap(10)
        extraCap.add("Hi")

        doAssert extraCap.capacity == 10
        doAssert extraCap.len == 2

    return this.data.len - 1

iterator items*(this: StackString): char {.inline.} =
    ## Iterates over each char in the [StackString]
    runnableExamples:
        let str = ss"abc"

        var chars = newSeq[char]()

        for c in str.items:
            chars.add(c)

        doAssert chars == @['a', 'b', 'c']

    var i = 0
    let strLen = this.len
    while i < strLen:
        yield this.data[i]
        inc i

iterator mitems*(this: var StackString): var char {.inline.} =
    ## Iterates over each char in the [StackString], returning a mutable reference
    runnableExamples:
        var str = ss"fly in the sky"

        for c in str.mitems:
            if c == 'f':
                c = 's'
            elif c == 'k':
                c = 't'

        doAssert str == "sly in the sty"

    var i = 0
    let strLen = this.len
    while i < strLen:
        yield this.data[i]
        inc i

iterator pairs*(this: StackString): (int, char) {.inline.} =
    ## Iterates over each index-char pairs in the [StackString]
    runnableExamples:
        let str = ss"abc"

        var strPairs = newSeq[(int, char)]()

        for pair in str.pairs:
            strPairs.add(pair)

        doAssert strPairs[0] == (0, 'a')
        doAssert strPairs[^1] == (2, 'c')

    var i = 0
    let strLen = this.len
    while i < strLen:
        yield (i, this.data[i])
        inc i

iterator mpairs*(this: var StackString): (int, var char) {.inline.} =
    ## Iterates over each index-char pairs in the [StackString], returning a mutable reference to the char
    runnableExamples:
        var str = ss"ooo"

        for (i, c) in str.mpairs:
            if i == 0 or i == 2:
                c = 'l'

        doAssert str == "lol"

    var i = 0
    let strLen = this.len
    while i < strLen:
        yield (i, this.data[i])
        inc i

{.boundChecks: off.}
func `[]`*(this: StackString, i: Natural | BackwardsIndex): char {.inline, raises: [IndexDefect].} =
    ## Returns the character at the specified index in the [StackString], or raises `IndexDefect` if the index is invalid
    runnableExamples:
        let str = ss"Hello world"

        doAssert str[^1] == 'd'

    when stackStringsPreventAllocation:
        {.fatal: "The `[]` proc can allocate memory at runtime, see `stackStringsPreventAllocation`".}

    let idx = when i is BackwardsIndex:
        this.len - i.int
    else:
        i

    # Do bounds check manually because the StackString's len field is the actual bound we want to check, not data.len
    when not defined(danger):
        let cond = idx >= this.len or idx < 0
        
        if unlikely(cond):
            if this.len == 0:
                raise newException(IndexDefect, "index out of bounds, the container is empty")
            else:
                let idx = when i is BackwardsIndex:
                    this.len - i.int
                else:
                    i

                raise newException(IndexDefect, "index " & $idx & " not in 0 .. " & $this.high)

    return this.data[idx]
{.boundChecks: on.}

template `[]`*(this: StackString, slice: HSlice): openArray[char] =
    ## Returns an `openArray` for the specified range in the [StackString], or raises `RangeDefect` if the range is invalid.
    ## The returned range is a reference to the original [StackString] `data` memory.
    ## 
    ## If you want to use the `openArray` value as an actual value that can be stored in a variable,
    ## you need to enable the experimental `views` feature.
    runnableExamples:
        {.experimental: "views".}

        let str = ss"Hello world"

        let part = str[0..4]

        doAssert part == ['H', 'e', 'l', 'l', 'o']
        when NimMajor > 1: ## Nim 2.0 no longer requires `unsafeaddr`
            doAssert part[0].addr == addr str.data[0]
        else:
            doAssert part[0].unsafeaddr == unsafeaddr str.data[0]

    when stackStringsPreventAllocation:
        {.fatal: "The `[]` template can allocate memory at runtime, see `stackStringsPreventAllocation`".}

    let a = slice.a
    let b = slice.b

    # Do bounds check manually because the StackString's len field is the actual bound we want to check, not data.len
    when not defined(danger):
        let cond = (
            a > b or
            a >= this.len or a < 0 or
            b >= this.len or b < 0
        )
        
        if unlikely(cond):
            if this.len == 0:
                raise newException(RangeDefect, "range out of bounds, the container is empty")
            else:
                raise newException(RangeDefect, "range " & $a & ".." & $b & " not in 0 .. " & $this.high)

    this.data.toOpenArray(a, b)

{.boundChecks: off.}
func tryGet*(this: StackString, i: Natural | BackwardsIndex): Option[char] =
    ## Returns the character at the specified index in the [StackString], or returns `None` if the index is invalid
    runnableExamples:
        import std/options

        let str = ss"Hello world"

        let char1 = str.tryGet(0)
        let char2 = str.tryGet(^1)
        let char3 = str.tryGet(100)

        doAssert char1.isSome
        doAssert char2.isSome
        doAssert char3.isNone
    
    let idx = when i is BackwardsIndex:
        this.len - i.int
    else:
        i

    if idx < 0 or idx >= this.len:
        return none[char]()
    else:
        return some this.data[idx]
{.boundChecks: on.}

{.boundChecks: off.}
func unsafeGet*(this: StackString, i: Natural | BackwardsIndex): char {.inline.} =
    ## Returns the character at the specified index in the [StackString].
    ## 
    ## Performs no bounds checks whatsoever; use only if you're 100% sure your index won't extend beyond the [StackString]'s capacity + its nil terminator.
    ## Since no checks are performed, you can read past the [StackString]'s length, but reading past its capacity + its nil terminator is undefined behavior and may crash.
    ## In most cases, you'll be reading zeros past the [StackString]'s length, unless you used `setLen` with `writeZerosOnTruncate` set to `false`.
    let idx = when i is BackwardsIndex:
        this.len - i.int
    else:
        i

    return this.data[idx]
{.boundChecks: on.}

{.boundChecks: off.}
func `[]=`*(this: var StackString, i: Natural | BackwardsIndex, value: char) {.inline, raises: [IndexDefect].} =
    ## Sets the character at the specified index in the [StackString], or raises `IndexDefect` if the index is invalid
    runnableExamples:
        var str = ss"Hello world"

        str[0] = 'Y'
        doAssert str == "Yello world"

    when stackStringsPreventAllocation:
        {.fatal: "The `[]=` proc can allocate memory at runtime, see `stackStringsPreventAllocation`".}

    let idx = when i is BackwardsIndex:
        this.len - i.int
    else:
        i

    # Do bounds check manually because the StackString's len field is the actual bound we want to check, not data.len
    when not defined(danger):
        let cond = idx >= this.len or idx < 0

        if unlikely(cond):
            if this.len == 0:
                raise newException(IndexDefect, "index out of bounds, the container is empty")
            else:
                let idx = when i is BackwardsIndex:
                    this.len - i.int
                else:
                    i

                raise newException(IndexDefect, "index " & $idx & " not in 0 .. " & $this.high)

    this.data[idx] = value
{.boundChecks: on.}

{.boundChecks: off.}
func trySet*(this: var StackString, i: Natural | BackwardsIndex, value: char): bool =
    ## Sets the character at the specified index in the [StackString] and returns true, or returns false if the index is invalid
    
    let idx = when i is BackwardsIndex:
        this.len - i.int
    else:
        i

    if idx < 0 or idx >= this.len:
        return false
    else:
        this.data[idx] = value
        return true
{.boundChecks: on.}

{.boundChecks: off.}
func unsafeSet*(this: var StackString, i: Natural | BackwardsIndex, value: char) {.inline.} =
    ## Sets the character at the specified index in the [StackString].
    ## 
    ## Performs no bounds checks whatsoever; use only if you're 100% sure your index won't extend beyond the [StackString]'s capacity.
    ## Since no checks are performed, you can write past the [StackString]'s length, but writing past its capacity is undefined behavior and may crash.
    ## Overwriting the [StackString]'s nil terminator will make the string unusable when interopping with C.
    let idx = when i is BackwardsIndex:
        this.len - i.int
    else:
        i

    this.data[idx] = value
{.boundChecks: on.}

# Bound checks are unnecessary here because the length is checked first
{.boundChecks: off.}
func `==`*(this: StackString, str: IndexableChars): bool {.inline.} =
    ## Returns whether the [StackString]'s content is equal to the content of another set of characters
    runnableExamples:
        let str1 = ss"abc"
        let str2 = ss"abc"
        let str3 = ss"nope"

        let heapStr1 = "abc"
        let heapStr2 = "nope"

        doAssert str1 == str2
        doAssert str1 != str3
        doAssert str1 == heapStr1
        doAssert str2 != heapStr2

    if this.len != str.len:
        return false

    for i in 0 ..< this.len:
        if this.data[i] != str[i]:
            return false
    
    return true
{.boundChecks: on.}

{.boundChecks: off.}
proc unsafeAdd*(this: var StackString, strOrChar: auto) {.inline.} =
    ## Appends the value to the [StackString].
    ## No capacity checks are performed whatsoever; only use this when you are 100% sure there is enough capacity!
    runnableExamples:
        var bigCap = stackStringOfCap(10)

        let strToAdd = ss"Hello"

        bigCap.unsafeAdd(strToAdd)
    
    when strOrChar is char:
        this.data[this.len] = strOrChar
        inc this.lenInternal
    else:
        let newLen = this.len + strOrChar.len
        
        for i in this.len ..< newLen:
            this.data[i] = strOrChar[i - this.len]
        
        this.lenInternal = newLen
{.boundChecks: on.}

{.boundChecks: off.}
proc tryAdd*(this: var StackString, strOrChar: auto): bool {.inline.} =
    ## Appends the value to the [StackString].
    ## If there is enough capacity to accomodate the new value, true will be returned.
    ## If there is not enough capacity to accomodate the new value, false will be returned.
    ## 
    ## If you want to use a version that raises an exception, you can use [add] instead.
    ## If you want to append as much as possible and then truncate whatever doesn't fit, you can use [addTruncate] instead.
    runnableExamples:
        var bigCap = stackStringOfCap(10)
        var smallCap = stackStringOfCap(3)

        let strToAdd = ss"Hello"

        doAssert bigCap.tryAdd(strToAdd) == true
        doAssert smallCap.tryAdd(strToAdd) == false

        doAssert bigCap == "Hello"
        doAssert smallCap == ""
    
    let newLen = when strOrChar is char:
        this.len + 1
    else:
        this.len + strOrChar.len

    if newLen > this.capacity:
            return false
    
    this.unsafeAdd(strOrChar)

    return true
{.boundChecks: on.}

{.boundChecks: off.}
proc addTruncate*(this: var StackString, strOrChar: auto): bool {.inline, discardable.} =
    ## Appends the provided value to the [StackString].
    ## If the capacity of the StackString is not enough to accomodate the value, the chars that cannot be appended will be truncated.
    ## If the provided value is truncated, `false` will be returned. Otherwise, `true` will be returned.
    ## 
    ## If you want to use a version that raises an exception when there is not enough, you can use [add] instead.
    ## If you want to avoid raising an exception when there is not enough capacity, you can use [tryAdd] instead.
    runnableExamples:
        var bigCap = stackStringOfCap(10)
        var smallCap = stackStringOfCap(3)

        let strToAdd = ss"Hello"

        doAssert bigCap.addTruncate(strToAdd) == true
        doAssert smallCap.addTruncate(strToAdd) == false

        doAssert bigCap == "Hello"
        doAssert smallCap == "Hel"
    
    when strOrChar is char:
        if this.len >= this.capacity:
            return false

        this.data[this.len] = strOrChar
        inc this.lenInternal

        return true
    else:
        let reqCap = this.len + strOrChar.len

        # Change return value based on whether value will be truncated
        var newLen: int
        if reqCap > this.capacity:
            result = false
            newLen = this.capacity
        else:
            result = true
            newLen = reqCap

        for i in this.len ..< newLen:
            this.data[i] = strOrChar[i - this.len]
        
        this.lenInternal = newLen
{.boundChecks: on.}

proc add*(this: var StackString, strOrChar: auto) {.inline, raises: [InsufficientCapacityDefect].} =
    ## Appends the provided value to the [StackString].
    ## If there is not enough capacity to accomodate the new value, [InsufficientCapacityDefect] will be raised.
    ## 
    ## If you don't want to deal with exceptions, you can use [tryAdd] or [addTruncate] instead.
    runnableExamples:
        var bigCap = stackStringOfCap(10)
        var smallCap = stackStringOfCap(3)

        let strToAdd = ss"Hello"

        bigCap.add(strToAdd)
        doAssertRaises InsufficientCapacityDefect, smallCap.add(strToAdd)

        doAssert bigCap == "Hello"
        doAssert smallCap == ""

        bigCap.add('!')
        doAssert bigCap == "Hello!"

    when defined(danger):
        this.unsafeAdd(strOrChar)
    else:
        if not this.tryAdd(strOrChar):
            let reqCap = when strOrChar is char:
                this.len + 1
            else:
                this.len + strOrChar.len
            raiseInsufficientCapacityDefect(
                "Cannot append to StackString due to insufficient capacity (capacity: " & $this.capacity & ", required capacity: " & $reqCap & ")",
                this.capacity, reqCap,
            )

{.boundChecks: off.}
proc unsafeSetLen*(this: var StackString, newLen: Natural | BackwardsIndex, writeZerosOnTruncate: bool = true) {.inline.} =
    ## Sets the length of the [StackString] to `newLen`.
    ## No capacity checks are performed whatsoever; only use this if you're 100% sure you are not exceeding capacity!
    ## 
    ## If `writeZerosOnTruncate` is true and `newLen` is less than the current capacity, the truncated bytes will be zeroed out.

    let lenRes = when newLen is BackwardsIndex:
        this.len - newLen.int
    else:
        newLen
    
    if unlikely(this.len == lenRes):
        return
    
    if writeZerosOnTruncate:
        if lenRes < this.len:
            for i in lenRes ..< this.len:
                this.data[i] = '\x00'

    this.lenInternal = lenRes
{.boundChecks: on.}

proc trySetLen*(this: var StackString, newLen: Natural | BackwardsIndex, writeZerosOnTruncate: bool = true): bool {.inline.} =
    ## Sets the length of the [StackString] to `newLen`, then returns true.
    ## If `newLen` is more than the [StackString]'s capacity, `false` will be returned.
    ## 
    ## If `writeZerosOnTruncate` is true and `newLen` is less than the current capacity, the truncated bytes will be zeroed out.
    runnableExamples:
        var str1 = ss"Hello world"
        
        doAssert str1.trySetLen(5) == true
        doAssert str1.trySetLen(11) == true
        doAssert str1.trySetLen(12) == false

    when not defined(danger):
        let lenRes = when newLen is BackwardsIndex:
            this.len - newLen.int
        else:
            newLen

        if unlikely(lenRes > this.capacity or lenRes < 0):
            return false
    
    this.unsafeSetLen(newLen, writeZerosOnTruncate)

    return true

proc setLen*(this: var StackString, newLen: Natural | BackwardsIndex, writeZerosOnTruncate: bool = true) {.inline, raises: [InsufficientCapacityDefect].} =
    ## Sets the length of the [StackString] to `newLen`.
    ## If `newLen` is more than the [StackString]'s capacity, [InsufficientCapacityDefect] will be raised.
    ## 
    ## If `writeZerosOnTruncate` is true and `newLen` is less than the current capacity, the truncated bytes will be zeroed out.
    runnableExamples:
        var str1 = ss"Hello world"
        var str2 = ss"Hi world"
        var str3 = ss"abc"

        # Note that all [StackString] objects' data are nil-terminated

        # The string will be truncated, and the truncated data will be overwritten with zeros
        str1.setLen(5)
        doAssert str1 == "Hello"
        doAssert str1.data == ['H', 'e', 'l', 'l', 'o', '\x00', '\x00', '\x00', '\x00', '\x00', '\x00', '\x00']

        # If we're sure it's safe to skip overwriting the truncated data with zeros, we can disable it
        str2.setLen(2, writeZerosOnTruncate = false)
        doAssert str2 == "Hi"
        doAssert str2.data == ['H', 'i', ' ', 'w', 'o', 'r', 'l', 'd', '\x00']

        # It works with BackwardsIndex, too
        str3.setLen(^1)
        doAssert str3 == "ab"

    when stackStringsPreventAllocation:
        {.fatal: "The `setLen` proc can allocate memory at runtime, see `stackStringsPreventAllocation`".}

    let lenRes = when newLen is BackwardsIndex:
        this.len - newLen.int
    else:
        newLen

    when not defined(danger):
        if unlikely(lenRes > this.capacity):
            raiseInsufficientCapacityDefect("New length " & $lenRes & " exceeds capacity " & $this.capacity, this.capacity, lenRes)
        elif unlikely(lenRes < 0):
            raiseInsufficientCapacityDefect("Cannot set length to negative value", this.capacity, lenRes)
    
    this.unsafeSetLen(newLen, writeZerosOnTruncate)

func find*(this: StackString, c: char): int {.inline.} =
    ## Finds the index of the specified char in the [StackString], or returns `-1` if the char was not found
    runnableExamples:
        let str = ss"abcdef"

        doAssert str.find('c') == 2
        doAssert str.find('f') == 5
        doAssert str.find('z') == -1
    
    for i in 0 ..< this.len:
        if unlikely(this.data[i] == c):
            return i
    
    return -1

func contains*(this: StackString, c: char): bool {.inline.} =
    ## Returns whether the specified char can be found within the [StackString]
    runnableExamples:
        let str = ss"abcdef"

        doAssert str.contains('c') == true
        doAssert str.contains('f') == true
        doAssert str.contains('z') == false
    
    return this.find(c) != -1

func find*(this: StackString, substr: StackString | string | IndexableChars): int {.inline.} =
    ## Finds the index of the specified substring in the [StackString], or returns `-1` if the substring was not found
    runnableExamples:
        let str = ss"abcdef"

        doAssert str.find("cde") == 2
        doAssert str.find("def") == 3
        doAssert str.find("f") == 5
        doAssert str.find("abd") == -1
        doAssert str.find("zef") == -1
    
    if this.len < substr.len:
        return -1
    
    for i in 0 .. this.len - substr.len:
        block comparison:
            for j in 0 ..< substr.len:
                if likely(this.data[i + j] != substr[j]):
                    break comparison
            
            # Didn't break, therefore the comparison matched
            return i
    
    # Didn't already return index, so no match was found
    return -1

func contains*(this: StackString, substr: StackString | string | IndexableChars): bool {.inline.} =
    ## Returns whether the specified substring can be found within the [StackString]
    runnableExamples:
        let str = ss"abcdef"

        doAssert str.contains("cde") == true
        doAssert str.contains("def") == true
        doAssert str.contains("f") == true
        doAssert str.contains("abd") == false
        doAssert str.contains("zef") == false
    
    return this.find(substr) != -1

template toOpenArray*(this: StackString): untyped =
    ## Converts the [StackString] to `openArray[char]`.
    ## Thanks to ElegantBeef for help on this template.
    
    this.data.toOpenArray(0, this.high)

template toCstring*(this: StackString): cstring =
    ## Converts the [StackString] to `cstring`.
    ## Note that no memory copying is done; this simply casts the [StackString]'s `data` to cstring.
    ## 
    ## There are a few implications to this:
    ##  - The reference will only live as long as its scope; use [toHeapCstring] if you want a heap-allocated cstring
    ##  - If you used [setLen] with `writeZerosOnTruncate` set to `false`, the content of the cstring will include the truncated part of the string
    runnableExamples:
        let str = ss"Hello world"
        let cstr = str.toCstring()

        doAssert cstr == "Hello world"
        when NimMajor > 1: ## Nim 2.0 no longer requires `unsafeaddr` 
            doAssert cstr[0].addr == addr str.data[0]
        else:
            doAssert cstr[0].unsafeaddr == unsafeaddr str.data[0]
    when NimMajor > 1: ## Nim 2.0 no longer requires `unsafeaddr`
        cast[cstring](addr this.data[0])
    else:
        cast[cstring](unsafeaddr this.data[0])

proc toHeapCstring*(this: StackString): cstring {.inline.} =
    ## Allocates a `cstring` on the heap and copies the contents of the [StackString] into it.
    ## The `cstring` is a pointer to heap memory which must be freed manually by the caller using `dealloc`.
    ## If you just want to get the [StackString]'s `data` stack pointer as a `cstring`, use `toCstring` instead.
    runnableExamples:
        let str = ss"Hello world"
        let cstr = str.toHeapCstring()

        doAssert cstr == "Hello world"
        when NimMajor > 1: ## Nim 2.0 no longer requires `unsafeaddr`
            doAssert cstr[0].addr != addr str.data[0]
        else:
            doAssert cstr[0].unsafeaddr != unsafeaddr str.data[0]

        # You need to deallocate the cstring when you're done with it
        dealloc(cstr)

    when stackStringsPreventAllocation:
        {.fatal: "The `toHeapCstring` proc can allocate memory at runtime, see `stackStringsPreventAllocation`".}

    let len = this.len

    # We don't need a zeroed block of memory because we'll be overwriting it manually
    result = cast[cstring](createU(char, len + 1))
    when NimMajor > 1: ## Nim 2.0 no longer requires `unsafeaddr`
        moveMem(result, addr this.data[0], len)
    else:
        moveMem(result, unsafeaddr this.data[0], len)
    result[len] = '\x00'

proc unsafeToStackString*(content: IndexableChars, size: static Natural): StackString[size] {.inline.} =
    ## Creates a new [StackString] of the specified size using the provided content.
    ## No capacity checks are performed whatsoever; only use this when you are 100% sure that the content's length is less than or equal to the specified size!
    runnableExamples:
        let nimStr = "Some runtime string"

        const maxSize = 32

        # We're already doing a capacity check, so we can use the unsafe version to avoid a redundant check
        if nimStr.len > maxSize:
            echo "String is too long!"
        else:
            let stackStr = nimStr.unsafeToStackString(maxSize)

            doAssert stackStr.len == nimStr.len
            

    result = stackStringOfCap(size)
    result.unsafeAdd(content)

proc toStackString*(content: IndexableChars, size: static Natural): StackString[size] {.inline.} =
    ## Creates a new [StackString] of the specified size using the provided content.
    ## If you don't want to raise a defect when the input string exceeds the specified size, use [tryToStackString].
    ## If you want to truncate the content in the resulting [StackString] if it's too long, use [toStackStringTruncate].
    runnableExamples:
        let nimStr = "hi"
        var stackStr = nimStr.toStackString(10)

        doAssert stackStr.len == 2

        stackStr.add(" world")

        doAssert stackStr.len == 8

        doAssertRaises InsufficientCapacityDefect, stackStr.add(", and everyone in it!")


    when stackStringsPreventAllocation:
        {.fatal: "The `toStackString` proc can allocate memory at runtime, see `stackStringsPreventAllocation`".}

    let len = content.len
    if len > size:
        raise newInsufficientCapacityDefect("Tried to create a StackString of size " & $size & ", but the provided content was of size " & $len, size, len)

    return content.unsafeToStackString(size)

proc tryToStackString*(content: IndexableChars, size: static Natural): Option[StackString[size]] {.inline.} =
    ## Creates a new [StackString] of the specified size using the provided content.
    ## If the content's length is more than the `size` argument, then None will be returned.
    ## If you want to raise a defect when the input string exceeds the specified size, use [toStackString].
    ## If you want to truncate the content in the resulting [StackString] if it's too long, use [toStackStringTruncate].
    runnableExamples:
        import std/options
    
        let nimStr = "too long very long"
        let stackStrRes = nimStr.tryToStackString(10)

        doAssert stackStrRes.isNone

        let stackStrRes2 = nimStr.tryToStackString(32)

        doAssert stackStrRes2.isSome

    if content.len > size:
        return none[StackString[size]]()

    return some content.unsafeToStackString(size)

proc toStackStringTruncate*(content: IndexableChars, size: static Natural): StackString[size] {.inline.} =
    ## Creates a new [StackString] of the specified size using the provided content.
    ## If the content length is more than `size`, only the part of the content that can fit in the size will be included, and the rest will be truncated.
    runnableExamples:
        let nimStr = "Hello world"
        let stackStr = nimStr.toStackStringTruncate(5)

        doAssert stackStr == "Hello"

    result = stackStringOfCap(size)
    result.addTruncate(content)
