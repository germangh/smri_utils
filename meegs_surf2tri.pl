#!/usr/bin/perl -w
#
# Usage:
#
#	perl meegs_surf2tri.pl folder [options]
#
# Where:
#
# 	folder is the name of the root folder under which the Freesurfer files
#	should be searched for
#
# Accepted options:
#
#	-regexp <regexp> 
#		Regular expression that will be used to match the Freesurfer 
#		files. By default regexp=^[^.].+_surf$
#

# (c) German Gomez-Herrero, german.gomezherrero@ieee.org

use strict;
use meegs;


my $root = shift(@ARGV);

my @args = (@ARGV,'-regexp','^[^.]+_surface$');

meegs->surf2tri($root,\@args);


exit(0);
