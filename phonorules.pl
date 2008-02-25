#!/usr/bin/perl

# Dan Blanchard
# Phonological Rule Processor

# Usage: ./phonorules <RULE FILE> <TEST FILE>

use strict;
use POSIX;

my @matches = ();
my @replaces = ();
my $rule;
my $ruleFile = $ARGV[0];
my $testFile = $ARGV[1];
my $match;
my $replace;
my $word;
my $madeSub = 0;

open (RULES, $ruleFile);
while (<RULES>)
{
	chomp;
	$rule = $_;
	# add support for comments after rules on same line
	if (!($rule =~ m/^#(\X|.)*/))
	{	
		$rule =~ s/\s+//g;
		$rule =~ m/^(\X+)->(\X+)?\/(\X+)?_(\X+)?$/;	
		$match = "($3)$1($4)";
		$match =~ s/V/(a|e|i|o|u)/g;					
		$replace = "\$1$2\$2";
		$replace =~ s/0//g;
		push(@matches,$match);
		push(@replaces,$replace);
#		print "MATCH: $match\nREPLACE: $replace\n";
	}
}
close (RULES);

open (TEST, $testFile);
while (<TEST>)
{
	chomp;
	$word = $_;
	$madeSub = 0;
	if (!($word =~ m/^#(\X|.)*/))
	{	
		for (my $i = 0; $i < scalar(@matches); $i++)
		{
			$match = $matches[$i];
			$replace = "\"$replaces[$i]\"";
			if ($word =~ m/$match/)
			{
				if ($match =~ m/\|/)
				{
					$replace =~ s/2/3/;					
				}
#				print "\nMATCHED: $match\tREPLACED BY: $replace\n";
				if (!($madeSub))
				{
					print "$word";					
				}
				print " -> ";
				$word =~ s/$matches[$i]/$replace/gee;
				print $word;
				$madeSub = 1;				
			}
		}
		if (!($madeSub))
		{
			print $word;
		}
		print "\n";			
	}
}
close (TEST);