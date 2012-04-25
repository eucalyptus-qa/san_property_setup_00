#!/usr/bin/perl
use strict;
use Cwd;

$ENV{'PWD'} = getcwd();

# does_It_Have( $arg1, $arg2 )
# does the string $arg1 have $arg2 in it ??
sub does_It_Have{
	my ($string, $target) = @_;
	if( $string =~ /$target/ ){
		return 1;
	};
	return 0;
};



#################### APP SPECIFIC PACKAGES INSTALLATION ##########################

my @ip_lst;
my @distro_lst;
my @source_lst;
my @roll_lst;

my %cc_lst;
my %sc_lst;
my %nc_lst;

my $clc_index = -1;
my $cc_index = -1;
my $sc_index = -1;
my $ws_index = -1;

my $clc_ip = "";
my $cc_ip = "";
my $sc_ip = "";
my $ws_ip = "";

my $nc_ip = "";

my $rev_no = 0;

my $max_cc_num = 0;

$ENV{'EUCALYPTUS'} = "/opt/eucalyptus";

#### read the input list
print "\n";
print "Reading the Input File\n";
print "\n";

my $index = 0;

open( LIST, "../input/2b_tested.lst" ) or die "$!";

my $is_memo = 0;
my $memo = "";

my $line;
while( $line = <LIST> ){
	chomp($line);

	if( $is_memo ){
		if( $line ne "END_MEMO" ){
			$memo .= $line . "\n";
		}else{
			$is_memo = 0;
		};
	}elsif( $line =~ /^([\d\.]+)\s+(.+)\s+(.+)\s+(\d+)\s+(.+)\s+\[([\w\s\d]+)\]/ ){
		print "IP $1 with $2 distro is built from $5 as Eucalyptus-$6\n";
		push( @ip_lst, $1 );
		push( @distro_lst, $2 );
		push( @source_lst, $5 );
		push( @roll_lst, $6 );

		my $this_roll = $6;

		if( does_It_Have($this_roll, "CLC") && $clc_ip eq "" ){
			$clc_index = $index;
			$clc_ip = $1;
		};

		if( does_It_Have($this_roll, "CC") ){
			$cc_index = $index;
			$cc_ip = $1;

			if( $this_roll =~ /CC(\d+)/ ){
				$cc_lst{"CC_$1"} = $cc_ip;
				if( $1 > $max_cc_num ){
					$max_cc_num = $1;
				};
			};			
		};

		if( does_It_Have($this_roll, "SC") ){
			$sc_index = $index;
			$sc_ip = $1;

			if( $this_roll =~ /SC(\d+)/ ){
                                $sc_lst{"SC_$1"} = $sc_ip;
                        };
		};

		if( does_It_Have($this_roll, "WS") ){
                        $ws_index = $index;
                        $ws_ip = $1;
                };

		if( does_It_Have($this_roll, "NC") ){
                        #$nc_ip = $nc_ip . " " . $1;
			$nc_ip = $1;
			if( $this_roll =~ /NC(\d+)/ ){
				if( $nc_lst{"NC_$1"} eq	 "" ){
                                	$nc_lst{"NC_$1"} = $nc_ip;
				}else{
					$nc_lst{"NC_$1"} = $nc_lst{"NC_$1"} . " " . $nc_ip;
				};
                        };
                };


		$index++;
        }elsif( $line =~ /^BZR_REVISION\s+(\d+)/  ){
		$rev_no = $1;
		print "REVISION NUMBER is $rev_no\n";
	}elsif( $line =~ /^BZR_BRANCH\s+(.+)/ ){
			my $temp = $1;
			if( $temp =~ /eucalyptus\/(.+)/ ){
				$ENV{'QA_BZR_DIR'} = $1; 
			};
	}elsif( $line =~ /^MEMO/ ){
		$is_memo = 1;
	}elsif( $line =~ /^END_MEMO/ ){
		$is_memo = 0;
	};
};

close( LIST );

$ENV{'QA_MEMO'} = $memo;

print "\n";

if( $source_lst[0] eq "PACKAGE" || $source_lst[0] eq "REPO" ){
	$ENV{'EUCALYPTUS'} = "";
};

if( $rev_no == 0 ){
	print "Could not find the REVISION NUMBER\n";
};

if( $clc_ip eq "" ){
	print "Could not find the IP of CLC\n";
};

if( $cc_ip eq "" ){
        print "Could not find the IP of CC\n";
};

if( $sc_ip eq "" ){
        print "Could not find the IP of SC\n";
};

if( $ws_ip eq "" ){
        print "Could not find the IP of WS\n";
};

if( $nc_ip eq "" ){
        print "Could not find the IP of NC\n";
};

chomp($nc_ip);


### Download Admin Credentials
print "\n";
print "Downloading Admin Credentials\n";
print "\n";

print "$clc_ip :: rm -f /root/admin_cred.zip\n";
system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"rm -f /root/admin_cred.zip\" ");
sleep(1);

