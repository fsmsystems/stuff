#!/usr/bin/perl -w
#
# nagios: -epn
#
# check_vmware3.pl
# should work with any VMWare Infrastructure 
# 
# All operations work with VMware VirtualCenter 2.0.1 or later.
# All operations work with VMware ESX Server 3.0.1 or later.
# 
#
# COPYRIGHT:
#  
# This software is Copyright (c) 2008 NETWAYS GmbH, Birger Schmidt
#                                <info@netways.de>
#      (Except where explicitly superseded by other copyright notices)
# 
# LICENSE:
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from http://www.fsf.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.fsf.org.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to NETWAYS GmbH.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# this Software, to NETWAYS GmbH, you confirm that
# you are the copyright holder for those contributions and you grant
# NETWAYS GmbH a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# Nagios and the Nagios logo are registered trademarks of Ethan Galstad.


use strict;
use warnings;
use VMware::VIRuntime;


# version string
my $version = '0.1';


# init variables
my @msg						= ();
my @perfdata				= ();
my $exitVal					= undef;
my @fineVMs					= ();
my @badVMs					= ();
my @missingVMs				= ();


# define states
our @state = ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN');


my %opts = (
   'host' => {
      type => "=s",
      help => "Name of the host",
      required => 0,
   },
   'timeout' => {
      type => "=i",
      help => "Timeout in seconds",
      required => 0,
   },
   'ignore' => {
      type => "=s",
      help => "List of VM-Names (separated by comma, regexp possible) to ignore if state not green",
      required => 0,
   },
   'ensure' => {
      type => "=s",
      help => "List of VM-Names (separated by comma, regexp possible) for which state must be green",
      required => 0,
   },
   'vmname' => {
      type => "=s",
      help => "one single VM to check - the other checks will be suppressed",
      required => 0,
   },
   'verboseVMs' => {
      type => "=i",
      help => "list VM names as plugin output",
      required => 0,
   },
);


sub printResultAndExit {

	# stop timeout
	alarm(0);

	# print check result and exit

	my $exitVal = shift;

	#print "check_vmware3 ";
	print "$state[$exitVal]:";

	print " @_" if (defined @_);

	print "\n";

	exit($exitVal);
}


eval { 
	require VMware::VIRuntime
} or printResultAndExit(3, 'Missing perl module VMware::VIRuntime. Download and install "VMware Infrastructure (VI) Perl Toolkit" from http://www.vmware.com/download/sdk/api.html');

# get command-line parameters
Opts::add_options(%opts);
Opts::parse();

Opts::validate();

if (defined Opts::get_option('help')) {
print "help";
}


# some code from check_esx3 by op5
sub get_key_metrices {
	my ($perfmgr_view, $group, @names) = @_;

	my $perfCounterInfo = $perfmgr_view->perfCounter;
	my @counters;
	my @units;

	foreach (@$perfCounterInfo) {
		if ($_->groupInfo->key eq $group) {
			my $cur_name = $_->nameInfo->key . "." . $_->rollupType->val;
			foreach my $index (0..@names-1)
			{
				if ($names[$index] =~ /$cur_name/)
				{
					$names[$index] =~ /(\w+).(\w+):*(.*)/;
					$counters[$index] = PerfMetricId->new(counterId => $_->key, instance => $3);
					$units[$index] = $_->unitInfo->label;
				}
			}
		}
	}
	return (\@counters, \@units);
}


sub get_performance_values {
	my ($view, $group, @list) = @_;
	$view->update_view_data();
	my @values;
	my $units;
	my @perf_data;
	eval {
		my $perfMgr = Vim::get_view(mo_ref => Vim::get_service_content()->perfManager);
		(my $metrices, $units) = get_key_metrices($perfMgr, $group, @list);
		my $perf_query_spec = PerfQuerySpec->new(entity => $view, metricId => $metrices, format => 'csv', intervalId => 20, maxSample => 1);
		my $perf_data = $perfMgr->QueryPerf(querySpec => $perf_query_spec);
		my $unsorted = shift(@$perf_data)->value;

		foreach my $id (@$unsorted) {
			foreach my $index (0..@$metrices-1) {
				if ($id->id->counterId == $$metrices[$index]->counterId) {
					$values[$index] = $id;
				}
			}
		}
		
	};
	foreach my $index (0..@list-1) {
		(my $name = $list[$index]) =~ tr/.:*/_/d;          # replace . with _ and delete : *
		($name = $view->name . '_' . $group . '_' . $name) =~ s/_average//;    # prepend group and remove tailing average
		if (defined $values[$index]) {
			push (@perf_data, "${name}=" . $values[$index]->value . @$units[$index] . ';0;0;0;0');
			#push (@perf_data, "${name}=" . $values[$index]->value);
		} else {
			#push (@perf_data, "${name}=noData");
			push (@perf_data, "${name}=0;0;0;0;0");
		}
	}
	return @perf_data;
}


