#!/usr/bin/perl
=pod

=head1 NAME

apertium-tsx-lint - Test a tsx file for common problems

=head1 SYNOPSIS

  apertium-tsx-lint tsx-file [DIC]

=head1 DESCRIPTION

TBD

=head1 COPYRIGHT

Copyright 2013 Jimmy O'Regan

This program is free software; you can use, redistribute and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; version 2, or

=item * the Artistic License version 2.0.

=back

=cut


use warnings;
use strict;
use utf8;

use XML::Parser;
use Data::Dumper;

my @elements;

my $DEBUG = 1;

my $current_label = "";
my %items = ();
my %ritems = ();
my @current_tags = ();
my %label_lines = ();
my $reading = 0;
my $saw_open = 0;

my $dic;

my @labels = ();

my $parser = XML::Parser->new(Handlers => {Start=>\&handle_start,
					End=>\&handle_end});
$parser->parsefile($ARGV[0]) or die "$!\n";

if($ARGV[1]) {
	open($dic, "<$ARGV[1]") or die "$!\n";
} else {
	$dic = *STDIN;
}
binmode $dic, ":utf8";

my $diclineno = 0;
while(<$dic>) {
	chomp;
	s/^\^//;
	s/\$$//;
	$diclineno++;
	my $linetext = $_;
	my @words = split/\//;

	my %matched;
	for my $inword(@words) {
		my $word = $inword;
		if($inword =~ /#/) {
			$word = (split(/#/, $inword))[0];
		}
		for my $regex(keys %ritems) {
			my $has_match = 0;
			my $curlabel = $ritems{$regex};
			if($word =~ "($regex)") {
				push(@{$matched{$curlabel}}, $1);
			}
		}
	}
	while (my ($key, $value) = each %matched) {
		if($#{$value} != 0) {
			print "MASKED_AMBIGUITY: $key ($label_lines{$key}) matches more than one analysis:\n";
			print "INPUT: $linetext\n";
			print "MATCHED: " . join("/", @{$value}) . "\n";
		}
	}
}

sub handle_start {
	my ($expat, $element, %attrs) = @_;
	my $line = $expat->current_line;

	if($element eq 'def-label' || $element eq 'def-mult') {
		$reading = 1;
		$current_label = $attrs{'name'};
		if(!$attrs{'closed'} || $attrs{'closed'} ne 'true') {
			$saw_open = 1;
		}
		$label_lines{$current_label} = $line;
		print "$element : $line : $current_label\n" if($DEBUG);
	}
	if($element eq 'tags-item' && $reading) {
		my $current_item = "";
		if($attrs{'lemma'} && $attrs{'lemma'} ne '') {
			$current_item = "^" . $attrs{'lemma'};
		}
		my @tags = split(/\./,$attrs{'tags'});
		my $regex = "";
		for my $tag (@tags) {
			if($tag eq '*') {
				$regex .= '(?:<[^>]*>)+';
			} else {
				$regex .= '<' . $tag . '>';
			}
		}
		$current_item .= $regex;
		push(@current_tags, $current_item);
		print "$element : $line : $current_item\n" if($DEBUG);
	}
	if($element eq 'label-item' && $reading) {
		my $name = $attrs{'label'};
		push(@current_tags, $items{$name});
		print "$element : $line : $name : $items{$name}\n" if($DEBUG);
	}
}

sub handle_end {
	my ($expat, $element) = @_;
	if($element eq 'def-label') {
		my $current_items = join("|", @current_tags);
		$items{$current_label} = $current_items;
		if($ritems{$current_items}) {
			my $conflict = $ritems{$current_items};
			print "WARN_CONFLICT: $current_label ($label_lines{$current_label}) conflicts with $conflict ($label_lines{$conflict})\n";
		} else {
			$ritems{$current_items} = $current_label;
		}
		$current_label = "";
		@current_tags = ();
		$reading = 0;
	}
	if($element eq 'def-mult') {
		my @local_tags = map { (my $s = $_) =~ s/^\^//; $s } @current_tags;
		my $current_items = join("\\+", @local_tags);
		$items{$current_label} = $current_items;
		$current_label = "";
		@current_tags = ();
		$reading = 0;
	}
	if($element eq 'tagset' && !$saw_open) {
		print "NO_OPEN_TAGS: all items are defined as 'closed' \n";
		print "(Tagger training will fail: open classes are needed to handle unknown words)\n";
	}
}
