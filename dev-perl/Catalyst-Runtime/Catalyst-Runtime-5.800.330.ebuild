# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=4

MODULE_AUTHOR=BOBTFISH
MODULE_VERSION=5.80033
inherit perl-module

DESCRIPTION="The Elegant MVC Web Application Framework - runtime version"

SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="test"

COMMON_DEPEND="
	dev-perl/List-MoreUtils
	>=dev-perl/namespace-autoclean-0.90.0
	>=dev-perl/namespace-clean-0.130.0
	>=dev-perl/B-Hooks-EndOfScope-0.80.0
	>=dev-perl/MooseX-Emulate-Class-Accessor-Fast-0.9.30
	>=dev-perl/Moose-1.990.0
	>=dev-perl/Moose-1.30.0
	>=dev-perl/MooseX-MethodAttributes-0.240.0
	>=dev-perl/MooseX-Role-WithOverloading-0.90.0

	>=dev-perl/Class-C3-Adopt-NEXT-0.70.0
	>=dev-perl/Cgi-Simple-1.1.09
	dev-perl/Data-Dump
	dev-perl/Data-OptList

	dev-perl/HTML-Parser
	>=dev-perl/HTTP-Body-1.60.0
	>=dev-perl/libwww-perl-5.814

	>=dev-perl/HTTP-Request-AsCGI-1.0.0

	>=virtual/perl-Module-Pluggable-3.9
	>=dev-perl/Path-Class-0.90.0
	virtual/perl-Scalar-List-Utils
	dev-perl/Sub-Exporter
	>=dev-perl/Text-SimpleTable-0.30.0
	virtual/perl-Time-HiRes
	>=dev-perl/Tree-Simple-1.15
	dev-perl/Tree-Simple-VisitorFactory
	>=dev-perl/URI-1.350.0
	virtual/perl-Text-Balanced
	dev-perl/MRO-Compat
	>=dev-perl/MooseX-Getopt-0.30
	dev-perl/MooseX-Types
	dev-perl/MooseX-Types-Common
	>=dev-perl/String-RewritePrefix-0.4.0

	dev-perl/B-Hooks-OP-Check-StashChange
	!<=dev-perl/Catalyst-View-Mason-0.17
	!<=dev-perl/Catalyst-Devel-1.190.0

"
RDEPEND="
	${COMMON_DEPEND}
"
DEPEND="
	${COMMON_DEPEND}
	test? (
		dev-perl/Class-Data-Inheritable
	)
"

SRC_TEST="do parallel"
