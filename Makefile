ROOTDIR=$(shell pwd)
OCAMLMAKEFILE=OCamlMakefile
include Makefile.config

SOURCES= servlet.ml
OCAMLC= ocamljava
INCDIRS= +cadmium

RESULT= app
OCAMLBCFLAGS=-java-package $(PKGNAME) $(foreach lib,$(JAVALIBS),-classpath $(PATH_$(lib))) \
	-I +cadmium -provider fr.x9c.cadmium.primitives.cadmiumservlet.Servlets
TRASH=*.jo *.jar *.war appengine-web.xml

.PHONY: all
all: appengineml.war.ae
	@ :

runsdk:
	$(APPENGINE_SDK_BIN) appengineml.war.ae

runlive:
	$(APPENGINE_APPCFG_BIN) update appengineml.war.ae

%.war: $(SOURCES:%.ml=%.cmj)
	ocamljava $(OCAMLBCFLAGS) -o $@ -standalone \
	  -additional-jar $(PATH_ocamlrun-servlet) -I $(dir $(PATH_ocamlrun)) \
	  -servlet web.xml cadmiumLibrary.cmja cadmiumServletLibrary.cmja $^

appengine-web.xml: appengine-web.xml.in
	sed -e 's/@APPENGINE_NAME@/$(APPENGINE_NAME)/g' < $< > $@

%.war.ae: appengine-web.xml %.war
	rm -rf $@ && mkdir -p $@
	cd $@ && unzip ../$*.war
	cp $< $@/WEB-INF/

include $(OCAMLMAKEFILE)
