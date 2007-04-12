BLOCK 64
FORTH [TEXTCAPITALIZED], mandelbrot, [TEXT], display, [EXECUTE], empty, [VARIABLE], xl, [BINARY], 0, [VARIABLE], xr, [BINARY], 0, [VARIABLE], yt, [BINARY], 0, [VARIABLE], yb, [BINARY], 0, [VARIABLE], xspan, [BINARY], 0, [VARIABLE], yspan, [BINARY], 0, [VARIABLE], dark, [BINARY], 0, [VARIABLE], pixel, [BINARY], 0, [VARIABLE], count, [BINARY], 0, [VARIABLE], level, [BINARY], 0
FORTH zlen, [EXECUTE], hp, [EXECUTE], vp, [EXECUTE], *, [EXECUTE], 1+,
 FORTH [EXECUTE], dup, [EXECUTE], +, ";"
FORTH allot, [TEXT], n-a, align, here, dup, push, +, here!, pop, ";"
 FORTH [VARIABLE], z, [BINARY], 0, [EXECUTE], zlen, [EXECUTE], cells,
 FORTH [EXECUTE], allot, [EXECUTE], 1, [EXECUTE], cells, [EXECUTE], /,
 FORTH [EXECUTE], z, [EXECUTE], !
FORTH abs, 0, or, -if, negate, then, ";"
FORTH fixed, [COMPILELONGHEX], 10000000, [COMPILESHORT], 10000, */, ";"
FORTH clear, red, screen, zlen,
 FORTH [EXECUTE], z, @, zero, 0,
 FORTH [EXECUTE], pixel, !, ";"
FORTH reinit,
 FORTH [EXECUTE], xr, @, [EXECUTE], xl, @, negate, +,
 FORTH [EXECUTE], xspan, !,
 FORTH [EXECUTE], yt, @, [EXECUTE], yb, @, negate, +,
 FORTH [EXECUTE], yspan, !,
 FORTH [COMPILEWORD], ";"
FORTH init, [TEXT], -2.1,
 FORTH [EXECUTESHORT], -21000, [EXECUTE], fixed, nop, [EXECUTE], xl, "!",
 FORTH [TEXT], 1.1,
 FORTH [EXECUTESHORT], 11000, [EXECUTE], fixed, nop, [EXECUTE], xr, "!",
 FORTH [TEXT], 1.2,
 FORTH [EXECUTESHORT], 12000, [EXECUTE], fixed, nop, [EXECUTE], yt, "!",
 FORTH [TEXT], -1.2,
 FORTH [EXECUTESHORT], -12000, [EXECUTE], fixed, nop, [EXECUTE], yb, "!",
 FORTH [COMPILESHORTHEX], -80, [EXECUTE], dark, !
 FORTH [COMPILESHORT], 5000, [EXECUTE], count, !
 FORTH [COMPILESHORT], 2, [EXECUTE], level, !
 FORTH [COMPILEWORD], ";"
FORTH fb, [TEXT], -a, [TEXT], framebuffer, [EXECUTE], vframe,
 FORTH [EXECUTESHORT], 4, [EXECUTE], *, ";"
FORTH darker, [TEXT], n-, 2*, fb, +, dup, w@, 0, +, drop, if,
 FORTH [EXECUTE], dark, @, swap, +w!, ";", then, drop, ";"
FORTH z@, [TEXT], i-nn, 2*, [EXECUTE], z, @, +, dup, @, swap, 1+, @, ";"
FORTH ge4, [TEXT], n-f, ;# 'if' tests true (nz) if abs(n) > 4
 FORTH [COMPILEWORD], abs, [EXECUTESHORT], -40000, [EXECUTE], fixed,
 FORTH [COMPILEWORD], +, drop, -if, 0, drop, ";", then, ";"
FORTH fx*, [COMPILELONGHEX], 10000000, */, ";"
FORTH four, [TEXT], n-, dup, z@, ge4, if, drop, drop, ";",
 FORTH [COMPILEWORD], then, ge4, if, drop, ";",
 FORTH [COMPILEWORD], then, dup, z@, dup, fx*, ge4, if, drop, drop, ";"
 FORTH [COMPILEWORD], then, dup, fx*, ge4, if, drop, ";"
 FORTH [COMPILEWORD], then, z@, dup, fx*, swap, dup, fx*, +, ge4, ";"
FORTH z!, [TEXT], nni-, 2*, [EXECUTE], z, @, +, dup, push, 1+, !, pop, !, ";"
FORTH [EXECUTESHORT], 2, [EXECUTE], +load,
 FORTH [EXECUTESHORT], 4, [EXECUTE], +load
 FORTH [EXECUTE], ok, [EXECUTE], h
