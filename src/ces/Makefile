##----------------------------------------------------------------------------
# Created with genmake.pl v1.1 on Sat Jan  5 21:18:00 2008
# genmake.pl home: http://muquit.com/muquit/software/
# Copryright: GNU GPL (http://www.gnu.org/copyleft/gpl.html)
##----------------------------------------------------------------------------
rm=/bin/rm -f
FORT= ifort
FORT= mpif90
DEFS=
PROGNAME= perseus1
INCLUDES=  -I. #-I$(MKLINCLUDE)
LIBS= lib_vtk_io.o #-L$(MKLPATH)


DEFINES= $(INCLUDES) $(DEFS)
# FORTFLAGS= -O3 -coarray=distributed
# FORTFLAGS= -O3 -coarray -coarray-num-images=9
# FORTFLAGS= -O3 -coarray -coarray-num-images=4
# FORTFLAGS= -O3 -openmp
FORTFLAGS= -O2 -xHost #-CB -fpe:0 -traceback -check noarg_temp_created #-fpp
# FORTFLAGS= -O2 -xHost -mkl #-CB -fpe:0 -traceback -check noarg_temp_created #-fpp

# OBJS = dg_3D_geo_hydro_array_HLL.f90
# OBJS = dg_3D_geo_hydro_array_HLLC2.f90
# OBJS = dg_3D_geo_hydro_tracer2.f90
# OBJS = dg_3D_hydro_hall_LLF.f90
# OBJS = dg_2D_ic_hydro4.f90
# OBJS = dg_2D_comp_hydro_new.f90
# OBJS = dg_2D_comp_hydro2.f90
# OBJS = dg_2D_comp_hydro.f90
# OBJS = dg_3D_hydro_cubic_viscosity3.f90
# OBJS = dg_3D_hydro_cubic.f90
# OBJS = dg_3D_hydro_sean.f90
# OBJS = dg_3D_hydro_H2O_bitri.f90
# OBJS = dg_3D_hydro_H2O_bitri.f90
# OBJS = dg_3D_hydro_bitri_H2O.f90
# OBJS = dg_3D_hydro_bitri_version2.f90
# OBJS = dg_3D_hydro_bitri_version2_SEAN.f90
OBJS = dg_3D_hydro_bitri_version2_FH_test.f90
# OBJS = dg_3D_hydro_H2O_sourceless.f90
# OBJS = dg_3D_hydro.f90
# OBJS = dg_3D_hydro_quad.f90
# OBJS = dg_3D_hydro_cubic_sub_sample2.f90
# OBJS = dg_3D_hydro_cubic_speed_test.f90
# OBJS = dg_3D_incompressible_NS.f90
# OBJS = dg_3D_incompressible_NS_div_clean.f90
# OBJS = dg_3D_incompressible_Euler_div_clean.f90

.c.o:
	$(rm) $@
	$(FORT) $(FORTFLAGS) -c $*.f90

all: $(PROGNAME)

$(PROGNAME) : $(OBJS)
	$(FORT) $(FORTFLAGS) $(OBJS) $(LIBS) -o $(PROGNAME)
#	strip $(PROGNAME)
#	$(PROGNAME)
	mpiexec -n 16 $(PROGNAME)

clean:
	$(rm) $(OBJS) $(PROGNAME) core *~
