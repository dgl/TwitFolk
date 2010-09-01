# © 2010 David Leadbeater; https://dgl.cx/licence
package TwitFolk::Client::Twitter;
use Moose;
use AnyEvent::IRC::Util qw(prefix_nick);
use AnyEvent::Twitter::Stream;
use Try::Tiny;
use TwitFolk::Log;

extends "TwitFolk::Client";

with qw(TwitFolk::Client::OAuth);

# Who to contact when we need OAuth fixing
has owner => (isa => "Str", is => "rw");

# Our listener for tweets
has listener => (isa => "Maybe[AnyEvent::Twitter::Stream]", is => "rw");

# Timer for reconnections
has reconnect_timer => (is => "rw");

sub BUILD {
  my($self) = @_;

  $self->irc->reg_cb(privatemsg => sub { $self->on_privmsg(@_) });
}

sub sync {
  my($self) = @_;

  try {
    if($self->authorize) {
      $self->start_stream;
    }
  } catch {
    warn "Can't sync: $_";
  };
}

sub need_authorization {
  my($self, $url) = @_;

  $self->irc->msg($self->owner,
    "Please could you be so kind as to login as me on Twitter, go to $url and then msg me with the pin, thank you!");
}

sub on_privmsg {
  my($self, $irc, $nick, $msg) = @_;

  if(lc prefix_nick($msg) eq $self->owner
      && $msg->{params}->[-1] =~ /^(\d+)\s*$/) {

    try {
      $self->authorization_response($1);
      $self->irc->msg($self->owner, "Most excellent, sir!");
      $self->start_stream;
    } catch {
      $self->irc->msg($self->owner, "Sorry, that didn't seem to work: $_");
    }
  }
}

sub reconnect {
  my($self) = @_;

  $self->listener(undef);

  $self->reconnect_timer(
    AE::timer 10, 0, sub {
      $self->reconnect_timer(undef);
      debug "Reconnecting to twitter...";
      $self->sync;
    }
  );
}

sub start_stream {
  my($self) = @_;
  return if $self->listener;

  debug "Starting stream";

  $self->listener(
    AnyEvent::Twitter::Stream->new(
      consumer_key    => $self->consumer_key,
      consumer_secret => $self->consumer_secret,
      token           => $self->access_token,
      token_secret    => $self->access_token_secret,
      method          => "userstream",
      on_tweet        => sub {
        my($tweet) = @_;
        debug "on_tweet: " . JSON::to_json($tweet);

        return unless $tweet->{user};
        $self->on_update($tweet);
        $self->last_tweets->update(twitter => $tweet->{id}); # This is totally pointless with streaming API, but doesn't hurt
      },
      on_error        => sub {
        debug "Error from twitter stream: @_";
        $self->reconnect;
      },
      on_eof          => sub {
        debug "EOF from twitter stream";
        $self->reconnect;
      },
    )
  );
}

1;
