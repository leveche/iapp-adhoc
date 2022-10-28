#!/usr/bin/perl

use warnings;
use strict;

$|++;

use Data::Dumper;
use Net::LDAPS;
use Getopt::Long;
use MIME::Lite;

####### Constants section
my $categories = {
    'Staff' => {
	'ACD' => 'academic',
	'ADJ' => 'adjunct',
	'APO' => 'academic-professional-officer',
	'CFS' => 'contract-for-services',
	'CLN' => 'clinical',
	'EMP' => 'employee',
	'EMR' => 'emeritus',
	'FAC' => 'faculty',
	'FSO' => 'faculty-service-officer',
	'GST' => 'guest',
	'INT' => 'instructor',
	'LIB' => 'librarian',
	'NOU' => 'non-university-employee',
	'PDF' => 'post-doctoral-fellow',
	'PRC' => 'preceptor',
	'SCA' => 'special-continuing-academic',
	'SES' => 'sessional',
	'SUP' => 'support',
	'BRG' => 'bridge-benefits',
	'PRH' => 'prehire',
    },
    'Student' => {
	'PRO' => 'prospect',
	'STD' => 'student',
	'APL' => 'applicant',
	'CEA' => 'continuing-education-applicant',
	'CEP' => 'continuing-education-prospect',
	'CES' => 'continuing-education-student',
    },
    'noRTI'   => {
	'noRTI' => 'no-active-RTI',
	}
};


###### initialize and configure

my $config = {
		debug			=> 0,
		env 			=> 'DEV',
		ldapserver		=> 'directory.srv.example.org',
		category_to_process	=> 'Staff',
		cutoff			=> 1400652000,
		# cutoff => 1397226955,
		proc_limit		=> 5,
		run_stage		=> 'test1',
		smtp_server		=> 'smtp.srv.example.org',
		sendmail		=> 0,
		sleepbetween		=> 1,
		maxtries		=> 2,
		mailfields		=> [ 'mail', 'mailLocalAddress', 'mailRoutingAddress', 'mailForwardingAddress', 'uOfAOffCampusMail' ],
		bcc			=> '',
		stages	=> { 
	  'test1' => {
		processed_CCIDs => '/var/myccid-mailouts/test1/processed-ccids',
		proc_limit	=> 5,
		email_template	=> '/var/myccid-mailouts/test1/email_template.txt',
		email_from	=> 'helpdesk@example.org',
		email_subject	=> 'CCID Password Change',
		dry_run		=> 0,
		},

			},
};

GetOptions ( "debug"	=> \$config->{'debug'},
		"env=s"	=> \$config->{'env'},
		"cutoff=i"=> \$config->{'cutoff'},
		"limit=i"	=> \$config->{'proc_limit'},
		"category=s"=> \$config->{'category_to_process'},
		"stats"	=> \$config->{'stats'},
		"smtp=s"	=> \$config->{'smtp_server'},
		"stage=s"	=> \$config->{'run_stage'},
		"bcc=s"		=> \$config->{'bcc'},
		"ldapserver=s"  => \$config->{'ldapserver'},
		"sendmail"	=> \$config->{'sendmail'},
		"dryrun"	=> \$config->{'dry_run'},
		"sleep"		=> \$config->{'sleepbetween'},
);

unless ($config->{stages}->{$config->{'run_stage'}}) {
	die "Don't know how to configure stage $config->{'run_stage'}\n";
}

=head3 $CCIDs structure

