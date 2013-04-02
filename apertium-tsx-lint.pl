#!/usr/bin/perl

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

my @labels = ();

my $parser = XML::Parser->new(Handlers => {Start=>\&handle_start,
					End=>\&handle_end});
$parser->parsefile($ARGV[0]) or die "$!\n";

#if($ARGV[1] && 

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
		my $regex = $attrs{'tags'};
		$regex =~ s/\*/[^>]\*/;
		$regex =~ s/\./></g;
		$current_item .= "<";
		$current_item .= $regex;
		$current_item .= ">";
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
		my $current_items = join("\\+", @current_tags);
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
