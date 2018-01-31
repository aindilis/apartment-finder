#!/usr/bin/perl -w

my $addresses = eval `cat street-data`;

foreach my $address (keys %$addresses) {
  print "$address\n";
  # get rid of additional
  $address =~ s/ at (North|South|East|West)$/ at SPECIAL1/ig;
  $address =~ s/North Ave(nue)?/SPECIAL1/ig;

  $address =~ s/ at (.+) and (.+)$/$1 at $2/;
  $address =~ s/(\/| and )\w+$//;

  $address =~ s/\./ /g;

  # remove common lint
  $address =~ s/\s*\b([nsew]|west|north|south|east|avenue|ave|st|street|blvd|drive|dr)\.?\b\s*/ /ig;

  # remove prefixed street address
  $address =~ s/^[\d]+ //;

  $address =~ s/^\s+//g;
  $address =~ s/\s+$//g;
  $address =~ s/\s{2,}/ /g;

  $address =~ s/SPECIAL1/North/g;

  # remove
  print $address."\n";
  if ($address =~ /^(.*) at (.*)$/) {
    my ($s1,$s2) = (lc($1),lc($2));
    $s2 =~ s/\s+//;

    print "\t\t<$s1>at<$s2>\n";
  } else {
    print "\t\tFoul\n";
  }
}
