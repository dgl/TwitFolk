# © 2010 David Leadbeater; https://dgl.cx/licence
package TwitFolk::Client::OAuth;

=head1 NAME

TwitFolk::Client::OAuth - Handle OAuth stuffs

=head1 DESCRIPTION

Twitter wants an OAuth login thesedays, this provides the handling for it, you
need to implement need_authorization in the class that does this role; it will
be given the URL Twitter wants you to go to, this will give the user a pin,
that should be passed back to authorization_response.

Probably should be two roles to separate out the state saving, but I'm lazy.

=cut

use Moose::Role;
use Net::Twitter;
use JSON qw(from_json to_json); # For serialisation

requires "need_authorization";

has state_file           => (isa => "Str", is => "ro", default => sub { "oauth.state" });
has consumer_key         => (isa => "Str", is => "ro");
has consumer_secret      => (isa => "Str", is => "ro");
has access_token         => (isa => "Str", is => "rw");
has access_token_secret  => (isa => "Str", is => "rw");
has api                  => (isa => "Net::Twitter", is => "rw");
has api_args             => (isa => "HashRef", is => "ro", default => sub { {} });

sub BUILD { }

# I'm bad, but this is easier.
after BUILD => sub {
  my($self) = @_;
  
  $self->api(Net::Twitter->new(
    traits          => [qw(API::REST OAuth)],
    consumer_key    => $self->consumer_key,
    consumer_secret => $self->consumer_secret,
    %{$self->api_args}
  ));

  unless(open my $fh, "<", $self->state_file) {
    warn "Unable to open '" . $self->state_file . "': $!" unless $!{ENOENT};

  } else {
    my $state = from_json(join "", <$fh>);

    $self->access_token($state->{access_token});
    $self->access_token_secret($state->{access_token_secret});
  
    if($self->access_token) {
      $self->api->access_token($self->access_token);
      $self->api->access_token_secret($self->access_token_secret);
    }
  }
};

sub authorize {
  my($self) = @_;

  my $authorized = $self->api->authorized;

  unless($authorized) {
    $self->need_authorization($self->api->get_authorization_url);
  }

  return $authorized;
}

sub authorization_response {
  my($self, $pin) = @_;

  my($access_token, $access_token_secret, $user_id, $screen_name) =
    $self->api->request_access_token(verifier => $pin);

  $self->access_token($access_token);
  $self->access_token_secret($access_token_secret);

  $self->save_state;
  return 1;
}

sub save_state {
  my($self) = @_;
  my $new = $self->state_file . ".new";

  open my $fh, ">", $new or do {
    warn "Unable to write to '$new': $!";
    return;
  };

  print $fh to_json {
    access_token        => $self->access_token,
    access_token_secret => $self->access_token_secret
  };

  rename $new => $self->state_file; 
}

1;
