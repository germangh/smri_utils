#!usr/bin/perl -w
#
# Usage:
#
#	perl meegs_dlm2hpts.pl fileIn [options]
#
# Where:
#
# 	fileIn is the name of the Mango comma delimited file. Alternatively, 
#	fileIn can be the name of a root folder containing Mango .csv files.
#	All files having the tag "mango" and the extension ".csv" will be 
#	converted.
#
# Accepted optional arguments:
#
#   -hpts <filename>
#       Name of the output file. Defaults to the same name as the input 
#       file but with the file extension .hpts
#	
#
#
# Notes:
#
# * First three points in the .csv file are expected to be the NAS, LAP and
#   RAS.
#
# 
# (c) German Gomez-Herrero, german.gomezherrero@ieee.org

use strict;
use MEEGS;

my $root = shift(@ARGV);

my @args = (@ARGV,qw(-header 0 -x 1 -y 2 -z 3 -category hpi -cardinals 0)); 

MEEGS->dlm2hpts($root, \@args);


exit(0);

