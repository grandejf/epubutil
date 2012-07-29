package EPUBPackager;

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw();

use Archive::Zip;

use strict;

sub new {
  my ($class, $filename) = @_;
  my $self = {};
  bless($self, $class);
  $self->{filename} = $filename;
  $self->{zip} = Archive::Zip->new();
  $self->{zip}->read($self->{filename});
  $self->{modified} = 0;
  return $self;
}

sub walk {
  my $self = shift;
  my ($handler) = @_;

  foreach my $filename ($self->{zip}->memberNames()) {
    &$handler($filename);
  }
}

sub content {
  my $self = shift;
  my ($filename) = @_;
  my $content = $self->{zip}->contents($filename);
  return $content;
}

sub replaceContent {
  my $self = shift;
  my ($filename, $content) = @_;
  $self->{zip}->contents($filename, $content);
  $self->{modified} = 1;
}

sub save {
  my $self = shift;
  return unless $self->{modified};
  $self->{zip}->overwrite();
}

1;