sub displayVM($) {

	my $vm_view = shift @_;
	my $vmname = $vm_view->name;
	my $host = '';
	my $option_host = '';
	
	if (defined Opts::get_option('host')) {
		$option_host = Opts::get_option('host');
		my $mor_host = $vm_view->runtime->host;    # this is the host that actualy runs the VM
		$host = Vim::get_view(mo_ref => $mor_host)->name; 
		#print Dumper ($vm_view, $mor_host, $host) . "\n\n";
	}
	if ($option_host eq $host) {
		if (defined $vm_view->guestHeartbeatStatus) {
			push (@perfdata, "${vmname}_guestHeartbeatStatus=" . $vm_view->guestHeartbeatStatus->val);
			if ($vm_view->guestHeartbeatStatus->val eq 'green') {   # everything fine
				push (@fineVMs, $vmname);
			} else { # (gray, red, yellow?)
				push (@badVMs, $vmname);
				if ( @main::ignorelist )  {
					if ( !($vmname =~ join ('|', @main::ignorelist)) )  {   # not on ignorelist
						# unshift (@msg,  "bad guestHeartbeatStatus (" . $vm_view->guestHeartbeatStatus->val . ") for '$vmname'");
						$exitVal = 2; # critical
					}
				} else { # no ignorelist
					$exitVal = 2; # critical
				}
			}
		} else {
			push (@perfdata, "${vmname}_guestHeartbeatStatus=noData");
			unshift (@msg,  "unable to get guestHeartbeatStatus of " . $vmname);
			$exitVal = 2; # critical
			push (@badVMs, $vmname);
		}
		
		push (@perfdata, "${vmname}_guestState=" . $vm_view->guest->guestState);
		
		if (defined Opts::get_option('vmname')) {
			if (defined $vm_view->guest->hostName) {
				push (@perfdata, "${vmname}_hostName=" . $vm_view->guest->hostName);
			} else {
				push (@perfdata, "${vmname}_hostName=noData");
			}
			if (defined $vm_view->guest->ipAddress) {
				push (@perfdata, "${vmname}_ipAddress=" . $vm_view->guest->ipAddress);
			} else {
				push (@perfdata, "${vmname}_ipAddress=noData");
			}
			if (defined $vm_view->guest->toolsStatus) {
				push (@perfdata, "${vmname}_toolsStatus=" . $vm_view->guest->toolsStatus->val);
			} else {
				push (@perfdata, "${vmname}_toolsStatus=noData");
			}
			if (defined $vm_view->guest->toolsVersion) {
				my @requiredVersion = grep { ref($_) && $_->key eq 'vmware.tools.requiredversion' } @{$vm_view->config->extraConfig}; # filter reqver from extraConfig
				push (@perfdata, "${vmname}_toolsVersion=" . $vm_view->guest->toolsVersion . ';0;0;0;' .
					((defined $requiredVersion[0]->value) ? $requiredVersion[0]->value : '0'));
			} else {
				#push (@perfdata, "${vmname}_toolsVersion=noData");
				push (@perfdata, "${vmname}_toolsVersion=0;0;0;0;0");
			}
			if (defined $vm_view->summary->quickStats->guestMemoryUsage) {
				push (@perfdata, $vmname . "_guestMemoryUsage=" . $vm_view->summary->quickStats->guestMemoryUsage . 'MB;0;0;0;' .
					((defined $vm_view->summary->config->memorySizeMB) ? $vm_view->summary->config->memorySizeMB : '0'));
					# $vm_view->config->hardware->memoryMB);
					# $vm_view->summary->runtime->maxMemoryUsage);  # get it from config not runtime
			} else {
				#push (@perfdata, "${vmname}_guestMemoryUsage=noData");
				push (@perfdata, "${vmname}_guestMemoryUsage=0MB;0;0;0;0");
			}
			if (defined $vm_view->summary->quickStats->overallCpuUsage) {
				push (@perfdata, $vmname . '_overallCpuUsage=' . $vm_view->summary->quickStats->overallCpuUsage . 'MHz;0;0;0;' .
					((defined $vm_view->summary->runtime->maxCpuUsage) ? $vm_view->summary->runtime->maxCpuUsage : '0'));
			} else {
				#push (@perfdata, "${vmname}_overallCpuUsage=noData");
				push (@perfdata, "${vmname}_overallCpuUsage=0MHz;0;0;0;0");
			}
			
			if (defined $vm_view->guest->disk) {
				my $disk_len = @{$vm_view->guest->disk};
				my $cnt = 0;
				#while ($cnt < $disk_len) {
				while ($cnt < 6) { # max 6 virtual disks - even if not defined because we need the perfdata to graph something
					if (defined $vm_view->guest->disk->[$cnt] and defined $vm_view->guest->disk->[$cnt]->freeSpace 
						and defined $vm_view->guest->disk->[$cnt]->capacity) {
						push (@perfdata, "${vmname}_Disk". $cnt ."freespace=" . $vm_view->guest->disk->[$cnt]->freeSpace .
						'B;0;0;0;' . $vm_view->guest->disk->[$cnt]->capacity);
					} else {
						#push (@perfdata, "${vmname}_Disk".$cnt."freespace=noData");
						push (@perfdata, "${vmname}_Disk". $cnt .'freespace=0B;0;0;0;0');
					}
					if (defined $vm_view->guest->disk->[$cnt] and defined $vm_view->guest->disk->[$cnt]->diskPath) {
						push (@perfdata, "${vmname}_Disk". $cnt ."Path=" . $vm_view->guest->disk->[$cnt]->diskPath);
					} else {
						push (@perfdata, "${vmname}_Disk". $cnt ."Path=noData");
					}
					$cnt++;
				}
			} else {
				my $cnt = 0;
				while ($cnt < 6) { # max 6 virtual disks - even if not defined because we need the perfdata to graph something
					push (@perfdata, "${vmname}_Disk". $cnt .'freespace=0B;0;0;0;0');
					$cnt++;
				}
				push (@perfdata, "${vmname}_Disk=noData");
			}
			if (defined $vm_view->guest->net) {
				my $net_len = @{$vm_view->guest->net};
				my $cnt = 0;
				while ($cnt < $net_len) {
					push (@perfdata, "${vmname}_net".$cnt."connected=" . $vm_view->guest->net->[$cnt]->connected);
					#push (@perfdata, "${vmname}_net".$cnt."deviceConfigId=" . $vm_view->guest->net->[$cnt]->deviceConfigId);
					#if (defined $vm_view->guest->net->[$cnt]->macAddress) {
					#	push (@perfdata, "${vmname}_net".$cnt."macAddress=" . $vm_view->guest->net->[$cnt]->macAddress);
					#}
					#else {
					#	push (@perfdata, "${vmname}_net".$cnt."macAddress=noData");
					#}
					#if (defined $vm_view->guest->net->[$cnt]->network) {
					#	push (@perfdata, "${vmname}_net".$cnt."network=" . $vm_view->guest->net->[$cnt]->network);
					#}
					#else {
					#	push (@perfdata, "${vmname}_net".$cnt."network=noData");
					#}
					#if (defined $vm_view->guest->net->[$cnt]->ipAddress) {
					#	my $ip_len = @{$vm_view->guest->net->[$cnt]->ipAddress};
					#	my $cnt_ip = 0;
					#	while ($cnt_ip < $ip_len) {
					#		push (@perfdata, "${vmname}_net".$cnt."ipAddress=" .$vm_view->guest->net->[$cnt]->ipAddress->[$cnt_ip]);
					#		$cnt_ip++;
					#	}
					#} else {
					#	push (@perfdata, "${vmname}_net".$cnt."ipAddress=noData");
					#}
					$cnt++;
				}
			} else {
				push (@perfdata, "${vmname}_guestNet=noData");
			}
			#push (@perfdata, (get_performance_values($vm_view, 'cpu', ('usage.average'))));#, 'usagemhz.average', 'wait.summation:*'))));
			#push (@perfdata, (get_performance_values($vm_view, 'mem', ('consumed.average', 'active.average'))));#, 'usage.average', 'overhead.average', 'swapped.average', 'swapin.average', 'swapout.average'))));
			push (@perfdata, (get_performance_values($vm_view, 'disk', ('read.average:*', 'write.average:*'))));#, 'usage.average:*'))));
			push (@perfdata, (get_performance_values($vm_view, 'net', ('received.average:*', 'transmitted.average:*'))));
		}
	}
}

