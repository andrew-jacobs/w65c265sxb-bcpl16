# Intcode interpreter for the original 16-bit BCPL system
# see https://docs.jeelabs.org/tfoc/ -jcw, 2017-10-20

from __future__ import print_function
import array, math, sys

########## a few small utility functions

def u(x): # convert to 16-bit unsigned
    return x & 0xFFFF

def s(x): # convert to 16-bit signed
    x = u(x)
    if x & 0x8000:
        x -= 0x10000
    return x

def getbyte(a, b): # read a byte from a word
    t = M[a+b//2]
    if b & 1:
        t &= 0xFF
    else:
        t >>= 8
    return t

def putbyte(a, b, v): # write a byte into a word
    t = M[a+b//2]
    if b & 1:
        t = (t & 0xFF00) | v
    else:
        t = (t & 0x00FF) | (v << 8)
    M[a+b//2] = t

########## file handling, and loading the binary code from file

FT = [sys.stdin, sys.stdout, sys.stderr] + [None] * 17
FI, FO = 0, 1

def cstr(a): # convert target string to Python string
    s = ''
    for i in range(getbyte(a, 0)):
        s += chr(getbyte(a, i+1))
    return s

def ftslot(): # find the next unused file table slot
    for i, f in enumerate(FT):
        if f == None:
            return i
    return -1

try:
    f = sys.stdin
    if len(sys.argv) > 1:
        f = open(sys.argv[1], 'rb')
    H = array.array('H')
    H.fromfile(f, 5)
    M = array.array('H')
    try:
        M.fromfile(f, 0x10000)
    except EOFError:
        pass
    M.extend([0] * (20000-len(M)))
finally:
    if len(sys.argv) > 1:
        f.close()

########## main interpreter loop

G, C, P = H[1:4]
A = B = 0

while True:
    oC = C
    W = M[C]; C += 1

    if (W & 0x0200) == 0:
        D = W & 0x01FF
    else:
        D = M[C]; C += 1

    if W & 0x0800:
        D += P
    if W & 0x0400:
        D += G
    if W & 0x1000:
        D = M[D]

    O = W >> 13

    if 0: # enable this to generate instruction trace output
        x = "LSAJTFKX"[O]
        if W & 0x1000:
            x += 'I'
        if W & 0x0800:
            x += 'P'
        if W & 0x0400:
            x += 'G'
        x += str(W & 0x1FF)
        print("CWxDABP", oC, format(W, '04X'), x, D, A, B, P, sep='\t')

    if O == 0: # L
        B, A = A, D
    elif O == 1: # S
        M[D] = A
    elif O == 2: # A
        A = u(A + D)
    elif O == 3: # J
        C = D
    elif O == 4: # T
        if A != 0:
            C = D
    elif O == 5: # F
        if A == 0:
            C = D
    elif O == 6: # K
        D += P
        M[D], M[D+1] = P, C
        P, C = D, A
    else: # X<n> operation code dispatch
        if D == 1:
            A = M[A]
        elif D == 2:
            A = u(-A)
        elif D == 3:
            A = A ^ 0xFFFF
        elif D == 4:
            C, P = M[P+1], M[P]
        elif D == 5:
            A = u(s(B) * s(A))
        elif D == 6:
            # work around Python difference with negative values
            T = abs(s(B)) // abs(s(A))
            if s(B) * s(A) < 0:
                A = u(-T)
            else:
                A = T
        elif D == 7:
            # work around Python difference with negative values
            A = u(int(math.fmod(s(B), s(A))))
        elif D == 8:
            A = u(s(B) + s(A))
        elif D == 9:
            A = u(s(B) - s(A))
        elif D == 10:
            if B == A:
                A = 0xFFFF
            else:
                A = 0
        elif D == 11:
            if B != A:
                A = 0xFFFF
            else:
                A = 0
        elif D == 12:
            if s(B) < s(A):
                A = 0xFFFF
            else:
                A = 0
        elif D == 13:
            if s(B) >= s(A):
                A = 0xFFFF
            else:
                A = 0
        elif D == 14:
            if s(B) > s(A):
                A = 0xFFFF
            else:
                A = 0
        elif D == 15:
            if s(B) <= s(A):
                A = 0xFFFF
            else:
                A = 0
        elif D == 16:
            A = u(B << A)
        elif D == 17:
            A = B >> A
        elif D == 18:
            A = B & A
        elif D == 19:
            A = B | A
        elif D == 20:
            A = B ^ A
        elif D == 21:
            A = B ^ A ^ 0xFFFF
        elif D == 22:
            break
        elif D == 23:
            B, D = M[C], M[C+1]
            while B != 0:
                B -= 1; C += 2
                if A == M[C]:
                    D = M[C+1]
                    break
            C = D
        elif D == 24:
            FI = A-1
        elif D == 25:
            FO = A-1
        elif D == 26:
            try:
                A = ord(FT[FI].read(1))
            except:
                A = u(-1)
        elif D == 27:
            FT[FO].write(chr(A))
        elif D == 28:
            f = ftslot()
            if f >= 0:
                try:
                    FT[f] = open(cstr(A), 'r')
                except:
                    FT[f] = None
                    f = -1
            A = f+1
        elif D == 29:
            f = ftslot()
            if f >= 0:
                try:
                    FT[f] = open(cstr(A), 'w')
                except:
                    FT[f] = None
                    f = -1
            A = f+1
        elif D == 30:
            print("stop:", A)
            break
        elif D == 31:
            A = M[P]
        elif D == 32:
            P, C = A, B
        elif D == 33:
            if A > 2:
                FT[FI].close()
                FT[FI] = None
            FI = 0
        elif D == 34:
            if A > 2:
                FT[FO].close()
                FT[FO] = None
            FO = 1
        elif D == 35:
            D = P + B + 1
            M[D], M[D+1], M[D+2], M[D+3] = M[P], M[P+1], P, B
            P, C = D, A
        elif D == 36:
            A = getbyte(A, B)
        elif D == 37:
            putbyte(A, B, M[P+4])
        elif D == 38:
            A = FI+1
        elif D == 39:
            A = FO+1
        else:
            assert D != D
