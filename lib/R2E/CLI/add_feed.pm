package R2E::CLI::add_feed;
use MooseX::App::Command;
use MooseX::Method::Signatures;

extends qw(R2E::CLI);

command_short_description "Add a feed to the database";
command_long_description <<"LONG";
Add a feed to a the database.
LONG
    ;

use R2E::DB;

option name => (
    is            => 'rw',
    isa           => 'Str',
    required      => 1,
    documentation => "Name of the feed",
    );

option url => (
    is            => 'rw',
    isa           => 'Str',
    required      => 1,
    documentation => "Feed URL",
    );

option category => (
    is            => 'rw',
    isa           => 'Str',
    required      => 1,
    default       => 'none',
    documentation => "Feed category",
    );

option start => (
    is            => 'rw',
    isa           => 'Str',
    documentation => "Start pattern",
    );

option fetch_linked => (
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Should rss2email fetch the linked page to put in the email',
    );

option stop => (
    is            => 'rw',
    isa           => 'Str',
    documentation => "Stop pattern",
    );

method run () {
    my $db = R2E::DB->connect($self->dsn);

    ## check if category exists and create it if it doesn't.
    my $category = $db->resultset("Category")->find_or_create(
	{name => $self->category}
	);

    ## Add feed
    my $options = {
	title       => $self->name,
	category_id => $category->category_id,
	url         => $self->url,
	fetch_linked => $self->fetch_linked,
    };

    $options->{start_pattern} = $self->start if defined $self->start;
    $options->{stop_pattern}  = $self->stop  if defined $self->stop;

    my $feed = $db->resultset("Feed")->find_or_create($options);
}

1;