sub retrieve_performance() {
	if (defined Opts::get_option('host')) {
		my $host = Vim::find_entity_view(view_type => "HostSystem", filter => {'name' => Opts::get_option('host')});
		if (!defined($host)) {
			push (@msg, "Host ".Opts::get_option('host')." not found");
			$exitVal = 2;
			return;
		}
		push (@perfdata, (get_performance_values($host, 'cpu', ('usage.average', 'usagemhz.average'))));
		push (@perfdata, (get_performance_values($host, 'mem', ('usage.average', 'consumed.average'))));#, 'overhead.average', 'swapused.average'))));
		#push (@perfdata, (get_performance_values($host, 'disk', ('commandsAborted.summation:*', 'busResets.summation:*', 'totalReadLatency.average:*', 'totalWriteLatency.average:*', 'kernelLatency.average:*', 'deviceLatency.average:*', 'queueLatency.average:*'))));
		#push (@perfdata, (get_performance_values($host, 'net', ('received.average:*', 'transmitted.average:*'))));
	}

	my $vm_views;
	if (defined Opts::get_option('vmname')) {
		if ($vm_views = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {'name' => Opts::get_option('vmname')})) {
			displayVM($vm_views);
			if (scalar(@fineVMs)) {
	   			push (@msg, Opts::get_option('vmname') . ' is running fine.');
			} else {
	   			push (@msg, Opts::get_option('vmname') . ' does not (proper) run.');
			}
		} else {
			$exitVal = 2;
	   		push (@msg, 'Could not find a VM named: ' . Opts::get_option('vmname'));
		}
	} else {
		$vm_views = Vim::find_entity_views(view_type => 'VirtualMachine');
		#print Dumper ($vm_views) . "\n\n";
		if(defined @$vm_views) {
			foreach my $vm (@$vm_views) { # Print VMs 
				displayVM($vm);
			} 
			push (@msg, "fine VMs (" . scalar(@fineVMs) . ")");
			if (defined Opts::get_option('verboseVMs') and scalar(@fineVMs)) { 
				$msg[-1] .= ': ' . join (', ', @fineVMs);
			}
			push (@msg, "bad VMs (" . scalar(@badVMs) . ")");
			#push (@msg, "not (proper) running VMs (" . scalar(@badVMs) . ")");
			if (defined Opts::get_option('verboseVMs') and scalar(@badVMs)) {
				$msg[-1] .= ': ' . join (', ', @badVMs);
			}
		}
	}
}



