# meegs.pm
#
# Perl utilities for M/EEG source analysis
# Written by German Gomez-Herrero <german.gomezherrero@ieee.org>
#
# Revision: 23-05-2011
# Created: 23-05-2011


use strict;
package meegs;

our $VERSION = 0.1;





# -----------------------------------------------------------------------------
# Ensures CRLR ends of lines
sub fix_nl
{
	shift(@_);
	my($fileIn, $fileOut) = @_;
	
	defined(my $csvFile = shift(@_)) || 
		die ":: Error: A file name is expected as input argument ::";
	
	if (!defined($fileOut))
	{
		$fileOut = $fileIn;
		$fileOut =~ s/^([^.]+)(.*)/$1_fix_nl$2/ig;
	}
	
	open(IN, "<$fileIn")
		|| die ":: Error: Cannot open file $fileIn ::";
		
	open(OUT, ">$fileOut")
		|| die ":: Error: Cannot open file $fileOut ::";
		
	$/="\r";	
	while (<IN>)
	{
		chomp;				
	    print OUT $_."\n";		
	}
    close(IN);
	close(OUT);
}
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Processes input arguments and returns them in a hash array having
# parameter names as keys and corresponding values.
#
# Usage:
#	my $newArgs = meegs->process_arguments($defArgs, $inputArgs);
#
#
# Where:
#
#	$defArgs is a reference to a hash containing argument names and
#	default values.
#
#	$inputArgs is a reference to the @ARGV array of the calling function
#
#	$newArgs is a reference to a hash containing a list of argument names and
#	correponding user-defined values or, in their absence, default values.
#
sub process_arguments
{
	shift(@_);
	my($defArg, $argv) = @_;
	
	# Convert array argv to a hash array
	my %args;
	my $count = 0;
	while ($argv->[$count])
	{	
		$args{$argv->[$count]} = $argv->[$count+1];
		$count = $count + 2;
	}
	
	my($key, $value);
	while (($key, $value) = each(%args))
	{			
		$defArg->{$key} = $value;					
	}	
	return ($defArg);
}
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Generates .tri equivalents of all the Freesurfer BEM surfaces within a 
# folder structure. It assumes the file tags and directory structure 
# generated by the MNE toolbox
sub surf2tri
{
	use meegs;
    use Cwd;
	use File::Find;

	shift(@_);
	my $root = shift(@_);

	# Default options	
	my $defArgs = {-regexp => '^[^.].+_surf$'};
	
	# Override default options with user-defined values
	my $args = meegs->process_arguments($defArgs, $_[0]);		
    my $baseDir = cwd();
	find(
		sub
		{
			if ($File::Find::name =~ m/$args->{-regexp}/)
			{	
				surf2tri1($baseDir);
			}
		},
		$root
	);	
}

sub surf2tri1
{	
	use File::Find;
	use File::Spec;
	use Cwd;
	my $baseDir = shift;
	my $file = File::Spec->rel2abs($File::Find::name, $baseDir);	    
	my $triFile = $file;
	$triFile =~ s/^([^.]+)(.*)/$1.tri/ig;		
	system("mne_convert_surface --surf $file --triout $triFile");
	my ($volume, $directories, $name) = File::Spec->splitpath( $triFile );
	print $file." -> ".$name."\n\n";	
}


# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Converts a comma delimited file with point ROI coordinates (as generated
# e.g. by Mango) into a .hpts file that the MNE toolbox can read. This 
# function can also be used to convert .sfp files to .htps format.
#
# Usage:
#	dlm2hpts($args)
#
# Where: 	
#
#	$args is a reference to the @ARGV array from the calling function
#
#	-header <nrows>
#		Number of header rows. Default: 2
#
#   -x <xcolidx>
#       Index of the column containing the X coordinates. Def: 5
#
#   -y <ycolidx>
#       Index of the column containing the Y coordinates. Def: 6
#
#   -z <zcolidx>
#       Index of the column containing the Z coordinates. Def: 7
#
#   -label <labelcolidx>
#       Index of the column containing the point labels. Def: undef
#
#   -hpts <filename>
#       Name of the output file. Defaults to the same name as the input 
#       file but with the file extension .hpts
#
#	-category <cat>
#		Allowed categories are hpi, cardinal, eeg and extra. The first three
#		points are automatically assumed to be cardinals.
#
#	-separator <regexp>
#		Regular expression that matches the column separators. Def: "\s*,\s*"
#
#	-cardinals <#card>
#		Number of cardinal points in the file. The cardinal points will be
#		assumed to be at the beginning of the file. Def: 3
#
# Notes:
#
# * First three points in the .csv file are expected to be the NAS, LAP and
#   RAS.
#
# * The indices of the x, y, and z columns can be negative, in which case the
#	sign of the corresponding coordinates will be inverted before writing them 
#	to the output .hpts file.
#
sub dlm2hpts
{
	use meegs;
	use File::Find;

	shift(@_);
	my $root = shift(@_);
	my $argv = shift(@_);
	
	# Default options	
	my $defArgs = {-regexp => '.*'};
	
	# Override default options with user-defined values	
	my $args = meegs->process_arguments($defArgs, $argv);		

	find(
		sub
		{			
			if ($File::Find::name =~ m/$args->{-regexp}/)
			{									
				dlm2hpts1($argv);				
			}
		},
		$root
	);		
}



