package TwitFolk::Client::Identica;
use AE;
use Moose;
use Try::Tiny;
use TwitFolk::Log;

extends "TwitFolk::Client";

with qw(TwitFolk::Client::Basic);

has max_tweets => (isa => "Int", is => "ro");
has sync_timer => (is => "rw");

sub BUILD {
  my($self) = @_;

  $self->api_args->{identica} = 1;

  $self->sync_timer(
    # Every 300 seconds
    AE::timer 300, 300, sub {
      $self->sync;
    }
  );
}

sub sync {
  my($self) = @_;

  my $svcname = "identica"; # lame, but works for now

  # Ask for 10 times as many tweets as we will ever say, but no more than
  # 200
  my $max = $self->max_tweets >= 20 ? 200 : $self->max_tweets * 10;
  my $count = 0;
  my $opts = { count => $max };

  # Ask for the timeline of friend's statuses, only since the last tweet
  # if we know its id
  $opts->{since_id} = $self->last_tweets->get("identica") if $self->last_id;

  # Net::Twitter sometimes dies inside JSON::Any :(
  my $tweets;
  try {
    $tweets = $self->api->friends_timeline($opts);
  } catch {
    debug("%s->friends_timeline() error: %s", $svcname, $@);
  }
  return unless $tweets;

  if ($self->api->http_code != 200) {
    debug("%s->friend_timeline() failed: %s", $svcname,
      $self->api->http_message);
    return;
  }

=pod

$tweets should now be a reference to an array of:

          {
            'source' => 'web',
            'favorited' => $VAR1->[0]{'favorited'},
            'truncated' => $VAR1->[0]{'favorited'},
            'created_at' => 'Tue Oct 28 22:22:14 +0000 2008',
            'text' => '@deltafan121 Near Luton, which is just outside London.',
            'user' => {
                        'location' => 'Bedfordshire, United Kingdom',
                        'followers_count' => 10,
                        'profile_image_url' => 'http://s3.amazonaws.com/twitter_production/profile_images/62344418/SP_A0089_2_normal.jpg',
                        'protected' => $VAR1->[0]{'favorited'},
                        'name' => 'Robert Leverington',
                        'url' => 'http://robertleverington.com/',
                        'id' => 14450923,
                        'description' => '',
                        'screen_name' => 'roberthl'
                      },
            'in_reply_to_user_id' => 14662919,
            'id' => 979630447,
            'in_reply_to_status_id' => 979535561
          }
=cut

=pod
But I guess we better check, since this happened one time at band camp:

Tue Nov 18 07:58:41 2008| *** twitter->friend_timelines() failed: Can't connect to twitter.com:80 (connect: timeout)
Tue Nov 18 08:03:41 2008| *** twitter->friend_timelines() failed: Can't connect to twitter.com:80 (connect: timeout)
Tue Nov 18 08:08:50 2008| *** twitter->friend_timelines() failed: read timeout
Tue Nov 18 08:13:41 2008| *** twitter->friend_timelines() failed: Can't connect to twitter.com:80 (connect: timeout)
Tue Nov 18 08:18:41 2008| *** twitter->friend_timelines() failed: Can't connect to twitter.com:80 (connect: timeout)
Tue Nov 18 08:23:43 2008| *** twitter->friend_timelines() failed: Can't connect to twitter.com:80 (connect: timeout)
Not an ARRAY reference at ./twitfolk.pl line 494.
=cut

  if (ref($tweets) ne "ARRAY") {
    debug("%s->friend_timelines() didn't return an arrayref!", $svcname);
    return;
  }

  debug("Got %u new tweets from %s", scalar @$tweets, $svcname);

  # Iterate through them all, sorted by id low to high
  for my $tweet (sort { $a->{id} <=> $b->{id} } @{ $tweets }) {

    if ($count >= $self->max_tweets) {
      debug("Already did %u tweets, stopping there", $count);
      last;
    }

    if ($tweet->{id} <= $self->last_tweets->get("identica")) {
      # Why does Twitter still return tweets that are <= since_id?
      debug("%s/%s: ignored as somehow <= %s !?", $svcname,
        $tweet->{id}, $self->last_tweets->get("identica"));
      next;
    }

    $self->on_update($tweet);

    $self->last_tweets->update(identica => $tweet->{id});

    $count++;
  }
}

1;
