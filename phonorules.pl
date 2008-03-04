#!/usr/bin/perl

# Dan Blanchard
# Phonological Rule Processor

# Usage: ./phonorules <RULE FILE> <TEST FILE>

# TODO "n or more" repetitions
# TODO symbols
# TODO features

use strict;
use POSIX;
use utf8;
use Encode;
use Text::ASCIITable;

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
my $replace;
my $uForm;
my $sForm;
my @line;


# Setup Unicode input and output
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

# Read rule file
open RULES, $ruleFile;
binmode RULES, ":utf8";
while (<RULES>)
{
	chomp;
	$rule = $_;
	$rule =~ s/%.*$//;
	if ($rule ne "")
	{	
		$rule =~ s/\s+//g;	# remove extra whitespace
		$rule =~ s/0/∅/g;	# pretty-print empty sets
		$rule =~ m/^(\X+)?((->)|➔)(\X+)?((\/)|(╱))(\X+)?_(\X+)?$/;	
		$match = "($8)$1($9)";
		$replace = "\$1$4\$2";
		$match =~ s/∅//g; # insertions
		$match =~ s/V/(a|e|i|o|u)/g;	# vowels				
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
			$replace = "\"$replaces[$i]\"";
			if ($uForm =~ m/$match/)
			{
				if ($match =~ m/\|/)
				{
					$replace =~ s/2/3/;					
				}
				$uForm =~ s/$matches[$i]/$replace/gee;
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
close (TEST);

# Build output table
$outputTable->setCols(@columnNames);
$outputTable->addRow(@outputColumns);
$outputTable->addRow(@surfaceForms);
$outputTable->addRow(@attestedForms);
print "\n$outputTable\n";