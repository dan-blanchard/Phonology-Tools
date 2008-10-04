#!/usr/bin/perl

# Dan Blanchard
# Feature Chart Query Maker

use strict;
use POSIX;
use utf8;
use Encode;
use Text::ASCIITable;
use Getopt::Std;
use warnings;
use featurechart;
use Readonly;

# Special Characters
Readonly::Scalar my $WORD_BOUNDARY => '#';
Readonly::Scalar my $MORPHEME_BOUNDARY => '+';
Readonly::Scalar my $PHONEME_BOUNDARY => ' ';
Readonly::Scalar my $LEFT_OPTIONAL => '(';
Readonly::Scalar my $RIGHT_OPTIONAL => ')';
Readonly::Scalar my $LEFT_DISJUNCTIVE => '{';
Readonly::Scalar my $RIGHT_DISJUNCTIVE => '}'; 
Readonly::Scalar my $DELIMITER_DISJUNCTIVE => ',';
Readonly::Scalar my $EMPTY_SET_ASCII => '0';
Readonly::Scalar my $EMPTY_SET_UNICODE => '∅';
Readonly::Scalar my $ARROW_ASCII => "->";
Readonly::Scalar my $ARROW_UNICODE => '➔';
Readonly::Scalar my $SLASH_ASCII => '/';
Readonly::Scalar my $SLASH_UNICODE => '╱';
Readonly::Scalar my $PLACE_MARKER => '_';
Readonly::Scalar my $LEFT_FEATURE_BUNDLE => '[';
Readonly::Scalar my $RIGHT_FEATURE_BUNDLE => ']'; 
Readonly::Scalar my $DELIMITER_FEATURE_BUNDLE => ',';
Readonly::Scalar my $EMPTY_CELL => '-';
Readonly::Scalar my $ZERO_OR_MORE => '*';
Readonly::Scalar my $DELIMITER_PHONEME => ',';

# Global variables
my $featureFile = $ARGV[0];
my $inventoryFile = "";
if (scalar(@ARGV) > 1)
{
	$inventoryFile = $ARGV[1];
}
my $featureChart;
my $phonemes;

# Setup Unicode input and output
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";
binmode STDERR, ":utf8";


# Read in feature chart
$featureChart = FeatureChart->new();
if ($inventoryFile ne "")
{
	$featureChart->read_file($featureFile,$inventoryFile);	
}
else
{
	$featureChart->read_file($featureFile);
}

sub findCommonFeatures
{
	my @phonemeList = @_;
	my $currentFeatureSet = Set::Scalar->new();
	my $nextFeatureSet;
	my $nextPhoneme;
	my $difference = 0;
	if (scalar(@phonemeList) > 1)
	{
		# print "Phoneme list: @phonemeList\n";
		for (my $i = 0; $i < (scalar(@phonemeList) - 1); $i++)
		{	
			if (substr($phonemeList[$i+1],0,1) eq "-")
			{
				$nextPhoneme = substr($phonemeList[$i+1], 1);
				$difference = 1;
			}
			else
			{
				$nextPhoneme = $phonemeList[$i+1];
				$difference = 0;				
			}
			$nextFeatureSet = Set::Scalar->new(split(",",substr($featureChart->featuresForPhone($nextPhoneme),1,-1)));
			# print "Next feature set: $nextFeatureSet\n";
			if ($currentFeatureSet->is_empty)
			{
				$currentFeatureSet = Set::Scalar->new(split(",",substr($featureChart->featuresForPhone($phonemeList[$i]),1,-1)));
			}			
			if ($difference == 0)
			{
				$currentFeatureSet = $currentFeatureSet->intersection($nextFeatureSet);						
			}
			else
			{
				# Added to correctly handle case where user enters an invalid phoneme
				if (!$nextFeatureSet->is_empty)
				{
					$currentFeatureSet = $currentFeatureSet->difference($nextFeatureSet);											
				}
				else
				{
					$currentFeatureSet = $currentFeatureSet->empty;
				}
			}
		}
	}
	else
	{	
		$currentFeatureSet = Set::Scalar->new(split(",",substr($featureChart->featuresForPhone($phonemeList[0]),1,-1)))
	}	
	return $currentFeatureSet . "\nMatching Phones: " . substr($featureChart->phonesForFeatures($currentFeatureSet->members),1,-1);
}

# Expects comma-separated list of phonemes with minuses in front of features to be eliminated.  Can't have minus infront of first one.
print "Enter phonemes to see their common features [CTRL-D to quit]: ";	
while ($phonemes = <STDIN>)
{
	chomp $phonemes;
	if (substr($phonemes, 0, 1) eq "[")
	{
		print substr($featureChart->phonesForFeatures(split($DELIMITER_FEATURE_BUNDLE,substr($phonemes,1,-1))),1,-1) . "\n\n";
	}
	else
	{
		print findCommonFeatures(split($DELIMITER_PHONEME,$phonemes)) . "\n\n";		
	}
	print "Enter phonemes to see their common features [CTRL-D to quit]: ";	
}