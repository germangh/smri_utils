#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: MNE analysis of MRI data
# Documentation: implementation.txt


use Config::IniFiles;
use Getopt::Long;
use File::Spec::Functions;
use Cwd qw(abs_path cwd);
use File::Find;
use List::MoreUtils qw(any);
use File::Temp qw(tempfile);
use File::Path qw(make_path);

use strict;
use warnings;

sub subject_ids($$);

my $help;
my $donothing;
my $ini           = '/etc/SOMSDS.ini';
my @subjects_in;
my $homog;
my $mne = $ENV{'MNE_ROOT'};
my $freesurfer = $ENV{'FREESURFER_HOME'};
my $matlab = $ENV{'MATLAB_ROOT'};

unless ($mne){
  die "The MNE_ROOT environment variable must point to the location of the MNE software";
}

my ($vol, $dir, $file) = File::Spec->splitpath($0);
if (-e abs_path(catfile($dir,'smri.ini'))){
  $ini = abs_path(catfile($dir,'smri.ini'));  
} 

GetOptions("conf=s"             => \$ini,
           "homog=s"            => \$homog,
           "help"               => \$help,
           "donothing"          => \$donothing,
           "subjects|subject=s" => \@subjects_in,
           "mne=s"              => \$mne);
			
my $folder = shift;

if ($help || !$folder){
  print "Usage: smri_mne folder [--]
  
  --subjects      comma-separated list of subjects, e.g. 1,2,5..7
  
  --conf          location of the smri.ini configuration file
  
  --help          displays this help\n";
  die "\n";
}

$folder = File::Spec->rel2abs($folder);

if ($homog){
  $homog = "--homog";
} else {
  $homog = '';
}

# Read configuration file and get the link pattern
my $conf = new Config::IniFiles(-file => $ini);
my $link_name = $conf->val('Recording', 'link_pattern');
my $sep       = $conf->val('Recording', 'field_sep');

# Merge multiple --condition/--field invocations
my $subjects  = join(',', @subjects_in);

# Generate subject ids of the form 000x
my @subjects = ();
if ($subjects){
  my @tmp_subjects = split(/\s*,\s*/, $subjects); 
  foreach (@tmp_subjects){    
    if ($_ =~ m/(\d+)\.\.(\d+)/){      
      my @this_subjects = subject_ids($1, $2);  
      @subjects = (@subjects, @this_subjects);      
    }elsif ($_ =~ m/^\d+$/){
      push @subjects, subject_ids($_, $_);  
    }else{
      push @subjects, $_;    
    }    
  }
}

unless (@subjects){
  opendir (DIR, "$folder/subjects") or die $!;
  while (my $file = readdir(DIR)){
    if ($file =~ m/^\d\d\d\d$/){
      push @subjects, $file;
    }
  }
}

foreach (@subjects){
  unless (-e "$folder/subjects/$_/mri"){next;}
  my $cmd = "export SUBJECTS_DIR=$folder/subjects\n".
            "export SUBJECT=$_\n".            
            "export FSF_OUTPUT_FORMAT=mgz\n". 
            "export FREESURFER_HOME=$freesurfer\n".   
            "source $freesurfer/SetUpFreeSurfer.sh\n".
            "export MNE_ROOT=$mne\n".
            "export MATLAB_ROOT=$matlab\n".
            'PATH=$PATH\:'.$mne.'/bin;export PATH'."\n".
            "source $mne/bin/mne_setup_sh\n".    
            "$mne/bin/mne_setup_mri --overwrite --subject $_\n".
            "$mne/bin/mne_setup_source_space --spacing 7 --cps --overwrite --subject $_\n".
            "$mne/bin/mne_watershed_bem --atlas --overwrite --subject $_\n".
            "ln -s $folder/subjects/$_/bem/watershed/$_"."_inner_skull_surface ".
            "$folder/subjects/$_/bem/inner_skull.surf\n".
            "ln -s $folder/subjects/$_/bem/watershed/$_"."_outer_skull_surface ".
            "$folder/subjects/$_/bem/outer_skull.surf\n".
            "ln -s $folder/subjects/$_/bem/watershed/$_"."_outer_skin_surface ".
            "$folder/subjects/$_/bem/outer_skin.surf\n".
            "$mne/bin/mne_setup_forward_model --surf --ico 4 --subject $_ ".
            $homog."\n".
            "$freesurfer/bin/mkheadsurf -subjid $_"."\n".
            "$mne/bin/mne_surf2bem --surf $folder/subjects/$_/surf/lh.seghead --id 4 --check --fif $folder/subjects/$_/surf/$_"."-head-dense.fif"."\n".
            "mv $folder/subjects/$_/surf/$_"."-head.fif $folder/subjects/$_/surf/$_"."-head-sparse.fif"."\n".
            "ln -s $folder/subjects/$_/surf/$_"."-head-dense.fif $folder/subjects/$_/surf/$_"."-head.fif"."\n".
            "$mne/bin/mne_convert_surface --surf $folder/subjects/$_/bem/$_"."-outer_skin-5120.surf --triout $folder/subjects/$_/bem/$_"."-outer_skin-5120.tri"."\n".
            "$mne/bin/mne_convert_surface --surf $folder/subjects/$_/bem/$_"."-outer_skull-5120.surf --triout $folder/subjects/$_/bem/$_"."-outer_skull-5120.tri"."\n".
            "$mne/bin/mne_convert_surface --surf $folder/subjects/$_/bem/$_"."-inner_skull-5120.surf --triout $folder/subjects/$_/bem/$_"."-inner_skull-5120.tri"."\n".
            "";

  my $fh = File::Temp->new( SUFFIX => '.sh' );
  $fh->unlink_on_destroy(1);
  print $fh "#!/bin/bash\n";
  print $fh $cmd;
  my $fname = $fh->filename;
  unless ($donothing){
    `qsub -N mne-bem-$_ $fname`;
  }
  print $cmd,"\n\n";
}

sub subject_ids($$) {
  my ($first, $last) = (shift, shift);
  my @ids = ();
  for (my $i=$first; $i<=$last; ++$i){
    push @ids, "0"x(4-length("$i"))."$i";    
  }
  @ids;
}


