# Feature Chart Class
# by Dan Blanchard

package FeatureChart;

use utf8;
use Encode;
use Text::ASCIITable;
use Set::Scalar;
use warnings;
use strict;

# Constructor
sub new 
{
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = {};
	$self->{'phonesToFeatures'} = ();
	$self->{'featuresToPhones'} = ();
	$self->{'features'} = [];
	$self->{'outputTable'} = Text::ASCIITable->new({headingText => 'Feature Chart' });
	bless($self, $class);
	return($self);
}

sub read_file 
{
	my $self = $_[0];
	my @line;
	my $first = 1;
	my $featureKey = "";
	open FEATURES, $_[1];
	binmode FEATURES, ":utf8";
	while (<FEATURES>)
	{
		chomp;
		@line = split(/\t/);	
		if (!$first)
		{
			$self->{'outputTable'}->addRow(@line);
			for (my $i = 1; $i < scalar(@line); $i++)
			{
				$self->{'phonesToFeatures'}{$line[0]}{$self->{'features'}[$i-1]} = $line[$i];
				if ($line[$i] ne "0")
				{
					$featureKey = $line[$i] . @{$self->{'features'}}[$i-1]; # Stores feature value as +feature or -feature
					if (exists($self->{'featuresToPhones'}{$featureKey}))
					{
						$self->{'featuresToPhones'}{$featureKey}->insert($line[0]);
					}					
					else
					{
						$self->{'featuresToPhones'}{$featureKey} = Set::Scalar->new([$line[0]]);
					}
				}
			}
		}
		else
		{
			# read features from first line
			$self->{'outputTable'}->setCols(@line);
			shift(@line);
			push(@{$self->{'features'}}, @line);
			$first = 0;
		}
		
	}
	close(FEATURES);
}

sub output
{
	my $self = $_[0];
	print $self->{'outputTable'};
}

sub phonesForFeatures
{
	my $self = shift;
	my @featureList = @_;
	my $featureSet = Set::Scalar->new();
	my $first = 1;
	for (my $i = 1; $i < scalar(@featureList); $i++)
	{
		if (exists($self->{'featuresToPhones'}{$featureList[$i]}))
		{
			if (!$first)
			{
				$featureSet = $featureSet->intersect($self->{'featuresToPhones'}{$featureList[$i]});				
			}
			else
			{
				$featureSet = $featureSet->union($self->{'featuresToPhones'}{$featureList[$i]});				
				$first = 0;
			}
		}
		else
		{
			print "ERROR:\tUnknown feature '$featureList[$i]'\n";
			exit(0);
		}
	}
	if ($featureSet->size == 0)
	{
		print "ERROR: There are no segments in your feature chart that meet the specified criteria.\n";
		exit(0);
	}
	return $featureSet->members();
}


1;
