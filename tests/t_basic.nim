import unittest

import stack_strings

test "Can add":
    var str = stackStringOfCap(10)

    str.add(ss"lol")

    check str == "lol"

test "Random tests":
    var str1 = ss"Hello world"
    var str2 = ss"Hi world"
    var str3 = ss"abc"

    # The string will be truncated, and the truncated data will be overwritten with zeros
    str1.unsafeSetLen(5)
    check str1 == "Hello"
    check str1.data == ['H', 'e', 'l', 'l', 'o', '\x00', '\x00', '\x00', '\x00', '\x00', '\x00', '\x00']

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

