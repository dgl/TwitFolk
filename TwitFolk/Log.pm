package TwitFolk::Log;
use constant DEBUG => $ENV{IRC_DEBUG};

use parent "Exporter";
our @EXPORT = qw(debug);

sub debug {
  warn sprintf "$_[0]\n", @_[1 .. $#_] if DEBUG;
}

1;
