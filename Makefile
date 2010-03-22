ROOTDIR=$(shell pwd)
OCAMLMAKEFILE=OCamlMakefile
include Makefile.config

SOURCES= bridge.ml servlet.ml
OCAMLC= ocamljava
INCDIRS= +cadmium +site-lib/dyntype +site-lib/shelf +site-lib/orm
ANNOTATE= yes
RESULT= app
OCAMLBCFLAGS=-java-package $(PKGNAME) $(foreach lib,$(JAVALIBS),-classpath $(PATH_$(lib)))  \
	-I +cadmium -provider fr.x9c.cadmium.primitives.cadmiumservlet.Servlets
TRASH=*.jo *.jar *.war appengine-web.xml *.cmj

.PHONY: all depend
all: depend appengineml.war.ae 
	@ :

depend: 
	@ :

runsdk:
	$(APPENGINE_SDK_BIN) appengineml.war.ae

runlive:
	$(APPENGINE_LIVE_BIN) update appengineml.war.ae

%.war: $(SOURCES:%.ml=%.cmj)
	ocamljava $(OCAMLBCFLAGS) -o $@ -standalone \
	  -additional-jar $(PATH_ocamlrun-servlet) \
	  -additional-jar $(PATH_appengine) \
	  -additional-jar $(shell ocamlfind printconf path)/orm/orm_ae.jar \
	  -I $(dir $(PATH_ocamlrun)) -I +site-lib/dyntype -I +site-lib/shelf -I +site-lib/orm \
	  -servlet web.xml cadmiumLibrary.cmja cadmiumServletLibrary.cmja \
	  value.cmj type.cmj json.cmj orm.cmj \
	  $(SOURCES:%.ml=%.cmj)

appengine-web.xml: appengine-web.xml.in
	sed -e 's/@APPENGINE_NAME@/$(APPENGINE_NAME)/g' < $< > $@

%.war.ae: appengine-web.xml %.war
	rm -rf $@ && mkdir -p $@
	cd $@ && unzip ../$*.war
	cp $< $@/WEB-INF/
	find $@

include $(OCAMLMAKEFILE)
