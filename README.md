# find-geotagged

A small Perl script that searches directories for geotagged photos
(JPEG, HEIC, TIFF) within a given radius of coordinates, using EXIF GPS
data via [Image::ExifTool](https://exiftool.org/).

## Usage

```
Usage: $0 LAT LON RADIUS_KM DIR [DIR ...]
```

Coordinates can also be passed as a single `LAT/LON` argument:

```
Usage: $0 LAT/LON RADIUS_KM DIR [DIR ...]
```

## Example

```sh
# find photos within 10 km of Belgrade
./bin/find-geotagged.pl 44.7866 20.4489 10 ~/photo

# same thing, coordinates as LAT/LON
./bin/find-geotagged.pl 44.7866/20.4489 10 ~/photo
```

Output lists each matching file with its distance and coordinates:

```
/home/user/photo/belgrade.jpg	0.432 km - 44.786200, 20.449100
```

While the slow EXIF scan runs, a spinner with the path of the file
currently being read is shown in place (updated at most 10 times per
second); found results are printed on their own lines.

## Cache

Coordinates of every geotagged file found during a scan are stored in a
SQLite database at `$XDG_DATA_HOME/find-geotagged/geotagged.db`
(default `~/.local/share/find-geotagged/geotagged.db`). On each run the
cache is queried first with a bounding box around the requested point,
the hits are filtered to the actual circle, and only files missing from
the cache are scanned via EXIF — so repeated searches over the same
directories get faster.

The cache table `photos` stores the absolute file path (`filename`,
UNIQUE), `latitude` and `longitude`, with a composite index on
`(latitude, longitude)` for the bounding-box lookup. The implementation
lives in the `File::Find::Geotagged` module (`lib/`).

## Requirements

- Perl
- `Image::ExifTool`
- `DBI` + `DBD::SQLite`
- `File::Find`, `Math::Trig`, `Cwd`, `FindBin` (core modules)

## Tests

```sh
prove -l t/
```
