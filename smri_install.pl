#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Installs the smri package
# Documentation: utilities.txt


use Cwd qw(abs_path cwd);
use File::Spec::Functions;
use File::Copy::Recursive qw(dircopy);
use File::Copy;

my $bin_dir = shift;
my $mod_dir = shift;

my $def_bin_dir;
my $def_module;
if ($^O eq 'darwin'){
  # If we are in Mac OS X
  $def_bin_dir 	= "$ENV{HOME}/bin"; 
  $def_module   = "$ENV{HOME}/bin";
} else {
	$def_bin_dir  = '/usr/local/bin';
	$def_module   = '/usr/local/bin';
}

unless($bin_dir){$bin_dir = $def_bin_dir;}
unless($mod_dir){$mod_dir = $def_module;}

print "Installing links to: $bin_dir\n";
print "Copying module files to: $mod_dir\n";
        
# Copy scripts to the bin directory
foreach (qw(smri_mne smri_freesurfer smri_freesurfer_mgz smri_uninstall smri_install)){
  my $file = catfile($mod_dir, $_.'.pl');
  copy($_.'.pl', $file) or die "Copy $_.pl -> $file failed: $!";
  print "copy $_.pl $file\n";
  chmod (0755, $file) or die "Coudn't chmod $file: $!";  
  my $link_name = catfile($bin_dir, $_);
  symlink $file, $link_name or die "Couldn't create link $link_name: $!";
  print "symlink $file $link_name\n";
}

