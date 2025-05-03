import std/unittest
import std/options
import std/strutils

import stack_strings

test "Can add":
    var str = stackStringOfCap(10)

    str.add(ss"lol")

    check str == "lol"

test "LenType compiletime check":
    check compiles(block:
        const strMsg1 = "abcd".repeat(31)
        var str1 = ss(strMsg1, uint8)
        echo str1.data
    )
    check not compiles(block:
        const strMsg2 = "abcd".repeat(32)
        var str2 = ss(strMsg2, int8)
        echo str2.data
    )
    check compiles(block:
        var str3 = stackStringOfCap(126, int8)
        str3.add(ss"lol")
    )
    check not compiles(block:
        var str3 = stackStringOfCap(127, int8)
        str3.add(ss"lol")
    )

test "Random tests":
    var str1: StackString[11] = ss"Hello world"
    var str2 = ss"Hi world"
    var str3 = ss"abc"
    var str4 = ss("hello world", uint8)

    # The string will be truncated, and the truncated data will be overwritten with zeros
    str1.unsafeSetLen(5)
    check str1 == "Hello"
    check str1.data == ['H', 'e', 'l', 'l', 'o', '\x00', '\x00', '\x00', '\x00', '\x00', '\x00', '\x00']

    str4.unsafeSetLen(5)
    # check str4 == "hello"
    check str4.data == ['h', 'e', 'l', 'l', 'o', '\x00', '\x00', '\x00', '\x00', '\x00', '\x00', '\x00']

    # If we're sure it's safe to skip overwriting the truncated data with zeros, we can disable it
    str2.unsafeSetLen(2, writeZerosOnTruncate = false)
    check str2 == "Hi"
    check str2.data == ['H', 'i', ' ', 'w', 'o', 'r', 'l', 'd', '\0']

    # It works with BackwardsIndex, too
    str3.unsafeSetLen(^1)
    check str3 == "ab"

    check str1.trySet(0, 'a') == true
    check str1.trySet(5, 'a') == false
    check str1 == "aello"
    check str1.unsafeGet(5) != 'a'

    str1.unsafeSet(5, 'a')
    check str1.unsafeGet(5) == 'a'
    discard $str1

    str4.unsafeSet(5, 'a')
    check str4.unsafeGet(5) == 'a'
    discard $str4

test "len type overrides":
    let nimStr = "hi"
    var str6 = stackStringOfCap(10, int8)
    str6.addTruncate(nimStr)
    check str6.len == 2

    echo $str6

test "unsafeToStackString":
    let nimStr = "hi"
    var str7 = nimStr.unsafeToStackString(10)
    check str7.len == 2
    check str7 == "hi"

    check not compiles(block:
        var str8 = nimStr.unsafeToStackString(200, int8)
        check str8.len == 2
        check str8 == "hi"
    )

test "toStackString":
    let nimStr = "hi"
    var str9 = nimStr.toStackString(10)
    check str9.len == 2
    check str9 == "hi"

test "tryToStackString":
    let nimStr = "hi"
    var str9 = nimStr.tryToStackString(10)
    check str9.isSome()
    check str9.get().len == 2
    check str9.get() == "hi"

test "toStackStringTruncate":
    let nimStr = "hi"
    var str9 = nimStr.toStackStringTruncate(10)
    check str9.len == 2
    check str9 == "hi"

    check not compiles(block:
        var str10 = nimStr.toStackStringTruncate(200, int8)
        check str10.len == 2
        check str10 == "hi"
    )