BLOCK 65
FORTH zlen, helper, word, returns, length, of, z, array
FORTH allot, grabs, space, at, [COMPILEWORD], here, and, returns, that, "address;", z, points, to, the, array, of, values, as, generated, by, "z**2+z0"
FORTH abs, absolute, value
FORTH fixed, convert, to, fixed, point
FORTH clear, wipes, out, the, [COMPILEWORD], z, array, and, clears, screen
FORTH reinit, sets, [COMPILEWORD], xspan, and, [COMPILEWORD], yspan
FORTH init, sets, screen, boundaries, based, on, zoom, and, pan, settings
FORTH fb, returns, framebuffer, byte, address
FORTH darker, changes, pixel, color
FORTH z@, returns, complex, number, at, specified, index
FORTH ge4, checks, if, fixed-point, number, above, 4
FORTH four, check, if, complex, number, above, 4
FORTH z!, stores, complex, number, at, specified, index
BLOCK 66
FORTH x0, [COMPILELONGHEX], 10000000, hp, */, ;# scale to A(3,28) fixed
 FORTH [EXECUTE], xspan, @, fx*, [EXECUTE], xl, @, +, ";"
FORTH y0, [COMPILELONGHEX], 10000000, vp, */, ;# make fixed-point number
 FORTH [EXECUTE], yspan, @, fx*, negate, [EXECUTE], yt, @, +, ";"
FORTH z0, [TEXT], -a, [EXECUTE], z, [EXECUTE], @, [EXECUTE], zlen,
 FORTH [EXECUTESHORT], -2, [EXECUTE], +, [EXECUTE], +, ";"
FORTH z0!, [TEXT], n-, hp, /mod, y0, z0, 1+, !, x0, z0, !, ";"
FORTH z0@, [TEXT], -nn, [EXECUTE], z0, @, z0, 1+, @, ";"
FORTH z+c, [TEXT], n-, dup, z0!, dup, push, z@, z0@, swap, push, +,
 FORTH [COMPILEWORD], swap, pop, +, swap, pop, z!, ";"
FORTH z**2, [TEXT], n-, dup, push, z@, dup, fx*, dup, ge4, swap, ;# b**2 a
 FORTH [COMPILEWORD], if, pop, z!, ";", then, dup, fx*, dup, ge4, swap,
 FORTH [COMPILEWORD], if, pop, z!, ";", then, negate, +,
 FORTH [COMPILEWORD], pop, dup, push, z@, fx*, dup, ge4,
 FORTH [COMPILEWORD], if, pop, z!, ";", then, 2*, pop, z!, ";"
FORTH z2+c, [TEXT], n-, dup, z**2, z+c, ";"
FORTH update, [TEXT], n-, dup, four, if, drop, ";", then,
 FORTH [COMPILEWORD], dup, z2+c, dup, four, if, drop, ";", then, darker, ";"
FORTH iter,
 FORTH [EXECUTE], pixel, @, [EXECUTE], count, @, for, dup, update,
 FORTH [COMPILEWORD], 1+, [EXECUTE], hp, [EXECUTE], vp, [EXECUTE], *, mod,
 FORTH [COMPILEWORD], next, [EXECUTE], pixel, !, ";"
FORTH zoom, [TEXT], nn-,
 FORTH [EXECUTE], xr, @, [EXECUTE], xl, @, +, 2/,
 FORTH [COMPILEWORD], over, over, +, [EXECUTE], xr, !,
 FORTH [COMPILEWORD], swap, negate, +, [EXECUTE], xl, !,
 FORTH [EXECUTE], yt, @, [EXECUTE], yb, @, +, 2/,
 FORTH [COMPILEWORD], over, over, +, [EXECUTE], yt, !,
 FORTH [COMPILEWORD], swap, negate, +, [EXECUTE], yb, !,
 FORTH [COMPILEWORD], 0, [EXECUTE], xspan, !, ";" ;# force reinit
FORTH +zoom,
 FORTH [EXECUTE], level, @, 2*, [EXECUTE], level, !,
 FORTH [EXECUTE], yspan, @, [COMPILESHORT], 4, /,
 FORTH [EXECUTE], xspan, @, [COMPILESHORT], 4, /,
 FORTH [COMPILEWORD], zoom, ";"
FORTH -zoom,
 FORTH [EXECUTE], level, @, -1, +, drop, if,
 FORTH [EXECUTE], level, @, 2/, [EXECUTE], level, !,
 FORTH [EXECUTE], yspan, @,
 FORTH [EXECUTE], xspan, @,  ;# expanding by two, so add it to both sides
 FORTH [COMPILEWORD], zoom, then, ";"
