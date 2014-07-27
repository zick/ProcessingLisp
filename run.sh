#!/bin/sh
cat - > lisp/input && \
processing-java --run --sketch=`pwd`/lisp --output=`pwd`/lisp/out --force
