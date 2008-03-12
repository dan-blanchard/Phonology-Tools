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
use Readonly;

# Special Characters
Readonly::Scalar my $WORD_BOUNDARY => '#';
Readonly::Scalar my $MORPHEME_BOUNDARY => '+';
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

# Command-line arguments
our ($opt_f);
getopts('f:');

# Global variables
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
my $tempForm;
my $sForm;
my @line;
my $featureChart;

# Tests for lowercase greek letters, such as those used as feature-value variables
sub IsGreekLower 
{
	return <<'END';
+utf8::Greek
&utf8::LowercaseLetter
END
}

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
		$rule =~ s/\Q$EMPTY_SET_ASCII\E/$EMPTY_SET_UNICODE/g;	# pretty-print empty sets
		if ($rule =~ m/^(\X+)?(?:(?:\Q$ARROW_ASCII\E)|\Q$ARROW_UNICODE\E)(\X+)?(?:(?:\Q$SLASH_ASCII\E)|(?:\Q$SLASH_UNICODE\E))(\X+)?\Q$PLACE_MARKER\E(\X+)?$/)			
		{
			no warnings;
			push(@originalRules,$rule);
			$rule =~ s/\Q$LEFT_OPTIONAL\E/\(\?:/g; # Properly formats optional sections of rules
			$rule =~ s/\Q$RIGHT_OPTIONAL\E/\)\?/g;
			$rule =~ m/^(\X+)?(?:(?:\Q$ARROW_ASCII\E)|\Q$ARROW_UNICODE\E)(\X+)?(?:(?:\Q$SLASH_ASCII\E)|(?:\Q$SLASH_UNICODE\E))(\X+)?\Q$PLACE_MARKER\E(\X+)?$/; # Have to do this after optional rule fixing
			$match = "($3)($1)($4)";
			$replace = "\$1$2\$3";
			$match =~ s/\Q$EMPTY_SET_UNICODE\E//g; # insertions
			print "Match: $match\n";
			if ($opt_f)
			{
				if ($match =~ m/\Q$LEFT_FEATURE_BUNDLE\E(\X+)\Q$RIGHT_FEATURE_BUNDLE\E/)
				{					
					$temp = $match;
					# The mess below converts features to disjunctions of phones that match those features
					$temp =~ s{\Q$LEFT_FEATURE_BUNDLE\E([^\Q$LEFT_FEATURE_BUNDLE\E]+)\Q$RIGHT_FEATURE_BUNDLE\E}
								{$featureChart->phoneDisjuctionForFeatures(split(/$DELIMITER_FEATURE_BUNDLE/,$1))}eg;
				}							
				if ($replace =~ m/\Q$LEFT_FEATURE_BUNDLE\E(\X+)\Q$RIGHT_FEATURE_BUNDLE\E/)
				{
					$temp = $replace;
					$temp =~ s{\Q$LEFT_FEATURE_BUNDLE\E([^\Q$LEFT_FEATURE_BUNDLE\E]+)\Q$RIGHT_FEATURE_BUNDLE\E}
								{$featureChart->phoneDisjuctionForFeatures(split(/$DELIMITER_FEATURE_BUNDLE/,$1))}eg;
				}
				$match =~ s/(\Q$RIGHT_FEATURE_BUNDLE\E\X+)\Q$MORPHEME_BOUNDARY\E(\Q$LEFT_FEATURE_BUNDLE\E\X+)/$1\\$MORPHEME_BOUNDARY$2/g;	# morpheme boundaries with features (middle)
				$match =~ s/^(\X+)\Q$MORPHEME_BOUNDARY\E(\Q$LEFT_FEATURE_BUNDLE\E\X+)/$1\\$MORPHEME_BOUNDARY$2/g;	    # morpheme boundaries with features (beginning)
				$match =~ s/(\Q$RIGHT_FEATURE_BUNDLE\E\X*)\Q$MORPHEME_BOUNDARY\E$/$1\\$MORPHEME_BOUNDARY$2/g;	    	# morpheme boundaries with features (end)
			}
			else
			{
				$match =~ s/\Q$MORPHEME_BOUNDARY\E/\\$MORPHEME_BOUNDARY/g;
				$match =~ s/([\+\[\]\-])/\\$1/g; # escape special characters
			}
			$match =~ s/\(\Q$WORD_BOUNDARY\E(\X+)?\)(\X+)\((\X+)?\)/\^($1)$2($3)/g; # word boundary at beginning
			$match =~ s/\Q$WORD_BOUNDARY\E/\$/g; # word boundary at end
			$replace =~ s/\Q$EMPTY_SET_UNICODE\E//g;	# don't actually want empty sets in replacement string
			# More Pretty-Printing Stuff #		
			$originalRules[-1] =~ s/\Q$ARROW_UNICODE\E/ $ARROW_UNICODE /g;	
			$originalRules[-1] =~ s/\Q$ARROW_ASCII\E/ $ARROW_UNICODE /g;
			$originalRules[-1] =~ s/\Q$SLASH_UNICODE\E/ $SLASH_UNICODE  /g;
			$originalRules[-1] =~ s/\Q$SLASH_ASCII\E/ $SLASH_UNICODE  /g;
			push(@matches,$match);
			push(@replaces,$replace);
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
			$col = "";
			for (my $i = 0; $i < scalar(@matches); $i++)
			{
				$tempForm = $uForm;
				$match = $matches[$i];
				if ($match !~ m/\\\Q$MORPHEME_BOUNDARY\E/)
				{
					$uForm =~ s/\Q$MORPHEME_BOUNDARY\E//g;		
				}
				# print "Match: $match\n";
				# print "Replace: $replaces[$i]\n";
				# print "uForm: $uForm\n";
				if ($opt_f)
				{
					# The mess below converts features to disjunctions of phones that match those features
					$match =~ s{\Q$LEFT_FEATURE_BUNDLE\E([^\Q$LEFT_FEATURE_BUNDLE\E]+)\Q$RIGHT_FEATURE_BUNDLE\E}
								{$featureChart->phoneDisjuctionForFeatures(split(/$DELIMITER_FEATURE_BUNDLE/,$1))}eg;
				}
				if ($uForm =~ m/$match/)
				{
					$phoneReplacing = $2;
					my $tempReplace = $replaces[$i];
					if ($opt_f)
					{
						# The mess below looks up features of phones, intersects them with those specified in $replace, and then returns the first phone that satisfies that
						$tempReplace =~ s{\Q$LEFT_FEATURE_BUNDLE\E([^\Q$LEFT_FEATURE_BUNDLE\E]+)\Q$RIGHT_FEATURE_BUNDLE\E}
											{$featureChart->unifyPhoneFeatures($phoneReplacing,split(/$DELIMITER_FEATURE_BUNDLE/,$1))}ge;						
					}
					# print "Phone being replaced: $phoneReplacing\n";
					# print "Altered replace: $tempReplace\n";
					$replace = "\"$tempReplace\"";
					$uForm =~ s/$match/$replace/gee;						
					$col = $col . $uForm . "\n";
				}
				else
				{
					$col = $col . "$EMPTY_CELL\n";
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