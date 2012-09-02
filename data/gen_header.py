#!/usr/bin/env python

# Script to generate _column_names.h from column-types.json
#############################################################################
# Emperor - an orthodox file manager for the GNOME desktop
# Copyright (C) 2012    Thomas Jollans
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################

import json
import sys

column_types = json.load (sys.stdin)

idx = 1
for col_name, col_def in column_types.items():
    if "title" in col_def:
        sys.stdout.write ('char *title{0} = _("{1}");\n'.format(idx,
                                                        col_def["title"]))
    idx += 1
