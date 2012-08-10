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
#  $self->{zip}->addDirectory("META-INF");
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

  $self->{manifest} = {};
  $self->{modified} = 1;
}

sub add_file {
  my $self = shift;
  my ($data, $filename, $flags) = @_;

  my $id = $flags->{id};
  unless ($id) {
    $id = $filename;
    $id =~ s!.*/([^/]+)!$1!o;
    $id =~ s!\.!_!go;
  }
  my $mediatype = $flags->{mediatype};
  unless ($mediatype) {
    my ($ext) = ($filename =~ m!\.([^/.]+)$!o);
    if ($ext) {
      if ($ext eq 'ncx') {
	$mediatype = "application/x-dtbncx+xml";
      }
      elsif ($ext eq 'css') {
	$mediatype = "text/css";
      }
      elsif ($ext eq 'svg') {
	$mediatype = "image/svg+xml";
      }
      elsif ($ext =~ /html$/o) {
	$mediatype = "application/xhtml+xml";
      }
      elsif ($ext =~ /(png|jpg|jpeg)/o) {
	$ext = 'jpeg' if $ext eq 'jpg';
	$mediatype = "image/$ext";
      }
      else {
	$mediatype = "application/xhtml+xml";
      }
    }
    else {
      $mediatype = "application/xhtml+xml";
    }
  }
  $self->{manifest}->{$id} = {id=>$id,
			      href=>$filename,
			      'media-type'=>$mediatype,
			      data=>$data};

  return $self->{manifest}->{$id};
}

sub add_nav_point {
  my $self = shift;
  my ($src, $label) = @_;
  push @{$self->{navpoints}}, {src=>$src, label=>$label};
}

sub add_to_spine {
  my $self = shift;
  my ($xhtml, $filename, $flags) = @_;

  unless ($filename) {
    $self->{xhtml_auto_ctr} ||= 1;
    $filename = sprintf("Text/content%0.8d.xhtml",$self->{xhtml_auto_ctr});
    $self->{xhtml_auto_ctr}++;
  }
  my $e = $self->add_file($xhtml,$filename,$flags);
  push @{$self->{spine}}, $e->{id};
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

  my @manifest;
  foreach my $id (sort keys %{$self->{manifest}}) {
    my $e = $self->{manifest}->{$id};
    push @manifest,qq[<item id="$e->{id}" href="$e->{href}" media-type="$e->{'media-type'}" />];
  }
  my $manifestbuf = join("\n", @manifest);

  my @spine;
  foreach my $id (@{$self->{spine}}) {
    push @spine,qq[<itemref idref="$id" />];
  }
  my $spinebuf = join("\n", @spine);
  
  my $buf = << "XML";
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookID" version="2.0" >
    <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
      $metabuf
    </metadata>
    <manifest>
      $manifestbuf
    </manifest>
    <spine toc="ncx">
      $spinebuf
    </spine>
</package>
XML
  print "$buf\n";
  $self->{zip}->addString($buf,$self->{content_opf});
}

sub create_toc {
  my $self = shift;

  
  my $buf = << "XML";
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
<head>
    <meta name="dtb:uid" content=" $self->{meta}->{identifier}"/>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
</head>

<docTitle>
    <text>$self->{meta}->{title}</text>
</docTitle>
<navMap>

</navMap>
</ncx>
XML

  $self->add_file($buf,"OEBPS/toc.ncx",{id=>'ncx'});
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
  if (! $self->{create}) {
    $self->{zip}->overwrite();
  }
  else {
    $self->create_toc();
    $self->create_content_opf();
    foreach my $id (sort keys %{$self->{manifest}}) {
      my $e = $self->{manifest}->{$id};
      $self->{zip}->addString($e->{data},"OEBPS/" . $e->{href});
    }
    $self->{zip}->writeToFileNamed($self->{filename});
  }
}

1;