BLOCK 67
FORTH x0, creates, real, part, of, complex, number, at, specified, index
FORTH y0, creates, imaginary, part, of, complex, number, at, specified, index
FORTH z0, returns, address, of, temporary, storage, for, z0, the, constant, value, for, this, index
FORTH z0!, generate, complex, number, z0, [TEXTALLCAPS], aka, c, of, z2+c, for, this, index
FORTH z**2, the, square, of, complex, number, "a,", "b", is,  a**2, -, b**2, ",", 2a*b
FORTH z2+c, calculate, z**2, +, c
FORTH update, z, and, pixel, if, not, already, past, the, limit
FORTH iter, iterates, over, the, array, updating, continuously
FORTH zoom, zooms, in, or, out
FORTH +zoom, zooms, in, 2, times, closer
FORTH -zoom, zooms, out
BLOCK 68
FORTH left, [EXECUTE], xspan, @, [COMPILESHORT], 10, /, negate, dup,
 FORTH [EXECUTE], xl, @, +, ge4, if, drop, ";", then, dup,
 FORTH [EXECUTE], xl, +!, [EXECUTE], xr, +!, 0, [EXECUTE], xspan, !, ";"
FORTH right, [EXECUTE], xspan, @, [COMPILESHORT], 10, /, dup,
 FORTH [EXECUTE], xr, @, +, ge4, if, drop, ";", then, dup,
 FORTH [EXECUTE], xl, +!, [EXECUTE], xr, +!, 0, [EXECUTE], xspan, !, ";"
FORTH up, [EXECUTE], yspan, @, [COMPILESHORT], 10, /, dup,
 FORTH [EXECUTE], yt, @, +, ge4, if, drop, ";", then, dup,
 FORTH [EXECUTE], yt, +!, [EXECUTE], yb, +!, 0, [EXECUTE], xspan, !, ";"
FORTH down, [EXECUTE], yspan, @, [COMPILESHORT], 10, /, negate, dup,
 FORTH [EXECUTE], yb, @, +, ge4, if, drop, ";", then, dup,
 FORTH [EXECUTE], yt, +!, [EXECUTE], yb, +!, 0, [EXECUTE], xspan, !, ";"
FORTH nul, ";"
FORTH h, pad, nul, nul, accept, nul,
 FORTH [COMPILEWORD], nul, nul, nul, nul,  left, up, down, right,
 FORTH [COMPILEWORD], -zoom, nul, nul, +zoom, nul, nul, nul, nul,
 FORTH [COMPILEWORD], nul, nul, nul, nul,  nul, nul, nul, nul,
 FORTH [EXECUTESHORTHEX], 250000 [EXECUTE], ",",
 FORTH [EXECUTESHORT], 0, [EXECUTE], ","
 FORTH [EXECUTELONGHEX], 110160c, [EXECUTE], ","
 FORTH [EXECUTELONGHEX], 2b000023, [EXECUTE], ","
 FORTH [EXECUTESHORT], 0, [EXECUTE], ",",
 FORTH [EXECUTESHORT], 0, [EXECUTE], ","
 FORTH [EXECUTESHORT], 0, [EXECUTE], ","
FORTH 0., [TEXT], n-, [COMPILESHORTHEX], 18, +, emit, ";"
FORTH fx., [TEXT], n-, ;# show fixed-point as float
 FORTH [COMPILELONGHEX], -1, and, -if,
 FORTH [COMPILESHORTHEX], 23, [TEXT], -, emit, negate, then,
 FORTH [COMPILELONGHEX], 10000000, /mod, 0.,
 FORTH [COMPILESHORTHEX], 25, [TEXT], ., emit,
 FORTH [COMPILELONGHEX], 10000000, [COMPILESHORT], 5, for,
 FORTH [COMPILESHORT], 5, +, [TEXT], round, [TEXT], up,
 FORTH [COMPILESHORT], 10, /, swap,
 FORTH [COMPILEWORD], over, /mod, 0., swap, next, drop, drop, space,
 FORTH [COMPILEWORD], ";"
FORTH  ok, init, show, [EXECUTE], xspan, @, -1, +, drop, -if,
 FORTH [COMPILEWORD], reinit, clear, then, iter, keyboard,
 FORTH [COMPILEWORD], 0, [EXECUTE], vc, [EXECUTESHORT], -2, [EXECUTE], +,
 FORTH [EXECUTE], ih, [EXECUTE], *, at,
 FORTH [COMPILESHORT], 45, [TEXT], *, emit, [EXECUTE], level, @, .,
 FORTH [EXECUTE], xr, @, [EXECUTE], xl, @, +, 2/, fx.,
 FORTH [EXECUTE], yt, @, [EXECUTE], yb, @, +, 2/, fx.,
 FORTH [COMPILEWORD], ";"
;# test words
FORTH g, ge4, if, 1, ";", then, 0, ";"
FORTH f, four, if, 1, ";", then, 0, ";"
BLOCK 69
FORTH left, pans, left, 1/10, of, screen
FORTH right, pans, right
FORTH up, pans, upwards
FORTH down, pans, downwards
FORTH h, sets, up, keypad
FORTH ok, sets, the, display, and, starts, the, generator
BLOCK
