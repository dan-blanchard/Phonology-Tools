#!/usr/bin/perl

# Dan Blanchard
# Phonological Rule Processor

# Usage: ./phonorules [-v] [-d] [-f <FEATURE CHART FILE>] [-s <SYMBOL TABLE FILE>] <RULE FILE> <TEST FILE>

# TODO fix n or more repetitions
# TODO fix morpheme boundaries
# TODO fix ()
# TODO fix ()*
# TODO add indexed feature bundles
# TODO add support for lower case greek letters in bundles
# TODO add angle brackets
# TODO symbols
# TODO add indexing to feature bundles


# Rule form: (A)->(B)(/(C)_(D))
# Perl form: s/(C)?(A)?(D)?/$1B$3/g
# SPE		vs		Perl
# ()				(?:)?
# α					\g{α} (with 5.10) need to count backreferences with 5.8
# {a,b,...}			(?:a|b|...)
# a^10				a{10,}
# ()*				()* (with /g for global, since it applies to ALL, not just longest)
# <A>B<C>			(?:ABC)|(?:B) (can happen INSIDE FEATURE BUNDLES!)
# + in rule			+? in between every character of rules that don't contain +
# #					$ at end and ^ at beginning
# []1				somehow match indexed feature bundles

use 5.010;
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
Readonly::Scalar my $DELIMITER_DISJUNCTIVE => '|';
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
Readonly::Scalar my $REPETITION_MARKER => '^';


# Command-line arguments
our ($opt_v, $opt_f, $opt_d, $opt_s);
getopts('vdf:s:');

# Setup Unicode input and output
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";
binmode STDERR, ":utf8";

# Global variables
my @matches = ();
my @replaces = ();
my @originalRules = ();
my @contextFreeMatches = ();
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

