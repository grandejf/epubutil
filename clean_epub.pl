#!/usr/bin/perl -w

use Getopt::Long; use IPC::Open2;
use XML::LibXML;
use EPUBPackager;
use strict;

my $conf_file;
GetOptions('conf=s'=>\$conf_file,);

$conf_file ||= "clean_epub.conf";

my $conf = readConf($conf_file);
$conf->{tidy} = 1 unless defined $conf->{tidy};
$conf->{noChapterHeaderTopMargin} = 1 unless defined $conf->{noChapterHeaderTopMargin};
	
my $filename = $ARGV[0];

my $epub = new EPUBPackager($filename);

$epub->walk(sub {
  my ($filename) = @_;

  if ($filename =~ m!OEBPS/Text/.*\.xhtml$!oi) {
    my $content = $epub->content($filename);
    $content =~ s!\r([^\n])!\n$1!go;
    $content =~ s!\s+$!!o;
    my $p = XML::LibXML->new();
    $p->set_options({validation=>0,recover=>2,suppress_errors=>1,pedantic_parser=>0,load_ext_dtd=>0});
    my $doc = $p->parse_html_string($content);
    my $orgContent = $doc->toStringHTML;
    if ($conf->{removeTableDups}) {
      foreach my $node ($doc->findnodes('//td')) {
	my $childrenText = '';
	foreach my $child ($node->childNodes()) {
	  $childrenText .= $child->toString;
	}
	if ($childrenText =~ /^(.+)\s*\1\s*$/so) {
	  $node->removeChildNodes();
	  my $frag = $p->parse_html_string($1);
	  my @body = $frag->findnodes('//body');
	  foreach my $c ($body[0]->childNodes()) {
	    $node->addChild($c);
	  }
	}	
      }
    }
    my $newContent = $doc->toStringHTML;
    if (($orgContent ne $newContent) || $conf->{tidy}) {
      $newContent = tidy($newContent);
      $epub->replaceContent($filename, $newContent);
    }
  }
  elsif ($filename =~ m!OEBPS/Styles/.*\.css$!oi) {
    my $content = $epub->content($filename);
    my $newContent = '';
    my %changes;
    $changes{'h1'}->{'margin-top'} = '' if $conf->{noChapterHeaderTopMargin};
    if (scalar(keys %changes) > 0) {
      foreach my $block (split /(\s+\S+\s+{(?:.*?)}(\s+|$))/os, $content) {
	next unless $block;
	my ($sel, $styleblock) = ($block =~ m!(\S+)\s*{(.*)}!os);
	if ($sel && $changes{$sel}) {
	  my @styles = map { s!^\s*(.*)\s*$!$1!o; $_; } split m!((?:/\*.*?\*/)|;)!s, $styleblock;
	  my @newStyles;
	  my %seenProps;
	  foreach my $s (@styles) {
	    next if $s eq ';';
	    if ($s =~ m!/\*!o) {
	      # do nothing
	    }
	    elsif ($s =~ /^(.*):(.*)/o) {
	      my ($prop, $value) = ($1, $2);
	      $seenProps{$prop} = 1;
	      my $change = $changes{$sel}->{$prop};
	      if (defined($change)) {
		$s = '';
		if ($change ne '') {
		  $s = "$prop: $change;";
		}
	      }
	      else {
		$s = "$s;";
	      }
	    }
	    push @newStyles, $s if $s;
	  }
	  $newContent .= "$sel\n{\n". join("\n", @newStyles) . "}\n";
	}
	else {
	  $newContent .= "$block";
	}
      }
    }
    if ($newContent) {
      $epub->replaceContent($filename, $newContent);
    }
  }
});
$epub->save();


sub readConf {
  my ($filename) = @_;
  my $conf = {};
  open(CONF, $filename) or return $conf;
  while (<CONF>) {
    my $line = $_;
    chomp($line);
    next if /^\s*#/o;
    my ($name, $val) = ($line =~ /^\s*(\S+)\s*=\s*(.*)\s*$/o);
    $conf->{$name} = $val;
  }
  close CONF;
  return $conf;
}

sub tidy {
  my ($html) = @_;
  my $cmd = "tidy -asxhtml -q -wrap 0 2> /dev/null";
  my $pid = open2(\*OUT,\*IN, $cmd);
  print IN $html;
  close IN;
  $html = '';
  while (<OUT>) {
    $html .= $_;
  }
  close OUT;
  waitpid($pid,0);
  return $html;
}
