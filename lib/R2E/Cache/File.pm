package R2E::Cache::File;
use Moose;
use MooseX::Method::Signatures;

# This package exists because Cache::File doesn't handle utf8 properly.
# As such, it's not as fully featured.

use feature 'unicode_strings';
use open ':encoding(utf8)';
use encoding 'utf8';

use File::Path qw(make_path remove_tree);
use Digest::SHA3 qw(sha3_256_hex);
use DateTime;
use Try::Tiny;

method get (
    Str $key
    ) {

    my $path = $self->cache_root.'/'.$self->_path_hash($key);

    if (-r "$path/content") {
	my $mtime = (stat(_))[9];
	my $mtime_dt = DateTime->from_epoch(
	    epoch     => $mtime,
	    time_zone => $self->time_zone,
	    );

	# TODO read an expiration time from somewhere ($path/expiry ?)

	my $cache_dt = $mtime_dt->add($self->default_duration);
	my $now_dt   = DateTime->now(time_zone => $self->time_zone);

	# If now is later than the cache timeout ...
	if (DateTime->compare($now_dt, $cache_dt) == 1) {
	    # remove the old key from the cache
	    $self->_remove_key($key);
	    return undef;
	}
	else {
	    return $self->_slurp_file("$path/content");
	}
    }
    else {
	return undef;
    }
}

method set (
    Str $key,
    Str $content,
    $expiry? # DateTime::Duration
    ) {

    $expiry = $self->default_duration unless defined $expiry;

    my $errors;

    my $path = $self->cache_root.'/'.$self->_path_hash($key);
    make_path($path, { error => \$errors} );
    if (@$errors) {
	my $message = '';
	foreach my $diag (@$errors) {
	    foreach my $file (keys %$diag) {

		$message .= "Error making $file: ". $diag->{$file}. "\n";
	    }
	}
	die $message;
    }

    $self->_spew_file("$path/key", $key);
    $self->_spew_file("$path/content", $content);

    return;
}

method clean () {
    remove_tree($self->cache_root);
}

method purge () {
}

method _remove_key (
    Str $key
    ) {
    my $path = $self->cache_root.'/'.$self->_path_hash($key);
    remove_tree($path);
}

method _slurp_fh ($fh) {
    return do { local $/, <$fh> };
}

method _slurp_file ($file_name) {
    open my $fh, '<:encoding(utf8)', $file_name or die "Can't open $file_name: $!\n";
    my $content;
    eval {
	$content = $self->_slurp_fh($fh);
    };
    close $fh;

    return $content;
}

method _spew_file (
    $file_name,
    $content
    ) {
    open my $fh, '>:encoding(utf8)', $file_name or die "Can't open $file_name: $!\n";
    eval {
	print $fh $content;
    };
    close $fh;
}

# returns the directory path
method _path_hash ($key) {
    my $digest = sha3_256_hex($key);
    my $path = sprintf(
	"%s/%s/%s",
	substr ($digest, 0, 2),
	substr ($digest, 2, 3),
	$digest
	);
    return $path;
}

with 'R2E::Cache';

1;

__END__