sub MatchStringToRegularExpression
{
	my $matchString = shift;
	$matchString =~ s/\Q$EMPTY_SET_UNICODE\E//g; # insertions
	if ($opt_v)
	{
		print "\n\nMatch string: $matchString\n\n";
	}
	if ($opt_f) #If we're dealing with features at all, convert all phonemes to features
	{
		if (!$opt_d)
		{
			$matchString =~ s{([\(\Q$RIGHT_FEATURE_BUNDLE\E])([^\Q$WORD_BOUNDARY\E\Q$MORPHEME_BOUNDARY\E\Q$PHONEME_BOUNDARY\E\Q$LEFT_OPTIONAL\E\Q$RIGHT_OPTIONAL\E\Q$LEFT_DISJUNCTIVE\E\Q$RIGHT_DISJUNCTIVE\E\Q$DELIMITER_DISJUNCTIVE\E\Q$LEFT_FEATURE_BUNDLE\E\Q$RIGHT_FEATURE_BUNDLE\E\Q$DELIMITER_FEATURE_BUNDLE\E\Q$ZERO_OR_MORE\E\Q$REPETITION_MARKER\E]+)}
								{$1.$featureChart->featureBundlesForPhones($2,"",$LEFT_FEATURE_BUNDLE,$RIGHT_FEATURE_BUNDLE,$DELIMITER_FEATURE_BUNDLE)}eg;
			$matchString =~ s{^([^\Q$WORD_BOUNDARY\E\Q$MORPHEME_BOUNDARY\E\Q$PHONEME_BOUNDARY\E\Q$LEFT_OPTIONAL\E\Q$RIGHT_OPTIONAL\E\Q$LEFT_DISJUNCTIVE\E\Q$RIGHT_DISJUNCTIVE\E\Q$DELIMITER_DISJUNCTIVE\E\Q$LEFT_FEATURE_BUNDLE\E\Q$RIGHT_FEATURE_BUNDLE\E\Q$DELIMITER_FEATURE_BUNDLE\E\Q$ZERO_OR_MORE\E\Q$REPETITION_MARKER\E]+)}
								{$featureChart->featureBundlesForPhones($1,"",$LEFT_FEATURE_BUNDLE,$RIGHT_FEATURE_BUNDLE,$DELIMITER_FEATURE_BUNDLE)}eg;
			$matchString =~ s/([^\(\Q$LEFT_FEATURE_BUNDLE\E]+)(\Q$LEFT_FEATURE_BUNDLE\E)/$1$PHONEME_BOUNDARY$2/g; # add phoneme boundary markers between feature bundles and other phonemes
		}
		else
		{			
			$matchString =~ s{([\(\Q$RIGHT_FEATURE_BUNDLE\E\Q$PHONEME_BOUNDARY\E\Q$WORD_BOUNDARY\E\Q$MORPHEME_BOUNDARY\E])([^\Q$WORD_BOUNDARY\E\Q$MORPHEME_BOUNDARY\E\Q$PHONEME_BOUNDARY\E\Q$LEFT_OPTIONAL\E\Q$RIGHT_OPTIONAL\E\Q$LEFT_DISJUNCTIVE\E\Q$RIGHT_DISJUNCTIVE\E\Q$DELIMITER_DISJUNCTIVE\E\Q$LEFT_FEATURE_BUNDLE\E\Q$RIGHT_FEATURE_BUNDLE\E\Q$DELIMITER_FEATURE_BUNDLE\E\Q$ZERO_OR_MORE\E\Q$REPETITION_MARKER\E]+)}
								{$1.$featureChart->featureBundleForPhone($2,$LEFT_FEATURE_BUNDLE,$RIGHT_FEATURE_BUNDLE,$DELIMITER_FEATURE_BUNDLE)}eg;
			$matchString =~ s{^([^\Q$WORD_BOUNDARY\E\Q$MORPHEME_BOUNDARY\E\Q$PHONEME_BOUNDARY\E\Q$LEFT_OPTIONAL\E\Q$RIGHT_OPTIONAL\E\Q$LEFT_DISJUNCTIVE\E\Q$RIGHT_DISJUNCTIVE\E\Q$DELIMITER_DISJUNCTIVE\E\Q$LEFT_FEATURE_BUNDLE\E\Q$RIGHT_FEATURE_BUNDLE\E\Q$DELIMITER_FEATURE_BUNDLE\E\Q$ZERO_OR_MORE\E\Q$REPETITION_MARKER\E]+)}
								{$featureChart->featureBundleForPhone($1,$LEFT_FEATURE_BUNDLE,$RIGHT_FEATURE_BUNDLE,$DELIMITER_FEATURE_BUNDLE)}eg;
		}
		$matchString =~ s/(\Q$RIGHT_FEATURE_BUNDLE\E\X+)\Q$MORPHEME_BOUNDARY\E(\Q$LEFT_FEATURE_BUNDLE\E\X+)/$1\\$MORPHEME_BOUNDARY$2/g;	# morpheme boundaries with features (middle)
		$matchString =~ s/^(\X+)\Q$MORPHEME_BOUNDARY\E(\Q$LEFT_FEATURE_BUNDLE\E\X+)/$1\\$MORPHEME_BOUNDARY$2/g;	    # morpheme boundaries with features (beginning)
		$matchString =~ s/(\Q$RIGHT_FEATURE_BUNDLE\E\X*)\Q$MORPHEME_BOUNDARY\E$/$1\\$MORPHEME_BOUNDARY$2/g;	    	# morpheme boundaries with features (end)
		
	}	
	$matchString =~ s/\(\Q$WORD_BOUNDARY\E(\X+)?\)(\X+)\((\X+)?\)/\^($1)$2($3)/g; # word boundary at beginning
	$matchString =~ s/\Q$WORD_BOUNDARY\E/\$/g; # word boundary at end
	# $matchString =~ s/(?:\Q$LEFT_DISJUNCTIVE\E[^\Q$RIGHT_DISJUNCTIVE\E\Q$DELIMITER_DISJUNCTIVE\E]+)\Q$DELIMITER_DISJUNCTIVE\E([^\Q$RIGHT_DISJUNCTIVE\E]+\Q$RIGHT_DISJUNCTIVE\E)/$1\|$2/g;
	$matchString =~ s/\Q$LEFT_DISJUNCTIVE\E/\(\?:/g; # disjunctions
	$matchString =~ s/\Q$RIGHT_DISJUNCTIVE\E/\)/g;
	$matchString =~ s/\Q$REPETITION_MARKER\E([0-9]+)/\{$1,\}/g; # repetitions
	return $matchString;
}

sub ReplaceStringToRegularExpression
{
	my $replaceString = shift;
	$replaceString =~ s/\Q$EMPTY_SET_UNICODE\E//g;	# don't actually want empty sets in replacement string
	return $replaceString;
}

# Check for feature chart file
if ($opt_f)
{
	$featureChart = FeatureChart->new();
	$featureChart->read_file($opt_f);
	# print $featureChart;	
}

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
		if (!$opt_d)
		{
			$rule =~ s/\s+//g;	# remove extra whitespace if we're not using digraphemes			
		}
		$rule =~ s/(\Q$ARROW_ASCII\E)\Q$EMPTY_SET_ASCII\E/$1$EMPTY_SET_UNICODE/;	# pretty-print empty sets
		$rule =~ s/\Q$EMPTY_SET_ASCII\E(\Q$ARROW_ASCII\E)/$EMPTY_SET_UNICODE$1/;	# pretty-print empty sets
		if ($rule =~ m/^(\X+)?(?:(?:(?:\Q$ARROW_ASCII\E)|\Q$ARROW_UNICODE\E)(\X+)?(?:(?:\Q$SLASH_ASCII\E)|(?:\Q$SLASH_UNICODE\E))(\X+)?\Q$PLACE_MARKER\E(\X+)?)?$/)			
		{
			no warnings;
			push(@originalRules,$rule);
			$rule =~ s/\Q$LEFT_OPTIONAL\E/\(\?:/g; # Properly formats optional sections of rules
			$rule =~ s/\Q$RIGHT_OPTIONAL\E/\)\?/g;
			# Have to do this after optional rule fixing
			if ($rule =~ m/^(\X+)?(?:(?:\Q$ARROW_ASCII\E)|\Q$ARROW_UNICODE\E)(\X+)?(?:(?:\Q$SLASH_ASCII\E)|(?:\Q$SLASH_UNICODE\E))(\X+)?\Q$PLACE_MARKER\E(\X+)?$/)
			{
				$match = "($3)($1)($4)";
				$replace = "\$1$2\$3";
				push(@contextFreeMatches, $1);
			}
			elsif ($rule =~ m/^(\X+)?(?:(?:\Q$ARROW_ASCII\E)|\Q$ARROW_UNICODE\E)(\X+)?$/) # Match transformational rules without /_ section
			{
				$match = "()($1)()";
				$replace = "\$1$2\$3";				
				push(@contextFreeMatches, $1);
			}
			else
			{
				print STDERR "ERROR: Your rule has managed to get to a part of this program that should not be possible.  The rule is $rule\n";
				exit(0);
			}
			$match = MatchStringToRegularExpression($match);
			$replace = ReplaceStringToRegularExpression($replace);
			if ($opt_v)
			{
				print "Match: $match\n";
				print "Replace: $replace\n";				
			}
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
		if (scalar(@line) == 2)
		{
			$sForm = $line[1];
		}
		else
		{
			$sForm = "";
		}
		$sForm = $line[1];
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
					$uForm =~ s/\Q$MORPHEME_BOUNDARY\E//g;		# This doesn't quite work because we permanently lose morpheme boundaries
				}
				# if ($opt_v)
				# {
				# 	print "Match: $match\n";
				# 	print "Replace: $replaces[$i]\n";
				# 	print "uForm: $uForm\n";					
				# }
				if ($opt_f)
				{					
					# The mess below converts features to disjunctions of phones that match those features
					$match =~ s{\Q$LEFT_FEATURE_BUNDLE\E([^\Q$LEFT_FEATURE_BUNDLE\E]*)\Q$RIGHT_FEATURE_BUNDLE\E}
								{$featureChart->phoneDisjuctionForFeatures(split(/$DELIMITER_FEATURE_BUNDLE/,$1))}eg;
					if ($match =~ m/\Q$PHONEME_BOUNDARY\E/)
					{						
						while ($uForm =~ s/([^()\Q$PHONEME_BOUNDARY\E\Q$FeatureChart::BAD_LEFT\E])([^()\Q$PHONEME_BOUNDARY\E\Q$FeatureChart::BAD_RIGHT\E])/$1$PHONEME_BOUNDARY$2/g)
						{
#							print "1: $1\t2:$2\n";							
						}
					}
					else
					{
						$uForm =~ s/\Q$PHONEME_BOUNDARY\E//g;
					}
					if ($opt_v)
					{
						print "Feature match: $match\n";
						print "uForm: $uForm\n";
					}
				}
				if ($uForm =~ m/$match/)
				{
					$phoneReplacing = $2;
					if ($opt_v)
					{
						print "Phone being replaced: $phoneReplacing\n";						
					}
					my $tempReplace = $replaces[$i];
					if ($opt_f)
					{
						# add code to split phoneReplacing and replace by phoneme_delimiter, check to see if they have the same number of elements, and process the phones/bundles one at a time
						$tempReplace =~ s/(\Q$RIGHT_FEATURE_BUNDLE\E)([^)])/$1$PHONEME_BOUNDARY$2/g;	
						$tempReplace =~ s/([^\(\Q$PHONEME_BOUNDARY\E\$])(\Q$LEFT_FEATURE_BUNDLE\E)/$1$PHONEME_BOUNDARY$2/g;
						$tempReplace =~ s/([\(\Q$RIGHT_FEATURE_BUNDLE\E\Q$PHONEME_BOUNDARY\E\$])([^\Q$PHONEME_BOUNDARY\E\Q$LEFT_FEATURE_BUNDLE\E)\$])([^\Q$PHONEME_BOUNDARY\E\Q$LEFT_FEATURE_BUNDLE\E)])/$1$2$PHONEME_BOUNDARY$3/g;
						$tempReplace =~ s/\)\(/)$PHONEME_BOUNDARY?(/g;
						while ($tempReplace =~ s/([\(\Q$RIGHT_FEATURE_BUNDLE\E\Q$PHONEME_BOUNDARY\E\$])([^\Q$PHONEME_BOUNDARY\E\Q$LEFT_FEATURE_BUNDLE\E)\$])([^\Q$PHONEME_BOUNDARY\E\Q$LEFT_FEATURE_BUNDLE\E)])/$1$2$PHONEME_BOUNDARY$3/g)
						{
							# This loop does all of its work in the condition-checking
						}
						my @oldBundles = split(/\Q$PHONEME_BOUNDARY\E/,$phoneReplacing);
						my @newBundles = split(/\Q$PHONEME_BOUNDARY\E/,$tempReplace);
						if ($opt_v)
						{
							print "tempReplace: $tempReplace\n";							
						}
						shift(@newBundles);
						pop(@newBundles);
						if (scalar(@oldBundles) >= scalar(@newBundles))
						{
							# print "Counts-old: " . scalar(@oldBundles) . "\tCounts-new: " . scalar(@newBundles) . "\n";
							for (my $j = 0; $j < scalar(@newBundles); $j++)
							{
								$newBundles[$j] =~ s{\Q$LEFT_FEATURE_BUNDLE\E([^\Q$LEFT_FEATURE_BUNDLE\E]+)\Q$RIGHT_FEATURE_BUNDLE\E}
														{$featureChart->unifyPhoneFeatures($oldBundles[$j],split(/$DELIMITER_FEATURE_BUNDLE/,$1))}ge;
								# print "in loop: $newBundles[$j]\n";
							}
							$tempReplace = join($PHONEME_BOUNDARY,@newBundles);
							$tempReplace = "\$1$PHONEME_BOUNDARY$tempReplace$PHONEME_BOUNDARY\$3";
						}
						elsif (scalar(@oldBundles) == 1)
						{
							$tempReplace =~ s{\Q$LEFT_FEATURE_BUNDLE\E([^\Q$LEFT_FEATURE_BUNDLE\E]+)\Q$RIGHT_FEATURE_BUNDLE\E}
													{$featureChart->unifyPhoneFeatures($phoneReplacing,split(/$DELIMITER_FEATURE_BUNDLE/,$1))}ge;							
						}
						elsif ($tempReplace !~ m/\Q$LEFT_FEATURE_BUNDLE\E/) # might want to add check to see if we're in feature mode here
						{
							# Everything's a-okay
						}
						else
						{
							print STDERR "ERROR: Rule $originalRules[$i] contains implicit insertion(s).  Please use a separate rules for insertions.\n";
 							exit(0);
						}
						# print "Feature replace: $tempReplace\n";
					}
					# print "Altered replace: $tempReplace\n";
					$replace = "\"$tempReplace\"";
					$uForm =~ s/$match/$replace/gee;
					$uForm =~ s/$PHONEME_BOUNDARY//g;
					$col = $col . $uForm . "\n";
				}
				else
				{
					$col = $col . "$EMPTY_CELL\n";
				}			
			}
			$uForm =~ s/$PHONEME_BOUNDARY//g;
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
#	print $featureChart;
}
print "\n$outputTable\n";
