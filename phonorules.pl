#!/usr/bin/perl

# Dan Blanchard
# Phonological Rule Processor

# Usage: ./phonorules <RULE FILE> <TEST FILE>

use strict;
use POSIX;
use utf8;
use Text::Autoformat;

my @matches = ();
my @replaces = ();
my @originalRules = ();
my $rule;
my $ruleFile = $ARGV[0];
my $testFile = $ARGV[1];
my $match;
my $replace;
my $uForm;
my $sForm;
my $madeSub = 0;
my @line;



open RULES, $ruleFile;
while (<RULES>)
{
	chomp;
	$rule = $_;
	$rule =~ s/%.*$//;
	# add support for comments after rules on same line
	if ($rule ne "")
	{	
		$rule =~ s/\s+//g;
		$rule =~ m/^(\X+)?->(\X+)?\/(\X+)?_(\X+)?$/;	
		$match = "($3)$1($4)";
		$match =~ s/V/(a|e|i|o|u)/g;					
		$replace = "\$1$2\$2";
		$replace =~ s/0//g;
		push(@matches,$match);
		push(@replaces,$replace);
		push(@originalRules,$rule);
#		print "MATCH: $match\nREPLACE: $replace\n";
	}
}
close (RULES);

# Print rules
print "Rules:\n";
for (my $i = 1; $i <= scalar(@originalRules); $i++)
{
	print "$i.\t" . $originalRules[$i-1] . "\n";
}
print "\n";

open TEST, $testFile;
while (<TEST>)
{
	chomp;
	$_ =~ s/%.*$//;
	$_ =~ s/\+//g;
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
	$madeSub = 0;
	if ($uForm ne "")
	{	
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
#				print "\nMATCHED: $match\tREPLACED BY: $replace\n";
				if (!($madeSub))
				{
					print "$uForm";					
				}
				print " -> ";
				$uForm =~ s/$matches[$i]/$replace/gee;
				print $uForm;
				$madeSub = 1;				
			}
		}
		if (!($madeSub))
		{
			print $uForm;
		}
		print "\n";			
	}
}
close (TEST);