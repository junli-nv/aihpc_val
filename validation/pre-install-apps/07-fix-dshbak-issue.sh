#!/bin/bash

# Issue: Use of uninitialized value $tag in string at /usr/bin/dshbak line 115, <> line 1.
# Resolution: https://github.com/chaos/pdsh/issues/132
sed -i.ori -e 's#next unless "$tag" ne "";#next unless defined $tag and "$tag" ne "";#g' /usr/bin/dshbak

