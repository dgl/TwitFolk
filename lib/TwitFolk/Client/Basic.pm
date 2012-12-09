# © 2010 David Leadbeater; https://dgl.cx/licence
package TwitFolk::Client::Basic;

=head1 NAME

TwitFolk::Client::Basic - Basic auth

=cut

use Moose::Role;
use Net::Twitter;

has username => (isa => "Str", is => "ro");
has password => (isa => "Str", is => "ro");
has api_args => (isa => "HashRef", is => "ro", default => sub { {} });

has api => (
  isa => "Net::Twitter",
  is => "rw"
);

sub BUILD { }

after BUILD => sub {
  my($self) = @_;

  $self->api(
    Net::Twitter->new(
      username => $self->username,
      password => $self->password,
      %{$self->api_args}
    )
  );
};

1;
