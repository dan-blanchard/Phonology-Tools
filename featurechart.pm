# Feature Chart Class
# by Dan Blanchard

package FeatureChart;

use utf8;
use Encode;

# Constructor
sub new 
{
	my $class = shift;
	$class = ref $class if ref $class;
	my $self = {};
	$self->{'chart'} = ();
	$self->{'features'} = [];
	bless($self, $class);
	return($self);
}

sub read_file 
{
	my @line;
	my $first = 1;
	open FEATURES, shift;
	binmode FEATURES, ":utf8";
	while (<FEATURES>)
	{
		chomp;
		@line = split(/\t/);	
		if (!$first)
		{
			for (my $i = 1; $i < scalar(@line); $i++)
			{
				$self->{'chart'}{$line[0]}{$features[$i]} = $line[$i];
			}
		}
		else
		{
			# read features from first line
			$self->{'features'} = @line;
			$first = 0;
		}
		
	}
	close(FEATURES);
}


1;
