# Feature Chart Class
# by Dan Blanchard

package FeatureChart;

use utf8;
use Encode;
use Text::ASCIITable;
use Set::Scalar;
use warnings;
use strict;
use Readonly;

Readonly::Scalar our $BAD_LEFT => '⟪';
Readonly::Scalar our $BAD_RIGHT => '⟫';

# Setup Unicode input and output
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";
binmode STDERR, ":utf8";

use overload	'""' => \&stringify; # Allows pretty printing of feature chart

# Constructor
sub new 
{
	# Perl constructor stuff
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = {};
	
	# Setup class variables
	$self->{'phonesToFeatures'} = ();
	$self->{'featuresToPhones'} = ();
	$self->{'features'} = [];
	$self->{'outputTable'} = Text::ASCIITable->new({headingText => 'Feature Chart' });
	$self->{'badFeatureCount'} = 0;
	# Sets up pretty printing of feature sets
	my $class_callback = sub { "[" . join(", ",sort $_[0]->elements) . "]" };
	Set::Scalar->as_string_callback($class_callback);
	
	bless($self, $class);
	return($self);
}

sub addLine
{
	my $self = shift;
	my @line = @_;
	my $featureKey = "";
	$self->{'outputTable'}->addRow(@line);
	# print "\nLine: @line\n";
	for (my $i = 1; $i < scalar(@line); $i++)
	{
		if ($line[$i] ne "0")
		{
			$featureKey = $line[$i] . @{$self->{'features'}}[$i-1]; # Stores feature value as +feature or -feature
			# print "\nFeature key: $featureKey\n";
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
		elsif (!exists($self->{'phonesToFeatures'}{$line[0]}))
		{
			$self->{'phonesToFeatures'}{$line[0]} = Set::Scalar->new();						
		}
	}	
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
			$self->addLine(@line);
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
	if (scalar(@featureList) == 0)
	{
		foreach my $phone (keys %{$self->{'phonesToFeatures'}})
		{
			$featureSet->insert($phone);
		}
		return $featureSet;
	}
	# print "Feature list: @_\n";
	my $first = 1;
	for (my $i = 0; $i < scalar(@featureList); $i++)
	{
		$featureList[$i] =~ s/^ //;
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
		my $tempPhone = $BAD_LEFT . $self->{'badFeatureCount'} . $BAD_RIGHT;
		my @tempList = ();
		push(@tempList, $tempPhone);
		my $added;
		foreach my $possibleFeature (@{$self->{'features'}})
		{
			$added = 0;
			foreach my $feature (@featureList)
			{
				if (!$added && (substr($feature,1) eq $possibleFeature))
				{
					push(@tempList, substr($feature,0,1));
					$added = 1;
				}
			}
			if (!$added)
			{
				push(@tempList, "0");
			}
		}
		$self->{'badFeatureCount'}++;
		$self->addLine(@tempList);
		print STDERR "WARNING: There are no phones in your feature chart that match the bundle [" . $featureList[0];
		shift(@featureList);
		foreach my $feature (@featureList)
		{
			print STDERR ", $feature";
		}
		print STDERR "], " . $tempPhone . " represents this feature bundle in the output table.\n";
		$featureSet->insert($tempPhone);
		# exit(0);
	}
	return $featureSet;
}

sub phoneDisjuctionForFeatures
{
	my $self = shift;
	# print "Feature list: @_\n";
	return "(?:" . join("|",$self->phonesForFeatures(@_)->members) . ")";
}

sub featuresForPhone
{
	my $self = shift;
	my $phone = shift;
	my @tempList = ();
	push(@tempList,$phone);
	if (exists($self->{'phonesToFeatures'}{$phone}))
	{
		return $self->{'phonesToFeatures'}{$phone};
	}
	else
	{
		print STDERR "WARNING: Could not find phone '$phone' in feature chart.  Treating as empty feature bundle, which will match anything.\n";		
		foreach my $possibleFeature (@{$self->{'features'}})
		{
			push(@tempList, "0");
		}
		$self->addLine(@tempList);
		return $self->{'phonesToFeatures'}{$phone};
	}
}

sub featureBundleForPhone
{
	my $self = shift;
	my $phone = shift;
	my $bundleLeft = shift;
	my $bundleRight = shift;
	my $bundleDelimiter = shift;
	return $bundleLeft . join($bundleDelimiter,$self->featuresForPhone($phone)->members) . $bundleRight;
}

sub featureBundlesForPhones
{
	my $self = shift;
	my $phones = shift;
	my $phoneDelimiter = shift;
	my $bundleLeft = shift;
	my $bundleRight = shift;
	my $bundleDelimiter = shift;
	my $returnString = "";
	foreach my $phone (split(/\Q$phoneDelimiter\E/,$phones))
	{		
		# print "Phone: $phone\n";
		$returnString = $returnString . ($self->featureBundleForPhone($phone,$bundleLeft,$bundleRight,$bundleDelimiter));
	}
	# print "Return string: $returnString\n";
	return $returnString;
}


sub unifyPhoneFeatures
{
	my $self = shift;
	my $phone = shift;
	# print "Phone: ". $phone . "\n";
	my $newFeatures = Set::Scalar->new();
	my @replacementList = ();
	my %replacementHash = ();
	my $featureKey;
	$newFeatures->insert(@_);
	# print ("New features: $newFeatures\n");
	my $oldFeatures = $self->featuresForPhone($phone);
	# print "Old features: $oldFeatures\n";
	if ($oldFeatures->size == 0)
	{
		return $self->phonesForFeatures($oldFeatures->members)->each;
	}
	while (defined(my $oldFeature = $oldFeatures->each))
	{
		$replacementHash{substr($oldFeature,1)} = substr($oldFeature,0,1);
	}	
	while (defined(my $newFeature = $newFeatures->each))
	{
		$replacementHash{substr($newFeature,1)} = substr($newFeature,0,1);
	}
	foreach $featureKey (keys %replacementHash)
	{
		push(@replacementList,$replacementHash{$featureKey} . $featureKey);
	}
	# print "Replacement list: @replacementList\n";
	return $self->phonesForFeatures(@replacementList)->each;
}

1;
