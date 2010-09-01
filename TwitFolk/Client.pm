# © 2010 David Leadbeater; https://dgl.cx/licence
package TwitFolk::Client;
use Moose;
use TwitFolk::Log;
use HTML::Entities;
use Encode qw(encode_utf8);

has irc         => (isa => "TwitFolk::IRC", is => "ro");
has target      => (isa => "Str", is => "ro");
has friends     => (isa => "TwitFolk::Friends", is => "ro");
has last_tweets => (isa => "TwitFolk::Last", is => "ro");

sub on_update {
  my($self, $update) = @_;

  my $screen_name = $update->{user}->{screen_name};
  my $nick = $self->friends->lookup_nick($screen_name);
  my $text = decode_entities $update->{text};

  # Skip tweets directed at others who aren't friends
  if ($text =~ /^@([[:alnum:]_]+)/) {
    my $other_sn = lc($1);
    unless (grep { lc($_) eq $other_sn } keys %{$self->friends->friends}) {
      debug("Ignoring reply tweet %s from [%s] to [%s]",
        $update->{id}, $screen_name, $other_sn);
      return;
    }
  }

  debug("%s/%s: [%s/\@%s] %s", ref $self, $update->{id}, $nick, $screen_name, $text);

  if ($text =~ /[\n\r]/) {
    debug("%s/%s contains dangerous characters; removing!",
      ref $self, $update->{id});
    $text =~ s/[\n\r]/ /g;
  }

  $self->irc->notice($self->target, encode_utf8 sprintf("[%s/\@%s] %s",
      $nick, $screen_name, $text));
}

1;
