# © 2010 David Leadbeater; https://dgl.cx/licence
package TwitFolk::Client;
use Moose;
use Encode qw(encode_utf8);
use HTML::Entities;
use Mail::SpamAssassin::Util::RegistrarBoundaries;
use TwitFolk::Log;
use URI;

has irc         => (isa => "TwitFolk::IRC", is => "ro");
has target      => (isa => "Str", is => "ro");
has friends     => (isa => "TwitFolk::Friends", is => "ro");
has last_tweets => (isa => "TwitFolk::Last", is => "ro");

sub on_update {
  my($self, $update) = @_;

  my $screen_name = $update->{user}->{screen_name};
  my $nick = $self->friends->lookup_nick($screen_name);
  my $text = decode_entities $update->{text};

  if($update->{retweeted_status}->{text}) {
    $text = "RT \@" . $update->{retweeted_status}->{user}->{screen_name} . ": "
      . decode_entities $update->{retweeted_status}->{text};
  }

  # Skip tweets from people who aren't friends
  unless(grep { lc($_) eq lc $screen_name } keys %{$self->friends->friends}) {
    debug("Ignoring tweet %s from [%s]", $update->{id}, $screen_name);
    return;
  }

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

  if ($update->{entities}->{urls}) {
    for my $url(@{$update->{entities}->{urls}}) {
      my $full_uri = $url->{expanded_url};
      my $uri = URI->new($full_uri);
      next unless $uri;
      my(undef, $domain) = Mail::SpamAssassin::Util::RegistrarBoundaries::split_domain($uri->host);
      # Use replacement rather than the given offset, makes doing the
      # replacement easier.
      if((5 + length $url->{url}) >= length $full_uri) {
        $text =~ s/\Q$url->{url}\E/$full_uri/;
      } else {
        $text =~ s/(\Q$url->{url}\E)/"$1 [" . $domain . "]"/e;
      }
    }
  }

  $self->irc->notice($self->target, encode_utf8 sprintf("[%s/\@%s] %s",
      $nick, $screen_name, $text));
}

1;
