package File::Find::Geotagged;

use strict;
use warnings;
use DBI;
use File::Path qw(make_path);
use File::Spec;
use Math::Trig qw(deg2rad pi great_circle_distance);

use constant EARTH_RADIUS_KM => 6371;
use constant DEG_PER_KM     => 180 / (pi * EARTH_RADIUS_KM);

=head1 NAME

File::Find::Geotagged - SQLite cache of geotagged photo coordinates

=head1 SYNOPSIS

    use File::Find::Geotagged;

    my $cache = File::Find::Geotagged->connect;
    my @rows  = $cache->find_in_bbox($lat, $lon, $radius_km);
    $cache->store_coords($filename, $lat, $lon);

=head1 DESCRIPTION

Caches filename -> (latitude, longitude) mappings in a SQLite database
stored under C<$XDG_DATA_HOME/find-geotagged/> (or
C<~/.local/share/find-geotagged/>). Coordinates are looked up by a
bounding box first; callers filter the circle themselves using
C<distance_km>.

=head1 METHODS

=over

=item C<connect>

Opens (creating if needed) the cache database and returns a cache
object. Croaks on failure.

=item C<db_file>

Class method returning the path of the SQLite database file.

=item C<find_in_bbox($lat, $lon, $radius_km)>

Returns a list of hashrefs C<{ filename, latitude, longitude }> for all
cached photos inside the bounding box of the given center and radius.

=item C<distance_km($lat1, $lon1, $lat2, $lon2)>

Class method: great-circle distance between two points in kilometers.

=item C<store_coords($filename, $lat, $lon)>

Inserts or replaces coordinates for a file (filename has a UNIQUE
index, so re-scanning updates the row instead of duplicating it).
The C<modified_at> column is set to the current UTC time on every
write.

=back

=cut

sub db_file {
    my $base = $ENV{XDG_DATA_HOME}
        // ($ENV{HOME} ? "$ENV{HOME}/.local/share" : '.');
    return File::Spec->catfile($base, 'find-geotagged', 'geotagged.db');
}

sub distance_km {
    my ($lat1, $lon1, $lat2, $lon2) = @_;
    # great_circle_distance expects colatitude (pi/2 - lat) as phi
    return great_circle_distance(
        deg2rad($lon1), pi / 2 - deg2rad($lat1),
        deg2rad($lon2), pi / 2 - deg2rad($lat2),
        EARTH_RADIUS_KM,
    );
}

sub connect {
    my $class = shift;
    my $file  = $class->db_file;
    my ($vol, $dir, undef) = File::Spec->splitpath($file);
    make_path(File::Spec->catpath($vol, $dir, ''));

    my $dbh = DBI->connect("dbi:SQLite:dbname=$file", '', '', {
        RaiseError => 1,
        PrintError => 0,
    });

    $dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS photos (
    id          INTEGER PRIMARY KEY,
    filename    TEXT    NOT NULL UNIQUE,
    latitude    REAL    NOT NULL,
    longitude   REAL    NOT NULL,
    modified_at TEXT    NOT NULL
)
SQL
    $dbh->do('CREATE INDEX IF NOT EXISTS idx_photos_bbox ON photos (latitude, longitude)');

    return bless { dbh => $dbh }, $class;
}

sub find_in_bbox {
    my ($self, $lat0, $lon0, $radius_km) = @_;

    my $lat_delta = $radius_km * DEG_PER_KM;
    my $cos_lat   = cos(deg2rad($lat0));
    my $lon_delta = abs($cos_lat) < 1e-6 ? 180 : $lat_delta / $cos_lat;

    my $sth = $self->{dbh}->prepare(<<'SQL');
SELECT filename, latitude, longitude, modified_at
FROM photos
WHERE latitude  BETWEEN ? AND ?
  AND longitude BETWEEN ? AND ?
SQL
    $sth->execute(
        $lat0 - $lat_delta, $lat0 + $lat_delta,
        $lon0 - $lon_delta, $lon0 + $lon_delta,
    );

    return @{ $sth->fetchall_arrayref({}) };
}

sub store_coords {
    my ($self, $filename, $lat, $lon) = @_;
    $self->{dbh}->do(
        q{INSERT OR REPLACE INTO photos (filename, latitude, longitude, modified_at)
          VALUES (?, ?, ?, datetime('now'))},
        undef, $filename, $lat, $lon,
    );
}

1;

__END__
