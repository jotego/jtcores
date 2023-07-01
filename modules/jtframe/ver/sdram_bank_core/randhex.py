#!/usr/bin/python

from random import *

for i in range(0,4*1024*1024):
    print("%X" % randint(0,65535) )
