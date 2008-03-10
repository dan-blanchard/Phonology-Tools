# Feature Chart Class
# by Dan Blanchard

package FeatureChart;

use utf8;
use Encode;
use Text::ASCIITable;
use Set::Scalar;

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
					if (exists($self->{'featuresToPhones'}{$self->{'features'}[$i]}))
					{
						$self->{'featuresToPhones'}{$features[$i]} = push($self->{'featuresToPhones'}{$features[$i]},$line[0])
					}					
				}
			}
		}
		else
		{
			# read features from first line
			$self->{'outputTable'}->setCols(@line);
			shift(@line);
			$self->{'features'} = @line;
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

sub phoneForFeatures
{
	$self->
}


1;
