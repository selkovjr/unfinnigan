package Finnigan::OLE2DirectoryEntry;

use strict;
use warnings;

use Finnigan;
use base 'Finnigan::Decoder';

my $UNUSED       = 0xFFFFFFFF;   # -1
my $END_OF_CHAIN = 0xFFFFFFFE;   # -2
my $FAT_SECTOR  = 0xFFFFFFFD;   # -3
my $DIF_SECTOR = 0xFFFFFFFC;   # -4
my $ROOT = 5;

my %SPECIAL = ($END_OF_CHAIN => 1, $UNUSED => 1, $FAT_SECTOR => 1, $DIF_SECTOR => 1);

sub new {
  my ($class, $file, $index) = @_;
  my $self = {file => $file, index => $index};
  bless $self, $class;

  # The directory entries are organized as a red-black tree. The
  # following piece of code does an ordered traversal of such a tree

  my $p = $file->{properties}->[$index];
  
  # copy the property's data
  $self->{name} = $p->name;
  $self->{type} = $p->type;
  $self->{start} = $p->start;
  $self->{size} = $p->size;
  
  # process child nodes, if any
  my @stack = ($index);
  my ($left, $right, $child);
  $index = $p->child;
  unless ( $index == $UNUSED ) {
    # start at the leftmost position
    $left = $file->{properties}->[$index]->left;
    $right = $file->{properties}->[$index]->right;
    $child = $file->{properties}->[$index]->child;

    while ( $left != $UNUSED ) {
      push @stack, $index;
      $index = $left;
      $left = $file->{properties}->[$index]->left;
      $right = $file->{properties}->[$index]->right;
      $child = $file->{properties}->[$index]->child;
    }

    while ( $index != $self->{index} ) { # while sid != self.sid:
      push @{$self->{children}}, new Finnigan::OLE2DirectoryEntry($file, $index);

      # try to move right
      $left = $file->{properties}->[$index]->left;
      $right = $file->{properties}->[$index]->right;
      $child = $file->{properties}->[$index]->child;
      if ( $right != $UNUSED ) {
        # and then back to the left
        $index = $right;
        while ( 1 ) {
          $left = $file->{properties}->[$index]->left;
          $right = $file->{properties}->[$index]->right;
          $child = $file->{properties}->[$index]->child;
          last if $left == $UNUSED;
          push @stack, $index;
          $index = $left;
        }
      }
      else {
        # couldn't move right; move up instead
        my $ptr;
        while ( 1 ) {
          $ptr = $stack[-1];
          pop @stack;
          $left = $file->{properties}->[$ptr]->left;
          $right = $file->{properties}->[$ptr]->right;
          $child = $file->{properties}->[$ptr]->child;
          last if $right != $index;
          $index = $right;
        }
        $left = $file->{properties}->[$index]->left;
        $right = $file->{properties}->[$index]->right;
        $child = $file->{properties}->[$index]->child;
        $index = $ptr if $right != $ptr;
      }
      # in the OLE file, entries are sorted on (length, name).
      # for convenience, we sort them on name instead.
      
      #self.kids.sort()
    }
  }

  return $self;
}

sub data {
  my $self = shift;
  print "parsing property: \"" . $self->name . "\"; size: " . $self->size . "; type: " . $self->type . "\n";

  my $data;

  # get the data
  my $stream_size;
  if ( $self->size ) {
    if (
        $self->size > $self->file->header->ministream_max
        or
        $self->type == $ROOT ) {  # the data in the root entry is always in big blocks
      $stream_size = 'big';
      print "  has data in big stream\n";
    }
    else {
      print "  has data in ministream\n";
      $stream_size = 'mini';
    }

    my $first = undef;
    my $previous = undef;
    my $size = 0;
    my $fragment_group = undef;
    my @chain = $self->file->get_chain($self->start, $stream_size);
    print "chain: @chain\n";

    my $contiguous;
    while ( 1 ) {
      my $block = shift @chain;
      if ( defined $block ) {
        $contiguous = 0;
        if ( not defined $first ) {
          $first = $block;
          $contiguous = 1;
        }
        if ( defined $previous and $block == $previous + 1 ) {
          $contiguous = 1;
        }
        if ( $contiguous ) {
          $previous = $block;
          $size += $self->file->sector_size($stream_size);
          next;
        }
      }
      last unless defined $first;

      $data .= $self->file->read(
                                 $stream_size, # which depot
                                 $first,       # where
                                 $previous - $first + 1 # how many sectors
                                );

      my $desc = sprintf "$stream_size blocks %s..%s (%s)", $first, $previous, $previous-$first+1;
      $desc .= sprintf " of %s bytes", $self->file->sector_size($stream_size);
      print "$desc\n";

      last unless $block;

      $first = $block;
      $previous = $block;
      $size = $self->file->sector_size;
    }
    return substr($data, 0, $self->size);
  }
  return undef;
}

sub file {
  shift->{file};
}

sub name {
  shift->{name};
}

sub type {
  shift->{type};
}

sub size {
  shift->{size};
}

sub start {
  shift->{start};
}

1;
__END__

=head1 NAME

Finnigan::OLE2DirectoryEntry -- a decoder for Microsoft structured data files, a container used to store instrument methods

=head1 SYNOPSIS

  use Finnigan;
  my $method_data = Finnigan::OLE2DirectoryEntry->decode(\*INPUT);
  $method_data->dump;

=head1 DESCRIPTION

...


=head2 EXPORT

None

=head1 SEE ALSO

Finnigan::MethodFile

=head1 AUTHOR

Gene Selkov, E<lt>selkovjr@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Gene Selkov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
