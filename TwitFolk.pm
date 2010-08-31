=pod

TwitFolk

Gate tweets from your Twitter/identi.ca friends into an IRC channel.

http://dev.bitfolk.com/twitfolk/

Copyright ©2008 Andy Smith <andy+twitfolk.pl@bitfolk.com>

Copyright ©2010 David Leadbeater <dgl@dgl.cx>

Artistic license same as Perl.

$Id: twitfolk.pl 1580 2010-06-10 12:45:21Z andy $
=cut

package TwitFolk;
our $VERSION = "0.2";

use Config::Tiny;
use Moose;
use Try::Tiny;

use TwitFolk::Client::Identica;
use TwitFolk::Client::Twitter;
use TwitFolk::Friends;
use TwitFolk::IRC;
use TwitFolk::Last;

with qw(MooseX::Daemonize);

has config_file => (
  isa     => "Str",
  is      => "ro",
  default => sub { "twitfolk.conf" }
);

has ircname => (
  isa     => "Str",
  is      => "ro",
  default => sub { "twitfolk $VERSION" }
);

has _config => (
  isa     => "HashRef",
  is      => "ro",
);

has _irc => (
  isa     => "TwitFolk::IRC",
  is      => "ro",
  default => sub { TwitFolk::IRC->new }
);

has _friends => (
  isa     => "TwitFolk::Friends",
  is      => "rw"
);

has _twitter => (
  isa     => "TwitFolk::Client",
  is      => "rw"
);

has _identica => (
  isa     => "TwitFolk::Client", 
  is      => "rw"
);

sub BUILD {
  my($self) = @_;

  my $config = Config::Tiny->read($self->config_file)
      or die Config::Tiny->errstr;
  # Only care about the root section for now.
  $self->{_config} = $config->{_};

  $self->_friends(
    TwitFolk::Friends->new(friends_file => $self->_config->{friends_file})
  );

  $self->pidfile($self->_config->{pidfile});
}


# The "main"
after start => sub {
  my($self) = @_;

  $SIG{HUP} = sub {
    $self->_friends->update;
    $self->_twitter->sync if $self->_twitter;
    $self->_identica->sync if $self->_identica;
  };

  try {
    $self->connect;
    AnyEvent->condvar->recv;
  } catch {
    # Just the first line, Moose can spew rather long errors
    $self->_irc->disconnect("Died: " . (/^(.*)$/m)[0]);
    warn $_;
  };
};

before shutdown => sub {
  my($self) = @_;

  $self->_irc->disconnect("Shutdown");
};

sub connect {
  my($self) = @_;
  my $c = $self->_config;

  $self->_irc->connect($self,
    $c->{target_server}, $c->{target_port},
    {
      nick     => $c->{nick},
      user     => $c->{username},
      real     => $self->ircname,
      password => $self->{target_pass},
      channel  => $c->{channel},
      away     => $c->{away}
    }
  );
}

# Bot is primed
sub on_join {
  my($self) = @_;

  my $last_tweets = TwitFolk::Last->new(
    tweet_id_file => $self->_config->{tweet_id_file}
  );

  # Probably should use traits rather than hardcoded classes like this, too
  # lazy though.

  if($self->_config->{use_twitter}) {
    $self->_twitter(
      TwitFolk::Client::Twitter->new(
        irc             => $self->_irc,
        target          => "#" . $self->_config->{channel},
        consumer_key    => $self->_config->{twitter_consumer_key},
        consumer_secret => $self->_config->{twitter_consumer_secret},
        owner           => $self->_config->{owner},
        last_tweets     => $last_tweets,
        friends         => $self->_friends,
      )
    );
    $self->_friends->twitter($self->_twitter);
    $self->_twitter->sync;
  }

  if($self->_config->{use_identica}) {
    $self->_identica(
      TwitFolk::Client::Identica->new(
        irc         => $self->_irc,
        target      => "#" . $self->_config->{channel},
        username    => $self->_config->{identica_user},
        password    => $self->_config->{identica_pass},
        max_tweets  => $self->_config->{max_tweets},
        last_tweets => $last_tweets,
        friends     => $self->_friends,
      )
    );
    $self->_friends->identica($self->_identica);
    $self->_identica->sync;
  }
}

1;
