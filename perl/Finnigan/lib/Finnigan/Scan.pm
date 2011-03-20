package Finnigan::Scan::CentroidList;

sub new {
  my ($class, $buf) = @_;
  my $self = {count => unpack 'V', $buf};
  my $offset = 4; # V

  my $chunk;
  foreach my $i (0 .. $self->{count} - 1) {
    push @{$self->{peaks}}, [unpack "x${offset} ff", $buf];
    $offset += 8;
  }

  return bless $self, $class;
}

sub list {
  shift->{peaks};
}

package Finnigan::Scan::Profile;

sub new {
  my ($class, $buf, $layout) = @_;
  my $self = {};
  @{$self}{'first value', 'step', 'peak count', 'nbins'} = unpack 'ddVV', $buf;
  my $offset = 24; # ddVV

  my $chunk;
  foreach my $i (0 .. $self->{'peak count'} - 1) {
    $chunk = new Finnigan::Scan::ProfileChunk $buf, $offset, $layout;
    $offset += $chunk->{size};
    push @{$self->{chunks}}, $chunk;
  }

  return bless $self, $class;
}

sub converter {
  $_[0]->{converter};
}

sub set_converter {
  $_[0]->{converter} = $_[1];
}

sub inverse_converter {
  $_[0]->{"inverse converter"};
}

sub set_inverse_converter {
  $_[0]->{"inverse converter"} = $_[1];
}

sub bins {
  my ($self, $range, $add_zeroes) = @_;
  my @list;
  my $start = $self->{"first value"};
  my $step = $self->{step};
  unless ( $range ) {
    unless ( exists $self->{converter} ) {
      $range = [$start, $start + $self->{nbins} * $step];
    }
  }

  push @list, [$range->[0], 0] if $add_zeroes;
  my $last_bin_written = 0;

  my $shift = 0; # this is declared outside the chunk loop to allow
                 # writing the empty bin following the last chunk with
                 # the same amount of shift as in the last chunk

  foreach my $i ( 0 .. $self->{"peak count"} - 1 ) { # each chunk
    my $chunk = $self->{chunks}->[$i];
    my $first_bin = $chunk->{"first bin"};
    $shift = $chunk->{fudge} || 0;
    my $x = $start + $first_bin * $step;

    if ( $add_zeroes and $last_bin_written < $first_bin - 1) {
      # add an empty bin ahead of the chunk, unless there is no gap
      # between this and the previous chunk
      my $x0 = $x - $step;
      my $x_conv = exists $self->{converter} ? &{$self->{converter}}($x0) + $shift : $x0;
      push @list, [$x_conv, 0];
    }

    foreach my $j ( 0 .. $chunk->{nbins} - 1) {
      my $x_conv = exists $self->{converter} ? &{$self->{converter}}($x) + $shift : $x;
      $x += $step;
      if ( $range ) {
        if ( exists $self->{converter} ) {
          next unless $x_conv >= $range->[0] and $x_conv <= $range->[1];
        }
        else {
          # frequencies have the reverse order
          next unless $x_conv <= $range->[0] and $x_conv >= $range->[1];
        }
      }
      my $bin = $first_bin + $j;
      push @list, [$x_conv, $chunk->{signal}->[$j]];
      $last_bin_written = $first_bin + $j;
    }

    if ( $add_zeroes
         and
         $i < $self->{"peak count"} - 1
         and
         $last_bin_written < $self->{chunks}->[$i+1]->{"first bin"} - 1
       ) {
      # add an empty bin following the chunk, unless there is no gap
      # between this and the next chunk
      my $bin = $last_bin_written + 1;
      # $x has been incremented inside the chunk loop
      my $x_conv = exists $self->{converter} ? &{$self->{converter}}($x) + $shift: $x;
      push @list, [$x_conv, 0];
      $last_bin_written++;
    }
  }

  if ( $add_zeroes and $last_bin_written < $self->{nbins} - 1 ) {
    # add an empty bin following the last chunk, unless there is no gap
    # left between it and the end of the range ($self->nbins - 1)
    my $x = $start + ($last_bin_written + 1) * $step;
    my $x_conv = exists $self->{converter} ? &{$self->{converter}}($x) + $shift: $x;
    push @list, [$x_conv, 0];
    push @list, [$range->[1], 0] if $add_zeroes;
  }
  return \@list;
}


