package R2E::CLI;
use warnings;
use strict;

use MooseX::App qw(BashCompletion Color Version);
use FindBin;

use R2E;

our $VERSION = $R2E::VERSION;

option 'verbose' => (
    is            => 'rw',
    isa           => 'Bool',
    documentation => 'Make output more verbose',
);

option 'debug' => (
    is            => 'rw',
    isa           => 'Bool',
    documentation => 'Turn on debugging output',
);

option 'dsn' => (
    is            => 'rw',
    isa           => 'Str',
    default       => "dbi:SQLite:$FindBin::Bin/../var/r2e.db",
    documentation => 'The database dsn',
    );

option 'concurrent' => (                                                        
    is            => 'rw',
    isa           => 'Int',
    default       => '3',
    documentation => 'Number of concurrent checks'
    );     
1;
