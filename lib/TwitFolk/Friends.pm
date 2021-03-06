package TwitFolk::Friends;
use Moose;
use Try::Tiny;
use TwitFolk::Log;

has friends_file => (isa => "Str", is => "ro");

has twitter  => (isa => "TwitFolk::Client", is => "rw");
has identica => (isa => "TwitFolk::Client", is => "rw");

has friends  => (isa => "HashRef", is => "rw", default => sub { {} });

=head2 lookup_nick

Return the nick associated with the screen name, or the screen name if nick is
not known.

=cut

sub lookup_nick {
  my($self, $screen_name) = @_;

  if(exists $self->friends->{lc $screen_name}) {
    return $self->friends->{lc $screen_name}->{nick};
  }

  return $screen_name;
}

=head2 update

Read a list of friends from the friends_file.  These will be friended in
Twitter if they aren't already.  Format is:
        
screen_name     IRC_nick    service

Start a line with # for a comment.  Any kind of white space is okay.

Service column may be 'twitter' or 'identica', defaulting to twitter if
none is specified.

=cut

sub update
{           
  my $self = shift;

  open my $ff, "<", $self->friends_file or die "Couldn't open friends_file: $!";

  while (<$ff>) {
    next if (/^#/);

    if (/^(\S+)\s+(\S+)(?:\s+(\S+))?/) {
      my $f = lc($1);
      my $nick = $2;
      my $svcname = $3 || 'twitter';

      if (!exists $self->friends->{$f}) {
        my $u;    
        my $svc;

        # Friend may be on identi.ca OR twitter
        if($svcname =~ /dent/i) {
          $svc = $self->identica && $self->identica->api;
        } else {
          $svc = $self->twitter->api;
        }

        try {
          $u = $svc->show_user($f);
        } catch {
          debug("%s->show_user(%s) error: %s", $svcname, $f, $_);
        };

        my $id = $u->{id};
        $self->friends->{$f}->{id} = $id;

        debug("%s: Adding new friend '%s' (%lu)", $svcname,
          $f, $id);

        0 && try {
          $svc->create_friend($id); 
        } catch {
          debug("%s->create_friend(%lu) error: %s",
            $svcname, $id, $_);
        };

        $self->friends->{$f}->{nick} = $nick;
      }
    }
  }
  close $ff or warn "Something weird when closing friends_file: $!";
}

=head1 sync

Learn friends from those already added in Twitter, just in case they got added
from outside as well.  Might make this update the friends file at some point.

=cut

sub sync
{
  my $self = shift;
  my $svc = shift;
  my $svcname = shift;

  my $twitter_friends;

  try {
    $twitter_friends = $svc->friends;
  } catch {
    debug("%s->friends() error: %s", $svcname, $_);
  };
  return unless $twitter_friends;

  if (ref($twitter_friends) ne "ARRAY") {
    debug("%s->friends() didn't return an arrayref!", $svcname);
    return;
  }

  for my $f (@{$twitter_friends}) {
    my $screen_name = lc($f->{screen_name});
    my $id = $f->{id};

    $self->friends->{$screen_name}->{id} = $id;

    if (! defined $self->friends->{$screen_name}->{nick}) {
      $self->friends->{$screen_name}->{nick} = $screen_name;
    }

    debug("%s: Already following '%s' (%lu)", $svcname, $screen_name,
      $self->friends->{$screen_name}->{id});
  }
}

1;
