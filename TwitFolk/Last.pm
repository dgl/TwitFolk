package TwitFolk::Last;
use Moose;
use TwitFolk::Log;

has tweet_id_file => (
  isa => "Str",
  is => "ro"
);

has last_tweets   => (
  isa => "ArrayRef[Int]",
  is => "rw",
  default => sub {
    my($self) = @_;
    [$self->init]
  }
);

my %service_map = (
  twitter => 0,
  identica => 1
);

=head2 init

Read the last tweet ids from a file so that no tweets should be repeated.
Supports storing two tweet ids, one per service: twitter then identi.ca.

=cut

sub init
{
  my($self) = @_;

  return 0, 0 unless -f $self->tweet_id_file;

  open my $lt, "<", $self->tweet_id_file or die "Couldn't open tweet_id_file: $!";

  my @ids = ();

  while (<$lt>) {
    die "Weird format $_ in tweet_id_file" unless (/^(\d+)/);
    push @ids, $1;
  }

  close $lt or warn "Something weird when closing tweet_id_file: $!";

  push @ids, 0 while (scalar @ids  < 2);
  debug("Last tweet id = %s", $_) foreach (@ids);

  return @ids;
}

sub update
{
  my($self, $service, $id) = @_;

  my $pos = $service_map{$service};

  if($self->last_tweets->[$pos] < $id) {
    $self->last_tweets->[$pos] = $id;
    $self->save;
  }
}

sub get {
  my($self, $service, $id) = @_;

  my $pos = $service_map{$service};

  return $self->last_tweets->[$pos];
}

=head2 save

Save the ids of the most recent tweet/dent so that it won't be repeated should
the bot crash or whatever

=cut

sub save
{
  my($self) = @_;

  open my $lt, ">", $self->tweet_id_file or die "Couldn't open tweet_id_file: $!";
  print $lt "$_\n" for @{$self->last_tweets};
  close $lt or warn "Something weird when closing tweet_id_file: $!";
}

1;
