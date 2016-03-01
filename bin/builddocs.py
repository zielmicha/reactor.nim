#!/usr/bin/env python3
import os, subprocess

nim_files = []

if not os.path.exists('doc/api'):
    os.mkdir('doc/api')

def is_include_path(path):
    return '/uv/' in path

for root, dirs, files in os.walk("reactor"):
    new_dir = 'doc/api/' + root
    if not os.path.exists(new_dir): os.mkdir(new_dir)

    for name in files:
        path = os.path.join(root, name)

        if name.endswith('.nim') and not is_include_path(path):
            nim_files.append(path)

for path in nim_files:
    print(path)
    new_file = 'doc/api/' + path
    with open(new_file, 'w') as output:
        for line in open(path, 'r'):
            if line.startswith('include reactor/'):
                fn = line.split(None)[1] + '.nim'
                if is_include_path(fn):
                    output.write(open(fn).read() + '\n')
            elif not line.startswith('import '):
                output.write(line)

    subprocess.check_call(['nim', 'doc', new_file])
