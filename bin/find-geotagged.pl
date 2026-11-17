#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use Cwd qw(abs_path);
use lib "$FindBin::RealBin/../lib";
use File::Find;
use Image::ExifTool;
use File::Find::Geotagged;

sub parse_args {
    my @args = @_;

    # Allow coordinates as a single "LAT/LON" argument
    if (@args && $args[0] =~ m{^\s*([+-]?\d+(?:\.\d+)?)\s*/\s*([+-]?\d+(?:\.\d+)?)\s*$}) {
        splice(@args, 0, 1, $1, $2);
    }

    return @args;
}

unless (caller) {
    my ($lat0, $lon0, $radius_km, @dirs) = parse_args(@ARGV);

    if (@ARGV < 3 || @dirs == 0) {
        die "Usage: $0 LAT LON RADIUS_KM DIR [DIR ...]\n" .
            "       $0 LAT/LON RADIUS_KM DIR [DIR ...]\n";
    }

    # store and compare absolute paths in the cache
    @dirs = map { abs_path($_) // $_ } @dirs;

    # --- 1-3. Results from the SQLite cache: bbox lookup, circle
    # filter, remember what was already printed ---
    my %already_found;
    my $cache = eval { File::Find::Geotagged->connect };
    if ($cache) {
        if (my $err = eval {
            for my $row ($cache->find_in_bbox($lat0, $lon0, $radius_km)) {
                $already_found{$row->{filename}} = 1;
                my $dist_km = File::Find::Geotagged::distance_km(
                    $row->{latitude}, $row->{longitude}, $lat0, $lon0);
                if ($dist_km <= $radius_km) {
                    printf "%s\t%.3f km - %f, %f\n",
                        $row->{filename}, $dist_km, $row->{latitude}, $row->{longitude};
                }
            }
            1;
        }) {
            # cache hits served
        } else {
            warn "Cache query failed, falling back to full scan: $@\n";
            %already_found = ();
        }
    } else {
        warn "Cache unavailable, scanning without it: $@\n";
    }

    # --- 4. Slow full scan, skipping cached hits and storing coords ---
    my $exifTool = Image::ExifTool->new;

    find(
        {
            wanted => sub {
                return unless -f $_;
                return unless /\.(jpe?g|heic|tiff?)$/i;
                return if $already_found{$File::Find::name};

                my $info = $exifTool->ImageInfo($_, { PrintConv => 0 }, 'GPSLatitude', 'GPSLongitude');
                return unless defined $info->{GPSLatitude} && defined $info->{GPSLongitude};

                my $lat = $info->{GPSLatitude};
                my $lon = $info->{GPSLongitude};

                if ($cache && !eval { $cache->store_coords($File::Find::name, $lat, $lon); 1 }) {
                    warn "Cache write failed, continuing without it: $@\n";
                    $cache = undef;
                }

                my $dist_km = File::Find::Geotagged::distance_km($lat, $lon, $lat0, $lon0);

                if ($dist_km <= $radius_km) {
                    printf "%s\t%.3f km - %f, %f\n", $File::Find::name, $dist_km, $lat, $lon;
                }
            },
            no_chdir => 1,
        },
        @dirs
    );
}

1;
