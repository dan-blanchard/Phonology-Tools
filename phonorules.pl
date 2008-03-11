#!/usr/bin/perl

# Dan Blanchard
# Phonological Rule Processor

# Usage: ./phonorules [-f <FEATURE CHART FILE>] <RULE FILE> <TEST FILE>

# TODO "n or more" repetitions
# TODO symbols

use strict;
use POSIX;
use utf8;
use Encode;
use Text::ASCIITable;
use Getopt::Std;
use warnings;
use FeatureChart;

our ($opt_f);
getopts('f:');
my @matches = ();
my @replaces = ();
my @originalRules = ();
my @outputColumns = ();
my @columnNames = ();
my @surfaceForms = ( "Surface Forms" );
my @attestedForms = ( "Attested Forms" );
my $col;
my $outputTable = Text::ASCIITable->new();
my $rule;
my $ruleFile = $ARGV[0];
my $testFile = $ARGV[1];
my $match;
my $phoneReplacing;
my $replace;
my $uForm;
my $sForm;
my @line;
my $featureChart;

# Check for feature chart file
if ($opt_f)
{
	$featureChart = FeatureChart->new();
	$featureChart->read_file($opt_f);
	# print $featureChart;	
}

# Setup Unicode input and output
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";
binmode STDERR, ":utf8";

# Read rule file
open RULES, $ruleFile;
binmode RULES, ":utf8";
my $temp;
while (<RULES>)
{
	chomp;
	$rule = $_;
	$rule =~ s/%.*$//;
	if ($rule ne "")
	{	
		$rule =~ s/\s+//g;	# remove extra whitespace
		$rule =~ s/0/∅/g;	# pretty-print empty sets
		if ($rule =~ m/^(\X+)?(?:(?:->)|➔)(\X+)?(?:(?:\/)|(?:╱))(\X+)?_(\X+)?$/)			
		{
			no warnings;
			$match = "($3)($1)($4)";
			$replace = "\$1$2\$3";
			$match =~ s/∅//g; # insertions
			if ($opt_f)
			{
				if ($match =~ m/\[(\X+)\]/)
				{					
					$temp = $match;
					# The mess below converts features to disjunctions of phones that match those features
					$temp =~ s{\[([^\[]+)\]}
								{$featureChart->phoneDisjuctionForFeatures(split(/,/,$1))}eg;
				}							
				if ($replace =~ m/\[(\X+)\]/)
				{
					$temp = $replace;
					$temp =~ s{\[([^\[]+)\]}
								{$featureChart->phoneDisjuctionForFeatures(split(/,/,$1))}eg;
				}
			}
			$match =~ s/\(#(\X+)?\)(\X+)\((\X+)?\)/\^($1)$2($3)/g; # word boundary at beginning
			$match =~ s/#/\$/g; # word boundary at end
			$replace =~ s/∅//g;	# don't actually want empty sets in replacement string
			# More Pretty-Printing Stuff #		
			$rule =~ s/➔/ ➔ /g;	
			$rule =~ s/->/ ➔ /g;
			$rule =~ s/╱/ ╱  /g;
			$rule =~ s/\// ╱  /g;
			push(@matches,$match);
			push(@replaces,$replace);
			push(@originalRules,$rule);
		}
	}
}
close (RULES);

# Setup rule column
push(@columnNames,"");
$col = $originalRules[0];
for (my $i = 1; $i < scalar(@originalRules); $i++)
{
	$col = $col . "\n" . $originalRules[$i];
}
push(@outputColumns,$col);
$outputTable->setOptions('drawRowLine',1);

# Read test file
open TEST, $testFile;
binmode TEST, ":utf8";
while (<TEST>)
{
	chomp;
	$_ =~ s/%.*$//;
	if ($_ ne "")
	{
		@line = split(/\t/);
		$uForm = $line[0];
		$uForm =~ s/\s+//g;	
		if (scalar(@line) == 2)
		{
			$sForm = $line[1];
		}
		else
		{
			$sForm = "";
		}
		$sForm = $line[1];
		$sForm =~ s/\s+//g;	
		if ($uForm ne "")
		{	
			push(@columnNames, $uForm);					
			$uForm =~ s/\+//g;
			$col = "";
			for (my $i = 0; $i < scalar(@matches); $i++)
			{
				$match = $matches[$i];
				# print "Match: $match\n";
				# print "Replace: $replaces[$i]\n";
				if ($opt_f)
				{
					# The mess below converts features to disjunctions of phones that match those features
					$match =~ s{\[([^\[]+)\]}
								{$featureChart->phoneDisjuctionForFeatures(split(/,/,$1))}eg;
				}
				if ($uForm =~ m/$match/)
				{
					$phoneReplacing = $2;
					# The mess below looks up features of phones, intersects them with those specified in $replace, and then returns the first phone that satisfies that
					my $tempReplace = $replaces[$i];
					if ($opt_f)
					{
						$tempReplace =~ s{\[(\X+)\]}
											{$featureChart->unifyPhoneFeatures($phoneReplacing,split(/,/,$1))}ge;						
					}
					
					# print "Phone being replaced: $phoneReplacing\n";
					# print "Altered replace: $tempReplace\n";
					$replace = "\"$tempReplace\"";
					$uForm =~ s/$match/$replace/gee;						
					$col = $col . $uForm . "\n";
				}
				else
				{
					$col = $col . "-\n";
				}			
			}
			if (($uForm ne $sForm) && ($sForm ne ""))
			{
				$uForm = "*$uForm";
			}
			push(@surfaceForms, $uForm);
			push(@attestedForms, $sForm);
			push(@outputColumns, $col);
		}
	}
}
close (TEST);

# Build output table
$outputTable->setCols(@columnNames);
$outputTable->addRow(@outputColumns);
$outputTable->addRow(@surfaceForms);
$outputTable->addRow(@attestedForms);
if ($opt_f)
{
	print $featureChart;
}
print "\n$outputTable\n";