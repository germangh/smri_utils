#!usr/bin/perl -w
#
# Usage:
#
#	perl meegs_fix_nl.pl fileIn [fileOut]
#
# Where:
#
# 	fileIn is the name of the file to be fixed
#
#	fileOut is the name of the output file. By default, the output file will
#	have the same name as the input file but with the tag fix_nl added at
#   the end
#

# (c) German Gomez-Herrero, german.gomezherrero@ieee.org

use strict;
use meegs;

meegs->fix_nl(@ARGV);

exit(0);
