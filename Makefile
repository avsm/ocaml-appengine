include Makefile.config

PWD := $(shell pwd)
SOURCES:= $(wildcard mlsrc/*.ml)

JAVALIBS=ocamlrun ocamlrun-servlet appengine-api-1.0-sdk-1.3.1

URI_ocamlrun= http://cadmium.x9c.fr/distrib/ocamlrun.jar
URI_ocamlrun-servlet= http://cadmium.x9c.fr/distrib/ocamlrun-servlet.jar
PATH_appengine= $(APPENGINE_SDK)/lib/user/appengine-api-1.0-sdk-$(APPENGINE_VERSION).jar

OBJDIR:=$(PWD)/obj
OBJSTAMP=$(OBJDIR)/.stamp

.PHONY: all dist
all: $(OBJDIR)/native.war.ae
	@:

$(OBJSTAMP):
	rm -rf $(OBJDIR)
	mkdir -p $(OBJDIR)
	@touch $@

# grab the JAR distfile either from a local path or a remote URL
$(OBJDIR)/%.jar: $(OBJSTAMP)
	rm -f $@
	if [ -z "$(PATH_$*)" ]; then wget -O $@ $(URL_$*); else cp $(PATH_$*) $@; fi
	@touch $@
	
PKGNAME= appengineml
OPTIONS= -java-package $(PKGNAME) $(JAVALIBS:%=-classpath $(OBJDIR)/%.jar) \
	 -I +cadmium -provider fr.x9c.cadmium.primitives.cadmiumservlet.Servlets

%.cmj: %.ml $(JAVALIBS:%=$(OBJDIR)/%.jar)
	ocamljava $(OPTIONS) -c -I +cadmium $<

$(OBJDIR)/appengine-web.xml: appengine-web.xml.in Makefile $(OBJSTAMP)
	sed -e 's/@APPENGINE_NAME@/$(APPENGINE_NAME)/g' < $< > $@

$(OBJDIR)/%.pre.war: $(SOURCES:%.ml=%.cmj)
	ocamljava $(OPTIONS) -o $@ -standalone \
	  -additional-jar $(OBJDIR)/ocamlrun-servlet.jar \
	  -I $(OBJDIR) -servlet $(PWD)/web.xml cadmiumLibrary.cmja cadmiumServletLibrary.cmja \
	  $(SOURCES:%.ml=%.cmj)

$(OBJDIR)/%.war.ae: $(OBJDIR)/appengine-web.xml $(OBJDIR)/%.pre.war
	rm -rf $@
	mkdir -p $@
	cd $@ && unzip $<
	cp $< $@/WEB-INF/

clean:
	rm -f mlsrc/*.cmj mlsrc/*.cmja mlsrc/*.cmi
	rm -rf $(OBJDIR)

.SECONDARY: $(JAVALIBS:%=$(OBJDIR)/%.jar)
