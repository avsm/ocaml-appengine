ROOTDIR=$(shell pwd)
OCAMLMAKEFILE=OCamlMakefile
include Makefile.config

SOURCES= appengine.ml bridge.ml servlet.ml
OCAMLC= ocamljava
INCDIRS= +cadmium +site-lib/dyntype +site-lib/shelf
ANNOTATE= yes
RESULT= app
OCAMLBCFLAGS=-java-package $(PKGNAME) $(foreach lib,$(JAVALIBS),-classpath $(PATH_$(lib))) -classpath . \
	-I +cadmium -provider fr.x9c.cadmium.primitives.cadmiumservlet.Servlets -provider pack/Appengine
TRASH=*.jo *.jar *.war appengine-web.xml appengine.ml appengine.mli pack/Appengine.java pack/Appengine.class appengine.c

.PHONY: all depend
all: depend appengineml.war.ae 
	@ :

depend: appengine.ml
	@ :

runsdk:
	$(APPENGINE_SDK_BIN) appengineml.war.ae

runlive:
	$(APPENGINE_LIVE_BIN) update appengineml.war.ae

appengine.ml appengine.mli pack/Appengine.java pack/Appengine.class appengine.c: appengine.nickel
	mkdir -p pack
	env CLASSPATH=$(PATH_ocamlwrap):$(PATH_appengine) java fr.x9c.nickel.Main --java-dir=pack --java-package=pack $<
	$(JAVAC) -target 1.6 -cp $(PATH_ocamlrun):$(PATH_appengine) pack/Appengine.java
	$(OCAMLC) -i -I +cadmium appengine.ml > appengine.mli
	$(OCAMLC) -c -I +cadmium appengine.mli

%.war: $(SOURCES:%.ml=%.cmj)
	ocamljava $(OCAMLBCFLAGS) -o $@ -standalone \
	  -additional-class pack/Appengine.class \
	  -additional-jar $(PATH_ocamlrun-servlet) \
	  -additional-jar $(PATH_appengine) \
	  -I $(dir $(PATH_ocamlrun)) -I +site-lib/dyntype -I +site-lib/shelf \
	  -servlet web.xml cadmiumLibrary.cmja cadmiumServletLibrary.cmja \
	  value.cmj type.cmj json.cmj \
	  $(SOURCES:%.ml=%.cmj)

appengine-web.xml: appengine-web.xml.in
	sed -e 's/@APPENGINE_NAME@/$(APPENGINE_NAME)/g' < $< > $@

%.war.ae: appengine-web.xml %.war
	rm -rf $@ && mkdir -p $@
	cd $@ && unzip ../$*.war
	cp $< $@/WEB-INF/
	mv $@/pack/* $@/WEB-INF/classes/pack/
	find $@

include $(OCAMLMAKEFILE)
