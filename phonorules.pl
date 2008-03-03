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
		$rule =~ s/\s+//g;
		$rule =~ s/0/∅/g;
		$rule =~ m/^(\X+)?->(\X+)?\/(\X+)?_(\X+)?$/;	
		$match = "($3)$1($4)";
		$replace = "\$1$2\$2";
		$match =~ s/∅//g; # insertions
		$match =~ s/V/(a|e|i|o|u)/g;	# vowels				
		$match =~ s/#/\$/g; # word boundary
		$replace =~ s/∅//g;
		$rule =~ s/->/ ➔ /g;
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


# Read test file
open TEST, $testFile;
binmode TEST, ":utf8";
while (<TEST>)
{
	chomp;
	$_ =~ s/%.*$//;
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
		push(@outputColumns, $col);
	}
}
close (TEST);

# Build output table
$outputTable->setCols(@columnNames);
$outputTable->addRow(@outputColumns);
print $outputTable;