sub dlm2hpts1
{		
	use File::Find;
    use File::Spec;
    use meegs;
		
	#shift(@_);
	my $csvFile = $File::Find::name; 
	
	# Default options#
	my $hptsFile = $csvFile;
	$hptsFile =~ s/(\.\w+)$/.hpts/ig;
	my $defArgs = {-header => 2, 
		-x => 5, 
		-y => 6, 
		-z => 7, 
		-hpts => $hptsFile, 
		-category => "eeg", 
		-separator => '"\s*,\s*"',
		-cardinals => 3, 
		-label => undef, 
		-scale => 1};	
	# Override default options with user-defined values	
	my $args = meegs->process_arguments($defArgs, $_[0]);
    
	open(CSV, "<$csvFile")
		|| die ":: Error: Cannot open file $csvFile ::";
		
	open(HPTS, ">$args->{-hpts}")
		|| die ":: Error: Cannot open file $hptsFile ::";		

	# Skip header
	my $lineCount = 0;		
	while(($lineCount++ < $args->{-header}) && (<CSV>)){}
	
	# Add a comment to the header of the generated file
	my $format = "%-15s%13s%13.2f%13.2f%13.2f\n";
    my $absCsvFile = File::Spec->rel2abs($csvFile);
	print HPTS 	"# \n",
				"# This file has been generated from\n",
                "# $absCsvFile\n",
				"# using meegs_csv2hpts\n", 
				"# \n";
    my $formatHeader = $format; 
	$formatHeader =~ s/d/s/ig;
	$formatHeader =~ s/.\d+f/s/ig;
	printf HPTS $formatHeader, '# <category>', '<identifier>', '<x/mm>', 
				'<y/mm>', '<z/mm>';
				
	# Determine the signs of the axes
	my($x, $y, $z)=(1, 1, 1);
	if ($args->{-x} < 0){$x = -1};
	if ($args->{-y} < 0){$y = -1};
	if ($args->{-z} < 0){$z = -1};
	
	# Read cardinal points
	my $count = 0;
	my @line;
	my $label;
	$/ = "\n";		
	while (($count++ < $args->{-cardinals}) && 
		(@line = split(/$args->{-separator}/, <CSV>, -1)))
	{			
		if (!defined($args->{-label}) || !defined($line[$args->{-label}-1]))
		{	
			$label = $count;
		}
		else
		{
			$label = $line[$args->{-label}-1];				
		}		
		
		printf HPTS $format,'  cardinal', 
			$label,
			$args->{-scale}*$x*$line[abs($args->{-x})-1],
			$args->{-scale}*$y*$line[abs($args->{-y})-1],
			$args->{-scale}*$z*$line[abs($args->{-z})-1];	
	}
	
	# Read all other points
	while (<CSV>)
	{		
		@line = split(/$args->{-separator}/, $_, -1);	
		if (!defined($args->{-label}) || !defined($line[$args->{-label}-1]))
		{	
			$label = $count;
		}
		else
		{
			$label = $line[$args->{-label}-1];				
		}
		printf HPTS $format,'  '.$args->{-category}, 
			$label,
			$args->{-scale}*$x*$line[abs($args->{-x})-1], 
			$args->{-scale}*$y*$line[abs($args->{-y})-1],
			$args->{-scale}*$z*$line[abs($args->{-z})-1];	
		$count++;	
	}
    close(CSV);
	close(HPTS);
	print $csvFile." -> ".$hptsFile."\n";

}
# -----------------------------------------------------------------------------