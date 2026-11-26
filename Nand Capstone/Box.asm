// Box.asm  -  Capstone: Make the Computer Draw a Box
// Student K = 98
//   start row     = K              = 98
//   height        = 20 rows
//   width         = 16*((K mod 4)+1) = 16*3 = 48 pixels = 3 words (from left edge)
//   first address = SCREEN + 32*98 = 16384 + 3136 = 19520
//
// While any key is pressed the box is black; when released it is white.
// The box is redrawn continuously, so the screen always matches the keyboard.

(LOOP)
    @KBD
    D=M
    @PRESSED
    D;JNE           // key pressed -> black
    @color
    M=0             // no key -> white
    @DRAW
    0;JMP
(PRESSED)
    @color
    M=-1            // all 16 bits set = black

(DRAW)
    @19520          // SCREEN + 32*98
    D=A
    @addr
    M=D
    @20
    D=A
    @rows
    M=D             // 20 rows left to draw

(ROW)
    @color
    D=M
    @addr
    A=M
    M=D             // word 0 (pixels 0-15)
    A=A+1
    M=D             // word 1 (pixels 16-31)
    A=A+1
    M=D             // word 2 (pixels 32-47)

    @32
    D=A
    @addr
    M=M+D           // next screen row

    @rows
    M=M-1
    D=M
    @ROW
    D;JGT           // more rows?

    @LOOP
    0;JMP