###########################################################################################
#
# main
#

#$Data::Dumper::Sortkeys = 1; #Sort the keys in the output 
#$Data::Dumper::Deepcopy = 1; #Enable deep copies of structures 
#$Data::Dumper::Indent = 2; #Output in a reasonable style (but no array indexes)



# set timeout
local $SIG{ALRM} = sub {
	$exitVal = 3;
	printResultAndExit($exitVal, join(' - ', 'Plugin Timeout', @msg) . "|" . join(' ', @perfdata));
};
(defined Opts::get_option('timeout')) ? alarm(Opts::get_option('timeout')) : alarm(60);

@main::ignorelist = ();
if (defined Opts::get_option('ignore')) {
	@main::ignorelist = split(/,/, Opts::get_option('ignore'));
}
	

$exitVal = 0; # as far as we know, everything is fine til now.

eval
{
	# try
	Util::connect();
	retrieve_performance();
	Util::disconnect();
};
if($@)
{
	# catch
	if ($@ =~ /VirtualMachineVMCIDevice/) {
		push (@msg, 'you have to apply a patch to VICommon.pm to avoid a bug in the VMWare perl API. Find it over here: http://www.nagioswiki.org/wiki/Plugin:check_vmware3.pl');
	}
	$exitVal = 3;
	printResultAndExit($exitVal, join(' - ', @msg, 'ERRORMSG: ' . $@) . "|" . join(' ', @perfdata));
}


# check if the expected VMs are reported or missing
if (defined Opts::get_option('ensure')) {
   my @ensurelist = split(/,/, Opts::get_option('ensure'));
   #print "ensureVMs: @ensurelist\n" if ($main::verbose >= 100);
   foreach my $ensureVM (@ensurelist) {
      if (!grep (/$ensureVM/, (@fineVMs, @badVMs))) {
         push (@missingVMs, $ensureVM);
         $exitVal = 2;
	  }
   }
   push (@msg, "missing VMs (" . scalar(@missingVMs) . ")");
   if (defined Opts::get_option('verboseVMs') and scalar(@missingVMs)) {
      $msg[-1] .= ': ' . join (', ', @missingVMs);
   }
}

printResultAndExit($exitVal, join(' - ', @msg) . "|" . join(' ', @perfdata));

# end main


