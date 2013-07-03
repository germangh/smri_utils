#!/usr/bin/perl -w
#
# Usage:
#
#	perl meegs_sfp2hpts.pl fileIn [options]
#
# Where:
#
# 	fileIn is the name of a .spf file that contains EGI 3-D cartesian 
#	coordinates
#
# ## Accepted optional arguments:
#
#   -hpts <filename>
#       Name of the output file. By default the output file name is the 
#       same as the input file name but with the file extension .hpts
#
# Notes:
#
# * First three points in the .csv file are expected to be the NAS, LAP and
#   RAS.
#
# 

# (c) German Gomez-Herrero, german.gomezherrero@ieee.org

use strict;
use meegs;

my $file = shift(@ARGV);

my @args = (@ARGV,qw(-header 0 -x 2 -y 3 -z 4 -category eeg 
					 -cardinals 3 -label 1 -scale 10),'-separator', '\s+');
					 
				 
meegs->dlm2hpts($file,\@args);

exit(0);

