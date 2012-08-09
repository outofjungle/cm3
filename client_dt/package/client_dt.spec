Name: client_dt
Summary: Chisel embedded daemontools
Version: %(awk '/^Version/ {print $2;exit}' package/README)
Release: 1
Group: Applications/System
buildarch: noarch
License: Proprietary
AutoReq: 0
Requires: perl >= 5.8, rsync >= 2.5.7

%description
%(svn info | grep URL)
%(svn info | grep Revision)
%(svn status | grep -vE '^?')
%(cat package/README | perl -pe 'exit if /CHANGELOG/;')

%undefine __check_files

%files
%defattr(-,root,root)
%attr(0555,root,root)/bin/envuidgid
%attr(0555,root,root)/bin/multilog
%attr(0555,root,root)/bin/readproctitle
%attr(0555,root,root)/bin/setuidgid
%attr(0555,root,root)/bin/supervise
%attr(0555,root,root)/bin/svok
%attr(0555,root,root)/bin/tai64n
%attr(0555,root,root)/bin/tai64nlocal
%attr(0555,root,root)/bin/svstat
%attr(0555,root,root)/bin/svscan
%attr(0444,root,root)/bin/svc
%attr(0555,root,root)/bin/softlimit
%attr(0555,root,root)/bin/setlock
%attr(0555,root,root)/bin/pgrphack
%attr(0555,root,root)/bin/fghack
%attr(0555,root,root)/bin/envdir
%attr(0555,root,root)/bin/svscanboot
%attr(0555,root,root)/sbin/dt-activate
