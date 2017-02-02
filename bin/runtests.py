#!/usr/bin/env python3
import glob
import subprocess
import sys
import os

os.chdir(os.path.dirname(__file__)); os.chdir('..')

for name in glob.glob('tests/*.nim'):
    lines = open(name).read().splitlines()
    if not (lines and lines[0].startswith('# TEST.')):
        # not marked as test, at least compile it
        subprocess.check_call(['nim', 'c', '--verbosity:0', name])
        continue

    assert lines[1].startswith('discard """')
    lines[1] = lines[1].split('"""', 1)[1]
    expected_output = []
    for line in lines[1:]:
        expected_output.append(line.split('"""', 1)[0])
        if '"""' in line:
            break

    expected_output = '\n'.join(expected_output).encode('utf8')
    subprocess.check_call(['nim', 'c', '--verbosity:0', name])
    bin_name = name.rsplit('.', 1)[0]
    got_output = subprocess.check_output([bin_name], stderr=subprocess.STDOUT).strip()
    if got_output != expected_output:
        print(name, 'failure')
        print('Expected:')
        print(expected_output)
        print('Got:')
        print(got_output)
        sys.exit(1)
    else:
        print(name, 'ok')