print "$clc_ip :: $ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --get-credentials admin_cred.zip; unzip -o ./admin_cred.zip\n";
system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"cd /root; $ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --get-credentials admin_cred.zip; unzip -o ./admin_cred.zip\" ");
sleep(5);

print "\n";

### Check SAN option
print "\n";
print "Checking SAN option in MEMO\n";
print "\n";

my $ebs_storage_manager = "NO-SAN";

my $san_provider = "NO-SAN";

if( is_san_provider_from_memo() == 1 ){
	$san_provider = $ENV{'QA_MEMO_SAN_PROVIDER'};
};

if( is_ebs_storage_manager_from_memo() == 1){
	$ebs_storage_manager = $ENV{'QA_MEMO_EBS_STORAGE_MANAGER'};
};

print "\n";
print "ACTIONS:\n";
print "SAN_PROVIDER\t$san_provider\n";
print "EBS_STORAGE_MANAGER\t$ebs_storage_manager\n";
print "\n";

my $bzr = $ENV{'QA_BZR_DIR'};

#if( $bzr =~ /eee-2\.0/ ){

if( $san_provider eq "NetappProvider" ){

	print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p PARTI00.storage.sanhost=192.168.5.191\n";
	system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p PARTI00.storage.sanhost=192.168.5.191\" ");
	sleep(1);


	print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p PARTI00.storage.sanuser=root\n";
	system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p PARTI00.storage.sanuser=root\" ");
	sleep(1);


	print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p PARTI00.storage.sanpassword=zoomzoom\n";
	system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p PARTI00.storage.sanpassword=zoomzoom\" ");
	sleep(1);

	print "\n";
	print "[TEST_REPORT]\tSAN setup \'$san_provider\' is completed\n";

}elsif( $san_provider eq "EquallogicProvider" ){

	print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p PARTI00.storage.sanhost=192.168.7.189\n";
	system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p PARTI00.storage.sanhost=192.168.7.189\" ");
	sleep(1);


	print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p PARTI00.storage.sanuser=grpadmin\n";
	system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p PARTI00.storage.sanuser=grpadmin\" ");
	sleep(1);


	print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p PARTI00.storage.sanpassword=zoomzoom\n";
	system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p PARTI00.storage.sanpassword=zoomzoom\" ");
	sleep(1);

	print "\n";
	print "[TEST_REPORT]\tSAN setup \'$san_provider\' is completed\n";

}elsif( $ebs_storage_manager eq "DASManager" ){

	#We need to make sure that /dev/sdb is clean.
        print "$sc_ip :: parted -s /dev/sdb rm 1\n";
	system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$sc_ip \"parted -s /dev/sdb rm 1\" ");
 
	print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p PARTI00.storage.dasdevice=/dev/sdb\n";
	system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p PARTI00.storage.dasdevice=/dev/sdb\" ");
	sleep(1);

	print "\n";
	print "[TEST_REPORT]\tSAN setup \'$ebs_storage_manager\' is completed\n";

}else{
	print "\n";
	print "[TEST_REPORT]\tSAN setup is not specified\n";
};


### TEMP SOL. to VLAN TAG issue	101311
print "\n";
print "\n";
print "Checking the Version of Eucalyptus\n";
print "\n";

print "$clc_ip :: cat $ENV{'EUCALYPTUS'}/etc/eucalyptus/eucalyptus-version\n";
my $this_euca_version = `ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"cat $ENV{'EUCALYPTUS'}/etc/eucalyptus/eucalyptus-version\"`;
chomp($this_euca_version);
print "Eucalyptus Version\t$this_euca_version\n";
if( $this_euca_version =~ /^3/ ){
	print "\n";
	print "\n";
	print "Putting Limit on VLAN TAG range\n";
	print "\n";

	print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p cloud.network.global_max_network_tag=1000\n";
	system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p cloud.network.global_max_network_tag=1000\" ");
	sleep(1);
};


print "\n";
print "\n[TEST_REPORT]\tFinished set_san_property_beta.pl\n";
print "\n";

exit(0);

1;



sub is_san_provider_from_memo{
	if( $ENV{'QA_MEMO'} =~ /^SAN_PROVIDER=(.+)\n/m ){
		my $extra = $1;
		$extra =~ s/\r//g;
		print "FOUND in MEMO\n";
		print "SAN_PROVIDER=$extra\n";
		$ENV{'QA_MEMO_SAN_PROVIDER'} = $extra;
		return 1;
	};
	return 0;
};

sub is_ebs_storage_manager_from_memo{
	if( $ENV{'QA_MEMO'} =~ /^EBS_STORAGE_MANAGER=(.+)\n/m ){
		my $extra = $1;
		$extra =~ s/\r//g;
		print "FOUND in MEMO\n";
		print "EBS_STORAGE_MANAGER=$extra\n";
		$ENV{'QA_MEMO_EBS_STORAGE_MANAGER'} = $extra;
		return 1;
	};
	return 0;
};


1;

