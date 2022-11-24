#!/usr/bin/perl
BEGIN {push @INC, '/root/'}

use TraverseSOAP;


my ($idle, $waiting) = &rxinfo();

my $hostname = `hostname`;
chomp($hostname);
my $address = $hostname;

									
my $traverseSOAP = TraverseSOAP->new(
	"_afs", # username
	'secret', # password
#	"imrstest01.imrs.example.org" # alternate server (defaults to production)
);

$traverseSOAP->insertResult($hostname, $address, "Idle Threads", $idle);
$traverseSOAP->insertResult($hostname, $address, "Calls Waiting For Thread", $waiting);

$traverseSOAP->logout();

sub rxinfo {

    open(RXDEBUG, "/usr/afsws/etc/rxdebug localhost -noconn |") || return(-1, -1);
    my @rxdebug = <RXDEBUG>;
    close(RXDEBUG) || return(-1, -1);


    foreach (@rxdebug) {
        if (/\d+ calls waiting for a thread$/o) {
            ($waiting, $extra) = split(/\s+/o, $_, 2);
        } elsif (/\d+ threads are idle$/o) {
            ($idle, $extra) = split(/\s+/o, $_, 2);
        }
    }

    return ($idle, $waiting);

}
