#!/bin/sh
set -e
cd "$(dirname "$0")"
cd ..
./bin/builddocs.py
rsync -r doc/ users:WWW/networkos.net/nim/reactor.nim/doc
