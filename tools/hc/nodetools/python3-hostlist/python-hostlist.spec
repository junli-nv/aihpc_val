%global srcname hostlist

%define py3_shbang_opts -E

%define extra_install_args --prefix /usr

Name:           python-%{srcname}
Version:        #VERSION#
Release:        #RELEASE#%{?dist}
Summary:        Python module for hostlist handling
Vendor:         NSC

Group:          Development/Languages
License:        GPL2+
URL:            http://www.nsc.liu.se/~kent/python-hostlist/
Source0:        http://www.nsc.liu.se/~kent/python-hostlist/%{name}-%{version}.tar.gz

BuildArch:      noarch

%global _description %{expand:
The hostlist.py module knows how to expand and collect Slurm hostlist
expressions.

The package also includes the 'hostlist' binary which can be used to
collect/expand hostlists and perform set operations on them, 'pshbak'
which collects output like 'dshbak' but using our hostlist library,
'hostgrep' which is a grep-like utility that understands hostlists,
and 'dbuck' which summarizes numerical data from multiple hosts.}

%description %_description

%package -n python3-%{srcname}
Summary: %{summary}
BuildRequires: python%{python3_pkgversion}-devel python3-setuptools

%description -n python3-%{srcname} %_description

%prep
%autosetup

%build
%py3_build

%install
%py3_install -- %{?extra_install_args}

%files -n python3-%{srcname}
%defattr(-,root,root,-)
%{python3_sitelib}/*
%{python3_sitelib}/__pycache__/*
%doc README
%doc COPYING
%doc CHANGES
/usr/bin/hostlist
/usr/bin/hostgrep
/usr/bin/pshbak
/usr/bin/dbuck
%{_mandir}/man1/hostlist.1.gz
%{_mandir}/man1/hostgrep.1.gz
%{_mandir}/man1/pshbak.1.gz
%{_mandir}/man1/dbuck.1.gz


%changelog
* Thu Jul 10 2025 Kent Engström <kent@nsc.liu.se> - 2.2.2-1
- Fix bug for Python before version 3.8 in new spurious ws detection.
- Remove an unused variable and clean up whitespace in the code.

* Mon Dec  2 2024 Kent Engström <kent@nsc.liu.se> - 2.2.1-1
- Rework dist tag handling for mock build.

* Fri Nov 29 2024 Kent Engström <kent@nsc.liu.se> - 2.2.0-1
- Complain about spurious whitespace in "hostlist" tool arguments.
- Remove dist tag for initial SRPM creation in a new way.

* Fri Nov 22 2024 Kent Engström <kent@nsc.liu.se> - 2.1.0-1
- Remove whitespace from hostlist arguments in the "hostlist" tool.

* Fri Oct 25 2024 Kent Engström <kent@nsc.liu.se> - 2.0.0-1
- Remove Python 2 support claim from package metadata
- Bump major version number due to removal of Python 2 support

* Tue Oct 15 2024 Torbjörn Lönnemark <ketl@nsc.liu.se> - 1.25.0-1
- Migrate from distutils to setuptools
- Drop support for Python 2

* Tue Apr 16 2024 Torbjörn Lönnemark <ketl@nsc.liu.se> - 1.24.0-1
- Always install tools as part of the Python 3 package

* Wed Nov 30 2022 Torbjörn Lönnemark <ketl@nsc.liu.se> - 1.23.0-1
- Fix TypeError in Python 3 when collecting 'n n1'
- Build python2 packages on <= el8 by default

* Tue Oct 11 2022 Torbjörn Lönnemark <ketl@nsc.liu.se> - 1.22-1
- hostgrep: dynamically add characters allowed in hostnames.
- Make python2 support opt-in at build time

* Mon Oct 19 2020 Torbjörn Lönnemark <ketl@nsc.liu.se> - 1.21-1
- Fixes for building on el8

* Tue Jan 14 2020 Kent Engström <kent@nsc.liu.se> - 1.20-1
- Adapt to Python 3 stricter comparison rules
- Fix Python 2+2 support for hostgrep, pshbak, dbuck

* Mon Sep 30 2019 Torbjörn Lönnemark <ketl@nsc.liu.se> - 1.19-1
- dbuck: Don't print hostlist padding for empty buckets

* Thu Jun 21 2018 Kent Engström <kent@nsc.liu.se> - 1.18-1
- Accept whitespace in hostlists passed as arguments
- Support both Python 2 and Python 3 natively

* Mon Jan 23 2017 Kent Engström <kent@nsc.liu.se> - 1.17-1
- New features in dbuck by cap@nsc.liu.se:
- Add option -z, --zero
- Add option -b, --bars
- Add option --highligh-hostlist and --color
- Add option -a, --anonymous
- Add option -p, --previous and --no-cache
- Also other fixes and cleanups in dbuck

* Mon May 23 2016 Kent Engström <kent@nsc.liu.se> - 1.16-1
- Ignore PYTHONPATH et al. in installed scripts

* Thu Apr 21 2016 Kent Engström <kent@nsc.liu.se> - 1.15-1
- Add missing options to the hostgrep(1) man page.
- Add --restrict option to hostgrep.
- Add --repeat-slurm-tasks option.
- dbuck: major rewrite, add -r/-o, remove -b/-m
- dbuck: add a check for sufficient input when not using -k
- dbuck: Fix incorrect upper bound of underflow bucket
