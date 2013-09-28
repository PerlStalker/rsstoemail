package R2E::CLI::create_db;
use MooseX::App::Command;
use MooseX::Method::Signatures;
extends qw(R2E::CLI);

command_short_description "Create the feed database";
command_long_description <<"LONG";
Create the feed database.
LONG
    ;

use R2E::DB;

option drop_tables => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Drop existing tables. (Use with caution!)',
    );

method run () {
    my $db = R2E::DB->connect($self->dsn);
    if ($self->drop_tables) {
	warn "Dropping existing tables\n" if $self->verbose;
	$db->deploy({ add_drop_table => 1 });

	my $category = $db->resultset("Category")->create({name => 'none'});
    }
    else {
	$db->deploy;
    }
}

1;
