# Feature Chart Class
# by Dan Blanchard

package FeatureChart;

use utf8;
use Encode;
use Text::ASCIITable;
use Set::Scalar;
use warnings;
use strict;

use overload	'""' => \&stringify; # Allows pretty printing of feature chart

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
	
	# Sets up pretty printing of feature sets
	my $class_callback = sub { "[" . join(", ",sort $_[0]->elements) . "]" };
	Set::Scalar->as_string_callback($class_callback);
	
	bless($self, $class);
	return($self);
}

sub read_file 
{
	my $self = shift;
	my @line;
	my $first = 1;
	my $featureKey = "";
	open FEATURES, $_[0];
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
				if ($line[$i] ne "0")
				{
					$featureKey = $line[$i] . @{$self->{'features'}}[$i-1]; # Stores feature value as +feature or -feature
					# Map phonemes to features
					if (exists($self->{'phonesToFeatures'}{$line[0]}))
					{
						$self->{'phonesToFeatures'}{$line[0]}->insert($featureKey);
					}
					else
					{
						$self->{'phonesToFeatures'}{$line[0]} = Set::Scalar->new($featureKey);						
					}
					# Map features to phonemes
					if (exists($self->{'featuresToPhones'}{$featureKey}))
					{
						$self->{'featuresToPhones'}{$featureKey}->insert($line[0]);
					}					
					else
					{
						$self->{'featuresToPhones'}{$featureKey} = Set::Scalar->new($line[0]);
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

sub stringify
{
	my $self = shift;
	return sprintf "%s", $self->{'outputTable'};
}

sub phonesForFeatures
{
	my $self = shift;
	my @featureList = @_;
	my $featureSet = Set::Scalar->new();
	my $first = 1;
	for (my $i = 0; $i < scalar(@featureList); $i++)
	{
		if (exists($self->{'featuresToPhones'}{$featureList[$i]}))
		{
			if (!$first)
			{
				$featureSet = $featureSet->intersection($self->{'featuresToPhones'}{$featureList[$i]});				
			}
			else
			{
				$featureSet = $featureSet->union($self->{'featuresToPhones'}{$featureList[$i]});				
				$first = 0;
			}
		}
		else
		{
			print STDERR "ERROR:\tUnknown feature '$featureList[$i]'\n";
			exit(0);
		}
	}
	if ($featureSet->size == 0)
	{
		print STDERR "ERROR: There are no phones in your feature chart that meet the specified criteria [" . $featureList[0];
		shift(@featureList);
		foreach my $feature (@featureList)
		{
			print STDERR ", $feature";
		}
		print STDERR "]\n";
		exit(0);
	}
	return $featureSet;
}

sub phoneDisjuctionForFeatures
{
	my $self = shift;
	return "(?:" . join("|",$self->phonesForFeatures(@_)->members) . ")";
}

sub featuresForPhone
{
	my $self = shift;
	if (exists($self->{'phonesToFeatures'}{$_[0]}))
	{
		return $self->{'phonesToFeatures'}{$_[0]};
	}
	else
	{
		print STDERR "ERROR: Could not find phone '$_[0]' in feature chart.\n";
		exit(0);
	}
}

sub adjustPhoneFeatures
{
	my $self = shift;
	my $phone = shift;
	# print "Phone: ". $phone . "\n";
	my $newFeatures = Set::Scalar->new();
	my @replacementList = [];
	$newFeatures->insert(@_);
	# print ("New features: $newFeatures");
	my $oldFeatures = $self->featuresForPhone($phone);
	while (defined(my $oldFeature = $oldFeatures->each))
	{
		while (defined(my $newFeature = $newFeatures->each))
		{
			if (substr($oldFeature,1) eq substr($newFeature,1))
			{
				push(@replacementList,$newFeature);
			}
			else
			{
				push(@replacementList,$oldFeature);
			}
		}
	}
	return @{$self->phonesForFeatures(@replacementList)}[0]
}

1;
