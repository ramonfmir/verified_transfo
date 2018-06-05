#!/usr/bin/python

import os
import sys
import time

if __name__ == "__main__":
    scripts = ['aos', 'soa', 'aosoa']
    modes = ['populate']#['apply_action', 'populate']

    for script in scripts:
        os.system('rm bin/' + script)
        os.system('gcc -Wall -O3 -o bin/' + script + ' ' + script +'.c')

    for mode in modes:
        print('')
        for script in scripts:
            start = time.time()
            os.system('./bin/' + script + ' ' + mode)
            end = time.time()
            print(script + ' ' + mode + ': %.02f' % (end - start))
