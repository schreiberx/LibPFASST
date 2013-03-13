#
# Makefile for libpfasst.
#

#
# config
#

FC     = mpif90 -f90=/home/memmett/gcc-4.8/bin/gfortran
FFLAGS = -fPIC -Wall -g -pg -Ibuild -Jbuild

STATIC = ar rcs
SHARED = /home/memmett/gcc-4.8/bin/gfortran -shared -Wl,-soname,pfasst

FSRC = $(shell ls src/*.f90)
OBJ  = $(subst src,build,$(FSRC:.f90=.o))

MKVERBOSE = 

#
# rules
#

all: libpfasst.so libpfasst.a

libpfasst.so: $(OBJ)
	$(SHARED) -o libpfasst.so $(OBJ)

libpfasst.a: $(OBJ)
	$(STATIC) libpfasst.a $(OBJ)

build/%.o: src/%.f90
ifdef MKVERBOSE
	$(FC) $(FFLAGS) -c $< $(OUTPUT_OPTION)
else
	@echo FC $(notdir $<)
	@$(FC) $(FFLAGS) -c $< $(OUTPUT_OPTION)
endif

#
# dependencies (generated by: python tools/f90_mod_deps.py --o-prefix build/ src/*.f90)
#

build/pfasst.o: build/pf_dtype.o build/pf_hooks.o build/pf_parallel.o build/pf_pfasst.o build/pf_version.o build/pf_implicit.o build/pf_explicit.o build/pf_imex.o
build/pf_dtype.o: 
build/pf_explicit.o: build/pf_dtype.o build/pf_timer.o
build/pf_hooks.o: build/pf_dtype.o build/pf_timer.o
build/pf_imex.o: build/pf_dtype.o build/pf_timer.o
build/pf_implicit.o: build/pf_dtype.o build/pf_timer.o
build/pf_interpolate.o: build/pf_dtype.o build/pf_restrict.o build/pf_timer.o
build/pf_mpi.o: build/pf_dtype.o build/pf_timer.o
build/pf_parallel.o: build/pf_dtype.o build/pf_interpolate.o build/pf_restrict.o build/pf_utils.o build/pf_timer.o build/pf_hooks.o
build/pf_pfasst.o: build/pf_dtype.o build/pf_utils.o build/pf_version.o build/pf_quadrature.o build/pf_mpi.o
build/pf_quadrature.o: build/pf_dtype.o build/sdc_quadrature.o
build/pf_restrict.o: build/pf_dtype.o build/pf_utils.o build/pf_timer.o
build/pf_timer.o: build/pf_dtype.o
build/pf_utils.o: build/pf_dtype.o
build/sdc_poly.o: 
build/sdc_quadrature.o: build/sdc_poly.o build/pf_dtype.o
