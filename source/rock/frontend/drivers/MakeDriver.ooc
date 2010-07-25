import io/[File, FileWriter], text/Buffer

import structs/[List, ArrayList, HashMap]
import ../[BuildParams, Target]
import ../compilers/AbstractCompiler
import ../../middle/Module
import ../../backend/cnaughty/CGenerator
import Driver, SequenceDriver

/**
   Generate the .c source files in a build/ directory, along with a
   Makefile that allows to build a version of your program without any
   ooc-related dependency.

   :author: Amos Wenger (nddrylliog)
 */
MakeDriver: class extends SequenceDriver {

    builddir, makefile, originalOutPath: File

    init: func (.params) { super(params) }

    setup: func {
        wasSetup := static false
        if(wasSetup) return

        // no lib-caching for the make driver!
        params libcache = false

        // keeping them for later (ie. Makefile invocation)
        params clean = false

        // build/
        builddir = File new("build")

        // build/rock_tmp/
        originalOutPath = params outPath
        params outPath = File new(builddir, params outPath getPath())
        params outPath mkdirs()

        // build/Makefile
        makefile = File new(builddir, "Makefile")

        wasSetup = true
    }

	compile: func (module: Module) -> Int {

        if(params verbose) {
           "Make driver" println()
        }

        setup()

        params outPath mkdirs()

        toCompile := module collectDeps()
        for(candidate in toCompile) {
            CGenerator new(params, candidate) write()
        }

        copyLocalHeaders(module, params, ArrayList<Module> new())

        printf("Writing to %s\n", makefile path)
        fW := FileWriter new(makefile)

        fW write("# Makefile generated by rock, the ooc compiler written in ooc\n\n")
        fW write("CC=%s\n" format(params compiler executablePath))

        fW write("# try to determine the OS and architecture\n")
        fW write("OS := $(shell uname -s)\n")
        fW write("MACHINE := $(shell uname -m)\n")
        fW write("ifeq ($(OS), Linux)\n")
        fW write("    ARCH=linux\n")
        fW write("else ifeq ($(OS), Darwin)\n")
        fW write("    ARCH=osx\n")
        fW write("else ifeq ($(OS), CYGWIN_NT-5.1)\n")
        fW write("    ARCH=win\n")
        fW write("else ifeq ($(OS), MINGW32_NT-5.1)\n")
        fW write("    ARCH=win\n")
        fW write("else\n")
        fW write("    $(shell echo \"OS ${OS} doesn't have pre-built Boehm GC packages. Please compile and install your own and recompile with GC_PATH=-lgc\")\n")
        fW write("endif\n")

        fW write("ifneq ($(ARCH), osx)\n")
        fW write("  ifeq ($(MACHINE), x86_64)\n")
        fW write("    ARCH:=${ARCH}64\n")
        fW write("  else\n")
        fW write("    ARCH:=${ARCH}32\n")
        fW write("  endif\n")
        fW write("endif\n")

        fW write("# this folder must contains libs/\n")
        fW write("ROCK_DIST?=.\n")

        fW write("# uncomment to link dynamically with the gc instead (e.g. -lgc)\n")
        fW write("#GC_PATH?=-lgc\n")
        fW write("GC_PATH?=${ROCK_DIST}/libs/${ARCH}/libgc.a\n")

        fW write("CFLAGS+=-I %s" format(originalOutPath getPath()))
        fW write(" -I ${ROCK_DIST}/libs/headers/")

        if(params debug) {
            fW write(" -g")
        }

        params compiler reset()
        iter := params compiler command iterator()
        iter next()
        while(iter hasNext?()) {
            fW write(" "). write(iter next())
        }

        for(define in params defines) {
            fW write(" -D"). write(define)
        }

        for(compilerArg in params compilerArgs) {
            fW write(" "). write(compilerArg)
        }

        for(incPath in params incPath getPaths()) {
            fW write(" -I "). write(incPath getPath())
        }

        fW write("\n")

        fW write("EXECUTABLE=")
        if(params binaryPath != "") {
            fW write(params binaryPath)
        } else {
            fW write(module simpleName)
        }
        fW write("\n")

        fW write("OBJECT_FILES:=")

        for(currentModule in toCompile) {
            printf("%p, %s\n", currentModule, currentModule fullName)
            path := File new(originalOutPath, currentModule getPath("")) getPath()
            fW write(path). write(".o ")
        }

        fW write("\n\n.PHONY: compile link\n\n")

        fW write("all: compile link\n\n")

        fW write("compile: ${OBJECT_FILES}")

        fW write("\n\t@echo \"Finished compiling for arch ${ARCH}\"\n")

        fW write("\n\n")

        oPaths := ArrayList<String> new()

        for(currentModule in toCompile) {
            path := File new(originalOutPath, currentModule getPath("")) getPath()
            oPath := path + ".o"  
            cPath := path + ".c"    
            oPaths add(oPath)

            fW write(oPath). write(": ").
               write(cPath). write(" ").
               write(path). write(".h ").
               write(path). write("-fwd.h\n")

            fW write("\t${CC} ${CFLAGS} -c %s -o %s\n" format(cPath, oPath))
        }

        fW write("\nlink: ${OBJECT_FILES}\n")

        fW write("\t${CC} ${CFLAGS} ${OBJECT_FILES} ")

        for(dynamicLib in params dynamicLibs) {
            fW write(" -l "). write(dynamicLib)
        }

        for(additional in params additionals) {
            fW write(" "). write(additional)
        }

        for(libPath in params libPath getPaths()) {
            fW write(" -L "). write(libPath getPath())
        }

        fW write(" -o ${EXECUTABLE}")

        libs := getFlagsFromUse(module)
        for(lib in libs) {
            fW write(" "). write(lib)
        }

        if(params enableGC) {
            fW write(" -lpthread ")
            if(params dynGC) {
                fW write("-lgc")
            } else {
                arch := params arch equals?("") ? Target getArch() : params arch
                Target toString(arch)
                fW write(" ${GC_PATH}")
            }
        }

        fW write("\n\n")

        fW close()
		
		return 0    
		
	}
	
}
