#!/usr/bin/perl -w

use strict;

use EPUBPackager;

my $sourcefilename = $ARGV[0];
my $epub_filename = $ARGV[1];

my %metadata;
open(SOURCE, "$sourcefilename") or die;
while (<SOURCE>) {
  my $line = $_;
  chomp $line;
  last if $line eq '';
  my ($key, $text) = ($line =~ /^(.*?):(.*)/o);
  $key = lc $key;
  $key =~ s!^\s+!!o;
  $key =~ s!\s+$!!o;
  $text =~ s!^\s+!!o;
  $text =~ s!\s+$!!o;
  $metadata{$key} = $text;
}
close SOURCE;

my $epub = EPUBPackager->new($epub_filename, {create=>1});

$epub->setMetadata(\%metadata);
$epub->save();
