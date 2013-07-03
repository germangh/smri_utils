#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Uninstalls the smri package
# Documentation: utilities.txt


use Cwd qw(abs_path cwd);
use File::Spec::Functions;
use File::Path qw(remove_tree);

my $def_bin_dir;
my $def_conf_dir;
my $def_module;
if ($^O eq 'darwin'){
  # If we are in Mac OS X
  $def_bin_dir 	= "$ENV{HOME}/bin"; 
  $def_module   = $def_bin_dir;
} else {
	$def_bin_dir  = '/usr/local/bin';
	$def_module   = $def_bin_dir;
}

my $bin_dir = shift;
my $mod_dir = shift;

unless($bin_dir){$bin_dir   = $def_bin_dir;}
unless($mod_dir){$mod_dir   = $def_module;}

print "Removing links from:   $bin_dir\n";
print "Removing module files from:   $mod_dir\n";

my @files = qw(smri_freesurfer smri_freesurfer_mgz smri_mne smri_install smri_uninstall);
my @files_mod = map {catdir($mod_dir, $_.'.pl')} @files;
my @files_bin = map {catdir($mod_dir, $_)} @files;

foreach (@files_bin,@files_mod){ 
  unlink($_) or die "I could not remove $_: $!\n";
  print "unlink $_\n";
};
