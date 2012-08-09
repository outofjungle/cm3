YIC       = /bin/yinst_create
YIC_OPTS  = --clean -t ${BUILDTYPE}
PERL      = /usr/local/bin/perl
IDENTITY  = /conf/dist_push_rsa
BUILDTYPE = test
PRINT_TAP = 0

.PHONY: package package-release clean all pkg

all: pkg

pkg:
	${YIC} ${YIC_OPTS} package/*.yicf

package:
	${YIC} --clean package/*.yicf

package-release:
	${YIC} --clean -r package/*.yicf

push_to_dist:
	dist_install chisel_builder_dt-*.tgz -batch -branch quarantine -group opspkg -identity $(IDENTITY) -headless

clean:
	rm -fr *.tgz *.tar.gz *.package
	@rm -rf doc
