#!/usr/bin/perl -w

use strict;

use EPUBPackager;
use XML::LibXML;

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
my $text = '';
while (<SOURCE>) {
  $text .= $_;
}
close SOURCE;

my $epub = EPUBPackager->new($epub_filename, {create=>1});

$epub->setMetadata(\%metadata);
my @sections = split_source($text);
foreach my $section (@sections) {
  print "$section\n";
  $epub->add_to_spine($section);
}
$epub->save();

exit;

sub split_source {
  my ($source) = @_;
  my $p = XML::LibXML->new();
  $p->set_options({validation=>0,recover=>2,suppress_errors=>1,pedantic_parser=>0,load_ext_dtd=>0});
  my $doc = $p->parse_html_string($source);

  my @body = $doc->findnodes('//body');
  my @sections;
  my $container = XML::LibXML::Document->createDocument();
  foreach my $c ($body[0]->childNodes) {
    if ($c->nodeType == XML_ELEMENT_NODE) {
      if ($c->tagName eq 'h1') {
	push @sections, $container;
	$container = XML::LibXML::Document->createDocument();
      }
    }
    $container->addChild($c);
  }
  push @sections, $container;

  my @hsections;
  foreach my $section (@sections) {
    my $html = $section->toStringHTML;
    next if $html =~ /^\s*$/os;
    push @hsections, tidy($html);
  }
  return @hsections;
}