package Finnigan::Scan::ProfileChunk;

sub new {
  my ($class, $buf, $offset, $layout) = @_;
  my $self = {};
  if ( $layout > 0 ) {
    @{$self}{'first bin', 'nbins', 'fudge'} = unpack "x${offset} VVf", $buf;
    $self->{size} = 12;
  }
  else {
    @{$self}{'first bin', 'nbins'} = unpack "x${offset} VV", $buf;
    $self->{size} = 8;
  }
  $offset += $self->{size};

  @{$self->{signal}} = unpack "x${offset} f$self->{nbins}", $buf;
  $self->{size} += 4 * $self->{nbins};

  return bless $self, $class;
}


package Finnigan::Scan;

use strict;
use warnings;

use Finnigan;

sub decode {
  my ($class, $stream) = @_;

  my $self = {
	      addr => tell $stream
	     };
  my $nbytes;
  my $bytes_to_read;
  my $current_addr;

  $self->{header} = Finnigan::PacketHeader->decode($stream);
  $self->{size} = $self->{header}->{size};
  my $header_data = $self->{header}->{data};

  $bytes_to_read = 4 * $header_data->{"profile size"}->{value};
  $nbytes = CORE::read $stream, $self->{"raw profile"}, $bytes_to_read;
  $nbytes == $bytes_to_read
    or die "could not read all $bytes_to_read bytes of scan profile at " . ($self->{addr} + $self->{size});
  $self->{size} += $nbytes;

  $bytes_to_read = 4 * $header_data->{"peak list size"}->{value};
  $nbytes = CORE::read $stream, $self->{"raw centroids"}, $bytes_to_read;
  $nbytes == $bytes_to_read
    or die "could not read all $bytes_to_read bytes of scan profile at " . ($self->{addr} + $self->{size});
  $self->{size} += $nbytes;

  # skip peak descriptors and the unknown streams
  $self->{size} += 4 * (
			$header_data->{"descriptor list size"}->{value} +
			$header_data->{"size of unknown stream"}->{value} +
			$header_data->{"size of triplet stream"}->{value}
		       );
  seek $stream, $self->{addr} + $self->{size}, 0;

  return bless $self, $class;
}

sub header {
  return shift->{header};
}

sub profile {
  new Finnigan::Scan::Profile $_[0]->{"raw profile"}, $_[0]->{header}->{data}->{layout}->{value};
}

sub centroids {
  new Finnigan::Scan::CentroidList $_[0]->{"raw centroids"};
}

1;
__END__

=head1 NAME

Finnigan::Scan -- a monolythic scan data decoder

=head1 SYNOPSIS

  use Finnigan;
  my $entry = Finnigan::ScanIndexEntry->decode(\*INPUT);
  say $entry->offset; # returns an offset from the start of scan data stream 
  say $entry->data_size;
  $entry->dump;

=head1 DESCRIPTION

ScanIndexEntry is a static (fixed-size) structure containing the
pointer to a scan, the scan's data size and some auxiliary information
about the scan.

ScanIndexEntry elements seem to form a linked list. Each
ScanIndexEntry contains the index of the next entry.

Although in all observed instances the scans were sequential and their
indices could be ignored, it may not always be the case.

It is not clear whether scan index numbers start at 0 or at 1. If they
start at 0, the list link index must point to the next item. If they
start at 1, then "index" will become "previous" and "next" becomes
"index" -- the list will be linked from tail to head. Although
observations are lacking, I am inclined to interpret it as a
forward-linked list, simply from common sense.


=head2 EXPORT

None

=head1 SEE ALSO

Finnigan::RunHeader

=head1 AUTHOR

Gene Selkov, E<lt>selkovjr@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Gene Selkov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut