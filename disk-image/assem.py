# Intcode assembler for the original 16-bit BCPL system
# see https://docs.jeelabs.org/tfoc/ -jcw, 2017-10-20

from __future__ import print_function
import array, sys

labv = [0] * 501
Ch, Cnext = '', ''
Cp = 0

G = 1
M = array.array('H', [0] * 402 + [0x1401,0xC002,0xE016])

def rch():
    global Ch, Cnext
    if Cnext == '':
        try:
            Ch = sys.stdin.read(1)
            if Ch == '/':
                while sys.stdin.read(1) != '\n':
                    pass
                Ch = sys.stdin.read(1)
        except EOFError:
            Ch = ''
    else:
        Ch, Cnext = Cnext, ''
    return Ch

def eat(c):
    global Cnext
    if rch() == c:
        return True
    Cnext = Ch
    return False

def rdn():
    global Cnext
    v, neg = 0, eat('-')
    while '0' <= rch() and Ch <= '9':
        v = 10 * v + ord(Ch) - ord('0')
    Cnext = Ch
    if neg:
        v = -v
    return v

def stw(n):
    global Cp
    M.append(n & 0xFFFF)
    Cp = 0

def stc(c):
    global Cp
    if Cp == 0:
        stw(c << 8)
    else:
        M[-1] |= c
    Cp = 1-Cp

def setlab(n):
    k = labv[n]
    assert k >= 0
    while k > 0:
        kp = k
        nv = M[kp]
        M[kp] = len(M)
        k = nv
    labv[n] = -len(M)

def labref(n, a):
    k = labv[n]
    if k < 0:
        k = -k
    else:
        labv[n] = a
    M[a] += k

while rch() != '':
    if '0' <= Ch and Ch <= '9':
        Cnext = Ch
        setlab(rdn())
        Cp = 0
        continue
    if Ch in ['$', ' ', '\n']:
        continue
    f = "LSAJTFKX".find(Ch)
    if f >= 0:
        W = f << 13
        if eat('I'):
            W |= 0x1000
        if eat('P'):
            W |= 0x0800
        if eat('G'):
            W |= 0x0400
        if eat('L'):
            stw(W | 0x200)
            stw(0)
            labref(rdn(), len(M)-1)
        else:
            v = rdn()
            if v == (v & 0x1FF):
                stw(W | v)
            else:
                stw(W | 0x200)
                stw(v)
        continue
    if Ch == 'C':
        stc(rdn())
    elif Ch == 'D':
        if eat('L'):
            stw(0)
            labref(rdn(), len(M)-1)
        else:
            stw(rdn())
    elif Ch == 'G':
        A = rdn() + G
        eat('L')
        M[A] = 0
        labref(rdn(), A)
    elif Ch == 'Z':
        labv = [0 for _ in labv]
        Cp = 0
    else:
        assert Ch != Ch

if len(sys.argv) > 1:
    fo = open(sys.argv[1], 'wb')
else:
    fo = open('EXCODE', 'wb')
H = array.array('H', [0xBC0D, G, 402, len(M), 0])
H.tofile(fo)
M.tofile(fo)
fo.close()

print(len(M), 'words')