$CCIDs : { CCID_DN => { 'PwdLastSet' => 'timestamp',
			'UofARTI' => [ RTI1, RTI2, ... ],
			'mail' => mail,
	}

The RTIs in the list are not guaranteed to be unique.

=cut

my $CCIDs = {};

=head3 $RTIs structure

$RTIs : { RTI => [ CCID_DN1, CCID_DN2, ... ] }

The CCIDs in the list for each RTI is not unique when the hash 
is assembled, but will be made unique in a post-processing step.

=cut

my $RTIs = {};

# store the list of already-processed CCIDs
my $done = {};

######## Set up LDAP connection
my $l = Net::LDAP->new("$config->{'ldapserver'}")
	or die "$@";

print "===============\nConnecting to LDAP host $config->{'ldapserver'}...\n";
my $m = $l->start_tls( verify=> 'allow') 
	or die "Can't connect to LDAP server\n";

if ($config->{'env'} ~~ ['PROD','UAT']) {
	print "Binding an cn=manager...\n";
	$m = $l->bind( 'cn=manager,dc=ualberta,dc=ca',
			password => 'secret'
			    ) or die "$@";
}

my $VMAIL = {};
##### virtual mailbox file
open (my $vmail, '<', '/tmp/virtusertable');
while (<$vmail>) {
	my @m = split /\t/, $_;
	chomp @m;
	$VMAIL->{$m[1]} = $m[0];
}
close $vmail;

# print keys %{$VMAIL};
# print values %{$VMAIL};

##### Read in CCIDs with RTI set
print "Searching for CCIDs with active RTI... ";
$m = $l->search( base => 'ou=people,dc=ualberta,dc=ca',
		filter => '(&(userPassword=*)(ou=ais)(!(organizationalStatus=disabled)))', 
		);
print "done\n";

print "Populating \$CCIDs and \$RTI structures... ";
foreach my $e ($m->entries) {

	my $RTI = $e->get_value('UofARTI');
	my $ccid = $e->dn;
	getRTIs($ccid);

	# Now populate email, last password reset
	unless ( $config->{'run_stage'} eq 'stage1' ) {
		my $q = $l->search ( base=> $ccid, 
				scope => 'base',
				filter => '(ObjectClass=*)');
		foreach my $e ($q->entries) {
			foreach my $m ( @{$config->{'mailfields'}} ) {
				$CCIDs->{$ccid}->{$m} = $e->get_value($m) ? $e->get_value($m) : '-';
				chomp $CCIDs->{$ccid}->{$m};
			};
		};
	};

};

print "done\n";

if ($config->{'debug'}) {
	print Dumper($CCIDs);
	print Dumper($RTIs);
};

#### main loop

foreach my $ccid (keys %$CCIDs) {

	# RTI in the right category?
	my $c = $config->{'category_to_process'};
	my $rtiOK = 0;
	for my $rti (@{$CCIDs->{$ccid}->{'UofARTI'}}) {
		print "RTI: $rti " 
		if $config->{'debug'} ;

		if ( $categories->{$c}->{$rti} ) {
			$rtiOK = 1;
			print "RTI $rti is in category $c\n"
			if $config->{'debug'};
		} 
	};
	
	if ($rtiOK) {
		print getCCID($ccid), ":: ";
		my @addresses = map { $CCIDs->{$ccid}->{ $_ } } @{$config->{'mailfields'}};
		print join (',', @addresses);
		foreach my $address ( @addresses ) {
			if ($VMAIL->{$address}) {
				print ",$VMAIL->{$address}";
			} else {
				print ",-";
			};
		};
		print " ::\n";
	} else {
		print STDERR "getCCID($ccid) :: no RTI in category $config->{'category_to_process'}\n";
	};

};

exit 0;

##### AUX methods

sub getParent {
	my $dn = shift;
	my @dn = split(/,/,$dn);
	return join(',',@dn[1 .. $#dn]);
}

sub getCCID {
	my $dn = shift;
	my @dn = split(/,/,$dn);
	$dn[0] =~ s/uid=//;
	return shift @dn;
}

sub uniq {
  my %seen;
  return grep { !$seen{$_}++ } @_;
}

sub dumpstats {
	print "counting...\n";
	my $count = {};

	foreach my $c (keys %$categories) {
		foreach my $rti (keys %{$categories->{$c}}) {
			unless ($RTIs->{$rti}) { 
				print "added $rti \n" if $config->{'debug'};
				push ( @{$count->{$c}}, ());
			};
			print Dumper($RTIs->{$rti}) if $config->{'debug'};
			if ($RTIs->{$rti}) {
				push ( @{$count->{$c}}, @{$RTIs->{$rti}} );
			};
		};
		#print $#{$count->{$c}},"\n";
		my @uniqcount = uniq(@{$count->{$c}});
		print "Total Unique in category $c: $#uniqcount\n";
	};
};

sub getRTIs {
	my $ccid = shift;
	my $m = $l->search( base => $ccid,
			filter => '(UofaRTI=*)',
                );
	if ($m->entries) {
		foreach my $e ($m->entries) {
			my $RTI = $e->get_value('UofARTI');
			if (! $RTI ) {
				$RTI = 'noRTI';
				print "RTI\n";
			};
			push ( @{$CCIDs->{$ccid}->{'UofARTI'}}, ($RTI));
			push ( @{$RTIs->{$RTI}}, ($ccid));
		};
	} else {
			push ( @{$CCIDs->{$ccid}->{'UofARTI'}}, ('noRTI'));
			push ( @{$RTIs->{'noRTI'}}, ($ccid));
	};
}

__END__
