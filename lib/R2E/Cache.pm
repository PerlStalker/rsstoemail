package R2E::Cache;
use Moose::Role;
use MooseX::Method::Signatures;

# This package exists because Cache::File doesn't handle utf8 properly.
# As such, it's not as fully featured.

use File::Path qw(make_path remove_tree);
use DateTime::Duration;
use DateTime::TimeZone;

requires qw(get set clean purge);

has cache_root => (
    is            => 'rw',
    isa           => 'Str',
    required      => 1,
    );

has default_duration => (
    is            => 'rw',
    isa           => 'DateTime::Duration',
    lazy          => 1,
    builder       => '_build_default_duration',
    );

has time_zone => (
    is            => 'rw',
    isa           => 'DateTime::TimeZone',
    lazy          => 1,
    builder       => '_build_time_zone',
    );

# return the content of the cache
method get (
    Str $key
    ) {
}

# set the content of the cache
method set (
    Str $key,
    Str $content,
    $expiry? # DateTime::Duration
    ) {
}

# clear the entire cache
method clean () {
}

# purge old items
method purge () {
}

method _build_time_zone () {
    return DateTime::TimeZone->new(name => 'local'); # guess the time zone
}

method _build_default_duration () {
    return DateTime::Duration->new(minutes => 15);
}

1;

__END__
