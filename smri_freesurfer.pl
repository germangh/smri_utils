#!/usr/bin/perl
# (c) German Gomez-Herrero, g.gomez@nin.knaw.nl

# Description: Runs freesurfer recon-all
# Documentation: implementation.txt


use Config::IniFiles;
use Getopt::Long;
use File::Spec::Functions;
use Cwd qw(abs_path cwd);
use File::Find;
use List::MoreUtils qw(any);
use File::Temp qw(tempfile);
use File::Path qw(make_path remove_tree);
use File::Copy::Recursive qw(dircopy);

use strict;
use warnings;

sub subject_ids($$);


my $help;
my $donothing;
my $ini           = '/etc/SOMSDS.ini';
my @subjects_in;
my $mod;
my $dev;
my $tec;
my $sess;
my $queue;
my $hostname;
my $copyfsavg;
my $freesurfer = $ENV{'FREESURFER_HOME'};
my $file_ext      = '.nii.gz';

unless ($freesurfer){
  die "The FREESURFER_HOME environment variable must point to the location of the MNE software";
}

my ($vol, $dir, $file) = File::Spec->splitpath($0);
if (-e abs_path(catfile($dir,'smri.ini'))){
  $ini = abs_path(catfile($dir,'smri.ini'));  
} 

GetOptions("conf=s"             => \$ini,
           "help"               => \$help,
           "copyfsavg"          => \$copyfsavg, 
           "donothing"          => \$donothing,
           "subjects|subject=s" => \@subjects_in,
           "modality=s"         => \$mod,
           "queue=s"            => \$queue,
           "hostname=s"         => \$hostname,
           "device=s"           => \$dev,
           "technique=s"        => \$tec,
           "session=s"          => \$sess, 
           "freesurfer=s"       => \$freesurfer);
			
my $folder = shift;

if ($help || !$folder){
  print "Usage: smri_freesurfer subjfolder [--]
  
  --copyfsavg     do not run recon-all but simply copy the fsaverage folders.

  --subjects      comma-separated list of subjects, e.g. 1,2,5..7

  --modality      code of the structural MRI modality. Default: smri

  --device        device to consider, e.g. siemens-trio

  --technique     code of the structural MRI technique to use for the freesurfer
                  analysis. Default: t1

  --fileext       file extensions to be considered. Default: .nii.gz

  --conf          location of the smri.ini configuration file

  --queue         name of the OGE queue to use

  --hostname      host name

  --help          displays this help\n";
  die "\n";
}

$folder = File::Spec->rel2abs($folder);

# Read configuration file and get the link pattern
my $conf = new Config::IniFiles(-file => $ini);
my $link_name = $conf->val('link', 'name');
my $sep       = $conf->val('link', 'field_sep');

unless ($mod){$mod=$sep};
unless ($dev){$dev=$sep};
unless ($tec){$tec=$sep};
unless ($sess){$sess=$sep};

unless ($queue || $hostname){
    $queue = 'verylong.q';
}

# Merge multiple --condition/--field invocations
my $subjects  = join(',', @subjects_in);

# By default, analyze ALL subjects
unless ($subjects){
  $subjects = '0..9999';
}

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

foreach (qw(RECID CONDID BLKID META)){
  $link_name =~ s/$_/$sep/g;
}

$link_name         =~ s/MODID/$mod/g;
$link_name         =~ s/DEVID/$dev/g;
$link_name         =~ s/TECID/$tec/g;
$link_name         =~ s/SESSID/$sess/g;
$link_name         =~ s/(\s+)/$sep/g;
$link_name         =~ s/($sep{2,})/.*/g;
$link_name         = $link_name.$file_ext;

my @links;
if (@subjects){
  foreach (@subjects){
    my $this_link_name = $link_name;
    $this_link_name =~ s/SUBJID/$_/g;
    push @links, $this_link_name;
  }
}else{
  $link_name         =~ s/SUBJID/$sep/g;
  $link_name         =~ s/($sep{2,})/.*/g;
  push @links, $link_name;
}

##print join(',',@links),"\n";
my $sub_regex = '^.+(\d\d\d\d).+$';

# Scan the folder structure and run freesurfer
unless ($copyfsavg){
  find(
    	  sub 
    	  {
  	  	  freesurfer(\@links, $sub_regex, $donothing);
  	    },
  	    $folder
  ); 
}

# To make the freesurfer folder fully portable
if ($copyfsavg){
  foreach (qw(fsaverage lh.EC_average rh.EC_average)){
    my $from = catdir($freesurfer, 'subjects', $_);
    my $to   = catdir($folder, $_);
    print "rm -rf $to\n";
    print "Are you sure you want to proceed (y/N)? ";
    my $resp = <>;
    if ($resp =~ m/^[yY]$/){
      remove_tree($to, {safe => 1, verbose=>1});
      print "copy $from $to\n";
      my $noCopied = dircopy($from, $to);
      print "$noCopied files/directories were copied\n";
    }
  }
}


sub freesurfer($$){
  # Runs recon-all for each subject
  my ($links, $regex, $donothing) = (shift, shift, shift);
  my $fname = $File::Find::name;
  unless ((any {$fname=~m/^$_$/} @$links)){return;}
  my $path = catdir($File::Find::dir, '../../mri/orig');
  make_path $path;
  my $mgz_name = $fname;
  $mgz_name =~ s|^(.+)/smri/.*/+([^/.]+)\..+$|$1/mri/orig/001.mgz|;
  print "mkdir $path\n";
  my $subject = $fname;
  $subject =~ s/$regex/$1/;
  my $root_path = $File::Find::dir;
  $root_path =~ s%^(.+/subjects)/.+$%$1%;

  my $cmd = "export FSF_OUTPUT_FORMAT=mgz\n". 
            "export FREESURFER_HOME=$freesurfer\n".            
            "source $freesurfer/SetUpFreeSurfer.sh\n".
            "mri_convert -i $fname -o $mgz_name\n".
            "recon-all -all -no-isrunning -qcache -subjid $subject -cortparc -cortparc2 -parcstats".
            " -parcstats2 -sd $root_path\n".
            "export SUBJECTS_DIR=$root_path\n".
            "mkheadsurf -subjid $subject";
  my $fh = File::Temp->new( SUFFIX => '.sh' );
  $fh->unlink_on_destroy(1);
  print $fh "#!/bin/bash\n";
  print $fh $cmd;
  $fname = $fh->filename;
  my $options =' ';
  if ($hostname){
    $options  = $options."-l hostname=$hostname ";
  }
  if ($queue){
    $options = $options."-q $queue ";
  }
  unless ($donothing){
    `qsub $options -N recon-all-$subject $fname`;
  }
  print $cmd,"\n\n";
}

sub subject_ids($$) {
  # Creates a list of subject IDs
  my ($first, $last) = (shift, shift);
  my @ids = ();
  for (my $i=$first; $i<=$last; ++$i){
    push @ids, "0"x(4-length("$i"))."$i";    
  }
  @ids;
}


