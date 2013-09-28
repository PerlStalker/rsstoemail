package R2E::CLI::clear_cache;
use MooseX::App::Command;
use MooseX::Method::Signatures;

extends qw(R2E::CLI);

command_short_description "Clear the cache.";
command_long_description <<"LONG";
Clears old items from the cache purges the entire cache with the
--purge option.
LONG
    ;

use R2E;

option purge => (
    is            => 'rw',
    isa           => 'Bool',
    documentation => 'Purge the cache instead of cleaning it.'
    );

method run () {
    my $r2e = R2E->new;
    
    if ($self->purge) {
	$r2e->cache->purge;
    }
    else {
	$r2e->cache->clean;
    }
}

1;
