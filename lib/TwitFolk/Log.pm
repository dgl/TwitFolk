package TwitFolk::Log;
use constant DEBUG => $ENV{IRC_DEBUG};

use parent "Exporter";
our @EXPORT = qw(debug);

binmode STDERR, ":encoding(UTF-8)";

sub debug {
  eval {
    printf(STDERR "$_[0]\n", @_[1 .. $#_]) if DEBUG;
  };
  if($@) {
    warn "WTF: $@ (with @_)";
  }
}

1;
