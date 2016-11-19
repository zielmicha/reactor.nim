#!/usr/bin/env python3
import os, subprocess

os.chdir(os.path.dirname(__file__) + '/..')

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
    new_file = 'doc/api/' + path
    with open(new_file, 'w') as output:
        for line in open(path, 'r'):
            if line.startswith('include reactor/'):
                fn = line.split(None)[1] + '.nim'
                if is_include_path(fn):
                    output.write(open(fn).read() + '\n')
            elif not line.startswith('import '):
                output.write(line)

    subprocess.check_call(['nim', 'doc', '--docSeeSrcUrl:https://github.com/zielmicha/reactor.nim/tree/master', new_file])

for root, dirs, files in os.walk("doc/"):
    for name in files:
        path = os.path.join(root, name)

        if path.endswith('.rst') and '#' not in path:
            subprocess.check_call(['nim', 'rst2html', path])

STYLE = '''
<link href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css" rel=stylesheet>
'''

def postprocess_html(data):
    out = []
    css = False
    for line in data.splitlines():
        if line == '<style type="text/css" >':
            out.append(STYLE)
            css = True
        if line == '</style>':
            css = False
        if not css:
            out.append(line)
    return '\n'.join(out)

for root, dirs, files in os.walk("doc/"):
    for name in files:
        path = os.path.join(root, name)

        if path.endswith('.html') and 'doc/api/' not in path:
            html = postprocess_html(open(path).read())
            with open(path, 'w') as f:
                f.write(html)
