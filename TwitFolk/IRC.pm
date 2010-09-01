# © 2010 David Leadbeater; https://dgl.cx/licence
package TwitFolk::IRC;
use EV; # AnyEvent::Impl::Perl seems to behave oddly
use strict;

=head1 NAME

TwitFolk::IRC - Lame wrapper around AnyEvent::IRC::Client for TwitFolk

=cut

use base "AnyEvent::IRC::Client";
use AnyEvent::IRC::Util qw(prefix_nick);
use TwitFolk::Log;

sub connect {
  my($self, $parent, $addr, $port, $args) = @_;

  ($self->{twitfolk_connect_cb} = sub {
    $self->SUPER::connect($addr, $port, $args);

    $self->{parent} = $parent;
    $self->{args} = $args;

    my $channel = $args->{channel};
    $self->send_srv(JOIN => $channel =~ /^#/ ? $channel : "#$channel");

    if($args->{away}) {
      $self->send_srv(AWAY => $args->{away});
    }

  })->();

  # Register our callbacks
  for(qw(registered disconnect join irc_433 irc_notice)) {
    my $callback = "on_$_";
    $self->reg_cb($_ => sub {
      my $irc = shift;
      debug "IRC: $callback: " . (ref($_[0]) eq 'HASH' ? JSON::to_json($_[0]) : "");
      $self->$callback(@_)
    });
  }
}

sub msg {
  my($self, $who, $text) = @_;
  $self->send_srv(PRIVMSG => $who, $text);
}

sub notice {
  my($self, $who, $text) = @_;
  $self->send_srv(NOTICE => $who, $text);
}

sub on_registered {
  my($self) = @_;

  $self->enable_ping(90);
}

sub on_disconnect {
  my($self) = @_;

  $self->{reconnect_timer} = AE::timer 10, 0, sub {
    undef $self->{reconnect_timer};
    $self->{twitfolk_connect_cb}->();
  };
}

sub on_join {
  my($self, $nick, $channel, $myself) = @_;

  $self->{parent}->on_join if $myself;
}

# Nick in use
sub on_irc_433 {
  my($self) = @_;

  $self->send_srv(NICK => $self->{nick} . $$);
  $self->msg("NickServ", "RECOVER $self->{args}->{nick} $self->{args}->{nick_pass}");
}

sub on_irc_notice {
  my($self, $msg) = @_;

  if(lc prefix_nick($msg) eq 'nickserv') {
    local $_ = $msg->{params}->[-1];

    if (/This nick is owned by someone else/ ||
      /This nickname is registered and protected/i) {
      debug("ID to NickServ at request of NickServ");
      $self->msg("NickServ", "IDENTIFY $self->{args}->{nick_pass}");

    } elsif (/Your nick has been recovered/i) {
      debug("NickServ told me I recovered my nick, RELEASE'ing now");
      $self->msg("NickServ", "RELEASE $self->{args}->{nick} $self->{args}->{nick_pass}");

    } elsif (/Your nick has been released from custody/i) {
      debug("NickServ told me my nick is released, /nick'ing now");
      $self->send_srv(NICK => $self->{args}->{nick});
    } else {
      debug("Ignoring NickServ notice: %s", $_);
    }
  }
}

1;
