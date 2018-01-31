#!/usr/bin/perl -w

use Data::Dumper;
use Manager::Dialog qw(QueryUser);
use PerlLib::Geo;

my $geo = PerlLib::Geo->new();

while (1) {
  print Dumper($geo->GetLatLongForAddress(QueryUser("Location: ")));
}
