# Tetris
## Overview
Tetris is an implementation of the classical Tetris using x86 Assembly.

## Prerequisites
* DosBox
* 8086 assembler files (masm.exe and link.exe)

## Running the Project
1. Clone this project locally
2. Extract the 8086 assembler files in the same directory
3. Open DosBox and enter the following commands:
```bash
mount c: /path/to/repository
c:
masm.exe tetris.asm
link.exe tetris.obj
tetris.exe
```

You should see the title screen similar to this:

![title-screen](media/title-screen.png)