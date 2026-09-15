EAPI=8

MY_PN="nginx-otel"
COMMIT="e3b6c98b1556e4c82cec39acc7be91a62449fa84"

# Gentoo's dev-cpp/opentelemetry-cpp installs the generated .pb.h headers but
# not the raw .proto sources, so nginx-otel's own CMake (which regenerates its
# own, separate OTLP/gRPC export code from scratch, sharing no proto-derived
# types with opentelemetry-cpp) needs its own copy fetched here.
#
# This version is NOT required to match OPENTELEMETRY_PROTO in
# dev-cpp/opentelemetry-cpp's ebuild -- nginx-otel's generated proto code
# never crosses the API boundary with opentelemetry-cpp's own, and OTLP's
# trace-export schema has been stable for a long time. It was set to 1.8.0
# purely for least-surprise consistency with what opentelemetry-cpp-1.24.0
# happened to use. Portage has no way to keep this in sync automatically
# (SRC_URI is evaluated before any other ebuild can be introspected), so if
# dev-cpp/opentelemetry-cpp bumps its own pin, there is no automatic breakage
# to worry about -- just no obligation to follow it either.
OTEL_PROTO_PV="1.8.0"

NGINX_MOD_INSTALL_CONF_STUB=1

inherit nginx-module

DESCRIPTION="NGINX native OpenTelemetry (OTLP/gRPC) tracing module"
HOMEPAGE="https://github.com/nginx/nginx-otel"
SRC_URI="
	https://github.com/nginx/${MY_PN}/archive/${COMMIT}.tar.gz -> ${P}.tar.gz
	https://github.com/open-telemetry/opentelemetry-proto/archive/refs/tags/v${OTEL_PROTO_PV}.tar.gz
		-> opentelemetry-proto-${OTEL_PROTO_PV}.tar.gz
"
S="${WORKDIR}/${MY_PN}-${COMMIT}"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="amd64"

# Built against Gentoo's own net-libs/grpc and dev-cpp/opentelemetry-cpp
# instead of the upstream default of vendoring/rebuilding grpc+protobuf+abseil
# via CMake FetchContent (see NGX_OTEL_CMAKE_OPTS in src_configure below).
COMMON_DEPEND="
	>=dev-cpp/opentelemetry-cpp-1.24.0:=[otlp,grpc]
	net-libs/grpc:=
	dev-libs/protobuf:=
	dev-cpp/abseil-cpp:=
"
DEPEND+=" ${COMMON_DEPEND}"
RDEPEND+=" ${COMMON_DEPEND}"
BDEPEND+="
	dev-build/cmake
	virtual/pkgconfig
"

src_configure() {
	# Tell nginx-otel's "config" hook (which shells out to cmake) to use
	# find_package() against system grpc/opentelemetry-cpp rather than its
	# default of FetchContent-ing and building its own copies from source.
	# NGX_OTEL_PROTO_DIR must be supplied explicitly in "package" SDK mode,
	# since it is otherwise only derived from the (unused) FetchContent tree.
	local -x NGX_OTEL_CMAKE_OPTS="
		-DNGX_OTEL_GRPC=package
		-DNGX_OTEL_SDK=package
		-DNGX_OTEL_PROTO_DIR=${WORKDIR}/opentelemetry-proto-${OTEL_PROTO_PV}
	"
	nginx-module_src_configure
}
