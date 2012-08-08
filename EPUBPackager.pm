package EPUBPackager;

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw();

use Archive::Zip;

use strict;

sub new {
  my ($class, $filename, $flags) = @_;
  my $self = {};
  bless($self, $class);
  $self->{filename} = $filename;
  $self->{zip} = Archive::Zip->new();
  $self->{zip}->read($self->{filename}) unless $flags->{create};
  $self->{modified} = 0;
  if ($flags->{create}) {
    $self->{create} = 1;
    $self->create();
  }
  return $self;
}

sub setMetadata {
  my $self = shift;
  my ($meta) = @_;
  $self->{meta} = $meta;
  $self->{meta}->{language} = "en-US" unless $meta->{language};
  my $uuid = `uuidgen`;
  chomp $uuid;
  $self->{meta}->{identifier} = $uuid unless $meta->{identifier};
}

sub create {
  my $self = shift;
  my $m = $self->{zip}->addString("application/epub+zip","mimetype");
  $m->desiredCompressionMethod(Archive::Zip::COMPRESSION_STORED);
  $self->{zip}->addDirectory("META-INF");
  $self->{content_opf} = "OEBPS/content.opf";
  my $container_xml = <<"CONTAINER";
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
<rootfiles>
<rootfile full-path="$self->{content_opf}" media-type="application/oebps-package+xml" />
</rootfiles>
</container> 
CONTAINER
  $m = $self->{zip}->addString($container_xml,"META-INF/container.xml");
  $m->desiredCompressionMethod(Archive::Zip::COMPRESSION_DEFLATED);
  $self->{modified} = 1;
}

sub create_content_opf {
  my $self = shift;

  my @meta;
  foreach my $key (keys %{$self->{meta}}) {
    my $attr = '';
    if ($key eq 'identifier') {
      $attr = qq[ id="BookID" opf:scheme="UUID"];
    }
    push @meta, qq[<dc:$key$attr>$self->{meta}->{$key}</dc:$key>];
  }
  my $metabuf = join("\n", @meta);

  my $manifestbuf = '';
  my $buf = << "XML";
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookID" version="2.0" >
    <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
      $metabuf
    </metadata>
    <manifest>
    </manifest>
    <spine toc="ncx">

    </spine>
</package>
XML
  $self->{zip}->addString($buf,$self->{content_opf});
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
  $self->create_content_opf();
  if (! $self->{create}) {
    $self->{zip}->overwrite();
  }
  else {
    $self->{zip}->writeToFileNamed($self->{filename});
  }
}

1;
